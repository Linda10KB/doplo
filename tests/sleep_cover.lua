-- Sleep covers must stay local to an open game and leave reader preferences alone.
package.path = "doplo.koplugin/?.lua;" .. package.path

local device = { supported = true }

function device:supportsScreensaver()
    return self.supported
end

package.loaded.device = device
local nativeCalls = 0
local screensaver = {}

function screensaver:setup(event, eventMessage)
    nativeCalls = nativeCalls + 1
    self.screensaver_type = "cover"
    self.image_file = "my-book-cover.jpg"
    self.show_message = true
    self.event_message = eventMessage
    return event, eventMessage
end

package.loaded["ui/screensaver"] = screensaver
G_reader_settings = setmetatable({}, {
    __index = function()
        error("Sleep cover must not read or change persistent reader preferences")
    end,
})

local SleepCover = require("doplo/sleep_cover")
local owner = { path = "doplo.koplugin", window = {}, ui = {} }
local originalSetup = screensaver.setup
local coverPath = owner.path .. "/resources/doplo-cover.png"

assert(SleepCover.attach(owner))
local attachedSetup = screensaver.setup
assert(attachedSetup ~= originalSetup)
assert(SleepCover.attach(owner) and screensaver.setup == attachedSetup)

for cycle = 1, 3 do
    screensaver:setup()
    assert(screensaver.ui == owner.ui)
    assert(screensaver.screensaver_type == "cover")
    assert(screensaver.image_file == coverPath and screensaver.image == nil)
    assert(screensaver.show_message == false and screensaver.overlay_message == nil)
    assert(screensaver.screensaver_background == "white" and screensaver.prefix == "")
    assert(nativeCalls == 0)
    -- Native cleanup removes the per-sleep fields; the open game keeps its hook.
    screensaver.image_file = nil
    screensaver.screensaver_type = nil
end
print("PASS repeated sleeps use Doplo while leaving reader preferences untouched")

for _, event in ipairs({ "poweroff", "reboot" }) do
    local returnedEvent, returnedMessage = screensaver:setup(event, "Device event")
    assert(returnedEvent == event and returnedMessage == "Device event")
    assert(screensaver.image_file == "my-book-cover.jpg" and screensaver.show_message)
end
assert(nativeCalls == 2)

local originalOpen = io.open
io.open = function(path, mode)
    if path == coverPath then
        return nil
    end
    return originalOpen(path, mode)
end
screensaver:setup()
assert(nativeCalls == 3 and screensaver.image_file == "my-book-cover.jpg")
io.open = originalOpen

owner.window = nil
screensaver:setup()
assert(nativeCalls == 4 and screensaver.image_file == "my-book-cover.jpg")
SleepCover.detach(owner)
assert(screensaver.setup == originalSetup and owner.sleepCover == nil)
SleepCover.detach(owner)
print("PASS poweroff, reboot, missing asset and closed game use the normal cover")

owner.window = {}
assert(SleepCover.attach(owner))
local previousWrapper = screensaver.setup
local laterCalls = 0
local laterWrapper = function(currentScreensaver, ...)
    laterCalls = laterCalls + 1
    return previousWrapper(currentScreensaver, ...)
end
screensaver.setup = laterWrapper
local attachment = owner.sleepCover
SleepCover.detach(owner)
assert(screensaver.setup == laterWrapper and attachment.owner == nil)
screensaver:setup()
assert(laterCalls == 1 and nativeCalls == 5)
assert(screensaver.image_file == "my-book-cover.jpg")

assert(SleepCover.attach(owner))
screensaver:setup()
assert(screensaver.image_file == coverPath and nativeCalls == 5)
SleepCover.detach(owner)
assert(screensaver.setup == laterWrapper)
print("PASS closing and reopening preserves other plugins' screensaver hooks")

device.supported = false
assert(SleepCover.attach(owner) == false and screensaver.setup == laterWrapper)
device.supported = true
owner.path = "missing-plugin-directory"
assert(SleepCover.attach(owner) == false and screensaver.setup == laterWrapper)
owner.path = nil
assert(SleepCover.attach(owner) == false and screensaver.setup == laterWrapper)
print("PASS unsupported devices and incomplete installations remain usable")
