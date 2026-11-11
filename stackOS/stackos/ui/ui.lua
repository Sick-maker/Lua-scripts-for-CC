-- ui/ui.lua
-- Finds every advanced monitor (networked ones and the one on computer_0's top),
-- gives each its own session, routes taps to the right one, and redraws only
-- what changed: about 10 frames a second while something animates, 4 otherwise.

local Session = require("ui.session")
local theme = require("ui.theme")
local log = require("kernel.log")

local M = { sessions = {}, pages = {} }

function M.init()
  M.chrome = require("ui.chrome")
  M.pages.splash = require("layers.splash")
  M.pages.home = require("layers.home")
  M.pages.switchboard = require("layers.switchboard")
  M.pages.settings = require("layers.settings")
  M.pages.system = require("layers.system")
  M.scan()
end

local function isMonitor(n)
  local ok, t = pcall(peripheral.getType, n)
  return ok and t == "monitor"
end

function M.scan()
  for _, n in ipairs(peripheral.getNames()) do
    if isMonitor(n) and not M.sessions[n] then
      local dev = peripheral.wrap(n)
      if dev and dev.isColour and dev.isColour() then
        local ok, s = pcall(Session.new, n, dev, M)
        if ok then
          M.sessions[n] = s
          if s.cfg.splash == false then s:go(s:defaultPage()) else s:go("splash") end
          log.info("screen ready: " .. n)
        else
          log.error(("screen %s failed: %s"):format(n, tostring(s)))
        end
      end
    end
  end
end

local function safeRender(s)
  local ok, err = pcall(s.render, s)
  if not ok then log.error(("render %s: %s"):format(s.name, tostring(err))) end
end

function M.task()
  for _, s in pairs(M.sessions) do safeRender(s) end
  local frame = os.startTimer(0.1)
  local lastMinute = -1
  while true do
    local ev = table.pack(os.pullEvent())
    local e = ev[1]
    if e == "monitor_touch" then
      local s = M.sessions[ev[2]]
      if s then
        local ok, err = pcall(s.touch, s, ev[3], ev[4])
        if not ok then log.error("tap on " .. s.name .. ": " .. tostring(err)) end
        safeRender(s)
      end
    elseif e == "monitor_resize" then
      local s = M.sessions[ev[2]]
      if s then s:applyDisplay() end
    elseif e == "peripheral" then
      M.scan()
    elseif e == "peripheral_detach" then
      M.sessions[ev[2]] = nil
    elseif e == "stackos_state" or e == "stackos_devices" or e == "stackos_log" then
      for _, s in pairs(M.sessions) do s.dirty = true end
    elseif e == "timer" and ev[2] == frame then
      local now = os.epoch("utc")
      local minute = math.floor(os.time() * 60)
      local tick = minute ~= lastMinute
      lastMinute = minute
      local anim = false
      for _, s in pairs(M.sessions) do
        if s.toastText and now >= (s.toastUntil or 0) then s.toastText = nil; s.dirty = true end
        if s.armed and now >= (s.armedUntil or 0) then s.armed = nil; s.dirty = true end
        if s.dirty or s.animating or tick then safeRender(s) end
        if s.animating then anim = true end
      end
      frame = os.startTimer(anim and 0.1 or 0.25)
    end
  end
end

function M.shutdown()
  for _, s in pairs(M.sessions) do
    pcall(function()
      local d = s.dev
      theme.reset(d)
      d.setTextScale(1)
      d.setBackgroundColour(colours.black)
      d.setTextColour(colours.white)
      d.clear()
      d.setCursorPos(2, 2)
      d.write("stackOS is stopped.")
      d.setCursorPos(2, 3)
      d.setTextColour(colours.lightGrey)
      d.write("Start it on computer_0.")
    end)
  end
end

return M
