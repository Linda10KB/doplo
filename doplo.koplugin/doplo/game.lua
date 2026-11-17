-- SPDX-License-Identifier: AGPL-3.0-or-later
local M = require("doplo/model")
local bit = require("bit")
local Game = {}
Game.__index = Game
local function integer(v, lo, hi)
    return type(v) == "number" and v == math.floor(v) and v >= lo and v <= hi
end
function Game.new(p)
    local i = 1
    while i < p.n ^ 2 and p.givens[i] ~= -1 do
        i = i + 1
    end
    return setmetatable(
        {
            p = p,
            board = M.copy(p.givens),
            notes = M.array(p.n ^ 2, 0),
            selected = i,
            pencil = false,
            history = {},
            cursor = 0,
            revision = 0,
        },
        Game
    )
end
function Game:filled()
    local count = 0
    for _, v in ipairs(self.board) do
        if v ~= -1 then
            count = count + 1
        end
    end
    return count
end
function Game:solved()
    return self:filled() == self.p.n ^ 2 and M.check(self.p, self.board) == "solved"
end
function Game:edit(i, value, pencil)
    if not integer(i, 1, self.p.n ^ 2) or self.p.givens[i] ~= -1 then
        return false
    end
    if not integer(value, -1, self.p.n - self.p.blocks) then
        return false
    end
    local old, notes = self.board[i], self.notes[i]
    local new, marks = value, 0
    if pencil and value ~= -1 then
        -- Treat a tap on a filled cell as a no-op in pencil mode.
        if old ~= -1 then
            return false
        end
        new, marks = -1, bit.bxor(notes, 2 ^ value)
    end
    if new == old and marks == notes then
        return false
    end
    for k = #self.history, self.cursor + 1, -1 do
        self.history[k] = nil
    end
    self.history[#self.history + 1] = { i, old, notes, new, marks }
    if #self.history > 200 then
        table.remove(self.history, 1)
    end
    self.cursor, self.selected = #self.history, i
    self.board[i], self.notes[i] = new, marks
    return true
end
function Game:travel(redo)
    local index = redo and self.cursor + 1 or self.cursor
    local h = self.history[index]
    if not h then
        return false
    end
    local i, offset = h[1], redo and 4 or 2
    self.board[i], self.notes[i] = h[offset], h[offset + 1]
    self.selected = i
    self.cursor = self.cursor + (redo and 1 or -1)
    return true
end
function Game:snapshot()
    return {
        schema = 1,
        p = self.p,
        board = self.board,
        notes = self.notes,
        history = self.history,
        cursor = self.cursor,
        pencil = self.pencil,
        selected = self.selected,
        revision = self.revision,
        modified = self.modified,
    }
end
function Game.restore(data)
    if type(data) ~= "table" or data.schema ~= 1 or not M.validPuzzle(data.p) then
        return nil
    end
    local p, levelOK = data.p, false
    for _, level in ipairs(M.levels) do
        if level == p.level then
            levelOK = true
        end
    end
    if not levelOK then
        return nil
    end
    local size, maxValue = p.n ^ 2, p.n - p.blocks
    local maxMask = 2 ^ (maxValue + 1) - 1
    if
        type(data.board) ~= "table"
        or #data.board ~= size
        or type(data.notes) ~= "table"
        or #data.notes ~= size
        or not integer(data.selected, 1, size)
        or type(data.history) ~= "table"
        or #data.history > 200
        or not integer(data.cursor, 0, #data.history)
        or type(data.pencil) ~= "boolean"
        or not integer(data.revision, 0, 2 ^ 52)
        or not integer(data.modified or 0, 0, 2 ^ 52)
    then
        return nil
    end
    local function pair(v, notes)
        return integer(v, -1, maxValue) and integer(notes, 0, maxMask) and (v == -1 or notes == 0)
    end
    for i, v in ipairs(data.board) do
        if not pair(v, data.notes[i]) or (p.givens[i] ~= -1 and p.givens[i] ~= v) then
            return nil
        end
    end
    for _, h in ipairs(data.history) do
        if
            type(h) ~= "table"
            or #h ~= 5
            or not integer(h[1], 1, size)
            or p.givens[h[1]] ~= -1
            or not pair(h[2], h[3])
            or not pair(h[4], h[5])
        then
            return nil
        end
    end
    return setmetatable(data, Game)
end
return Game
