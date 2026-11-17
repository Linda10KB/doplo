-- SPDX-License-Identifier: AGPL-3.0-or-later
local M = require("doplo/model")
local L = require("doplo/line")
local band = require("bit").band
local S = {}
local function domains(p, board)
    local d, full = {}, 2 ^ (p.n - p.blocks + 1) - 1
    for i = 1, p.n ^ 2 do
        local g, v = p.givens[i], board and board[i] or -1
        if g ~= -1 and v ~= -1 and v ~= g then
            return nil
        end
        if v == -1 then
            v = g
        end
        d[i] = v == -1 and full or L.power[v]
        if not d[i] then
            return nil
        end
    end
    return d
end

-- Synchronous rounds keep the logical rating independent of scan direction.
local function propagate(p, d, stats, tick, hint, focus)
    local n, root = p.n, stats.nodes == 1
    local rows, cols, before = {}, {}, {}
    local wave = 0
    while true do
        wave = wave + 1
        for _, axis in ipairs({ "row", "col" }) do
            local out = axis == "row" and rows or cols
            for k = 1, n do
                local id = axis == "row" and k or n + k
                local line = M.line(d, n, axis, k)
                if not before[id] or not M.equal(line, before[id]) then
                    before[id] = line
                    out[k] = L.support(p, p[axis][k], line, tick)
                    if not out[k] then
                        return false
                    end
                end
            end
        end
        local changed, singles, candidate = false, 0, nil
        local best, width = nil, 99
        for i = 1, #d do
            local r, c = math.floor((i - 1) / n) + 1, (i - 1) % n + 1
            local a, b = rows[r][c], cols[c][r]
            local narrowed = band(a, b)
            if narrowed == 0 then
                return false
            end
            if narrowed ~= d[i] then
                changed, d[i] = true, narrowed
                if L.single[narrowed] ~= nil then
                    singles = singles + 1
                    if hint and (not candidate or focus == i) then
                        candidate =
                            { index = i, value = L.single[narrowed], rowMask = a, colMask = b, wave = wave }
                    end
                end
            end
            local count = L.size[narrowed]
            if count > 1 and count < width then
                best, width = i, count
            end
        end
        if candidate then
            return true, nil, candidate
        end
        if root and changed then
            stats.waves = wave
            if wave == 1 then
                stats.firstSingles = singles
            end
        end
        if not best then
            return true
        end
        if not changed then
            return true, best
        end
    end
end

-- limit=2 is an exhaustive uniqueness check up to the second witness.
-- A work limit yields "budget", which can never certify a puzzle.
local function budget(options)
    local used, limit = 0, options.workLimit or math.huge
    return function(cost)
        used = used + cost
        if used > limit then
            error(S.BUDGET, 0)
        end
        if options.tick then
            options.tick(cost)
        end
    end
end
S.BUDGET = {}
function S.solve(p, board, options)
    options = options or {}
    local result = { count = 0, nodes = 0, waves = 0, firstSingles = 0, status = "ok" }
    local d = domains(p, board)
    if not d then
        return result
    end
    local limit, tick = options.limit or 2, budget(options)
    local function search(state)
        result.nodes = result.nodes + 1
        local ok, choice = propagate(p, state, result, tick)
        if not ok then
            return
        end
        if not choice then
            local solved = {}
            for i = 1, #state do
                solved[i] = L.single[state[i]]
            end
            -- Independent rules check at every search leaf.
            if M.check(p, solved) == "solved" then
                result.count = result.count + 1
                if not result.solution then
                    result.solution = solved
                end
            end
            return
        end
        local mask = state[choice]
        while mask > 0 and result.count < limit do
            local flag = band(mask, -mask)
            mask = mask - flag
            local branch = M.copy(state)
            branch[choice] = flag
            search(branch)
        end
    end
    local ok, err = pcall(search, d)
    if not ok then
        if err ~= S.BUDGET then
            error(err, 0)
        end
        result.status = "budget"
    end
    return result
end

function S.hint(p, board, focus, options)
    options = options or {}
    -- These boards are certified unique. A wrong entry invalidates deductions.
    for i, v in ipairs(board) do
        if v ~= -1 and v ~= p.solution[i] then
            return nil, "conflict"
        end
    end
    local d = domains(p, board)
    if not d then
        return nil, "conflict"
    end
    local tick = budget(options)
    local function find()
        local ok, pick, h = propagate(p, d, { nodes = 1 }, tick, true, focus)
        if not ok then
            return nil, "conflict"
        end
        if h then
            return h
        end
        if not pick then
            return nil, "complete"
        end
        -- No single after propagation. Prove all alternatives impossible.
        local mask = d[pick]
        local wanted = p.solution[pick]
        for value = 0, p.n - p.blocks do
            if value ~= wanted and band(mask, L.power[value]) ~= 0 then
                local trial = M.copy(board)
                trial[pick] = value
                local a = S.solve(p, trial, { limit = 1, tick = tick })
                if a.status ~= "ok" then
                    return nil, "budget"
                end
                if a.count > 0 then
                    return nil, "ambiguous"
                end
            end
        end
        return { index = pick, value = wanted, alternatives = mask - L.power[wanted] }
    end
    local ok, h, why = pcall(find)
    if not ok then
        if h == S.BUDGET then
            return nil, "budget"
        end
        error(h, 0)
    end
    return h, why
end
return S
