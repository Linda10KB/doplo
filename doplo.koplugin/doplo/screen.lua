-- SPDX-License-Identifier: AGPL-3.0-or-later
local Device = require("device")
local UIManager = require("ui/uimanager")
local InputContainer = require("ui/widget/container/inputcontainer")
local Geometry = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local ButtonDialog = require("ui/widget/buttondialog")
local InfoMessage = require("ui/widget/infomessage")
local time = require("ui/time")
local Model = require("doplo/model")
local Generator = require("doplo/generator")
local Solver = require("doplo/solver")
local Layout = require("doplo/layout")
local Paint = require("doplo/paint")
local Celebration = require("doplo/celebration")
local DeviceSettings = require("doplo/device_settings")
local Tutorial = require("doplo/tutorial")
local band = require("bit").band
local DeviceScreen = Device.screen
local GameScreen = InputContainer:extend({ name = "doplo_board", covers_fullscreen = true, stop_events_propagation = true })

local function message(text)
    UIManager:show(InfoMessage:new({ text = text }))
end

local function cellLabel(cellIndex, size)
    return string.char(65 + (cellIndex - 1) % size) .. (math.floor((cellIndex - 1) / size) + 1)
end

local function candidateText(mask, maxDigit)
    local candidates = {}
    for value = 0, maxDigit do
        if band(mask, 2 ^ value) ~= 0 then
            candidates[#candidates + 1] = Model.valueText(value)
        end
    end
    return table.concat(candidates, ", ")
end

local function item(label, action)
    return { label, action }
end

function GameScreen:init()
    self.painter = Paint.new()
    self:layout()
    self.ges_events = {}
    for _, event in ipairs({ "Tap", "Hold" }) do
        self.ges_events[event] = { GestureRange:new({
            ges = event:lower(),
            range = function()
                return self.dimen
            end,
        }) }
    end
    if Device:hasKeys() then
        self.key_events.PrevCell = { { Device.input.group.PgBack } }
        self.key_events.NextCell = { { Device.input.group.PgFwd } }
        self.key_events.Leave = { { Device.input.group.Back } }
    end
end

function GameScreen:layout()
    self.dimen = Geometry:new({ x = 0, y = 0, w = DeviceScreen:getWidth(), h = DeviceScreen:getHeight() })
    self.geometry = Layout.make(self.game.p, self.dimen.w, self.dimen.h)
end

function GameScreen:use(id, game)
    self.id, self.game, self.dirty, self.reveal = id, game, false, false
    self:layout()
    UIManager:setDirty(self, "ui")
end

function GameScreen:onSetDimensions()
    self:layout()
    UIManager:setDirty(self, "ui")
end

GameScreen.onScreenResize = GameScreen.onSetDimensions

function GameScreen:paintTo(buffer)
    if self.dimen.w ~= DeviceScreen:getWidth() or self.dimen.h ~= DeviceScreen:getHeight() then
        self:layout()
    end
    self.painter:draw(buffer, self.geometry, self.game, self.reveal)
end

function GameScreen:refresh(rectangle)
    local refreshRegion
    if rectangle then
        refreshRegion = Geometry:new({ x = rectangle.x, y = rectangle.y, w = rectangle.w, h = rectangle.h })
    end
    UIManager:setDirty(self, "ui", refreshRegion)
end

function GameScreen:cellDirty(cellIndex, clues)
    local geometry = self.geometry
    local rectangle = Layout.cell(geometry, cellIndex)
    if not rectangle then
        return
    end
    self:refresh(rectangle)
    if clues then
        self:refresh(Layout.rect(rectangle.x, geometry.gy - geometry.top, geometry.cell, geometry.top))
        self:refresh(Layout.rect(geometry.gx - geometry.left, rectangle.y, geometry.left, geometry.cell))
    end
end

function GameScreen:afterChange(previousSelection)
    local game = self.game
    local moved = previousSelection ~= game.selected
    self:cellDirty(game.selected, moved)
    if moved then
        self:cellDirty(previousSelection, true)
    end

    local previousEditable = game.p.givens[previousSelection] == -1
    local selectedEditable = game.p.givens[game.selected] == -1
    if previousEditable ~= selectedEditable then
        self:refresh(self.geometry.panel)
        return
    end

    self:refresh(self.geometry.info)
    for _, button in ipairs(self.geometry.buttons) do
        if button.id == "undo" or button.id == "redo" then
            self:refresh(button)
        end
    end
end

function GameScreen:deviceSettings()
    DeviceSettings.show(self)
end

function GameScreen:howToPlay()
    Tutorial.show(self)
end

function GameScreen:celebrate()
    message(Celebration.next(self.owner.settings))
end

function GameScreen:select(cellIndex)
    local previousSelection = self.game.selected
    if cellIndex ~= previousSelection then
        self.game.selected = cellIndex
        self.dirty = true
        self:afterChange(previousSelection)
    end
end

function GameScreen:edit(value, overridePencil)
    if self.reveal then
        return
    end

    local game = self.game
    local pencilMode = game.pencil
    if overridePencil ~= nil then
        pencilMode = overridePencil
    end
    if not game:edit(game.selected, value, pencilMode) then
        return
    end

    self.dirty = true
    self:flush()
    self:afterChange(game.selected)
    if game:solved() then
        self:celebrate()
    end
end

function GameScreen:travel(redo)
    if self.reveal then
        return
    end

    local previousSelection = self.game.selected
    if not self.game:travel(redo) then
        return
    end

    self.dirty = true
    self:flush()
    self:afterChange(previousSelection)
    if self.game:solved() then
        self:celebrate()
    end
end

function GameScreen:pencil()
    self.game.pencil = not self.game.pencil
    self.dirty = true
    self:flush()
    self:refresh(self.geometry.panel)
end

function GameScreen:flush()
    if not self.dirty then
        return true
    end
    local ok, saveError = self.owner.store:save(self.id, self.game)
    if ok then
        self.dirty = false
        self.saveWarning = nil
        return true
    end
    if self.saveWarning ~= saveError then
        self.saveWarning = saveError
        message("Progress could not be saved. Keep this puzzle open and free some space.\n" .. tostring(saveError))
    end
    return false
end

function GameScreen:onFlushSettings()
    self:flush()
end

function GameScreen:onSuspend()
    self:stopJob()
    self:flush()
end

function GameScreen:onCloseWidget()
    self:stopJob()
    self.painter:clear()
    self.owner.window = nil
end

function GameScreen:onLeave()
    if self:flush() then
        UIManager:close(self, "partial")
    end
    return true
end

function GameScreen:onPrevCell()
    self:select((self.game.selected - 2) % self.game.p.n ^ 2 + 1)
    return true
end

function GameScreen:onNextCell()
    self:select(self.game.selected % self.game.p.n ^ 2 + 1)
    return true
end

-- Buttons in these native dialogs close before their action opens another one.
function GameScreen:choose(title, options)
    local dialog
    local rows = {}
    local function makeButton(option)
        local action = option[2]
        return {
            text = option[1],
            callback = function()
                UIManager:close(dialog)
                if action then
                    action()
                end
            end,
        }
    end

    for rowIndex, optionsRow in ipairs(options) do
        local buttons = {}
        for _, option in ipairs(optionsRow) do
            buttons[#buttons + 1] = makeButton(option)
        end
        rows[rowIndex] = buttons
    end
    dialog = ButtonDialog:new({ title = title, buttons = rows, width_factor = 0.89 })
    UIManager:show(dialog)
    return dialog
end

function GameScreen:library(page)
    local saved = self.owner.store:list()
    local rows, perPage = {}, 5
    local pages = math.max(1, math.ceil(#saved / perPage))
    page = math.max(1, math.min(page or 1, pages))
    for savedIndex = (page - 1) * perPage + 1, math.min(#saved, page * perPage) do
        local savedGame = saved[savedIndex]
        local state = savedGame.solved and "Solved" or ("%d/%d"):format(savedGame.filled, savedGame.n ^ 2)
        local label = ("%s %d×%d · %s · %s\n%s  #%s"):format(
            Model.name(savedGame),
            savedGame.n,
            savedGame.n,
            savedGame.level,
            state,
            os.date("%d %b %H:%M:%S", savedGame.modified),
            savedGame.id:sub(-4)
        )
        rows[#rows + 1] = { item(label, function()
            self.owner:resume(savedGame.id)
        end) }
    end
    local navigation = {}
    if page > 1 then
        navigation[#navigation + 1] = item("Previous", function()
            self:library(page - 1)
        end)
    end
    if page < pages then
        navigation[#navigation + 1] = item("Next", function()
            self:library(page + 1)
        end)
    end
    if #navigation > 0 then
        rows[#rows + 1] = navigation
    end
    rows[#rows + 1] = { item("Back", function()
        self:gameMenu()
    end) }
    self:choose(("Saved puzzles  ·  %d / %d"):format(page, pages), rows)
end

function GameScreen:gameMenu()
    if self.reveal then
        self.reveal = false
        self:refresh()
        return
    end
    self:choose("Doplo", {
        {
            item("New puzzle", function()
                self:newKind()
            end),
            item("Saved puzzles", function()
                self:library()
            end),
        },
        {
            item("Show solution", function()
                self:askReveal()
            end),
        },
        { item("Back to puzzle") },
    })
end

function GameScreen:askReveal()
    self:choose("View the solution? Your entries and pencil marks will be kept.", {
        { item("Back"), item("Show solution", function()
            self.reveal = true
            self:refresh()
        end) },
    })
end

function GameScreen:newKind()
    self:choose("New puzzle  ·  Choose a game", {
        {
            item("Doplo", function()
                self:newSize("classic")
            end),
            item("Doplo Plus", function()
                self:newSize("plus")
            end),
        },
        { item("Back", function()
            self:gameMenu()
        end) },
    })
end

function GameScreen:newSize(kind)
    local rows = {}
    for _, size in ipairs(Model.sizes[kind]) do
        local selectedSize = size
        local label = ("%d × %d"):format(selectedSize, selectedSize) .. (selectedSize == 12 and "  ·  Extended" or "")
        rows[#rows + 1] = { item(label, function()
            self:newLevel(Model.config(kind, selectedSize))
        end) }
    end
    rows[#rows + 1] = { item("Back", function()
        self:newKind()
    end) }
    self:choose(Model.name({ kind = kind }) .. "  ·  Choose a size", rows)
end

function GameScreen:newLevel(configuration)
    local prefilled = self.owner.settings:readSetting("prefilled_cells") == true
    local rows = { {}, {} }
    for levelIndex, level in ipairs(Model.levels) do
        local chosen = level
        local row = rows[math.ceil(levelIndex / 2)]
        row[#row + 1] = item(chosen, function()
            self:generate(configuration, chosen)
        end)
    end
    rows[#rows + 1] = { item("Prefilled cells: " .. (prefilled and "On" or "Off"), function()
        self.owner.settings:saveSetting("prefilled_cells", not prefilled):flush()
        self:newLevel(configuration)
    end) }
    rows[#rows + 1] = { item("Back", function()
        self:newSize(configuration.kind)
    end) }
    self:choose(("%s %d×%d  ·  Difficulty"):format(Model.name(configuration), configuration.n, configuration.n), rows)
end

-- Every long-running solver call also yields from inside its line search.
-- Timer cancellation drops the coroutine; it cannot install a stale puzzle.
function GameScreen:stopJob()
    local job = self.job
    if not job then
        return
    end
    self.job = nil
    UIManager:unschedule(job.step)
    UIManager:close(job.dialog)
end

function GameScreen:finishJob(job, result, reason)
    self:stopJob()
    if not result and job.fallback then
        job.fallback()
        return
    end
    job.done(result, reason)
end

function GameScreen:stepJob(job)
    if self.job ~= job then
        return
    end
    if time.now() >= job.deadline then
        self:finishJob(job, nil, "budget")
        return
    end

    job.sliceDeadline = time.now() + time.ms(10)
    local resumed, result, reason = coroutine.resume(job.coroutine)
    if not resumed then
        self:stopJob()
        require("logger").warn("Doplo task", result)
        if job.fallback then
            job.fallback()
        else
            message("Could not finish this hint.")
        end
        return
    end
    if coroutine.status(job.coroutine) == "dead" then
        self:finishJob(job, result, reason)
        return
    end
    UIManager:scheduleIn(0.02, job.step)
end

function GameScreen:work(title, operation, done, fallback, seconds)
    self:stopJob()
    local job = {
        deadline = time.now() + time.s(seconds),
        sliceDeadline = 0,
        done = done,
        fallback = fallback,
    }
    self.job = job

    local workCount = 0
    local function tick(cost)
        workCount = workCount + cost
        if workCount < 128 then
            return
        end
        workCount = 0
        if time.now() >= job.sliceDeadline then
            coroutine.yield()
        end
    end
    job.coroutine = coroutine.create(function()
        return operation(tick)
    end)
    job.step = function()
        self:stepJob(job)
    end

    local buttons = { {
        text = "Cancel",
        callback = function()
            self:stopJob()
        end,
    } }
    if fallback then
        buttons[#buttons + 1] = {
            text = "Play ready puzzle",
            callback = function()
                self:stopJob()
                fallback()
            end,
        }
    end
    job.dialog = ButtonDialog:new({ title = title, buttons = { buttons }, dismissable = false })
    UIManager:show(job.dialog)
    UIManager:scheduleIn(0.04, job.step)
end

function GameScreen:generate(configuration, level)
    local seed = os.time() + time.to_us(time.now()) % 2147483000
    local random = Generator.random(seed)
    local prefilled = self.owner.settings:readSetting("prefilled_cells") == true
    local function ready()
        self.owner:start(self.owner:ready(configuration, level))
    end
    self:work(("Generating %s %d×%d · %s…"):format(Model.name(configuration), configuration.n, configuration.n, level), function(tick)
        for _ = 1, 80 do
            local puzzle = Generator.attempt(configuration, level, random, { tick = tick, workLimit = 450000, prefilled = prefilled })
            if puzzle then
                return puzzle
            end
            tick(128)
        end
    end, function(puzzle)
        self.owner:start(puzzle)
    end, ready, 4)
end

function GameScreen:check()
    local game = self.game
    local status, axis, lineIndex, reason, value = Model.check(game.p, game.board)
    if status == "solved" then
        self:celebrate()
        return
    end
    if status == "invalid" then
        local name = axis == "row" and ("Row " .. lineIndex) or ("Column " .. string.char(64 + lineIndex))
        local why = ({
            sums = "The sums do not match the edge clues.",
            blocks = "The block count is impossible.",
            duplicate = "The digit " .. tostring(value) .. " appears twice.",
            given = "A fixed clue has changed.",
            range = "A value is outside the allowed range.",
        })[reason]
        message(name .. "\n" .. why)
        return
    end
    for cellIndex, value in ipairs(game.board) do
        if value ~= -1 and value ~= game.p.solution[cellIndex] then
            self:select(cellIndex)
            message("Cell " .. cellLabel(cellIndex, game.p.n) .. " conflicts with the unique solution. Recheck this entry.")
            return
        end
    end
    message(("All entries so far are consistent. %d cells remain."):format(game.p.n ^ 2 - game:filled()))
end

function GameScreen:hint()
    local game, puzzle = self.game, self.game.p
    self:work("Finding a logical step…", function(tick)
        return Solver.hint(puzzle, game.board, game.selected, { tick = tick, workLimit = 2000000 })
    end, function(hint, why)
        if not hint then
            local explanation = ({
                complete = "The puzzle is complete.",
                conflict = "An entry conflicts with the clues. Use Check to locate it.",
                budget = "The proof exceeded the hint time limit.",
                ambiguous = "No forced entry found.",
            })[why]
            message(explanation or "No hint available.")
            return
        end
        local cellIndex = hint.index
        self:select(cellIndex)
        local rowIndex, columnIndex = math.floor((cellIndex - 1) / puzzle.n) + 1, (cellIndex - 1) % puzzle.n + 1
        local name = cellLabel(cellIndex, puzzle.n)
        local clue = ("Row %d (%s) and column %s (%s)"):format(
            rowIndex,
            table.concat(puzzle.row[rowIndex], " · "),
            string.char(64 + columnIndex),
            table.concat(puzzle.col[columnIndex], " · ")
        )
        local whyText
        if hint.alternatives then
            whyText = "Trying each other candidate ("
                .. candidateText(hint.alternatives, puzzle.n - puzzle.blocks)
                .. ") makes a full solution impossible."
        else
            whyText = ("%s. After %d clue pass%s, the row allows {%s} and the column allows {%s}. Their only common value is %s."):format(
                clue,
                hint.wave,
                hint.wave == 1 and "" or "es",
                candidateText(hint.rowMask, puzzle.n - puzzle.blocks),
                candidateText(hint.colMask, puzzle.n - puzzle.blocks),
                Model.valueText(hint.value)
            )
        end
        self:choose(name .. " = " .. Model.valueText(hint.value) .. "\n\n" .. whyText, {
            { item("Back"), item("Place value", function()
                self:edit(hint.value, false)
            end) },
        })
    end, nil, 7)
end

function GameScreen:largePad(cellIndex)
    self:select(cellIndex)
    local puzzle = self.game.p
    local rowIndex, columnIndex = math.floor((cellIndex - 1) / puzzle.n) + 1, (cellIndex - 1) % puzzle.n + 1
    local title = ("Cell %s\nRow: %s\nColumn: %s"):format(
        cellLabel(cellIndex, puzzle.n),
        table.concat(puzzle.row[rowIndex], " · "),
        table.concat(puzzle.col[columnIndex], " · ")
    )
    if self.reveal or puzzle.givens[cellIndex] ~= -1 then
        message(title .. "\nValue: " .. Model.valueText(self.reveal and puzzle.solution[cellIndex] or puzzle.givens[cellIndex]))
        return
    end
    local marks = candidateText(self.game.notes[cellIndex], puzzle.n - puzzle.blocks)
    title = title .. "\nPencil: " .. (marks ~= "" and marks or "None")
    local rows = {}
    for digit = 1, puzzle.n - puzzle.blocks do
        local value = digit
        if (value - 1) % 3 == 0 then
            rows[#rows + 1] = {}
        end
        local row = rows[#rows]
        row[#row + 1] = item(tostring(value), function()
            self:edit(value)
            if self.game.pencil then
                self:largePad(cellIndex)
            end
        end)
    end
    rows[#rows + 1] = { item("■", function()
        self:edit(0)
        if self.game.pencil then
            self:largePad(cellIndex)
        end
    end), item("Erase", function()
        self:edit(-1)
    end) }
    rows[#rows + 1] = {
        item(self.game.pencil and "Pencil: on" or "Pencil: off", function()
            self:pencil()
            self:largePad(cellIndex)
        end),
        item("Back"),
    }
    self:choose(title, rows)
end

function GameScreen:onHold(_, gesture)
    local cellIndex = Layout.cellAt(self.geometry, gesture.pos.x, gesture.pos.y)
    if cellIndex then
        self:largePad(cellIndex)
    end
    return true
end

-- These controls remain available while viewing the read-only solution.
local navigationActions = {
    close = GameScreen.onLeave,
    game = GameScreen.gameMenu,
    device = GameScreen.deviceSettings,
    help = GameScreen.howToPlay,
}

function GameScreen:activateButton(buttonId)
    local navigate = navigationActions[buttonId]
    if navigate then
        navigate(self)
        return
    end
    if self.reveal then
        return
    end
    if buttonId == "undo" or buttonId == "redo" then
        self:travel(buttonId == "redo")
        return
    end
    if buttonId:match("^v%-?%d+$") then
        self:edit(tonumber(buttonId:sub(2)))
        return
    end
    self[buttonId](self)
end

function GameScreen:onTap(_, gesture)
    local x, y = gesture.pos.x, gesture.pos.y
    local cellIndex = Layout.cellAt(self.geometry, x, y)
    if cellIndex then
        self:select(cellIndex)
        return true
    end
    if Layout.inside(self.geometry.detail, x, y) then
        self:largePad(self.game.selected)
        return true
    end
    for _, button in ipairs(self.geometry.buttons) do
        if Layout.inside(button, x, y) then
            self:activateButton(button.id)
            return true
        end
    end
    return true
end

return GameScreen
