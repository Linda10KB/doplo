-- SPDX-License-Identifier: AGPL-3.0-or-later
local Layout = {}
local floor = math.floor

function Layout.rect(x, y, width, height)
    return { x = floor(x), y = floor(y), w = floor(width), h = floor(height) }
end

function Layout.inside(box, x, y)
    return x >= box.x and x < box.x + box.w and y >= box.y and y < box.y + box.h
end

local function addButton(layout, id, box, label)
    box.id = id
    box.label = label
    layout.buttons[#layout.buttons + 1] = box
end

local function makeHeader(layout, edge, gap)
    local px = layout.px
    local right = layout.w - edge
    local controls = {
        { id = "close", label = "Close", width = 66 },
        { id = "game", label = "Game", width = 75 },
        { id = "device", label = "Device settings", width = 130 },
        { id = "help", label = "How to play", width = 110 },
    }

    for _, control in ipairs(controls) do
        local width = px(control.width)
        right = right - width
        addButton(layout, control.id, Layout.rect(right, px(12), width, px(43)), control.label)
        right = right - gap
    end

    layout.title = Layout.rect(edge, px(2), right - edge, px(42))
    layout.subtitle = Layout.rect(edge, px(42), layout.title.w, px(22))
end

local function makeDetail(layout, panel, landscape, gap)
    local px = layout.px
    local detailSize = px(96)
    local textX = landscape and panel.x or panel.x + detailSize + px(12)
    local textY = landscape and panel.y + detailSize + gap or panel.y
    local textWidth = landscape and panel.w or panel.w - detailSize - px(12)
    local lineHeight = landscape and px(24) or px(25)
    local labelX = landscape and panel.x + detailSize + gap or textX
    local labelWidth = landscape and panel.w - detailSize - gap or textWidth

    layout.detail = Layout.rect(panel.x, panel.y, detailSize, detailSize)
    layout.detailLabel = Layout.rect(labelX, panel.y, labelWidth, lineHeight)
    layout.counter = Layout.rect(labelX, panel.y + lineHeight, labelWidth, lineHeight)
    layout.rowDetail = Layout.rect(textX, textY + (landscape and 0 or 2 * lineHeight), textWidth, lineHeight)
    layout.colDetail = Layout.rect(textX, layout.rowDetail.y + lineHeight, textWidth, lineHeight)
end

local function valueLabel(value)
    if value == -1 then
        return "Erase"
    end
    if value == 0 then
        return "■"
    end
    return tostring(value)
end

local function makeKeypad(layout, keys, keysPerRow, keyHeight, gap)
    local panel = layout.panel
    local keyRows = math.ceil(#keys / keysPerRow)
    local rowY = layout.info.y + layout.info.h + gap

    for rowIndex = 1, keyRows do
        local firstKey = (rowIndex - 1) * keysPerRow + 1
        local keyCount = math.min(keysPerRow, #keys - firstKey + 1)
        local keyWidth = (panel.w - (keyCount - 1) * gap) / keyCount

        for columnIndex = 1, keyCount do
            local value = keys[firstKey + columnIndex - 1]
            local keyX = panel.x + (columnIndex - 1) * (keyWidth + gap)
            addButton(layout, "v" .. value, Layout.rect(keyX, rowY, keyWidth, keyHeight), valueLabel(value))
        end
        rowY = rowY + keyHeight + gap
    end

    return rowY
end

local function makeActions(layout, rowY, barHeight, gap)
    local actions = {
        { "pencil", "Pencil" },
        { "undo", "Undo" },
        { "redo", "Redo" },
        { "hint", "Hint" },
        { "check", "Check" },
    }
    local panel = layout.panel
    local buttonWidth = (panel.w - (#actions - 1) * gap) / #actions

    for index, action in ipairs(actions) do
        local buttonX = panel.x + (index - 1) * (buttonWidth + gap)
        addButton(layout, action[1], Layout.rect(buttonX, rowY, buttonWidth, barHeight), action[2])
    end
end

local function makePanel(layout, puzzle, landscape, edge, gap)
    local px = layout.px
    local panelX = landscape and floor(layout.w * 0.62) or edge
    local panelWidth = layout.w - panelX - edge
    local keyHeight = px(48)
    local barHeight = px(43)
    local keys = {}

    for value = 1, puzzle.n - puzzle.blocks do
        keys[#keys + 1] = value
    end
    keys[#keys + 1] = 0
    keys[#keys + 1] = -1

    local keysPerRow = math.min(landscape and 4 or 6, #keys)
    local keyRows = math.ceil(#keys / keysPerRow)
    local detailHeight = landscape and px(172) or px(100)
    local panelHeight = detailHeight + gap + keyRows * (keyHeight + gap) + barHeight
    local panelY = landscape and floor((layout.h + layout.head - panelHeight) / 2)
        or layout.h - edge - panelHeight

    layout.panel = Layout.rect(panelX, panelY, panelWidth, panelHeight)
    layout.info = Layout.rect(panelX, panelY, panelWidth, detailHeight)
    makeDetail(layout, layout.panel, landscape, gap)
    local actionsY = makeKeypad(layout, keys, keysPerRow, keyHeight, gap)
    makeActions(layout, actionsY, barHeight, gap)
end

local function makeBoard(layout, puzzle, landscape, edge, gap)
    local px = layout.px
    local availableWidth = (landscape and layout.panel.x - gap or layout.w - edge) - edge
    local availableHeight = (landscape and layout.h - edge or layout.panel.y - px(12)) - layout.head - px(5)
    local rowClueCount = 1
    local columnClueCount = 1

    for lineIndex = 1, puzzle.n do
        rowClueCount = math.max(rowClueCount, #puzzle.row[lineIndex])
        columnClueCount = math.max(columnClueCount, #puzzle.col[lineIndex])
    end

    -- Reserve text space independently of cells, so large grids keep readable clues.
    layout.clueSize = px(puzzle.kind == "classic" and 25 or 22)
    layout.slotW = px(30)
    layout.slotH = px(26)
    layout.left = rowClueCount * layout.slotW + px(6)
    layout.top = columnClueCount * layout.slotH + px(6)
    layout.maxR = rowClueCount
    layout.maxC = columnClueCount
    layout.cell = math.max(1, floor(math.min(
        (availableWidth - layout.left) / puzzle.n,
        (availableHeight - layout.top) / puzzle.n
    )))
    layout.gx = edge + floor((availableWidth - layout.cell * puzzle.n - layout.left) / 2) + layout.left
    layout.gy = layout.head + px(5)
        + floor((availableHeight - layout.cell * puzzle.n - layout.top) / 2) + layout.top
end

function Layout.make(puzzle, width, height)
    local scale = math.min(width, height) / 600
    local function px(value)
        return math.max(1, floor(value * scale + 0.5))
    end
    local layout = {
        w = width,
        h = height,
        u = scale,
        px = px,
        head = px(70),
        buttons = {},
        n = puzzle.n,
        firstRow = 1,
        firstCol = 1,
        span = puzzle.n,
    }
    local edge = px(16)
    local gap = px(6)
    local landscape = width >= height * 1.16

    makeHeader(layout, edge, gap)
    makePanel(layout, puzzle, landscape, edge, gap)
    makeBoard(layout, puzzle, landscape, edge, gap)
    return layout
end

function Layout.cell(layout, index)
    local column = (index - 1) % layout.n
    local row = floor((index - 1) / layout.n)
    if column < 0 or row < 0 or column >= layout.n or row >= layout.n then
        return nil
    end
    return Layout.rect(layout.gx + column * layout.cell, layout.gy + row * layout.cell, layout.cell, layout.cell)
end

function Layout.cellAt(layout, x, y)
    local column = floor((x - layout.gx) / layout.cell)
    local row = floor((y - layout.gy) / layout.cell)
    if column < 0 or column >= layout.n or row < 0 or row >= layout.n then
        return nil
    end
    return row * layout.n + column + 1
end

return Layout
