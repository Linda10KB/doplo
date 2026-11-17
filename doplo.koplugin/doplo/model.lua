-- SPDX-License-Identifier: AGPL-3.0-or-later
local M = { EMPTY = -1, BLOCK = 0 }
M.sizes = { classic = { 5, 6 }, plus = { 7, 10, 12 } }
M.levels = { "Easy", "Medium", "Hard", "Expert" }

function M.config(kind, n)
    local blocks = kind == "plus" and ({ [7] = 2, [10] = 3, [12] = 4 })[n] or nil
    if kind == "classic" and (n == 5 or n == 6) then
        blocks = 2
    end
    if not blocks then
        return nil
    end
    return { kind = kind, n = n, blocks = blocks }
end

function M.array(n, value)
    local a = {}
    for i = 1, n do
        a[i] = value
    end
    return a
end

function M.copy(a)
    local b = {}
    for i = 1, #a do
        b[i] = a[i]
    end
    return b
end

function M.equal(a, b)
    if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

function M.index(n, axis, line, pos)
    if axis == "row" then
        return (line - 1) * n + pos
    end
    return (pos - 1) * n + line
end

function M.line(board, n, axis, line)
    local out = {}
    for pos = 1, n do
        out[pos] = board[M.index(n, axis, line, pos)]
    end
    return out
end

-- Input is a complete line. Classic includes only the interior; Plus includes
-- every nonempty run, including the runs touching either edge.
function M.sums(kind, line)
    local runs, blocks, sum = {}, 0, 0
    for _, value in ipairs(line) do
        if value == 0 then
            blocks = blocks + 1
            if kind == "plus" and sum > 0 then
                runs[#runs + 1], sum = sum, 0
            end
        elseif kind == "plus" or blocks == 1 then
            sum = sum + value
        end
    end
    if kind == "classic" then
        return { sum }
    end
    if sum > 0 then
        runs[#runs + 1] = sum
    end
    return runs
end

function M.checkLine(cfg, line, clue)
    local seen, blocks, empty = {}, 0, 0
    for pos = 1, cfg.n do
        local v = line[pos]
        if v == -1 then
            empty = empty + 1
        elseif v == 0 then
            blocks = blocks + 1
        elseif type(v) ~= "number" or v ~= math.floor(v) or v < 1 or v > cfg.n - cfg.blocks then
            return "range"
        elseif seen[v] then
            return "duplicate", v
        else
            seen[v] = true
        end
    end
    if blocks > cfg.blocks or blocks + empty < cfg.blocks then
        return "blocks"
    end
    if empty > 0 then
        return "incomplete"
    end
    if not M.equal(M.sums(cfg.kind, line), clue) then
        return "sums"
    end
    return "complete"
end

function M.check(p, board)
    if type(board) ~= "table" or #board ~= p.n ^ 2 then
        return "invalid", "row", 1, "range"
    end
    if p.givens then
        for i, fixed in ipairs(p.givens) do
            if fixed ~= -1 and board[i] ~= fixed then
                return "invalid", "row", math.floor((i - 1) / p.n) + 1, "given"
            end
        end
    end
    local full = true
    for _, axis in ipairs({ "row", "col" }) do
        for k = 1, p.n do
            local reason, value = M.checkLine(p, M.line(board, p.n, axis, k), p[axis][k])
            if reason == "incomplete" then
                full = false
            elseif reason ~= "complete" then
                return "invalid", axis, k, reason, value
            end
        end
    end
    return full and "solved" or "incomplete"
end

function M.puzzle(config, solution, givens)
    local p = {
        kind = config.kind,
        n = config.n,
        blocks = config.blocks,
        row = {},
        col = {},
        solution = M.copy(solution),
        givens = givens or M.array(config.n ^ 2, -1),
    }
    for _, axis in ipairs({ "row", "col" }) do
        for k = 1, p.n do
            p[axis][k] = M.sums(p.kind, M.line(solution, p.n, axis, k))
        end
    end
    return p
end

function M.validPuzzle(p)
    if type(p) ~= "table" then
        return false
    end
    local cfg = M.config(p.kind, p.n)
    if not cfg or cfg.blocks ~= p.blocks then
        return false
    end
    if
        type(p.solution) ~= "table"
        or #p.solution ~= p.n ^ 2
        or type(p.givens) ~= "table"
        or #p.givens ~= p.n ^ 2
    then
        return false
    end
    if type(p.row) ~= "table" or type(p.col) ~= "table" or #p.row ~= p.n or #p.col ~= p.n then
        return false
    end
    for i = 1, p.n ^ 2 do
        if p.givens[i] ~= -1 and p.givens[i] ~= p.solution[i] then
            return false
        end
    end
    return M.check(p, p.solution) == "solved"
end

function M.valueText(v)
    return v == 0 and "×" or tostring(v)
end
function M.name(p)
    return p.kind == "classic" and "Doplo" or "Doplo Plus"
end
return M
