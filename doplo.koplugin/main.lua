-- SPDX-License-Identifier: AGPL-3.0-or-later
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UI = require("ui/uimanager")
local Data = require("datastorage")
local Settings = require("luasettings")
local Info = require("ui/widget/infomessage")
local Game = require("doplo/game")
local Gen = require("doplo/generator")
local Store = require("doplo/store")
local Plugin = WidgetContainer:extend({ name = "doplo", is_doc_only = false })

function Plugin:init()
    self.ui.menu:registerToMainMenu(self)
end
function Plugin:addToMainMenu(items)
    items.doplo = {
        text = "Doplo",
        sorting_hint = "tools",
        callback = function()
            self:openGame()
        end,
    }
end
function Plugin:ready(cfg, level)
    local prefilled = self.settings:readSetting("prefilled_cells", false)
    local mode = prefilled and "prefilled" or "empty"
    local records = require("doplo/bank")[cfg.kind][cfg.n][mode][level]
    local key = table.concat({ "ready", cfg.kind, cfg.n, mode, level }, "_")
    local index = self.settings:readSetting(key, 0) % #records + 1
    self.settings:saveSetting(key, index)
    return Gen.decode(cfg.kind, cfg.n, level, records[index], prefilled)
end
function Plugin:activate(id, game)
    self.settings:saveSetting("active", id):flush()
    if self.window then
        self.window:use(id, game)
    else
        local Screen = require("doplo/screen")
        self.window = Screen:new({ owner = self, id = id, game = game })
        UI:show(self.window, "ui")
    end
end
function Plugin:start(p)
    if self.window and not self.window:flush() then
        return
    end
    local id, game = self.store:newId(), Game.new(p)
    local ok, err = self.store:save(id, game)
    if not ok then
        UI:show(Info:new({ text = "Could not save the new puzzle.\n" .. tostring(err) }))
        return
    end
    self:activate(id, game)
end
function Plugin:resume(id)
    if self.window and not self.window:flush() then
        return
    end
    local game = self.store:load(id)
    if game then
        self:activate(id, game)
        return true
    end
end
function Plugin:openGame()
    if self.window then
        return
    end
    local dir = Data:getSettingsDir()
    local err
    self.store, err = Store.new(dir .. "/doplo-games")
    if not self.store then
        UI:show(Info:new({ text = "Could not open Doplo saves.\n" .. tostring(err) }))
        return
    end
    self.settings = Settings:open(dir .. "/doplo.lua")
    if self:resume(self.settings:readSetting("active")) then
        return
    end
    local history = self.store:list()
    if history[1] and self:resume(history[1].id) then
        return
    end
    self:start(self:ready({ kind = "classic", n = 5 }, "Easy"))
end
return Plugin
