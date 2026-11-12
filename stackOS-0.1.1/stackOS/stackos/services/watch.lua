-- services/watch.lua
-- Every command that has a sensor to confirm it gets watched. If the sensor
-- confirms in time, it's logged and the watch ends. Halfway to the deadline the
-- watch turns "slow"; past it, it turns "failed": an alert goes to every screen
-- and the watch stays visible until the sensor catches up or a new command
-- replaces it. A new command on the same thing (a door, the elevator) replaces
-- the old watch, so reversing an action never raises a false alarm.

local log = require("kernel.log")
local registry = require("data.registry")

local M = { active = {}, last = {} }

local function now() return os.epoch("utc") end

local function currentFloor()
  local integ = require("services.integrators")
  for _, f in ipairs(registry.elevator.floors) do
    local st = integ.state[f.at]
    if st and st.on then return f.name end
  end
end

-- How long a trip to `target` should take from where the car is now
function M.tripSeconds(target)
  local from = currentFloor()
  if not from then return registry.elevator.trip.TOP.LOW end
  if from == target then return 0 end
  return registry.elevator.trip[from][target] or registry.elevator.trip.TOP.LOW
end

function M.expect(spec)
  local integ = require("services.integrators")
  local within = spec.within
  if within == "trip" then within = M.tripSeconds(spec.target) + 10 end
  local check
  if spec.sensor then
    local want = spec.want ~= false
    check = function()
      local st = integ.state[spec.sensor]
      return st and st.present and st.on == want
    end
  elseif spec.clocks ~= nil then
    local clocks = require("services.clocks")
    check = function() return clocks.running() == spec.clocks end
  else
    return
  end
  local t = now()
  M.active[spec.key] = {
    key = spec.key, spec = spec, check = check, started = t,
    deadline = t + within * 1000, within = within, state = "pending",
  }
  os.queueEvent("stackos_state")
end

function M.get(key) return M.active[key] end

-- Seconds since the watch started
function M.elapsed(w) return (now() - w.started) / 1000 end

local function broadcast(text, role, secs)
  local ok, ui = pcall(require, "ui.ui")
  if ok and ui.broadcast then ui.broadcast(text, role, secs) end
end

function M.step()
  local t = now()
  for key, w in pairs(M.active) do
    local ok, done = pcall(w.check)
    if ok and done then
      M.active[key] = nil
      M.last[key] = { ok = true, at = t, spec = w.spec }
      if w.state == "failed" then
        log.info(("confirmed late: %s after %.1f s"):format(w.spec.ok or key, (t - w.started) / 1000))
        broadcast(w.spec.ok .. " (late)", "ok", 4)
      else
        log.info(("confirmed: %s in %.1f s"):format(w.spec.ok or key, (t - w.started) / 1000))
      end
      os.queueEvent("stackos_state")
    elseif t > w.deadline and w.state ~= "failed" then
      w.state = "failed"
      M.last[key] = { ok = false, at = t, spec = w.spec }
      log.warn(("%s within %d s"):format(w.spec.fail or ("no confirmation for " .. key), w.within))
      broadcast(w.spec.fail or ("No confirmation: " .. key), "alert", 8)
      os.queueEvent("stackos_state")
    elseif w.state == "pending" and t > w.started + (w.deadline - w.started) / 2 then
      w.state = "slow"
      os.queueEvent("stackos_state")
    end
  end
end

function M.task()
  while true do
    sleep(0.25)
    M.step()
  end
end

return M
