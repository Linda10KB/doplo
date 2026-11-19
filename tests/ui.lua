-- Headless interaction/rendering regression tests. Native KOReader smoke tests
-- remain in ko_smoke.lua; these doubles exercise our own event routing only.
package.path = "doplo.koplugin/?.lua;" .. package.path

local function class(prototype)
    prototype = prototype or {}
    prototype.__index = prototype

    function prototype:extend(properties)
        return class(setmetatable(properties, self))
    end

    function prototype:new(properties)
        local instance = setmetatable(properties or {}, self)
        instance.key_events = {}
        if instance.init then
            instance:init()
        end
        return instance
    end

    return prototype
end

local ui = { stack = {}, dirty = {}, scheduled = {}, refreshModes = {} }

function ui:show(widget)
    self.stack[#self.stack + 1] = widget
end

function ui:close(widget)
    for index = #self.stack, 1, -1 do
        if self.stack[index] == widget then
            table.remove(self.stack, index)
        end
    end
end

function ui:setDirty(_, mode, region)
    self.dirty[#self.dirty + 1] = region or true
    self.refreshModes[#self.refreshModes + 1] = mode
end

function ui:scheduleIn(_, callback)
    self.scheduled[callback] = true
end

function ui:unschedule(callback)
    self.scheduled[callback] = nil
end

local deviceScreen = { w = 600, h = 800 }

function deviceScreen:getWidth()
    return self.w
end

function deviceScreen:getHeight()
    return self.h
end

function deviceScreen:scaleBySize(value)
    return value
end

local device = { screen = deviceScreen, light = true }

function device:hasKeys()
    return false
end

function device:hasFrontlight()
    return self.light
end

package.loaded.device = device
package.loaded["ui/uimanager"] = ui
for _, moduleName in ipairs({
    "ui/widget/container/inputcontainer",
    "ui/widget/container/widgetcontainer",
    "ui/geometry",
    "ui/gesturerange",
    "ui/widget/buttondialog",
    "ui/widget/infomessage",
}) do
    package.loaded[moduleName] = class()
end

package.loaded["ui/widget/frontlightwidget"] = class({ name = "native_frontlight" })
package.loaded["ui/time"] = {
    now = function()
        return 0
    end,
    s = function(seconds)
        return seconds
    end,
    ms = function(milliseconds)
        return milliseconds / 1000
    end,
    to_us = function(seconds)
        return seconds * 1000000
    end,
}
package.loaded["ffi/blitbuffer"] = {
    COLOR_BLACK = 0,
    COLOR_WHITE = 255,
    Color8 = function(value)
        return value
    end,
}
package.loaded["ui/font"] = {
    getFace = function(_, name, size)
        return { name = name, size = size }
    end,
}

local TextWidget = class()

function TextWidget:getSize()
    return { w = #self.text * self.face.size * 0.56, h = self.face.size }
end

function TextWidget:paintTo(buffer, x, y)
    buffer.texts[#buffer.texts + 1] = {
        text = self.text,
        x = x,
        y = y,
        size = self.face.size,
        color = self.fgcolor,
    }
end

function TextWidget:free() end

package.loaded["ui/widget/textwidget"] = TextWidget

local GameScreen = require("doplo/screen")
local Model = require("doplo/model")
local Generator = require("doplo/generator")
local Game = require("doplo/game")
local Layout = require("doplo/layout")
local settingValues = {}
local saveCount = 0
local settings = {}

function settings:readSetting(key, default)
    if settingValues[key] == nil then
        return default
    end
    return settingValues[key]
end

function settings:saveSetting(key, value)
    settingValues[key] = value
    return self
end

function settings:flush()
    return self
end

local owner = {
    settings = settings,
    store = {
        save = function()
            saveCount = saveCount + 1
            return true
        end,
    },
}
local puzzle = Generator.candidate(Model.config("plus", 11), Generator.random(642), 0)
puzzle.level = "Hard"
local gameScreen = GameScreen:new({ owner = owner, id = "test", game = Game.new(puzzle) })

local function top()
    return ui.stack[#ui.stack]
end

local function tap(rectangle, window)
    (window or gameScreen):onTap(nil, {
        pos = { x = rectangle.x + rectangle.w / 2, y = rectangle.y + rectangle.h / 2 },
    })
end

local function button(id, window)
    window = window or gameScreen
    for _, control in ipairs(window.geometry.buttons) do
        if control.id == id then
            tap(control, window)
            return
        end
    end
    error("Missing button " .. id)
end

local function findChoice(label)
    for _, row in ipairs(top().buttons) do
        for _, option in ipairs(row) do
            if option.text == label then
                return option
            end
        end
    end
end

local function choose(label)
    local option = assert(findChoice(label), "Missing choice " .. label)
    option.callback()
end

local function newBuffer()
    local buffer = { rects = {}, texts = {} }

    function buffer:paintRect(x, y, width, height, color)
        self.rects[#self.rects + 1] = { x, y, width, height, color }
    end

    function buffer:paintBorder(x, y, width, height, thickness, color)
        self:paintRect(x, y, width, thickness, color)
        self:paintRect(x, y + height - thickness, width, thickness, color)
        self:paintRect(x, y, thickness, height, color)
        self:paintRect(x + width - thickness, y, thickness, height, color)
    end

    function buffer:pixel(x, y)
        for index = #self.rects, 1, -1 do
            local rectangle = self.rects[index]
            local insideX = x >= rectangle[1] and x < rectangle[1] + rectangle[3]
            local insideY = y >= rectangle[2] and y < rectangle[2] + rectangle[4]
            if insideX and insideY then
                return rectangle[5]
            end
        end
    end

    return buffer
end

local function test(label, run)
    run()
    print("PASS " .. label)
end

test("device settings, native brightness and solution-view access", function()
    for _, reveal in ipairs({ false, true }) do
        gameScreen.reveal = reveal
        button("device")
        assert(top().title == "Device settings")
        choose("Brightness")
        assert(top().name == "native_frontlight")
        ui:close(top())
    end
    gameScreen.reveal = false

    device.light = false
    gameScreen:layout()
    button("device")
    assert(not findChoice("Brightness"))
    assert(findChoice("Rotate 90°"))
    choose("Refresh screen")
    assert(ui.refreshModes[#ui.refreshModes] == "full")
    assert(saveCount == 0)
    device.light = true
    gameScreen:layout()
end)

test("standalone help in play and solution views without changing the game", function()
    local initialBoard = Model.copy(gameScreen.game.board)
    local initialNotes = Model.copy(gameScreen.game.notes)
    local initialSelection = gameScreen.game.selected
    local initialPencil = gameScreen.game.pencil

    for _, reveal in ipairs({ false, true }) do
        gameScreen.reveal = reveal
        button("help")
        assert(top().title:find("How to play", 1, true))
        choose("Doplo")
        choose("1")
        assert(top().title:find("Not quite.", 1, true))
        choose("2")
        assert(top().title:find("Correct!", 1, true))
        choose("Back to puzzle")

        button("help")
        choose("Doplo Plus")
        choose("5")
        choose("Next")
        assert(top().title:find("Practice 2/4", 1, true))
        choose("Back to puzzle")
        assert(gameScreen.reveal == reveal)
    end

    gameScreen.reveal = false
    assert(Model.equal(gameScreen.game.board, initialBoard))
    assert(Model.equal(gameScreen.game.notes, initialNotes))
    assert(gameScreen.game.selected == initialSelection and gameScreen.game.pencil == initialPencil)
    assert(saveCount == 0 and #ui.stack == 0)
end)

test("filled blocks, enlarged notes, dialog editing, undo and refreshes", function()
    button("pencil")
    button("v1")
    button("v8")
    button("v0")
    assert(gameScreen.game.notes[1] == 259 and saveCount == 4)

    local buffer = newBuffer()
    gameScreen:paintTo(buffer)
    local largeNotes = {}
    for _, text in ipairs(buffer.texts) do
        if Layout.inside(gameScreen.geometry.detail, text.x, text.y) then
            largeNotes[text.text] = true
            assert(text.size >= 20)
        end
    end
    assert(largeNotes["1"] and largeNotes["8"])
    local detail = gameScreen.geometry.detail
    assert(buffer:pixel(detail.x + detail.w * 5 / 6, detail.y + detail.h * 5 / 6) == 0)

    ui.dirty = {}
    button("undo")
    assert(gameScreen.game.notes[1] == 258)
    local detailRefreshed = false
    for _, region in ipairs(ui.dirty) do
        if region ~= true and region.x == gameScreen.geometry.info.x and region.y == gameScreen.geometry.info.y then
            detailRefreshed = true
        end
    end
    assert(detailRefreshed)
    button("redo")
    tap(gameScreen.geometry.detail)
    assert(top().title:find("Pencil: ■, 1, 8", 1, true))
    choose("2")
    assert(gameScreen.game.notes[1] == 263)
    assert(top().title:find("Pencil: ■, 1, 2, 8", 1, true))
    choose("Back")

    button("pencil")
    button("v0")
    buffer = newBuffer()
    gameScreen:paintTo(buffer)
    local cell = Layout.cell(gameScreen.geometry, 1)
    for _, offset in ipairs({ 0.3, 0.5, 0.7 }) do
        assert(buffer:pixel(cell.x + cell.w * offset, cell.y + cell.h * offset) == 0)
    end
    assert(buffer:pixel(detail.x + detail.w / 2, detail.y + detail.h / 2) == 0)
    assert(buffer:pixel(cell.x + 2, cell.y + 2) == 255) -- Selection stays visible on a black block.
    button("v-1")
    assert(gameScreen.game.board[1] == -1 and gameScreen.game.notes[1] == 0)
end)

test("full-board navigation, new sizes and persistent prefill toggle", function()
    gameScreen:select(puzzle.n * puzzle.n)
    gameScreen:onNextCell()
    assert(gameScreen.game.selected == 1 and gameScreen.geometry.span == puzzle.n)
    gameScreen:onPrevCell()
    assert(gameScreen.game.selected == puzzle.n * puzzle.n)
    assert(gameScreen.geometry.firstCol == 1 and gameScreen.geometry.firstRow == 1)

    gameScreen:newLevel(Model.config("classic", 8))
    choose("Prefilled cells: Off")
    assert(settingValues.prefilled_cells == true)
    choose("Prefilled cells: On")
    assert(settingValues.prefilled_cells == false)
    choose("Back")
    choose("7 × 7")
    assert(top().title:find("Doplo 7×7", 1, true))
    ui.stack = {}

    gameScreen:newSize("plus")
    choose("11 × 11")
    assert(top().title:find("Doplo Plus 11×11", 1, true))
    ui.stack = {}
end)

-- Ready puzzles and cancellation must retain the selected starting mode.
package.loaded.datastorage = {}
package.loaded.luasettings = {}
package.loaded["doplo/store"] = {}
local Plugin = dofile("doplo.koplugin/main.lua")
owner.ready = Plugin.ready
owner.start = function(_, nextPuzzle)
    owner.started = nextPuzzle
end

test("missing start preference defaults to empty bank and generated puzzles", function()
    settingValues.prefilled_cells = nil
    local initial = owner:ready(Model.config("classic", 5), "Easy")
    assert(initial.prefilled == false and Game.new(initial):filled() == 0)

    local originalAttempt = Generator.attempt
    Generator.attempt = function(config, level, _, options)
        assert(options.prefilled == false)
        local generated = Generator.candidate(config, Generator.random(642), 0)
        generated.level = level
        generated.prefilled = options.prefilled
        return generated
    end
    gameScreen:generate(Model.config("classic", 5), "Easy")
    gameScreen.job.step()
    Generator.attempt = originalAttempt

    assert(not gameScreen.job and owner.started.prefilled == false)
    assert(Game.new(owner.started):filled() == 0)
    owner.started = nil
end)

local function checkBankModes(kind, size, level)
    for _, prefilled in ipairs({ false, true }) do
        settingValues.prefilled_cells = prefilled
        local ready = owner:ready(Model.config(kind, size), level)
        assert(ready.kind == kind and ready.n == size and ready.level == level)
        assert(ready.prefilled == prefilled)
        assert(prefilled or Game.new(ready):filled() == 0)
    end
end

test("ready-puzzle coverage, cancellation and empty-start timeout fallback", function()
    for _, kind in ipairs({ "classic", "plus" }) do
        for _, size in ipairs(Model.sizes[kind]) do
            for _, level in ipairs(Model.levels) do
                checkBankModes(kind, size, level)
            end
        end
    end

    settingValues.prefilled_cells = false
    gameScreen:generate(Model.config("classic", 8), "Expert")
    choose("Play ready puzzle")
    assert(not gameScreen.job and owner.started.prefilled == false)
    assert(Game.new(owner.started):filled() == 0)
    owner.started = nil

    gameScreen:generate(Model.config("plus", 11), "Easy")
    choose("Cancel")
    assert(not gameScreen.job and owner.started == nil)

    gameScreen:generate(Model.config("plus", 11), "Easy")
    gameScreen.job.deadline = -1
    gameScreen.job.step()
    assert(not gameScreen.job and owner.started.prefilled == false)
    assert(Game.new(owner.started):filled() == 0)
end)

test("different congratulations for completion, Check, undo/redo and reloading", function()
    local completionPuzzle = owner:ready(Model.config("classic", 5), "Easy")
    local completionGame = Game.new(completionPuzzle)
    completionGame.board = Model.copy(completionPuzzle.solution)
    completionGame.board[1] = -1
    completionGame.selected = 1
    local completionScreen = GameScreen:new({ owner = owner, id = "completion", game = completionGame })
    local congratulations = {}

    local function recordCongratulations()
        local text = top().text
        assert(text:find("Solved!", 1, true))
        assert(not congratulations[text], "Repeated congratulation: " .. text)
        congratulations[text] = true
        ui:close(top())
        return text
    end

    button("v" .. completionPuzzle.solution[1], completionScreen)
    assert(completionGame:solved())
    local firstMessage = recordCongratulations()
    button("check", completionScreen)
    recordCongratulations()
    button("check", completionScreen)
    recordCongratulations()

    button("undo", completionScreen)
    assert(not completionGame:solved() and #ui.stack == 0)
    button("redo", completionScreen)
    assert(completionGame:solved())
    recordCongratulations()

    -- A fresh module instance must continue from persisted settings, not restart.
    package.loaded["doplo/celebration"] = nil
    local Celebration = require("doplo/celebration")
    local reloadedMessage = Celebration.next(settings)
    assert(not congratulations[reloadedMessage])
    congratulations[reloadedMessage] = true

    -- Accept more compliments without changing this test, but reject a repeat
    -- before the cycle returns to its first message.
    local cycleRestarted = false
    for _ = 1, 100 do
        button("check", completionScreen)
        if top().text == firstMessage then
            cycleRestarted = true
            ui:close(top())
            break
        end
        recordCongratulations()
    end
    assert(cycleRestarted, "The compliment cycle did not restart")
end)

local function savePreview(path)
    gameScreen.game = Game.new(owner:ready(Model.config("plus", 12), "Hard"))
    for _, candidate in ipairs({ 1, 5, 8, 0 }) do
        gameScreen.game:edit(1, candidate, true)
    end
    gameScreen.game:edit(14, 0, false)
    gameScreen.game.selected = 1
    gameScreen.game.pencil = true
    gameScreen:layout()

    local buffer = newBuffer()
    gameScreen:paintTo(buffer)
    local output = assert(io.open(path, "w"))
    output:write(("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\">"):format(
        deviceScreen.w,
        deviceScreen.h
    ))
    for _, rectangle in ipairs(buffer.rects) do
        output:write(("<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" fill=\"rgb(%d,%d,%d)\"/>"):format(
            rectangle[1], rectangle[2], rectangle[3], rectangle[4], rectangle[5], rectangle[5], rectangle[5]
        ))
    end
    for _, text in ipairs(buffer.texts) do
        local escapedText = text.text:gsub("&", "&amp;"):gsub("<", "&lt;")
        output:write(("<text x=\"%d\" y=\"%d\" font-size=\"%d\" fill=\"rgb(%d,%d,%d)\">%s</text>"):format(
            text.x, text.y + text.size, text.size, text.color, text.color, text.color, escapedText
        ))
    end
    output:write("</svg>")
    output:close()
end

local previewPath = os.getenv("DOPLO_PREVIEW")
if previewPath then
    savePreview(previewPath)
end
