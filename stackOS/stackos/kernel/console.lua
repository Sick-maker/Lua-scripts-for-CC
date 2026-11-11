-- kernel/console.lua
-- Keeps computer_0's own screen showing a short status while the monitors do the work.

local version = require("version")
local log = require("kernel.log")

local M = {}

local function hms(s)
  s = math.floor(s)
  return ("%02d:%02d:%02d"):format(math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
end

function M.draw()
  local sched = require("kernel.sched")
  local devices = require("services.devices")
  local ui = require("ui.ui")
  local w, h = term.getSize()
  term.setBackgroundColour(colours.black)
  term.clear()
  term.setCursorPos(1, 1)
  term.setTextColour(colours.lime)
  term.write(("stackOS %s running"):format(version.version))
  term.setTextColour(colours.white)
  local screens = 0
  for _ in pairs(ui.sessions) do screens = screens + 1 end
  term.setCursorPos(1, 3)
  term.write(("Screens  %d"):format(screens))
  term.setCursorPos(1, 4)
  term.write(("Devices  %d of %d answering"):format(devices.okCount or 0, devices.expCount or 0))
  term.setCursorPos(1, 5)
  term.write(("Uptime   %s"):format(hms(sched.uptime())))
  term.setCursorPos(1, 6)
  term.setTextColour(colours.lightGrey)
  term.write("Hold Ctrl+T to stop stackOS.")
  term.setCursorPos(1, 8)
  term.setTextColour(colours.grey)
  term.write(("-"):rep(w))
  local lines = log.tail(h - 8)
  for i, l in ipairs(lines) do
    term.setCursorPos(1, 8 + i)
    term.write(l:sub(1, w))
  end
end

function M.task()
  while true do
    pcall(M.draw)
    sleep(2)
  end
end

return M
