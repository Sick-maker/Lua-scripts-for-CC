-- services/integrators.lua
-- Reads every sensor integrator once a second (all in parallel, every face) and
-- drives the output integrators: pulses, holds and analog levels. Each integrator
-- touches only its own device, so outputs go to every face at once.

local registry = require("data.registry")
local log = require("kernel.log")
local store = require("kernel.store")

local M = { state = {}, list = {}, lastPoll = 0, pollMs = 0, polls = 0 }

local SIDES = { "top", "bottom", "left", "right", "front", "back" }
local INPUT = { read = true, analog = true }
local OUTPUT = { pulse = true, hold = true, aout = true, cover = true }

local function pname(id) return "redstoneIntegrator_" .. id end
local reapply -- defined further down, used by the poll task

function M.init()
  M.state, M.list = {}, {}
  for id in pairs(registry.integrators) do
    M.state[id] = { level = 0, on = false, out = 0, present = false }
    M.list[#M.list + 1] = id
  end
  table.sort(M.list)
end

local function readInput(id)
  local n, st = pname(id), M.state[id]
  if not peripheral.isPresent(n) then st.present = false return end
  st.present = true
  local best, side = 0, nil
  for _, s in ipairs(SIDES) do
    local ok, v = pcall(peripheral.call, n, "getAnalogInput", s)
    if ok and type(v) == "number" and v > best then best, side = v, s end
  end
  st.level, st.on, st.side = best, best > 0, side
end

local function readOutput(id)
  local n, st = pname(id), M.state[id]
  if not peripheral.isPresent(n) then st.present = false return end
  st.present = true
  local best = 0
  for _, s in ipairs(SIDES) do
    local ok, v = pcall(peripheral.call, n, "getAnalogOutput", s)
    if ok and type(v) == "number" and v > best then best = v end
  end
  st.out = best
end

local function runAll(kinds, fn)
  local fns = {}
  for _, id in ipairs(M.list) do
    if kinds[registry.integrators[id].kind] then
      fns[#fns + 1] = function() fn(id) end
    end
  end
  if #fns > 0 then parallel.waitForAll(table.unpack(fns)) end
end

local function signature()
  local parts = {}
  for _, id in ipairs(M.list) do
    local st = M.state[id]
    parts[#parts + 1] = (st.present and "1" or "0") .. st.level .. "/" .. st.out
  end
  return table.concat(parts, ",")
end

function M.task()
  for _, id in ipairs(M.list) do M.state[id].present = peripheral.isPresent(pname(id)) end
  runAll(OUTPUT, readOutput)
  reapply()
  while true do
    local before = signature()
    local t0 = os.epoch("utc")
    for _, id in ipairs(M.list) do M.state[id].present = peripheral.isPresent(pname(id)) end
    runAll(INPUT, readInput)
    if M.polls % 10 == 0 then runAll(OUTPUT, readOutput) end
    M.polls = M.polls + 1
    M.pollMs = os.epoch("utc") - t0
    M.lastPoll = os.epoch("utc")
    if signature() ~= before then os.queueEvent("stackos_state") end
    sleep(1)
  end
end

-- Held outputs are remembered in settings, so they come back after a restart
local function desired()
  local d = store.get("outputs")
  if type(d) ~= "table" then
    d = {}
    store.set("outputs", d)
  end
  return d
end

local function setAll(id, level, remember)
  local n = pname(id)
  if remember then
    desired()[tostring(id)] = level
    store.touch()
  end
  if not peripheral.isPresent(n) then return false, "not on the network" end
  for _, s in ipairs(SIDES) do
    local ok, err = pcall(peripheral.call, n, "setAnalogOutput", s, level)
    if not ok then return false, err end
  end
  M.state[id].out = level
  os.queueEvent("stackos_state")
  return true
end

-- Put every remembered hold and dial back the way it was
reapply = function()
  for key, level in pairs(desired()) do
    local id = tonumber(key)
    local d = id and registry.integrators[id]
    if d and (d.kind == "hold" or d.kind == "aout") and M.state[id].present and M.state[id].out ~= level then
      local ok = setAll(id, level)
      log.info(("re-applied #%d %s to %d%s"):format(id, d.label, level, ok and "" or " (failed)"))
    end
  end
end

function M.hold(id, on)
  local d = registry.integrators[id]
  if not (d and d.kind == "hold") then return false, "not a hold integrator" end
  local ok, err = setAll(id, on and (d.level or 15) or 0, true)
  log.info(("#%d %s %s%s"):format(id, d.label, on and "ON" or "OFF", ok and "" or (" failed: " .. tostring(err))))
  return ok, err
end

function M.analogOut(id, level)
  local d = registry.integrators[id]
  if not (d and d.kind == "aout") then return false, "not an analog output" end
  level = math.max(0, math.min(15, math.floor(level)))
  return setAll(id, level, true)
end

function M.pulse(id, seconds)
  local d = registry.integrators[id]
  if not (d and (d.kind == "pulse" or d.kind == "cover")) then return false, "not a pulse integrator" end
  if not peripheral.isPresent(pname(id)) then return false, "not on the network" end
  seconds = seconds or d.pulse or 0.5
  if d.kind == "cover" then
    log.crit(("LAST RESORT fired by hand: #%d %s"):format(id, d.label))
  else
    log.info(("#%d %s pulse"):format(id, d.label))
  end
  local sched = require("kernel.sched")
  sched.spawn("pulse #" .. id, function()
    local ok, err = setAll(id, 15)
    if not ok then
      log.error(("pulse #%d failed: %s"):format(id, tostring(err)))
      return
    end
    sleep(seconds)
    setAll(id, 0)
  end)
  if d.verify then require("services.watch").expect(d.verify) end
  return true
end

-- Current season from the four sensors: name, short name, strength
local SEASONS = { { 21, "Spring", "Spr" }, { 47, "Summer", "Sum" }, { 48, "Fall", "Fal" }, { 49, "Winter", "Win" } }
function M.season()
  for _, s in ipairs(SEASONS) do
    local st = M.state[s[1]]
    if st and st.on then return s[2], s[3], st.level end
  end
end

function M.counts()
  local total, online = 0, 0
  for _, st in pairs(M.state) do
    total = total + 1
    if st.present then online = online + 1 end
  end
  return online, total
end

return M
