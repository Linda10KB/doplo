-- SPDX-License-Identifier: AGPL-3.0-or-later
local M = require("doplo/model")
local S = require("doplo/solver")
local Difficulty = require("doplo/difficulty")
local G = {}
-- Private PRNG. Does not change KOReader's process-wide random state.
function G.random(seed)
    local state = math.floor(seed) % 2147483646 + 1
    return function(bound)
        state = (state * 48271) % 2147483647
        return 1 + math.floor((state / 2147483647) * bound)
    end
end
local function shuffled(n, random)
    local a = {}
    for i = 1, n do
        a[i] = i
    end
    for i = n, 2, -1 do
        local j = random(i)
        a[i], a[j] = a[j], a[i]
    end
    return a
end

function G.candidate(cfg, random, fraction)
    local n, digits, solution = cfg.n, cfg.n - cfg.blocks, {}
    local rows, cols, symbols = shuffled(n, random), shuffled(n, random), shuffled(n, random)
    -- Isotopes of a cyclic Latin square. Collapse distinct extra symbols into
    -- blocks only after shuffling, preserving all row/column multiplicities.
    for r = 1, n do
        for c = 1, n do
            local v = symbols[(rows[r] + cols[c] - 2) % n + 1]
            solution[#solution + 1] = v <= digits and v or 0
        end
    end
    local p = M.puzzle(cfg, solution)
    local order = shuffled(n * n, random)
    for k = 1, math.floor(fraction * n * n + 0.5) do
        local i = order[k]
        p.givens[i] = solution[i]
    end
    return p
end
local densities = { Easy = { 28, 55 }, Medium = { 14, 38 }, Hard = { 3, 25 }, Expert = { 0, 17 } }
function G.attempt(cfg, level, random, opts)
    opts = opts or {}
    local range = densities[level]
    local fraction = (range[1] + random(range[2] - range[1] + 1) - 1) / 100
    local p = G.candidate(cfg, random, opts.prefilled == false and 0 or fraction)
    p.prefilled = opts.prefilled ~= false
    local r = S.solve(p, nil, opts)
    p.level = Difficulty.rate(r, p)
    if p.level == level and M.equal(r.solution, p.solution) then
        return p, r
    end
    return nil, r
end

function G.encode(p)
    local sol, mask = {}, {}
    for i, v in ipairs(p.solution) do
        sol[i] = tostring(v)
        mask[i] = p.givens[i] == -1 and "." or tostring(v)
    end
    return table.concat(sol), table.concat(mask)
end
function G.decode(kind, n, level, record, prefilled)
    local a, b = {}, {}
    for i = 1, n ^ 2 do
        a[i] = tonumber(record[1]:sub(i, i))
        b[i] = tonumber(record[2]:sub(i, i)) or -1
    end
    local p = M.puzzle(M.config(kind, n), a, b)
    p.level, p.prefilled = level, prefilled ~= false
    return p
end
return G
