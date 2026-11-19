-- Header controls must remain accessible on every supported grid and orientation.
package.path = "doplo.koplugin/?.lua;" .. package.path
local Layout = require("doplo/layout")
local Model = require("doplo/model")
local bank = require("doplo/bank")
local screenSizes = {
    { 600, 800 },
    { 800, 600 },
    { 1264, 1680 },
    { 1680, 1264 },
    { 320, 480 },
    { 480, 320 },
}

local function overlaps(first, second)
    return first.x < second.x + second.w and second.x < first.x + first.w
        and first.y < second.y + second.h and second.y < first.y + first.h
end

local function makePuzzle(kind, size)
    local solution = {}
    local record = bank[kind][size].empty.Hard[1][1]
    for index = 1, size ^ 2 do
        solution[index] = tonumber(record:sub(index, index))
    end
    return Model.puzzle(Model.config(kind, size), solution, Model.array(size ^ 2, -1))
end

local function checkLayout(puzzle, dimensions)
    local layout = Layout.make(puzzle, dimensions[1], dimensions[2])
    local controls = {}
    assert(layout.title.w >= layout.px(150), "Puzzle title lost its header space")

    for index, button in ipairs(layout.buttons) do
        controls[button.id] = button
        assert(button.x >= 0 and button.y >= 0)
        assert(button.x + button.w <= layout.w and button.y + button.h <= layout.h)
        assert(not overlaps(button, layout.title) and not overlaps(button, layout.subtitle))
        for otherIndex = index + 1, #layout.buttons do
            assert(not overlaps(button, layout.buttons[otherIndex]), "Overlapping touch targets")
        end
    end
    assert(controls.device and controls.device.label == "Device settings")
    assert(controls.help and controls.help.label == "How to play")
    assert(not controls.brightness, "Brightness must be grouped under Device settings")

    for index = 1, puzzle.n ^ 2 do
        local cell = Layout.cell(layout, index)
        assert(Layout.cellAt(layout, cell.x + cell.w / 2, cell.y + cell.h / 2) == index)
        assert(cell.x >= 0 and cell.y >= layout.head)
        assert(cell.x + cell.w <= layout.w and cell.y + cell.h <= layout.h)
        for _, button in ipairs(layout.buttons) do
            assert(not overlaps(cell, button), "A control overlaps the board")
        end
    end
end

for kind, sizes in pairs(Model.sizes) do
    for _, size in ipairs(sizes) do
        local puzzle = makePuzzle(kind, size)
        for _, dimensions in ipairs(screenSizes) do
            checkLayout(puzzle, dimensions)
        end
    end
end
print("PASS device/help controls and board geometry at six screen sizes for every variant")
