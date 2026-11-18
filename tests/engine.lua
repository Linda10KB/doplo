-- Run from the repository root with LuaJIT 2.1.
package.path = "doplo.koplugin/?.lua;" .. package.path
local bit = require("bit")
local M, L, S, G, D, Game =
    require("doplo/model"),
    require("doplo/line"),
    require("doplo/solver"),
    require("doplo/generator"),
    require("doplo/difficulty"),
    require("doplo/game")
local bank = require("doplo/bank")
local Layout = require("doplo/layout")
local cases = 0
local function test(label, f)
    f()
    cases = cases + 1
    print("PASS " .. label)
end
local function equal(a, b)
    assert(M.equal(a, b), table.concat(a or {}, ",") .. " != " .. table.concat(b or {}, ","))
end
local function puzzle(n, level, idx, kind, prefilled)
    kind = kind or (n < 7 and "classic" or "plus")
    local mode = prefilled == false and "empty" or "prefilled"
    return G.decode(kind, n, level, bank[kind][n][mode][level][idx or 1], prefilled)
end
test("Classic includes only the strict interior, including the zero case", function()
    equal(M.sums("classic", { 0, 1, 2, 3, 0 }), { 6 })
    equal(M.sums("classic", { 1, 0, 2, 3, 0 }), { 5 })
    equal(M.sums("classic", { 1, 0, 0, 3, 2 }), { 0 })
    equal(M.sums("classic", { 3, 0, 2, 0, 1 }), { 2 })
end)
test("Plus preserves clue order, edge runs and contiguous crosses", function()
    equal(M.sums("plus", { 1, 2, 0, 3, 0, 4, 5 }), { 3, 3, 9 })
    equal(M.sums("plus", { 0, 1, 2, 0, 3, 4, 5 }), { 3, 12 })
    equal(M.sums("plus", { 1, 2, 3, 4, 5, 0, 0 }), { 15 })
    equal(M.sums("plus", { 0, 1, 0, 0, 2, 3, 4, 5, 0, 6, 7, 8 }), { 1, 14, 21 })
    assert(M.checkLine(M.config("plus", 7), { 1, 2, 0, 3, 0, 4, 5 }, { 9, 3, 3 }) == "sums")
end)
test("Wrong range, duplicate digit, cross count, incomplete line and wrong sum", function()
    local cfg = M.config("classic", 5)
    assert(M.checkLine(cfg, { 0, 0, 0, -1, -1 }, { 0 }) == "blocks")
    assert(M.checkLine(cfg, { 0, 0, 1, 1, 3 }, { 0 }) == "duplicate")
    assert(M.checkLine(cfg, { 0, 0, 1, 4, 2 }, { 0 }) == "range")
    assert(M.checkLine(cfg, { 0, 0, 1, 2, -1 }, { 0 }) == "incomplete")
    assert(M.checkLine(cfg, { 0, 0, 1, 2, 3 }, { 2 }) == "sums")
    assert(M.checkLine(cfg, { 0, 0, 1, 2, 3 }, { 0 }) == "complete")
    assert(not L.support(M.config("plus", 7), { 16 }, M.array(7, 63)))
end)
test("Rows, columns, incomplete and invalid full grids checked without answer lookup", function()
    local p = puzzle(5, "Easy")
    assert(M.check(p, p.solution) == "solved" and M.check(p, p.givens) == "incomplete")
    local answer = p.solution
    p.solution = {}
    assert(M.check(p, answer) == "solved")
    local altered = M.copy(answer)
    altered[1] = -1
    local fixedStatus, _, _, fixedReason = M.check(p, altered)
    assert(fixedStatus == "invalid" and fixedReason == "given")
    p.col[3][1] = 99
    local s, axis, k = M.check(p, answer)
    assert(s == "invalid" and axis == "col" and k == 3)
end)
-- Independent oracle: enumerate complete permutations of the multiset and
-- parse clues from a string of digits split on blocks. No production sums or DP.
local function lines(cfg)
    local left = { [0] = cfg.blocks }
    for v = 1, cfg.n - cfg.blocks do
        left[v] = 1
    end
    local byClue = {}
    local function recurse(str)
        if #str == cfg.n then
            local sums = {}
            local function add(group)
                local s = 0
                for ch in group:gmatch(".") do
                    s = s + tonumber(ch)
                end
                sums[#sums + 1] = s
            end
            if cfg.kind == "classic" then
                add(assert(str:match("0([1-9]*)0")))
            else
                for run in str:gmatch("[1-9]+") do
                    add(run)
                end
            end
            local key = table.concat(sums, ",")
            byClue[key] = byClue[key] or {}
            byClue[key][#byClue[key] + 1] = str
            return
        end
        for v = 0, cfg.n - cfg.blocks do
            if left[v] > 0 then
                left[v] = left[v] - 1
                recurse(str .. v)
                left[v] = left[v] + 1
            end
        end
    end
    recurse("")
    return byClue
end
local cache = {}
test("Exact line domains match an independent permutation oracle", function()
    local rng = G.random(90210)
    for _, n in ipairs({ 5, 6, 7 }) do
        local cfg = M.config(n < 7 and "classic" or "plus", n)
        local oracle = lines(cfg)
        cache[n] = oracle
        for key, words in pairs(oracle) do
            local clue = {}
            for s in key:gmatch("%d+") do
                clue[#clue + 1] = tonumber(s)
            end
            for trial = 1, 8 do
                local full = 2 ^ (n - cfg.blocks + 1) - 1
                local allowed = M.array(n, full)
                if trial > 1 then
                    for pos = 1, n do
                        allowed[pos] = rng(full)
                    end
                end
                local wanted = M.array(n, 0)
                local found = false
                for _, word in ipairs(words) do
                    local fits = true
                    for pos = 1, n do
                        if bit.band(allowed[pos], 2 ^ tonumber(word:sub(pos, pos))) == 0 then
                            fits = false
                            break
                        end
                    end
                    if fits then
                        found = true
                        for pos = 1, n do
                            wanted[pos] = bit.bor(wanted[pos], 2 ^ tonumber(word:sub(pos, pos)))
                        end
                    end
                end
                local got = L.support(cfg, clue, allowed)
                if found then
                    equal(got, wanted)
                else
                    assert(not got)
                end
            end
        end
    end
end)
local function independentCount(p)
    local n = p.n
    local choices, prefix, col = {}, {}, {}
    for k = 1, n do
        choices[k] = {}
        prefix[k] = {}
        col[k] = ""
        for _, w in ipairs(cache[n][table.concat(p.row[k], ",")] or {}) do
            local fits = true
            for j = 1, n do
                local v = p.givens[(k - 1) * n + j]
                if v ~= -1 and v ~= tonumber(w:sub(j, j)) then
                    fits = false
                end
            end
            if fits then
                choices[k][#choices[k] + 1] = w
            end
        end
        for _, w in ipairs(cache[n][table.concat(p.col[k], ",")] or {}) do
            for j = 1, n do
                prefix[k][w:sub(1, j)] = true
            end
        end
    end
    local count = 0
    local function visit(r, old)
        if r > n then
            count = count + 1
            return
        end
        for _, w in ipairs(choices[r]) do
            local nextCol, ok = {}, true
            for c = 1, n do
                nextCol[c] = old[c] .. w:sub(c, c)
                if not prefix[c][nextCol[c]] then
                    ok = false
                    break
                end
            end
            if ok then
                visit(r + 1, nextCol)
            end
            if count >= 2 then
                break
            end
        end
    end
    visit(1, col)
    return count
end
test("Independent 5×5 row oracle agrees for all 48 bank puzzles and 60 new inputs", function()
    for _, level in ipairs(M.levels) do
        for j = 1, #bank.classic[5].prefilled[level] do
            assert(independentCount(puzzle(5, level, j)) == 1)
        end
    end
    local random = G.random(477)
    local seen = {}
    for j = 1, 60 do
        local p = G.candidate(M.config("classic", 5), random, j % 2 == 0 and 0 or 0.15)
        if j % 3 == 0 then
            p.col[1] = { 7 }
        end
        local cnt = independentCount(p)
        assert(S.solve(p).count == cnt)
        seen[cnt] = true
    end
    assert(seen[0] and seen[1] and seen[2])
end)
test("Independent board solver certifies all 48 Plus 7×7 puzzles", function()
    for _, level in ipairs(M.levels) do
        for j = 1, #bank.plus[7].prefilled[level] do
            assert(independentCount(puzzle(7, level, j)) == 1)
        end
    end
end)
test("Budget exhaustion cannot certify uniqueness or difficulty", function()
    local p = puzzle(12, "Expert")
    local a = S.solve(p, nil, { workLimit = 10 })
    assert(a.status == "budget" and not D.rate(a))
end)
test("Every size, mode and grade has twelve distinct, uniquely solved bank puzzles", function()
    local count, distinct = 0, {}
    for _, kind in ipairs({ "classic", "plus" }) do
        for _, n in ipairs(M.sizes[kind]) do
            for _, mode in ipairs({ "prefilled", "empty" }) do
                for _, level in ipairs(M.levels) do
                    local records = bank[kind][n][mode][level]
                    assert(#records == 12)
                    for j, record in ipairs(records) do
                        local p = puzzle(n, level, j, kind, mode == "prefilled")
                        local sig = kind .. mode .. n .. record[1] .. record[2]
                        assert(not distinct[sig])
                        distinct[sig] = true
                        assert(M.validPuzzle(p))
                        local r = S.solve(p)
                        assert(r.status == "ok" and r.count == 1 and D.rate(r, p) == level, kind .. n .. mode .. level)
                        equal(r.solution, p.solution)
                        if mode == "empty" then
                            assert(Game.new(p):filled() == 0)
                            equal(p.givens, M.array(n * n, -1))
                        end
                        count = count + 1
                    end
                end
            end
        end
    end
    assert(count == 960)
end)
test("Live offline generation produces every selected size and grade", function()
    for _, kind in ipairs({ "classic", "plus" }) do
        for _, n in ipairs(M.sizes[kind]) do
            for j, level in ipairs(M.levels) do
                local random = G.random(937 + n * 8 + j)
                local generated
                for _ = 1, 1800 do
                    generated = G.attempt(M.config(kind, n), level, random, { workLimit = 450000 })
                    if generated then
                        break
                    end
                end
                assert(generated, n .. " " .. level)
                local r = S.solve(generated)
                assert(M.validPuzzle(generated) and D.rate(r, generated) == level)
                equal(generated.solution, r.solution)
            end
        end
    end
end)
test("Live empty generation respects both the start option and chosen grade", function()
    for _, cfg in ipairs({ M.config("classic", 5), M.config("plus", 11) }) do
        for j, level in ipairs(M.levels) do
            local random, generated = G.random(135 + j * 7 + cfg.n)
            for _ = 1, 1200 do
                generated = G.attempt(cfg, level, random, { prefilled = false, workLimit = 600000 })
                if generated then break end
            end
            assert(generated, cfg.kind .. cfg.n .. level)
            assert(generated.prefilled == false and Game.new(generated):filled() == 0)
            local r = S.solve(generated)
            assert(D.rate(r, generated) == level and M.equal(r.solution, generated.solution))
        end
    end
end)
test("Logical hints are forced; wrong entries and a full board have no hint", function()
    local p = puzzle(5, "Hard")
    local b = M.copy(p.givens)
    while M.check(p, b) ~= "solved" do
        local h = assert(S.hint(p, b, 3))
        assert(b[h.index] == -1 and h.value == p.solution[h.index])
        for v = 0, 3 do
            if v ~= h.value then
                b[h.index] = v
                assert(S.solve(p, b, { limit = 1 }).count == 0)
            end
        end
        b[h.index] = h.value
    end
    local h, why = S.hint(p, b)
    assert(not h and why == "complete")
    b[1] = (b[1] + 1) % 4
    h, why = S.hint(p, b)
    assert(not h and why == "conflict")
end)
test("Expert contradiction hints eliminate every named alternative by independent search", function()
    local proved = false
    for j = 1, #bank.classic[5].prefilled.Expert do
        local p = puzzle(5, "Expert", j)
        local b = M.copy(p.givens)
        for _ = 1, 25 do
            local h = S.hint(p, b)
            if not h then
                break
            end
            if h.alternatives then
                local original = p.givens
                p.givens = M.copy(b)
                for v = 0, 3 do
                    if bit.band(h.alternatives, 2 ^ v) ~= 0 then
                        p.givens[h.index] = v
                        assert(independentCount(p) == 0)
                    end
                end
                p.givens[h.index] = h.value
                assert(independentCount(p) == 1)
                p.givens = original
                proved = true
                break
            end
            b[h.index] = h.value
        end
        if proved then
            break
        end
    end
    assert(proved)
end)
test("Given locks, pencil toggles, overwrite, erase, undo and branching redo", function()
    local g = Game.new(puzzle(5, "Easy"))
    local i = g.selected
    assert(not g:edit(1, 0, false))
    assert(g:edit(i, 2, true) and g.notes[i] == 4)
    assert(g:edit(i, 0, true) and g.notes[i] == 5)
    assert(g:edit(i, 1, false) and g.notes[i] == 0)
    assert(g:travel(false) and g.notes[i] == 5)
    assert(g:travel(true) and g.board[i] == 1)
    assert(g:edit(i, -1, false) and g.board[i] == -1)
    assert(g:travel(false) and g.board[i] == 1)
    assert(g:edit(i, 3, false) and not g:travel(true))
end)
test("Long games retain a consistent undo window and reject invalid saved data", function()
    local g = Game.new(puzzle(5, "Medium"))
    local i = g.selected
    for j = 1, 250 do
        assert(g:edit(i, j % 2, false))
    end
    assert(#g.history == 200 and g.cursor == 200)
    for _ = 1, 200 do
        assert(g:travel(false))
    end
    assert(not g:travel(false))
    local x = g:snapshot()
    x.notes[i] = 9999
    assert(not Game.restore(x))
end)
test("Portrait and landscape geometry keep every target on-screen and addressable", function()
    for _, kind in ipairs({ "classic", "plus" }) do
        for _, n in ipairs(M.sizes[kind]) do
        for _, wh in ipairs({ { 600, 800 }, { 1264, 1680 }, { 800, 600 }, { 1680, 1264 }, { 320, 480 } }) do
            local a = Layout.make(puzzle(n, "Hard", 1, kind), wh[1], wh[2], true)
            for i = 1, n * n do
                local b = Layout.cell(a, i)
                assert(Layout.cellAt(a, b.x + b.w / 2, b.y + b.h / 2) == i)
                assert(b.x > 0 and b.y > a.head and b.x + b.w <= a.w and b.y + b.h <= a.h)
                for _, bt in ipairs(a.buttons) do
                    assert(not Layout.inside(bt, b.x + b.w / 2, b.y + b.h / 2))
                end
            end
            assert(a.span == n and a.firstRow == 1 and a.firstCol == 1)
            assert(a.gy + n * a.cell <= a.panel.y or wh[1] >= wh[2] * 1.16)
            assert(a.detail.w >= a.px(90))
            for _, b in ipairs(a.buttons) do
                assert(b.id ~= "view")
                assert(b.x >= 0 and b.y >= 0 and b.x + b.w <= a.w and b.y + b.h <= a.h)
            end
        end
        end
    end
end)
test("Empty starts keep notes, edits and the mode through save restoration", function()
    for _, kind in ipairs({ "classic", "plus" }) do
        for _, n in ipairs(M.sizes[kind]) do
            local game = Game.new(puzzle(n, "Medium", 1, kind, false))
            assert(game:edit(1, 0, true) and game:edit(1, n - game.p.blocks, true))
            local restored = assert(Game.restore(game:snapshot()))
            assert(restored.p.prefilled == false and restored:filled() == 0)
            assert(restored.notes[1] == 1 + 2 ^ (n - restored.p.blocks))
            assert(restored:edit(1, 0, false) and restored:travel(false))
            assert(restored.notes[1] == 1 + 2 ^ (n - restored.p.blocks))
        end
    end
end)
print(("%d engine test groups passed."):format(cases))
