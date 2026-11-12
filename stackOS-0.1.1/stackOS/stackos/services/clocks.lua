-- services/clocks.lua
-- Samples the two system clocks four times a second, which is fast enough to
-- see both blinking. A clock counts as running if it changed recently. Screens
-- show a simulated version driven by game time (fast: 10 ticks off, 10 on;
-- slow: 40 off, 40 on) so the difference between them is easy to see. The
-- switchboard keeps showing the raw samples.

local registry = require("data.registry")

local M = { lastChange = {}, prev = {}, side = {} }
local SIDES = { "top", "bottom", "left", "right", "front", "back" }
local C = registry.clocks

local function now() return os.epoch("utc") end

local function sample(id)
  local integ = require("services.integrators")
  local name = "redstoneIntegrator_" .. id
  local st = integ.state[id]
  if not st or not peripheral.isPresent(name) then return end
  local level
  local side = M.side[id] or st.side
  if side then
    local ok, v = pcall(peripheral.call, name, "getAnalogInput", side)
    if ok and type(v) == "number" then level = v end
  end
  if not level or (level == 0 and not M.side[id]) then
    level = 0
    for _, s in ipairs(SIDES) do
      local ok, v = pcall(peripheral.call, name, "getAnalogInput", s)
      if ok and type(v) == "number" and v > 0 then
        level, M.side[id] = v, s
        break
      end
    end
  end
  local on = level > 0
  st.level, st.on, st.present = level, on, true
  if M.prev[id] ~= nil and M.prev[id] ~= on then M.lastChange[id] = now() end
  M.prev[id] = on
end

-- Running = changed within a little over one full cycle
function M.fastRunning() return M.lastChange[C.fast] ~= nil and now() - M.lastChange[C.fast] < 2500 end
function M.slowRunning() return M.lastChange[C.slow] ~= nil and now() - M.lastChange[C.slow] < 6000 end
function M.running() return M.fastRunning() and M.slowRunning() end

-- Simulated states from game time; off when the real clock isn't running
local function tick() return math.floor(os.epoch("ingame") / 3600) end
function M.simFast() return M.fastRunning() and math.floor(tick() / C.fastHalf) % 2 == 1 end
function M.simSlow() return M.slowRunning() and math.floor(tick() / C.slowHalf) % 2 == 1 end

function M.task()
  while true do
    parallel.waitForAll(function() sample(C.fast) end, function() sample(C.slow) end)
    os.queueEvent("stackos_clock")
    sleep(0.25)
  end
end

return M
