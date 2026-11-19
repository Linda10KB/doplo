-- Run from the repository root with LuaJIT 2.1.
package.path = "doplo.koplugin/?.lua;" .. package.path
local Tutorial = require("doplo/tutorial")

-- Deliberately provide no game: tutorial practice must be independent of it.
local screen = {}

function screen:choose(title, rows)
    self.dialog = { title = title, rows = rows }
end

local function choose(label)
    for _, row in ipairs(screen.dialog.rows) do
        for _, option in ipairs(row) do
            if option[1] == label then
                screen.dialog = nil
                if option[2] then
                    option[2]()
                end
                return
            end
        end
    end
    error("Missing tutorial choice: " .. label)
end

local function expectTitle(fragment)
    assert(screen.dialog.title:find(fragment, 1, true), screen.dialog.title)
end

Tutorial.show(screen)
choose("Doplo")
expectTitle("Practice 1/3")
choose("1")
expectTitle("Not quite.")
expectTitle("Practice 1/3")
choose("2")
expectTitle("Correct!")
choose("Try again")
expectTitle("Practice 1/3")
choose("2")
choose("Next")
expectTitle("Practice 2/3")
choose("6")
expectTitle("Not quite.")
choose("5")
expectTitle("outside the blocks")
choose("Next")
choose("0")
expectTitle("no digits between the blocks")
choose("Controls")
expectTitle("Practice complete")
choose("Practice again")
expectTitle("Practice 1/3")
choose("Back")
expectTitle("How to play")
print("PASS classic tutorial answers, feedback, retry and restart")

choose("Doplo Plus")
expectTitle("Practice 1/4")
choose("5")
choose("Next")
choose("9 · 3 · 3")
expectTitle("Not quite.")
choose("3 · 3 · 9")
expectTitle("in that order")
choose("Next")
choose("Back")
expectTitle("Practice 2/4")
choose("3 · 3 · 9")
choose("Next")
choose("0 · 3 · 12")
expectTitle("Not quite.")
choose("3 · 12")
expectTitle("right edge counts")
choose("Next")
choose("0 · 15")
expectTitle("Not quite.")
choose("15")
expectTitle("no zero clues")
choose("Controls")
expectTitle("Practice complete")
choose("Other game")
expectTitle("How to play")
choose("Back to puzzle")
assert(screen.dialog == nil)
print("PASS Plus tutorial run ordering, edge runs, touching blocks and exit")
