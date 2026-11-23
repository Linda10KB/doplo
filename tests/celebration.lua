-- Run from the repository root with LuaJIT 2.1.
local modulePath = "doplo.koplugin/doplo/celebration.lua"
local complimentCount = 616
local historyKey = "celebration_history"

local function copy(value)
    if type(value) ~= "table" then
        return value
    end
    local result = {}
    for key, entry in pairs(value) do
        result[key] = copy(entry)
    end
    return result
end

local function newSettings(values)
    local settings = { values = copy(values or {}), flushCount = 0 }

    function settings:readSetting(key)
        return copy(self.values[key])
    end

    function settings:saveSetting(key, value)
        self.values[key] = copy(value)
        return self
    end

    function settings:flush()
        self.flushCount = self.flushCount + 1
        return self
    end

    return settings
end

local function loadCelebration(entropy, entropyTracker)
    local isolatedMath = setmetatable({
        random = function()
            error("Compliments must not use the shared random generator")
        end,
        randomseed = function()
            error("Compliments must not seed the shared random generator")
        end,
    }, { __index = math })
    local environment = setmetatable({
        math = isolatedMath,
        io = {
            open = function(path, mode)
                assert(path == "/dev/urandom" and mode == "rb")
                if entropyTracker then
                    entropyTracker.opens = entropyTracker.opens + 1
                end
                if not entropy then
                    return nil
                end
                return {
                    read = function(_, count)
                        assert(count == 4)
                        return entropy
                    end,
                    close = function()
                        if entropyTracker then
                            entropyTracker.closes = entropyTracker.closes + 1
                        end
                    end,
                }
            end,
        },
    }, { __index = _G })
    local module = assert(loadfile(modulePath))
    setfenv(module, environment)
    return module()
end

local function nextCompliment(celebration, settings)
    local compliment = celebration.next(settings)
    assert(#compliment > 10 and not compliment:find("\n", 1, true))
    assert(settings.values[historyKey].last == compliment)
    assert(settings.values[historyKey].seen[compliment] == true)
    return compliment
end

local function collectRound(celebration, settings, knownCompliments)
    local seen = {}
    local order = {}
    for index = 1, complimentCount do
        local compliment = nextCompliment(celebration, settings)
        assert(not seen[compliment], "Repeated before the round ended: " .. compliment)
        if knownCompliments then
            assert(knownCompliments[compliment], "Unexpected compliment in a new round")
        end
        seen[compliment] = true
        order[index] = compliment
    end
    return seen, order
end

local function test(name, callback)
    callback()
    print("ok - " .. name)
end

test("616 unique compliments, reshuffled rounds and no boundary repeat", function()
    local celebration = loadCelebration("\1\2\3\4")
    local settings = newSettings()
    local knownCompliments, firstOrder = collectRound(celebration, settings)
    local _, secondOrder = collectRound(celebration, settings, knownCompliments)
    assert(firstOrder[complimentCount] ~= secondOrder[1])
    assert(table.concat(firstOrder) ~= table.concat(secondOrder), "A round repeated its order")
    assert(settings.flushCount == complimentCount * 2)
    assert(knownCompliments["Alles wordt toch net wat leuker zodra jij je ermee bemoeit."])
    assert(knownCompliments["Echt heel goed dat je bestaat. Vooral zo."])
end)

test("history and random progress survive settings and module reloads", function()
    local tracker = { opens = 0, closes = 0 }
    local celebration = loadCelebration("\5\6\7\8", tracker)
    local settings = newSettings({ games = { current = "unchanged" } })
    local seen = {}
    for _ = 1, 120 do
        seen[nextCompliment(celebration, settings)] = true
    end
    assert(tracker.opens == 1 and tracker.closes == 1)

    local continuedSettings = newSettings(settings.values)
    local continuedMessage = nextCompliment(celebration, continuedSettings)
    settings = newSettings(settings.values)
    celebration = loadCelebration("\9\9\9\9", tracker)
    local reloadedMessage = nextCompliment(celebration, settings)
    assert(continuedMessage == reloadedMessage, "Persisted random state was not resumed")
    assert(not seen[reloadedMessage])
    seen[reloadedMessage] = true
    for _ = 122, complimentCount do
        local compliment = nextCompliment(celebration, settings)
        assert(not seen[compliment], "Reload lost compliment history")
        seen[compliment] = true
    end
    assert(tracker.opens == 1 and tracker.closes == 1)
    assert(settings.values.games.current == "unchanged")
end)

test("device entropy produces different orders without touching math.random", function()
    local first = loadCelebration("\0\0\0\1")
    local second = loadCelebration("\212\92\140\73")
    local _, firstOrder = collectRound(first, newSettings())
    local _, secondOrder = collectRound(second, newSettings())
    assert(firstOrder[1] ~= secondOrder[1])
    local differingPositions = 0
    for index = 1, complimentCount do
        if firstOrder[index] ~= secondOrder[index] then
            differingPositions = differingPositions + 1
        end
    end
    assert(differingPositions > complimentCount * 0.9)
end)

test("the old last-message setting migrates without altering other settings", function()
    local legacyCompliment = "Wauw, ook vandaag ben jij weer een denderend succes."
    local celebration = loadCelebration("\0\0\0\1")
    local settings = newSettings({ last_celebration = 1, current_game = "keep-me" })
    local seen = { [legacyCompliment] = true }
    for _ = 2, complimentCount do
        local compliment = nextCompliment(celebration, settings)
        assert(not seen[compliment], "Migration repeated a known compliment")
        seen[compliment] = true
    end
    local lastCompliment = settings.values[historyKey].last
    local restartedCompliment = nextCompliment(celebration, settings)
    assert(seen[restartedCompliment] and restartedCompliment ~= lastCompliment)
    assert(settings.values.last_celebration == 1)
    assert(settings.values.current_game == "keep-me")
end)

test("unavailable or short device entropy has a working fallback", function()
    for _, entropy in ipairs({ false, "x" }) do
        local tracker = { opens = 0, closes = 0 }
        local celebration = loadCelebration(entropy, tracker)
        local settings = newSettings()
        local first = nextCompliment(celebration, settings)
        local second = nextCompliment(celebration, settings)
        assert(first ~= second and tracker.opens == 1)
        assert(tracker.closes == (entropy and 1 or 0))
    end
end)

test("damaged history and invalid legacy settings recover", function()
    local invalidHistories = {
        false,
        17,
        "broken",
        {},
        { version = 999 },
        { version = 1, seen = false, last = {} },
        { version = 1, seen = { unknown = true }, random_state = 0 },
        { version = 1, seen = "broken", random_state = math.huge },
        { version = 1, random_state = 0 / 0 },
    }
    for _, history in ipairs(invalidHistories) do
        local celebration = loadCelebration("\1\2\3\4")
        local settings = newSettings({ [historyKey] = history, last_celebration = -1 })
        local first = nextCompliment(celebration, settings)
        local second = nextCompliment(celebration, settings)
        assert(first ~= second)
        assert(settings.values[historyKey].version == 1)
        assert(not settings.values[historyKey].seen.unknown)
    end

    local celebration = loadCelebration("\0\0\0\1")
    local last = "Wauw, ook vandaag ben jij weer een denderend succes."
    local settings = newSettings({ [historyKey] = { version = 1, last = last } })
    assert(nextCompliment(celebration, settings) ~= last)
    assert(settings.values[historyKey].seen[last])
end)

print("Celebration tests passed")
