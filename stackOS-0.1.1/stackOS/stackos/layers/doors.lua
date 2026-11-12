-- layers/doors.lua
-- Each door is a tall rectangle: solid red when closed, solid green when open.
-- Tap to open or close it. Closing fills red from the bottom up; opening fills
-- green from the top down. The fill runs ahead to about 90% over the usual
-- travel time, then creeps toward 95% and holds there with a shimmer until the
-- door's own sensor confirms. Only then does it finish. If the sensor never
-- confirms, the frame flashes and the door says it isn't responding.

local W = require("ui.widgets")
local registry = require("data.registry")
local integ = require("services.integrators")
local watch = require("services.watch")

local M = {}
local D = registry.doors
local TRAVEL = 4 -- seconds a door usually takes
local finishing = {}

local function now() return os.epoch("utc") end
local function blink(ms) return math.floor(now() / (ms or 500)) % 2 == 0 end

local function fake(t)
  if t < TRAVEL then return 0.9 * t / TRAVEL end
  return 0.9 + 0.05 * (1 - math.exp(-(t - TRAVEL) / 3))
end

local function stateOf(d)
  local cl, op = integ.state[d.closed], integ.state[d.opened]
  if not (cl.present and op.present) then return "offline" end
  if cl.on and op.on then return "conflict" end
  if cl.on then return "closed" end
  if op.on then return "open" end
  return "unknown"
end

function M.title() return "Doors" end

function M.animated()
  for _, d in ipairs(D) do
    if watch.get("door:" .. d.key) then return true end
  end
  for _, f in pairs(finishing) do
    if f.at and now() - f.at < 700 then return true end
  end
  return false
end

local function drawDoor(ctx, d, sx, slotW, labelY, doorY, doorH, doorW)
  local R, c = ctx.R, ctx.c
  local dx = sx + math.floor((slotW - doorW) / 2)
  W.center(ctx, sx, slotW, labelY, d.name, R.text)
  local st = stateOf(d)
  local w = watch.get("door:" .. d.key)
  local base, over, frac, fromTop = R.surface, nil, 0, false
  local status, srole, hint = "", R.text, nil
  local frame = R.line

  if w then
    frac = fake(watch.elapsed(w))
    if w.spec.action == "close" then
      base, over, fromTop, status = R.ok, R.crit, false, "Closing"
    else
      base, over, fromTop, status = R.crit, R.ok, true, "Opening"
    end
    if w.state == "failed" then
      status, srole = "Not responding", R.alert
      frame = blink(300) and R.alert or R.line
      hint = "Tap to try again"
    elseif w.state == "slow" then
      status = status .. "..."
    end
    finishing[d.key] = { from = frac, action = w.spec.action }
  else
    local f = finishing[d.key]
    if f and not f.at then f.at = now() end
    if f and now() - f.at < 700 then
      frac = f.from + (1 - f.from) * math.min(1, (now() - f.at) / 600)
      if f.action == "close" then base, over, fromTop = R.ok, R.crit, false
      else base, over, fromTop = R.crit, R.ok, true end
      status = f.action == "close" and "Closed" or "Open"
    else
      finishing[d.key] = nil
      if st == "closed" then base, status, hint = R.crit, "Closed", "Tap to open"
      elseif st == "open" then base, status, hint = R.ok, "Open", "Tap to close"
      elseif st == "conflict" then base, status, srole = R.alert, "Sensors disagree", R.alert
      elseif st == "offline" then base, status, srole = R.surface, "Offline", R.crit
      else base, status, srole = R.line, "Unknown", R.muted end
    end
  end

  c:fill(dx - 1, doorY - 1, doorW + 2, doorH + 2, frame)
  c:fill(dx, doorY, doorW, doorH, base)
  if over and frac > 0 then
    local rows = math.min(doorH, math.floor(doorH * frac + 0.5))
    local top = fromTop and doorY or (doorY + doorH - rows)
    c:fill(dx, top, doorW, rows, over)
    -- shimmer on the leading edge while it waits for the sensor
    if w and frac >= 0.9 and blink(250) then
      local edge = fromTop and (doorY + rows) or (doorY + doorH - rows - 1)
      if edge >= doorY and edge < doorY + doorH then c:fill(dx, edge, doorW, 1, R.raised) end
    end
  end
  if st == "unknown" and not w then W.center(ctx, dx, doorW, doorY + math.floor(doorH / 2), "?", R.bg, base) end

  local sy = doorY + doorH + 1
  W.center(ctx, sx, slotW, sy, status, srole)
  if hint and sy + 1 <= ctx.y + ctx.ch - 1 then W.center(ctx, sx, slotW, sy + 1, hint, R.muted) end

  W.hot(ctx, dx - 1, doorY - 1, dx + doorW, doorY + doorH, function()
    local cur = watch.get("door:" .. d.key)
    local id
    if cur and cur.state ~= "failed" then
      ctx.s:toast("That door is already moving", "info")
      return
    elseif cur then
      id = cur.spec.action == "close" and d.close or d.open
    elseif st == "closed" then
      id = d.open
    elseif st == "open" then
      id = d.close
    else
      ctx.s:toast("Door state unknown; use the switchboard", "warn")
      return
    end
    local ok, err = integ.pulse(id)
    if not ok then ctx.s:toast(tostring(err), "crit") end
  end)
end

function M.draw(ctx)
  local n = #D
  local slotW = math.max(15, math.floor((ctx.w - 2) / n))
  local doorW = math.max(4, math.min(12, slotW - 6))
  local labelY = ctx.y + (ctx.ch >= 14 and 1 or 0)
  local doorY = labelY + 2
  local doorH = math.max(3, ctx.y + ctx.ch - doorY - 3)
  local x0 = math.floor((ctx.w - slotW * n) / 2) + 1
  for i, d in ipairs(D) do
    drawDoor(ctx, d, x0 + (i - 1) * slotW, slotW, labelY, doorY, doorH, doorW)
  end
end

return M
