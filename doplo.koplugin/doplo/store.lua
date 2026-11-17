-- SPDX-License-Identifier: AGPL-3.0-or-later
local Game = require("doplo/game")
local json = require("rapidjson")
local lfs = require("libs/libkoreader-lfs")
local fs = require("ffi/util")
local Store = {}
Store.__index = Store
local function validId(id)
    return type(id) == "string" and id:match("^%d%d%d%d%d%d%d%d%-%d%d%d%d%d%d%-%d+$")
end
function Store.new(dir)
    if lfs.attributes(dir, "mode") ~= "directory" then
        local ok, err = lfs.mkdir(dir)
        if not ok then
            return nil, err
        end
    end
    return setmetatable({ dir = dir }, Store)
end
function Store:path(id, slot)
    assert(validId(id))
    return self.dir .. "/" .. id .. "." .. slot .. ".json"
end
function Store:newId()
    local stamp = os.date("!%Y%m%d-%H%M%S")
    for seq = 1, 9999 do
        local id = ("%s-%04d"):format(stamp, seq)
        if not lfs.attributes(self:path(id, "a")) and not lfs.attributes(self:path(id, "b")) then
            return id
        end
    end
    error("Too many games created in one second")
end
local function readGame(path)
    if not lfs.attributes(path) then
        return
    end
    local ok, data = pcall(json.load, path)
    if not ok or type(data) ~= "table" then
        return
    end
    return Game.restore(data)
end
function Store:load(id)
    if not validId(id) then
        return nil
    end
    local a, b = readGame(self:path(id, "a")), readGame(self:path(id, "b"))
    if a and (not b or a.revision >= b.revision) then
        return a
    end
    return b
end
-- Write only the older slot, using an atomic replacement in the same folder.
-- The other slot remains readable after an interrupted write or a torn file.
function Store:save(id, game)
    local revision = game.revision + 1
    local dst = self:path(id, revision % 2 == 1 and "a" or "b")
    local tmp = dst .. ".tmp"
    local snap = game:snapshot()
    snap.revision, snap.modified = revision, os.time()
    local bytes, err = json.encode(snap)
    if not bytes then
        return nil, err
    end
    local f, openErr = io.open(tmp, "wb")
    if not f then
        return nil, openErr
    end
    local ok, why = f:write(bytes)
    if ok then
        ok, why = f:flush()
    end
    if ok then
        ok, why = fs.fsyncOpenedFile(f)
    end
    local closed, closeErr = f:close()
    if not ok or not closed then
        os.remove(tmp)
        return nil, why or closeErr
    end
    ok, why = os.rename(tmp, dst)
    if not ok then
        os.remove(tmp)
        return nil, why
    end
    fs.fsyncDirectory(dst)
    game.revision, game.modified = revision, snap.modified
    return true
end
function Store:list()
    local ids, list = {}, {}
    for name in lfs.dir(self.dir) do
        local id = name:match("^(.+)%.[ab]%.json$")
        if validId(id) then
            ids[id] = true
        end
    end
    for id in pairs(ids) do
        local game = self:load(id)
        if game then
            list[#list + 1] = {
                id = id,
                kind = game.p.kind,
                n = game.p.n,
                level = game.p.level,
                filled = game:filled(),
                solved = game:solved(),
                modified = game.modified or 0,
            }
        end
    end
    table.sort(list, function(a, b)
        if a.modified == b.modified then
            return a.id > b.id
        end
        return a.modified > b.modified
    end)
    return list
end
return Store
