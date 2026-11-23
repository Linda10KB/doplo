-- SPDX-License-Identifier: AGPL-3.0-or-later
local Device = require("device")
local SleepCover = {}

local function canRead(path)
    local file = io.open(path, "rb")
    if not file then
        return false
    end
    file:close()
    return true
end

local function prepareCover(screensaver, owner, coverPath)
    -- Use the native image renderer, rotation, refresh and wake-up handling.
    -- These are runtime fields: none of the reader's saved settings change.
    screensaver.ui = owner.ui
    screensaver.screensaver_type = "cover"
    screensaver.image_file = coverPath
    screensaver.image = nil
    screensaver.screensaver_background = "white"
    screensaver.show_message = false
    screensaver.prefix = ""
    screensaver.event_message = nil
    screensaver.overlay_message = nil
end

function SleepCover.attach(owner)
    if owner.sleepCover then
        return true
    end
    if not Device.supportsScreensaver or not Device:supportsScreensaver() then
        return false
    end
    if not owner.window or not owner.ui or type(owner.path) ~= "string" then
        return false
    end

    local coverPath = owner.path .. "/resources/doplo-cover.png"
    if not canRead(coverPath) then
        return false
    end
    local loaded, screensaver = pcall(require, "ui/screensaver")
    if not loaded or type(screensaver) ~= "table" or type(screensaver.setup) ~= "function" then
        return false
    end

    local attachment = {
        owner = owner,
        screensaver = screensaver,
        originalSetup = screensaver.setup,
    }
    attachment.setupWrapper = function(currentScreensaver, event, ...)
        local activeOwner = attachment.owner
        if event or not activeOwner or not activeOwner.window or not canRead(coverPath) then
            return attachment.originalSetup(currentScreensaver, event, ...)
        end
        -- KOReader prepares and displays the cover before broadcasting Suspend.
        -- Intercept setup while the game is open, rather than changing settings
        -- in onSuspend, which would be too late on some devices.
        prepareCover(currentScreensaver, activeOwner, coverPath)
    end

    owner.sleepCover = attachment
    screensaver.setup = attachment.setupWrapper
    return true
end

function SleepCover.detach(owner)
    local attachment = owner.sleepCover
    if not attachment then
        return
    end
    if attachment.screensaver.setup == attachment.setupWrapper then
        attachment.screensaver.setup = attachment.originalSetup
    end
    -- A later plugin may have wrapped our wrapper. Leave its hook intact while
    -- making our part a pass-through and releasing the game and reader UI.
    attachment.owner = nil
    owner.sleepCover = nil
end

return SleepCover
