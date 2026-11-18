-- SPDX-License-Identifier: AGPL-3.0-or-later
local Device = require("device")
local UI = require("ui/uimanager")
local Input = require("ui/widget/container/inputcontainer")
local Geom = require("ui/geometry")
local Range = require("ui/gesturerange")
local Dialog = require("ui/widget/buttondialog")
local Info = require("ui/widget/infomessage")
local time = require("ui/time")
local M = require("doplo/model")
local G = require("doplo/generator")
local S = require("doplo/solver")
local Layout = require("doplo/layout")
local Paint = require("doplo/paint")
local band = require("bit").band
local Screen = Device.screen
local W = Input:extend({ name = "doplo_board", covers_fullscreen = true, stop_events_propagation = true })
local function message(text)
    UI:show(Info:new({ text = text }))
end
local function coord(i, n)
    return string.char(65 + (i - 1) % n) .. (math.floor((i - 1) / n) + 1)
end
local function maskText(mask, d)
    local t = {}
    for v = 0, d do
        if band(mask, 2 ^ v) ~= 0 then
            t[#t + 1] = M.valueText(v)
        end
    end
    return table.concat(t, ", ")
end
local function item(label, action)
    return { label, action }
end

function W:init()
    self.painter = Paint.new()
    self:layout()
    self.ges_events = {}
    for _, event in ipairs({ "Tap", "Hold" }) do
        self.ges_events[event] = { Range:new({
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
function W:layout()
    self.dimen = Geom:new({ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() })
    self.a = Layout.make(self.game.p, self.dimen.w, self.dimen.h, Device:hasFrontlight())
end
function W:use(id, game)
    self.id, self.game, self.dirty, self.reveal = id, game, false, false
    self:layout()
    UI:setDirty(self, "ui")
end
function W:onSetDimensions()
    self:layout()
    UI:setDirty(self, "ui")
end
W.onScreenResize = W.onSetDimensions
function W:paintTo(bb)
    if self.dimen.w ~= Screen:getWidth() or self.dimen.h ~= Screen:getHeight() then
        self:layout()
    end
    self.painter:draw(bb, self.a, self.game, self.reveal)
end
function W:refresh(b)
    UI:setDirty(self, "ui", b and Geom:new({ x = b.x, y = b.y, w = b.w, h = b.h }) or nil)
end
function W:cellDirty(i, clues)
    local a = self.a
    local b = Layout.cell(a, i)
    if not b then
        return
    end
    self:refresh(b)
    if clues then
        self:refresh(Layout.rect(b.x, a.gy - a.top, a.cell, a.top))
        self:refresh(Layout.rect(a.gx - a.left, b.y, a.left, a.cell))
    end
end
function W:afterChange(old)
    local g = self.game
    local moved = old ~= g.selected
    self:cellDirty(g.selected, moved)
    if moved then
        self:cellDirty(old, true)
    end
    local locksChanged = (g.p.givens[old] == -1) ~= (g.p.givens[g.selected] == -1)
    if locksChanged then
        self:refresh(self.a.panel)
    else
        self:refresh(self.a.info)
        for _, b in ipairs(self.a.buttons) do
            if b.id == "undo" or b.id == "redo" then
                self:refresh(b)
            end
        end
    end
end
function W:brightness()
    if Device:hasFrontlight() then
        UI:show(require("ui/widget/frontlightwidget"):new({}))
    else
        message("Brightness control is not available on this device.")
    end
end
function W:select(i)
    local old = self.game.selected
    if i ~= old then
        self.game.selected = i
        self.dirty = true
        self:afterChange(old)
    end
end
function W:edit(v, overridePencil)
    if self.reveal then
        return
    end
    local g = self.game
    if g:edit(g.selected, v, overridePencil == nil and g.pencil or overridePencil) then
        self.dirty = true
        self:flush()
        self:afterChange(g.selected)
        if g:solved() then
            message("Solved! Every row, column and clue is correct.")
        end
    end
end
function W:travel(redo)
    if self.reveal then
        return
    end
    local old = self.game.selected
    if self.game:travel(redo) then
        self.dirty = true
        self:flush()
        self:afterChange(old)
    end
end
function W:pencil()
    self.game.pencil = not self.game.pencil
    self.dirty = true
    self:flush()
    self:refresh(self.a.panel)
end
function W:flush()
    if not self.dirty then
        return true
    end
    local ok, err = self.owner.store:save(self.id, self.game)
    if ok then
        self.dirty = false
        self.saveWarning = nil
        return true
    end
    if self.saveWarning ~= err then
        self.saveWarning = err
        message("Progress could not be saved. Keep this puzzle open and free some space.\n" .. tostring(err))
    end
    return false
end
function W:onFlushSettings()
    self:flush()
end
function W:onSuspend()
    self:stopJob()
    self:flush()
end
function W:onCloseWidget()
    self:stopJob()
    self.painter:clear()
    self.owner.window = nil
end
function W:onLeave()
    if self:flush() then
        UI:close(self, "partial")
    end
    return true
end
function W:onPrevCell()
    self:select((self.game.selected - 2) % self.game.p.n ^ 2 + 1)
    return true
end
function W:onNextCell()
    self:select(self.game.selected % self.game.p.n ^ 2 + 1)
    return true
end

-- Buttons in these native dialogs close before their action opens another one.
function W:choose(title, options)
    local dialog, rows = nil, {}
    for i, row in ipairs(options) do
        rows[i] = {}
        for _, opt in ipairs(row) do
            local action = opt[2]
            rows[i][#rows[i] + 1] = {
                text = opt[1],
                callback = function()
                    UI:close(dialog)
                    if action then
                        action()
                    end
                end,
            }
        end
    end
    dialog = Dialog:new({ title = title, buttons = rows, width_factor = 0.89 })
    UI:show(dialog)
    return dialog
end
function W:rules()
    local p = self.game.p
    local opening = ("Each row and column contains %d filled blocks and each digit 1–%d once.\n\n"):format(
        p.blocks,
        p.n - p.blocks
    )
    local detail = p.kind == "classic"
            and "Only digits strictly between the two blocks contribute to the edge sum. Adjacent blocks give zero."
        or "Each clue is the sum of one uninterrupted run of digits. Read from left to right or top to bottom. Blocks separate runs. Extra blocks may touch each other or an edge."
    if p.n == 12 then
        detail = detail .. " This 12 × 12 size extends the published Plus rules."
    end
    message(
        opening
            .. detail
            .. "\n\nTap a cell, then a value. The enlarged cell below the board shows all its pencil marks. Tap it or hold a cell for a larger keypad and its clues. Pencil toggles candidates. A dot marks a given. Page buttons move between cells while the board is open."
    )
end
function W:library(page)
    local saved = self.owner.store:list()
    local rows, per = {}, 5
    local pages = math.max(1, math.ceil(#saved / per))
    page = math.max(1, math.min(page or 1, pages))
    for k = (page - 1) * per + 1, math.min(#saved, page * per) do
        local s = saved[k]
        local state = s.solved and "Solved" or ("%d/%d"):format(s.filled, s.n ^ 2)
        local label = ("%s %d×%d · %s · %s\n%s  #%s"):format(
            M.name(s),
            s.n,
            s.n,
            s.level,
            state,
            os.date("%d %b %H:%M:%S", s.modified),
            s.id:sub(-4)
        )
        rows[#rows + 1] = { item(label, function()
            self.owner:resume(s.id)
        end) }
    end
    local nav = {}
    if page > 1 then
        nav[#nav + 1] = item("Previous", function()
            self:library(page - 1)
        end)
    end
    if page < pages then
        nav[#nav + 1] = item("Next", function()
            self:library(page + 1)
        end)
    end
    if #nav > 0 then
        rows[#rows + 1] = nav
    end
    rows[#rows + 1] = { item("Back", function()
        self:gameMenu()
    end) }
    self:choose(("Saved puzzles  ·  %d / %d"):format(page, pages), rows)
end
function W:gameMenu()
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
            item("How to play", function()
                self:rules()
            end),
        },
        { item("Back to puzzle") },
    })
end
function W:askReveal()
    self:choose("View the solution? Your entries and pencil marks will be kept.", {
        { item("Back"), item("Show solution", function()
            self.reveal = true
            self:refresh()
        end) },
    })
end
function W:newKind()
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
function W:newSize(kind)
    local rows = {}
    for _, size in ipairs(M.sizes[kind]) do
        local n = size
        local label = ("%d × %d"):format(n, n) .. (n == 12 and "  ·  Extended" or "")
        rows[#rows + 1] = { item(label, function()
            self:newLevel(M.config(kind, n))
        end) }
    end
    rows[#rows + 1] = { item("Back", function()
        self:newKind()
    end) }
    self:choose(M.name({ kind = kind }) .. "  ·  Choose a size", rows)
end
function W:newLevel(cfg)
    local prefilled = self.owner.settings:readSetting("prefilled_cells") == true
    local rows = { {}, {} }
    for j, level in ipairs(M.levels) do
        local chosen = level
        local row = rows[math.ceil(j / 2)]
        row[#row + 1] = item(chosen, function()
            self:generate(cfg, chosen)
        end)
    end
    rows[#rows + 1] = { item("Prefilled cells: " .. (prefilled and "On" or "Off"), function()
        self.owner.settings:saveSetting("prefilled_cells", not prefilled):flush()
        self:newLevel(cfg)
    end) }
    rows[#rows + 1] = { item("Back", function()
        self:newSize(cfg.kind)
    end) }
    self:choose(("%s %d×%d  ·  Difficulty"):format(M.name(cfg), cfg.n, cfg.n), rows)
end

-- Every long-running solver call also yields from inside its line search.
-- Timer cancellation drops the coroutine; it cannot install a stale puzzle.
function W:stopJob()
    local job = self.job
    if not job then
        return
    end
    self.job = nil
    UI:unschedule(job.step)
    UI:close(job.dialog)
end
function W:work(title, operation, done, fallback, seconds)
    self:stopJob()
    local job = { deadline = time.now() + time.s(seconds) }
    self.job = job
    local count, slice = 0, 0
    local function tick(cost)
        count = count + cost
        if count >= 128 then
            count = 0
            if time.now() >= slice then
                coroutine.yield()
            end
        end
    end
    local co = coroutine.create(function()
        return operation(tick)
    end)
    job.step = function()
        if self.job ~= job then
            return
        end
        if time.now() >= job.deadline then
            self:stopJob()
            if fallback then
                fallback()
            else
                done(nil, "budget")
            end
            return
        end
        slice = time.now() + time.ms(10)
        local ok, a, b = coroutine.resume(co)
        if not ok then
            self:stopJob()
            require("logger").warn("Doplo task", a)
            if fallback then
                fallback()
            else
                message("Could not finish this hint.")
            end
        elseif coroutine.status(co) == "dead" then
            self:stopJob()
            if not a and fallback then
                fallback()
            else
                done(a, b)
            end
        else
            UI:scheduleIn(0.02, job.step)
        end
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
    job.dialog = Dialog:new({ title = title, buttons = { buttons }, dismissable = false })
    UI:show(job.dialog)
    UI:scheduleIn(0.04, job.step)
end
function W:generate(cfg, level)
    local seed = os.time() + time.to_us(time.now()) % 2147483000
    local random = G.random(seed)
    local prefilled = self.owner.settings:readSetting("prefilled_cells") == true
    local function ready()
        self.owner:start(self.owner:ready(cfg, level))
    end
    self:work(("Generating %s %d×%d · %s…"):format(M.name(cfg), cfg.n, cfg.n, level), function(tick)
        for _ = 1, 80 do
            local p = G.attempt(cfg, level, random, { tick = tick, workLimit = 450000, prefilled = prefilled })
            if p then
                return p
            end
            tick(128)
        end
    end, function(p)
        self.owner:start(p)
    end, ready, 4)
end
function W:check()
    local g = self.game
    local status, axis, k, reason, value = M.check(g.p, g.board)
    if status == "solved" then
        message("Solved! Every row, column and clue is correct.")
        return
    end
    if status == "invalid" then
        local name = axis == "row" and ("Row " .. k) or ("Column " .. string.char(64 + k))
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
    for i, v in ipairs(g.board) do
        if v ~= -1 and v ~= g.p.solution[i] then
            self:select(i)
            message("Cell " .. coord(i, g.p.n) .. " conflicts with the unique solution. Recheck this entry.")
            return
        end
    end
    message(("All entries so far are consistent. %d cells remain."):format(g.p.n ^ 2 - g:filled()))
end
function W:hint()
    local g, p = self.game, self.game.p
    self:work("Finding a logical step…", function(tick)
        return S.hint(p, g.board, g.selected, { tick = tick, workLimit = 2000000 })
    end, function(h, why)
        if not h then
            local explanation = ({
                complete = "The puzzle is complete.",
                conflict = "An entry conflicts with the clues. Use Check to locate it.",
                budget = "The proof exceeded the hint time limit.",
                ambiguous = "No forced entry found.",
            })[why]
            message(explanation or "No hint available.")
            return
        end
        local i = h.index
        self:select(i)
        local r, c = math.floor((i - 1) / p.n) + 1, (i - 1) % p.n + 1
        local name = coord(i, p.n)
        local clue = ("Row %d (%s) and column %s (%s)"):format(
            r,
            table.concat(p.row[r], " · "),
            string.char(64 + c),
            table.concat(p.col[c], " · ")
        )
        local whyText
        if h.alternatives then
            whyText = "Trying each other candidate ("
                .. maskText(h.alternatives, p.n - p.blocks)
                .. ") makes a full solution impossible."
        else
            whyText = ("%s. After %d clue pass%s, the row allows {%s} and the column allows {%s}. Their only common value is %s."):format(
                clue,
                h.wave,
                h.wave == 1 and "" or "es",
                maskText(h.rowMask, p.n - p.blocks),
                maskText(h.colMask, p.n - p.blocks),
                M.valueText(h.value)
            )
        end
        self:choose(name .. " = " .. M.valueText(h.value) .. "\n\n" .. whyText, {
            { item("Back"), item("Place value", function()
                self:edit(h.value, false)
            end) },
        })
    end, nil, 7)
end
function W:largePad(i)
    self:select(i)
    local p = self.game.p
    local r, c = math.floor((i - 1) / p.n) + 1, (i - 1) % p.n + 1
    local title = ("Cell %s\nRow: %s\nColumn: %s"):format(
        coord(i, p.n),
        table.concat(p.row[r], " · "),
        table.concat(p.col[c], " · ")
    )
    if self.reveal or p.givens[i] ~= -1 then
        message(title .. "\nValue: " .. M.valueText(self.reveal and p.solution[i] or p.givens[i]))
        return
    end
    local marks = maskText(self.game.notes[i], p.n - p.blocks)
    title = title .. "\nPencil: " .. (marks ~= "" and marks or "None")
    local rows = {}
    for v = 1, p.n - p.blocks do
        local value = v
        if (v - 1) % 3 == 0 then
            rows[#rows + 1] = {}
        end
        local row = rows[#rows]
        row[#row + 1] = item(tostring(v), function()
            self:edit(value)
            if self.game.pencil then
                self:largePad(i)
            end
        end)
    end
    rows[#rows + 1] = { item("■", function()
        self:edit(0)
        if self.game.pencil then
            self:largePad(i)
        end
    end), item("Erase", function()
        self:edit(-1)
    end) }
    rows[#rows + 1] = {
        item(self.game.pencil and "Pencil: on" or "Pencil: off", function()
            self:pencil()
            self:largePad(i)
        end),
        item("Back"),
    }
    self:choose(title, rows)
end
function W:onHold(_, ges)
    local i = Layout.cellAt(self.a, ges.pos.x, ges.pos.y)
    if i then
        self:largePad(i)
    end
    return true
end
function W:onTap(_, ges)
    local x, y = ges.pos.x, ges.pos.y
    local i = Layout.cellAt(self.a, x, y)
    if i then
        self:select(i)
        return true
    end
    if Layout.inside(self.a.detail, x, y) then
        self:largePad(self.game.selected)
        return true
    end
    for _, b in ipairs(self.a.buttons) do
        if Layout.inside(b, x, y) then
            local id = b.id
            if id == "close" then
                self:onLeave()
            elseif id == "game" then
                self:gameMenu()
            elseif id == "brightness" then
                self:brightness()
            elseif self.reveal then
                return true
            elseif id == "undo" or id == "redo" then
                self:travel(id == "redo")
            elseif id:match("^v%-?%d+$") then
                self:edit(tonumber(id:sub(2)))
            else
                self[id](self)
            end
            break
        end
    end
    return true
end
return W
