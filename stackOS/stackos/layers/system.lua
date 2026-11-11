-- layers/system.lua
-- The technical page: version, uptime, Minecraft time and season, disk use,
-- the device roll call, task health and the latest log lines.

local W = require("ui.widgets")
local version = require("version")
local devices = require("services.devices")
local integ = require("services.integrators")
local log = require("kernel.log")

local M = {}

function M.title() return "System" end

local function hms(s)
  s = math.floor(s)
  return ("%02d:%02d:%02d"):format(math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
end

local function kb(n) return ("%.1f KB"):format(n / 1024) end

function M.draw(ctx)
  local R = ctx.R
  local sched = require("kernel.sched")
  local x, y, w = 2, ctx.y, ctx.w - 2
  local lastY = ctx.y + ctx.ch - 2

  local function row(label, value, role)
    if y > lastY then return end
    W.text(ctx, x, y, label, R.muted)
    W.text(ctx, x + 13, y, value, role or R.text, nil, w - 13)
    y = y + 1
  end

  row("stackOS", ("%s  \7  computer #%d  \7  up %s"):format(version.version, os.getComputerID(), hms(sched.uptime())))
  local season, _, lvl = integ.season()
  row("Minecraft", ("day %d, %s%s"):format(os.day(), textutils.formatTime(os.time(), true),
    season and ("  \7  " .. season .. " (" .. lvl .. ")") or ""))
  local cap = fs.getCapacity and fs.getCapacity("/") or 0
  local free = fs.getFreeSpace("/")
  row("Disk", ("%s used, %s free"):format(kb(math.max(0, cap - free)), kb(free)))
  local missing = #(devices.missing or {})
  row("Devices", ("%d of %d answer  \7  %d new"):format(devices.okCount or 0, devices.expCount or 0, #(devices.unknown or {})),
    missing == 0 and R.ok or R.warn)
  local on, total = integ.counts()
  row("Integrators", ("%d of %d online  \7  poll %d ms"):format(on, total, integ.pollMs or 0), on == total and R.ok or R.warn)
  local screens = 0
  for _ in pairs(ctx.ui.sessions) do screens = screens + 1 end
  row("Screens", tostring(screens))

  local core, trouble, restarts = 0, {}, 0
  for _, t in ipairs(sched.tasks) do
    if t.opts.keep then
      core = core + 1
      restarts = restarts + t.restarts
      if t.status ~= "running" then trouble[#trouble + 1] = t.name .. " " .. t.status end
    end
  end
  if #trouble == 0 then
    row("Tasks", ("all %d running%s"):format(core, restarts > 0 and ("  \7  " .. restarts .. " restarts") or ""),
      restarts > 0 and R.warn or R.ok)
  else
    row("Tasks", table.concat(trouble, ", "), R.crit)
  end

  if missing > 0 then row("Missing", table.concat(devices.missing, ", "), R.warn) end
  if #(devices.unknown or {}) > 0 then row("New", table.concat(devices.unknown, ", "), R.info) end

  y = y + 1
  if y <= lastY then
    W.text(ctx, x, y, "Log", R.muted)
    y = y + 1
    local lines = log.tail(lastY - y + 1)
    for _, l in ipairs(lines) do
      local role = R.text
      if l:find(" CRIT ", 1, true) then role = R.crit
      elseif l:find(" ERR ", 1, true) then role = R.alert
      elseif l:find(" WARN ", 1, true) then role = R.warn end
      W.text(ctx, x, y, l, role, nil, w)
      y = y + 1
    end
  end

  local by = ctx.y + ctx.ch - 1
  local bx = 2
  W.button(ctx, bx, by, 8, "Rescan", { fn = function()
    devices.scan()
    ctx.s:toast(("%d of %d devices answer"):format(devices.okCount, devices.expCount), "info")
  end })
  bx = bx + 9
  W.button(ctx, bx, by, 8, "Reboot", { bg = R.alert, fg = R.bg, confirm = true, key = "reboot",
    fn = function() log.warn("reboot requested from " .. ctx.s.name); os.reboot() end })
  bx = bx + 9
  W.button(ctx, bx, by, 6, "Stop", { bg = R.crit, fg = R.text, confirm = true, key = "stop",
    fn = function() log.warn("stop requested from " .. ctx.s.name); sched.stop() end })
end

return M
