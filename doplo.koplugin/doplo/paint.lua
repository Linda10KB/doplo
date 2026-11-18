-- SPDX-License-Identifier: AGPL-3.0-or-later
local BB = require("ffi/blitbuffer")
local Font = require("ui/font")
local Text = require("ui/widget/textwidget")
local Screen = require("device").screen
local M = require("doplo/model")
local Layout = require("doplo/layout")
local band = require("bit").band
local R = {}
R.__index = R
local black, white = BB.COLOR_BLACK, BB.COLOR_WHITE
local gray, light, ink, grid = BB.Color8(103), BB.Color8(239), BB.Color8(58), BB.Color8(139)
local floor, rect = math.floor, Layout.rect

function R.new()
    return setmetatable({ cache = {}, count = 0 }, R)
end
function R:clear()
    for _, v in pairs(self.cache) do
        v:free()
    end
    self.cache, self.count = {}, 0
end
function R:text(bb, b, label, px, face, color, align)
    label = tostring(label)
    color = color or black
    local size = math.max(5, floor(px * 100 / Screen:scaleBySize(100) + 0.5))
    local font = face or "cfont"
    local tw, s
    repeat
        local key = font .. "|" .. size .. "|" .. tostring(color) .. "|" .. label
        tw = self.cache[key]
        if not tw then
            tw = Text:new({ text = label, face = Font:getFace(font, size), fgcolor = color, padding = 0 })
            self.cache[key], self.count = tw, self.count + 1
        end
        s = tw:getSize()
        if (s.w <= b.w - 2 and s.h <= b.h + 1) or size <= 5 then
            break
        end
        size = math.max(5, math.min(size - 1, floor(size * math.min((b.w - 2) / s.w, b.h / s.h))))
    until false
    local x = align == "left" and b.x or (align == "right" and b.x + b.w - s.w or b.x + (b.w - s.w) / 2)
    tw:paintTo(bb, floor(x), floor(b.y + (b.h - s.h) / 2))
end
local function fill(bb, b, color)
    bb:paintRect(b.x, b.y, b.w, b.h, color)
end
local function frame(bb, b, thick, color)
    bb:paintBorder(b.x, b.y, b.w, b.h, thick, color)
end
-- Blocks use a solid rectangle at every scale, including pencil marks.
function R:value(bb, box, value, size, face, color)
    if value == 0 then
        local side = math.max(2, floor(math.min(box.w, box.h) * 0.55))
        fill(bb, rect(box.x + (box.w - side) / 2, box.y + (box.h - side) / 2, side, side), color or black)
    else
        self:text(bb, box, value, size, face, color)
    end
end
function R:cellContent(bb, box, p, value, notes, given)
    if value == 0 then
        fill(bb, box, black)
    elseif value ~= -1 then
        self:value(bb, box, value, box.h * 0.61, given and "tfont" or "cfont")
    elseif notes ~= 0 then
        local digits = p.n - p.blocks
        local cols = digits > 4 and 3 or 2
        local rows = math.ceil((digits + 1) / cols)
        local inset = math.max(2, floor(box.w * 0.05))
        local stepW, stepH = (box.w - 2 * inset) / cols, (box.h - 2 * inset) / rows
        for mark = 0, digits do
            if band(notes, 2 ^ mark) ~= 0 then
                local pos = mark == 0 and digits or mark - 1
                local note = rect(box.x + inset + (pos % cols) * stepW,
                    box.y + inset + floor(pos / cols) * stepH, stepW, stepH)
                self:value(bb, note, mark, math.min(stepH * 0.85, box.w * 0.28), "tfont", black)
            end
        end
    end
end
function R:draw(bb, a, g, reveal)
    if self.count > 600 then
        self:clear()
    end
    local p, px, cell = g.p, a.px, a.cell
    local sr, sc = floor((g.selected - 1) / p.n) + 1, (g.selected - 1) % p.n + 1
    bb:paintRect(0, 0, a.w, a.h, white)
    self:text(bb, a.title, M.name(p), px(35), "NotoSerif-Regular.ttf", black, "left")
    local subtitle = ("%d × %d   ·   %s"):format(p.n, p.n, p.level)
    if reveal then
        subtitle = subtitle .. "   ·   Solution"
    end
    self:text(bb, a.subtitle, subtitle, px(15), "cfont", ink, "left")
    bb:paintRect(px(19), a.head - 1, a.w - 2 * px(19), px(1), grid)

    for k = 1, a.span do
        local rowId, colId = a.firstRow + k - 1, a.firstCol + k - 1
        local top = rect(a.gx + (k - 1) * cell, a.gy - a.top, cell, a.top)
        local left = rect(a.gx - a.left, a.gy + (k - 1) * cell, a.left, cell)
        if colId == sc then
            bb:paintRect(top.x + floor(cell * 0.30), a.gy - px(3), floor(cell * 0.40), px(3), black)
        end
        if rowId == sr then
            bb:paintRect(a.gx - px(3), left.y + floor(cell * 0.30), px(3), floor(cell * 0.40), black)
        end
        if p.kind == "classic" then
            self:text(bb, top, p.col[colId][1], a.clueSize, "tfont", black)
            self:text(bb, left, p.row[rowId][1], a.clueSize, "tfont", black)
        else
            local sw = a.slotW
            local sh = a.slotH
            local row, col = p.row[rowId], p.col[colId]
            for j, v in ipairs(row) do
                local box = rect(a.gx - px(4) - (#row - j + 1) * sw, left.y, sw, cell)
                self:text(bb, box, v, a.clueSize, "tfont", black)
            end
            for j, v in ipairs(col) do
                local box = rect(top.x, a.gy - px(4) - (#col - j + 1) * sh, cell, sh)
                self:text(bb, box, v, a.clueSize, "tfont", black)
            end
        end
    end
    for pos = 0, a.span ^ 2 - 1 do
        local row = a.firstRow + floor(pos / a.span)
        local col = a.firstCol + pos % a.span
        local i = (row - 1) * p.n + col
        local box = Layout.cell(a, i)
        local given = p.givens[i] ~= -1
        local v = reveal and p.solution[i] or g.board[i]
        if given then
            fill(bb, box, light)
            local dot = math.max(2, floor(cell * 0.055))
            bb:paintRect(box.x + px(3), box.y + px(3), dot, dot, ink)
        end
        self:cellContent(bb, box, p, v, reveal and 0 or g.notes[i], given)
    end
    local side = cell * a.span
    for k = 1, a.span - 1 do
        bb:paintRect(a.gx + cell * k, a.gy, px(1), side, grid)
        bb:paintRect(a.gx, a.gy + cell * k, side, px(1), grid)
    end
    frame(bb, rect(a.gx, a.gy, side, side), px(2), black)
    local selected = Layout.cell(a, g.selected)
    local inset = px(2)
    frame(bb, rect(selected.x + inset, selected.y + inset, cell - 2 * inset, cell - 2 * inset), px(2), (reveal and p.solution[g.selected] or g.board[g.selected]) == 0 and white or black)

    local label = "Cell " .. string.char(64 + sc) .. sr
    if reveal then
        label = label .. " · Solution"
    elseif p.givens[g.selected] ~= -1 then
        label = label .. " · Given"
    elseif g.pencil then
        label = label .. " · Pencil"
    end
    local detail = a.detail
    if p.givens[g.selected] ~= -1 then
        fill(bb, detail, light)
    end
    self:cellContent(bb, detail, p, reveal and p.solution[g.selected] or g.board[g.selected],
        reveal and 0 or g.notes[g.selected], p.givens[g.selected] ~= -1)
    frame(bb, detail, px(2), black)
    self:text(bb, a.detailLabel, label, px(18), "tfont", black, "left")
    local counter = g:solved() and "Solved" or ("%d / %d filled"):format(g:filled(), p.n ^ 2)
    self:text(bb, a.counter, counter, px(16), "cfont", ink, "left")
    self:text(bb, a.rowDetail, "Row " .. sr .. ":  " .. table.concat(p.row[sr], " · "), px(22), "tfont", black, "left")
    self:text(bb, a.colDetail, "Column " .. string.char(64 + sc) .. ":  " .. table.concat(p.col[sc], " · "), px(22), "tfont", black, "left")
    for _, b in ipairs(a.buttons) do
        local isValue = b.id:match("^v%-?%d+$") ~= nil
        local active = b.id == "pencil" and g.pencil and not reveal
        local disabled = (b.id == "undo" and g.cursor == 0) or (b.id == "redo" and g.cursor == #g.history)
        if reveal and b.id ~= "game" and b.id ~= "close" and b.id ~= "brightness" then
            disabled = true
        end
        if isValue and g.p.givens[g.selected] ~= -1 then
            disabled = true
        end
        local labelText = b.label
        if b.id == "game" and reveal then
            labelText = "Return"
        end
        if active then
            fill(bb, b, black)
        else
            frame(bb, b, px(1), disabled and grid or ink)
        end
        local color = active and white or (disabled and gray or black)
        local number = isValue and b.id ~= "v-1"
        local draw = b.id == "v0" and self.value or self.text
        draw(
            self, bb,
            rect(b.x + px(2), b.y, b.w - 2 * px(2), b.h),
            b.id == "v0" and 0 or labelText,
            px(number and 28 or 17),
            number and "tfont" or "cfont",
            color
        )
    end
end
return R
