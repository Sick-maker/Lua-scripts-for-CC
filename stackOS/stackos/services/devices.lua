-- services/devices.lua
-- Keeps a live roll call of the network: what's present, what's missing from
-- the registry, and anything new that isn't registered yet.

local registry = require("data.registry")
local log = require("kernel.log")

local M = { present = {}, types = {}, missing = {}, unknown = {}, okCount = 0, expCount = 0, lastScan = 0 }

local SIDES = { top = true, bottom = true, left = true, right = true, front = true, back = true }

local function expectedSet()
  local set = {}
  for _, e in ipairs(registry.expected) do
    if e[2] then
      for i = e[2], e[3] do set[e[1] .. i] = true end
    else
      set[e[1]] = true
    end
  end
  return set
end

function M.scan()
  local present, types = {}, {}
  for _, n in ipairs(peripheral.getNames()) do
    present[n] = true
    types[n] = peripheral.getType(n)
  end
  M.present, M.types = present, types
  M.expected = M.expected or expectedSet()
  local missing, unknown, exp, ok = {}, {}, 0, 0
  for n in pairs(M.expected) do
    exp = exp + 1
    if present[n] then ok = ok + 1 else missing[#missing + 1] = n end
  end
  for n in pairs(present) do
    if not M.expected[n] and not SIDES[n] then unknown[#unknown + 1] = n end
  end
  table.sort(missing)
  table.sort(unknown)
  M.missing, M.unknown, M.expCount, M.okCount = missing, unknown, exp, ok
  M.lastScan = os.epoch("utc")
end

function M.ofType(t)
  local out = {}
  for n, ty in pairs(M.types) do
    if ty == t then out[#out + 1] = n end
  end
  table.sort(out)
  return out
end

function M.task()
  while true do
    local ev, name = os.pullEvent()
    if ev == "peripheral" or ev == "peripheral_detach" then
      M.scan()
      log.info(("%s %s"):format(ev == "peripheral" and "attached" or "detached", tostring(name)))
      os.queueEvent("stackos_devices")
    end
  end
end

return M
