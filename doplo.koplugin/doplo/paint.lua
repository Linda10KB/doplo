-- SPDX-License-Identifier: AGPL-3.0-or-later
local BlitBuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local TextWidget = require("ui/widget/textwidget")
local DeviceScreen = require("device").screen
local Model = require("doplo/model")
local Layout = require("doplo/layout")
local band = require("bit").band
local floor = math.floor
local rect = Layout.rect

local BLACK = BlitBuffer.COLOR_BLACK
local WHITE = BlitBuffer.COLOR_WHITE
local DISABLED_TEXT = BlitBuffer.Color8(103)
local GIVEN_BACKGROUND = BlitBuffer.Color8(239)
local SECONDARY_TEXT = BlitBuffer.Color8(58)
local GRID_LINE = BlitBuffer.Color8(139)
local REVEAL_CONTROLS = { game = true, close = true, device = true, help = true }
local Painter = {}
Painter.__index = Painter

local function fill(buffer, box, color)
    buffer:paintRect(box.x, box.y, box.w, box.h, color)
end

local function frame(buffer, box, thickness, color)
    buffer:paintBorder(box.x, box.y, box.w, box.h, thickness, color)
end

local function textX(box, textWidth, alignment)
    if alignment == "left" then
        return box.x
    end
    if alignment == "right" then
        return box.x + box.w - textWidth
    end
    return box.x + (box.w - textWidth) / 2
end

local function displayedValue(game, index, reveal)
    return reveal and game.p.solution[index] or game.board[index]
end

local function buttonDisabled(button, game, reveal)
    if reveal then
        return not REVEAL_CONTROLS[button.id]
    end
    if button.id == "undo" then
        return game.cursor == 0
    end
    if button.id == "redo" then
        return game.cursor == #game.history
    end
    return button.id:match("^v%-?%d+$") ~= nil and game.p.givens[game.selected] ~= -1
end

function Painter.new()
    return setmetatable({ cache = {}, count = 0 }, Painter)
end

function Painter:clear()
    for _, widget in pairs(self.cache) do
        widget:free()
    end
    self.cache = {}
    self.count = 0
end

function Painter:textWidget(label, font, size, color)
    local key = font .. "|" .. size .. "|" .. tostring(color) .. "|" .. label
    local widget = self.cache[key]
    if widget then
        return widget
    end

    widget = TextWidget:new({ text = label, face = Font:getFace(font, size), fgcolor = color, padding = 0 })
    self.cache[key] = widget
    self.count = self.count + 1
    return widget
end

function Painter:text(buffer, box, label, pixelSize, face, color, alignment)
    label = tostring(label)
    color = color or BLACK
    local font = face or "cfont"
    local size = math.max(5, floor(pixelSize * 100 / DeviceScreen:scaleBySize(100) + 0.5))
    local widget, dimensions

    repeat
        widget = self:textWidget(label, font, size, color)
        dimensions = widget:getSize()
        if (dimensions.w <= box.w - 2 and dimensions.h <= box.h + 1) or size <= 5 then
            break
        end
        local fitRatio = math.min((box.w - 2) / dimensions.w, box.h / dimensions.h)
        size = math.max(5, math.min(size - 1, floor(size * fitRatio)))
    until false

    local x = textX(box, dimensions.w, alignment)
    widget:paintTo(buffer, floor(x), floor(box.y + (box.h - dimensions.h) / 2))
end

-- Use a solid rectangle for block symbols, including pencil marks and keypad keys.
function Painter:value(buffer, box, value, size, face, color)
    if value ~= 0 then
        self:text(buffer, box, value, size, face, color)
        return
    end

    local side = math.max(2, floor(math.min(box.w, box.h) * 0.55))
    local block = rect(box.x + (box.w - side) / 2, box.y + (box.h - side) / 2, side, side)
    fill(buffer, block, color or BLACK)
end

function Painter:pencilMarks(buffer, box, digitCount, notes)
    local columns = digitCount > 4 and 3 or 2
    local rows = math.ceil((digitCount + 1) / columns)
    local inset = math.max(2, floor(box.w * 0.05))
    local slotWidth = (box.w - 2 * inset) / columns
    local slotHeight = (box.h - 2 * inset) / rows

    for mark = 0, digitCount do
        if band(notes, 2 ^ mark) ~= 0 then
            local position = mark == 0 and digitCount or mark - 1
            local note = rect(
                box.x + inset + (position % columns) * slotWidth,
                box.y + inset + floor(position / columns) * slotHeight,
                slotWidth,
                slotHeight
            )
            self:value(buffer, note, mark, math.min(slotHeight * 0.85, box.w * 0.28), "tfont", BLACK)
        end
    end
end

function Painter:cellContent(buffer, box, puzzle, value, notes, given)
    if value == 0 then
        fill(buffer, box, BLACK)
        return
    end
    if value ~= -1 then
        self:value(buffer, box, value, box.h * 0.61, given and "tfont" or "cfont")
        return
    end
    if notes ~= 0 then
        self:pencilMarks(buffer, box, puzzle.n - puzzle.blocks, notes)
    end
end

function Painter:header(buffer, layout, puzzle, reveal)
    local px = layout.px
    local subtitle = ("%d × %d   ·   %s"):format(puzzle.n, puzzle.n, puzzle.level)
    if reveal then
        subtitle = subtitle .. "   ·   Solution"
    end

    self:text(buffer, layout.title, Model.name(puzzle), px(35), "NotoSerif-Regular.ttf", BLACK, "left")
    self:text(buffer, layout.subtitle, subtitle, px(15), "cfont", SECONDARY_TEXT, "left")
    buffer:paintRect(px(19), layout.head - 1, layout.w - 2 * px(19), px(1), GRID_LINE)
end

function Painter:plusClues(buffer, layout, rowClues, columnClues, rowBox, columnBox)
    for index, value in ipairs(rowClues) do
        local clueX = layout.gx - layout.px(4) - (#rowClues - index + 1) * layout.slotW
        local clueBox = rect(clueX, rowBox.y, layout.slotW, layout.cell)
        self:text(buffer, clueBox, value, layout.clueSize, "tfont", BLACK)
    end
    for index, value in ipairs(columnClues) do
        local clueY = layout.gy - layout.px(4) - (#columnClues - index + 1) * layout.slotH
        local clueBox = rect(columnBox.x, clueY, layout.cell, layout.slotH)
        self:text(buffer, clueBox, value, layout.clueSize, "tfont", BLACK)
    end
end

function Painter:clues(buffer, layout, puzzle, selectedRow, selectedColumn)
    local cell = layout.cell
    local px = layout.px

    for offset = 0, layout.span - 1 do
        local rowIndex = layout.firstRow + offset
        local columnIndex = layout.firstCol + offset
        local columnBox = rect(layout.gx + offset * cell, layout.gy - layout.top, cell, layout.top)
        local rowBox = rect(layout.gx - layout.left, layout.gy + offset * cell, layout.left, cell)

        if columnIndex == selectedColumn then
            buffer:paintRect(columnBox.x + floor(cell * 0.30), layout.gy - px(3), floor(cell * 0.40), px(3), BLACK)
        end
        if rowIndex == selectedRow then
            buffer:paintRect(layout.gx - px(3), rowBox.y + floor(cell * 0.30), px(3), floor(cell * 0.40), BLACK)
        end
        if puzzle.kind == "classic" then
            self:text(buffer, columnBox, puzzle.col[columnIndex][1], layout.clueSize, "tfont", BLACK)
            self:text(buffer, rowBox, puzzle.row[rowIndex][1], layout.clueSize, "tfont", BLACK)
        else
            self:plusClues(buffer, layout, puzzle.row[rowIndex], puzzle.col[columnIndex], rowBox, columnBox)
        end
    end
end

function Painter:boardCells(buffer, layout, game, reveal)
    local puzzle = game.p
    local px = layout.px

    for position = 0, layout.span ^ 2 - 1 do
        local row = layout.firstRow + floor(position / layout.span)
        local column = layout.firstCol + position % layout.span
        local index = (row - 1) * puzzle.n + column
        local box = Layout.cell(layout, index)
        local given = puzzle.givens[index] ~= -1
        local value = displayedValue(game, index, reveal)

        if given then
            fill(buffer, box, GIVEN_BACKGROUND)
            local dotSize = math.max(2, floor(layout.cell * 0.055))
            buffer:paintRect(box.x + px(3), box.y + px(3), dotSize, dotSize, SECONDARY_TEXT)
        end
        self:cellContent(buffer, box, puzzle, value, reveal and 0 or game.notes[index], given)
    end
end

function Painter:grid(buffer, layout, game, reveal)
    local px = layout.px
    local cell = layout.cell
    local side = cell * layout.span

    for offset = 1, layout.span - 1 do
        buffer:paintRect(layout.gx + cell * offset, layout.gy, px(1), side, GRID_LINE)
        buffer:paintRect(layout.gx, layout.gy + cell * offset, side, px(1), GRID_LINE)
    end
    frame(buffer, rect(layout.gx, layout.gy, side, side), px(2), BLACK)

    local selected = Layout.cell(layout, game.selected)
    local inset = px(2)
    local selection = rect(selected.x + inset, selected.y + inset, cell - 2 * inset, cell - 2 * inset)
    local selectionColor = displayedValue(game, game.selected, reveal) == 0 and WHITE or BLACK
    frame(buffer, selection, px(2), selectionColor)
end

function Painter:detail(buffer, layout, game, reveal, selectedRow, selectedColumn)
    local puzzle = game.p
    local px = layout.px
    local given = puzzle.givens[game.selected] ~= -1
    local label = "Cell " .. string.char(64 + selectedColumn) .. selectedRow

    if reveal then
        label = label .. " · Solution"
    elseif given then
        label = label .. " · Given"
    elseif game.pencil then
        label = label .. " · Pencil"
    end
    if given then
        fill(buffer, layout.detail, GIVEN_BACKGROUND)
    end

    local value = displayedValue(game, game.selected, reveal)
    local notes = reveal and 0 or game.notes[game.selected]
    self:cellContent(buffer, layout.detail, puzzle, value, notes, given)
    frame(buffer, layout.detail, px(2), BLACK)
    self:text(buffer, layout.detailLabel, label, px(18), "tfont", BLACK, "left")

    local counter = game:solved() and "Solved" or ("%d / %d filled"):format(game:filled(), puzzle.n ^ 2)
    local rowClues = "Row " .. selectedRow .. ":  " .. table.concat(puzzle.row[selectedRow], " · ")
    local columnClues = "Column " .. string.char(64 + selectedColumn) .. ":  " .. table.concat(puzzle.col[selectedColumn], " · ")
    self:text(buffer, layout.counter, counter, px(16), "cfont", SECONDARY_TEXT, "left")
    self:text(buffer, layout.rowDetail, rowClues, px(22), "tfont", BLACK, "left")
    self:text(buffer, layout.colDetail, columnClues, px(22), "tfont", BLACK, "left")
end

function Painter:button(buffer, layout, button, game, reveal)
    local px = layout.px
    local isValue = button.id:match("^v%-?%d+$") ~= nil
    local active = button.id == "pencil" and game.pencil and not reveal
    local disabled = buttonDisabled(button, game, reveal)
    local label = button.id == "game" and reveal and "Return" or button.label
    local color = disabled and DISABLED_TEXT or BLACK

    if active then
        fill(buffer, button, BLACK)
        color = WHITE
    else
        frame(buffer, button, px(1), disabled and GRID_LINE or SECONDARY_TEXT)
    end

    local number = isValue and button.id ~= "v-1"
    local labelBox = rect(button.x + px(2), button.y, button.w - 2 * px(2), button.h)
    if button.id == "v0" then
        self:value(buffer, labelBox, 0, px(28), "tfont", color)
        return
    end
    self:text(buffer, labelBox, label, px(number and 28 or 17), number and "tfont" or "cfont", color)
end

function Painter:draw(buffer, layout, game, reveal)
    if self.count > 600 then
        self:clear()
    end
    local puzzle = game.p
    local selectedRow = floor((game.selected - 1) / puzzle.n) + 1
    local selectedColumn = (game.selected - 1) % puzzle.n + 1

    buffer:paintRect(0, 0, layout.w, layout.h, WHITE)
    self:header(buffer, layout, puzzle, reveal)
    self:clues(buffer, layout, puzzle, selectedRow, selectedColumn)
    self:boardCells(buffer, layout, game, reveal)
    self:grid(buffer, layout, game, reveal)
    self:detail(buffer, layout, game, reveal, selectedRow, selectedColumn)
    for _, button in ipairs(layout.buttons) do
        self:button(buffer, layout, button, game, reveal)
    end
end

return Painter
