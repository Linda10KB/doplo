-- SPDX-License-Identifier: AGPL-3.0-or-later
local Layout = require("doplo/layout")
local TutorialLayout = {}
local floor = math.floor

local function button(layout, id, label, box)
    box.id, box.label = id, label
    layout.buttons[#layout.buttons + 1] = box
end

local function board(layout, puzzle, area)
    local px = layout.px
    local rowCount, columnCount = 1, 1
    for index = 1, puzzle.n do
        rowCount = math.max(rowCount, #puzzle.row[index])
        columnCount = math.max(columnCount, #puzzle.col[index])
    end
    layout.slotW, layout.slotH = px(22), px(22)
    layout.left = rowCount * layout.slotW + px(24)
    layout.top = columnCount * layout.slotH + px(24)
    layout.clueSize = px(20)
    layout.cell = floor(math.min((area.w - layout.left) / puzzle.n, (area.h - layout.top) / puzzle.n))
    layout.gx = area.x + layout.left + floor((area.w - layout.left - layout.cell * puzzle.n) / 2)
    layout.gy = area.y + layout.top + floor((area.h - layout.top - layout.cell * puzzle.n) / 2)
end

function TutorialLayout.make(puzzle, width, height)
    local scale = math.min(width, height) / 600
    local function px(value)
        return math.max(1, floor(value * scale + 0.5))
    end
    local rect = Layout.rect
    local edge, gap = px(18), px(8)
    local landscape = width >= height * 1.16
    local layout = {
        w = width, h = height, px = px, n = puzzle.n, span = puzzle.n,
        firstRow = 1, firstCol = 1, buttons = {},
    }
    layout.title = rect(edge, px(10), width - 2 * edge - px(150), px(30))
    layout.subtitle = rect(edge, px(43), width - 2 * edge, px(23))
    button(layout, "close", "Back to puzzle", rect(width - edge - px(150), px(12), px(150), px(42)))

    local panelX = landscape and floor(width * 0.55) or edge
    local panelY = landscape and px(94) or floor(height * 0.56)
    local panelWidth = width - edge - panelX
    local navY = height - edge - px(44)
    local keyY = navY - gap - px(48)
    layout.stepTitle = rect(panelX, panelY, panelWidth, px(29))
    layout.instruction = rect(panelX, panelY + px(36), panelWidth, keyY - panelY - px(47))
    local boardArea = landscape
        and rect(edge, px(86), panelX - edge - gap, height - px(86) - edge)
        or rect(edge, px(78), width - 2 * edge, panelY - px(90))
    board(layout, puzzle, boardArea)

    local keyCount = puzzle.n - puzzle.blocks + 1
    local keyWidth = (panelWidth - gap * (keyCount - 1)) / keyCount
    for index = 1, keyCount do
        local value = index == keyCount and 0 or index
        button(layout, "v" .. value, tostring(value), rect(panelX + (index - 1) * (keyWidth + gap), keyY, keyWidth, px(48)))
    end
    local navWidth = (panelWidth - 2 * gap) / 3
    for index, action in ipairs({ { "back", "Previous" }, { "restart", "Restart" }, { "next", "Next" } }) do
        button(layout, action[1], action[2], rect(panelX + (index - 1) * (navWidth + gap), navY, navWidth, px(44)))
    end
    return layout
end

return TutorialLayout
