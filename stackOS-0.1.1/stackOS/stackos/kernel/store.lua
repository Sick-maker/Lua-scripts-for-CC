-- kernel/store.lua
-- Settings that survive restarts and updates, kept in /stackos-data/settings.db.
-- Saves are batched every few seconds and written atomically (temp file, then swap).

local M = { data = {}, dirty = false }

local DIR = "/stackos-data"
local PATH = DIR .. "/settings.db"

function M.init()
  if not fs.exists(DIR) then fs.makeDir(DIR) end
  for _, p in ipairs({ PATH, PATH .. ".tmp" }) do
    if fs.exists(p) then
      local f = fs.open(p, "r")
      local s = f and f.readAll()
      if f then f.close() end
      local t = s and textutils.unserialize(s)
      if type(t) == "table" then
        M.data = t
        return
      end
    end
  end
end

function M.get(key, default)
  local v = M.data[key]
  if v == nil then return default end
  return v
end

function M.set(key, value)
  M.data[key] = value
  M.dirty = true
end

function M.touch() M.dirty = true end

-- Per-monitor settings table, created on first use
function M.monitor(name)
  local mons = M.data.monitors
  if type(mons) ~= "table" then mons = {}; M.data.monitors = mons end
  local m = mons[name]
  if type(m) ~= "table" then
    m = {}
    mons[name] = m
    M.dirty = true
  end
  return m
end

function M.save()
  if not M.dirty then return true end
  local tmp = PATH .. ".tmp"
  local f = fs.open(tmp, "w")
  if not f then return false end
  f.write(textutils.serialize(M.data))
  f.close()
  if fs.exists(PATH) then fs.delete(PATH) end
  fs.move(tmp, PATH)
  M.dirty = false
  return true
end

function M.task()
  while true do
    sleep(5)
    pcall(M.save)
  end
end

return M
