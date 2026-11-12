-- kernel/log.lua
-- A rolling log. Lines go to /stackos-data/logs/stackos.log (rotated at 64 KB)
-- and to a small in-memory ring that the System page and console show.

local M = { ring = {}, max = 150 }

local DIR = "/stackos-data/logs"
local PATH = DIR .. "/stackos.log"
local LIMIT = 64 * 1024

local function stamp()
  return ("D%d %s"):format(os.day(), textutils.formatTime(os.time(), true))
end

function M.init()
  if not fs.exists(DIR) then fs.makeDir(DIR) end
end

local function rotate()
  if fs.exists(PATH) and fs.getSize(PATH) > LIMIT then
    local old = PATH .. ".1"
    if fs.exists(old) then fs.delete(old) end
    fs.move(PATH, old)
  end
end

function M.write(level, msg)
  local line = ("%s %s %s"):format(stamp(), level, tostring(msg))
  M.ring[#M.ring + 1] = line
  if #M.ring > M.max then table.remove(M.ring, 1) end
  pcall(function()
    rotate()
    local f = fs.open(PATH, "a")
    if f then
      f.writeLine(line)
      f.close()
    end
  end)
  os.queueEvent("stackos_log")
end

function M.info(m) M.write("INFO", m) end
function M.warn(m) M.write("WARN", m) end
function M.error(m) M.write("ERR ", m) end
function M.crit(m) M.write("CRIT", m) end

function M.tail(n)
  local out = {}
  for i = math.max(1, #M.ring - n + 1), #M.ring do out[#out + 1] = M.ring[i] end
  return out
end

return M
