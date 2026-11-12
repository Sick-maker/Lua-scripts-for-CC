-- layers/elevator.lua
-- ENGINE: green running, red off, flashing red when it doesn't match its
--         controls (FE on and brake off, but not turning; or the reverse).
--         Yellow is kept for the system test.
-- MOVING: flashes white while the car is between floors.
-- TOP / SEA / LOW: tap to call. Blue where the car is, flashing grey while
--         it's on its way, flashing orange if it's late.
-- BRAKE:  dark until engaged, bright red while engaged. Two taps either way.

local W = require("ui.widgets")
local registry = require("data.registry")
local integ = require("services.integrators")
local watch = require("services.watch")

local M = {}
local E = registry.elevator
local track = {}

local function now() return os.epoch("utc") end
local function blink(ms) return math.floor(now() / (ms or 500)) % 2 == 0 end

local function floorNow()
  for _, f in ipairs(E.floors) do
    local st = integ.state[f.at]
    if st and st.on then return f.name end
  end
end

local function engine()
  local running = integ.state[E.motor].on
  local fe = integ.state[15] and integ.state[15].on
  local braked = integ.state[E.brake].out > 0
  local commanded = fe and not braked
  if running and commanded then return "running" end
  if not running and not commanded then return "off" end
  return "mismatch"
end

function M.title() return "Elevator" end

function M.animated()
  return engine() == "mismatch" or floorNow() == nil or watch.get("elevator") ~= nil
end

function M.draw(ctx)
  local R, c = ctx.R, ctx.c
  local cur = floorNow()
  local moving = cur == nil
  if moving and not track.moveStart then track.moveStart = now() end
  if not moving and track.moveStart then
    track.lastTrip = (now() - track.moveStart) / 1000
    track.moveStart = nil
  end
  local w = watch.get("elevator")
  local es = engine()

  local info = ctx.w >= 44
  local colW = info and math.min(20, math.floor(ctx.w * 0.42)) or math.min(22, ctx.w - 4)
  local x = info and 3 or math.floor((ctx.w - colW) / 2) + 1
  local gaps = ctx.ch >= 15 and 1 or 0
  local fixed = 3 + gaps * 5
  local bh = math.max(1, math.floor((ctx.ch - fixed) / 3))
  local y = ctx.y + math.max(0, math.floor((ctx.ch - (fixed + bh * 3)) / 2))

  -- ENGINE
  local eRole, eText = R.ok, "ENGINE"
  if es == "off" then eRole, eText = R.crit, "ENGINE OFF"
  elseif es == "mismatch" then eRole, eText = blink(400) and R.crit or R.line, "ENGINE ?" end
  c:fill(x, y, colW, 1, eRole)
  W.center(ctx, x, colW, y, eText, R.bg, eRole)
  y = y + 1 + gaps

  -- MOVING
  local mRole = (moving and blink(500)) and R.text or R.surface
  c:fill(x, y, colW, 1, mRole)
  W.center(ctx, x, colW, y, "MOVING", (moving and blink(500)) and R.bg or R.muted, mRole)
  y = y + 1 + gaps

  -- Floors
  for i, f in ipairs(E.floors) do
    local here = cur == f.name
    local called = w and w.spec.target == f.name
    local bg, fg = R.surface, R.muted
    if here then
      bg, fg = R.sea, R.bg
    elseif called and w.state == "failed" then
      bg, fg = blink(300) and R.alert or R.surface, R.text
    elseif called then
      bg, fg = blink(500) and R.raised or R.line, R.text
    end
    W.button(ctx, x, y, colW, f.name, {
      h = bh, bg = bg, fg = fg,
      fn = function()
        if here then ctx.s:toast("The car is already at " .. f.name, "info") return end
        if integ.state[E.brake].out > 0 then ctx.s:toast("Release the brake first", "warn") return end
        local ok, err = integ.pulse(f.call)
        if not ok then ctx.s:toast(tostring(err), "crit") end
      end,
    })
    y = y + bh + (i < #E.floors and gaps or 0)
  end
  y = y + gaps

  -- BRAKE
  local braked = integ.state[E.brake].out > 0
  W.button(ctx, x, y, colW, braked and "BRAKE ON" or "BRAKE", {
    bg = braked and R.crit or R.line, fg = braked and R.bg or R.crit,
    confirm = true, key = "elevator-brake",
    armedLabel = braked and "Release?" or (moving and "Stop now?" or "Brake?"),
    fn = function()
      local ok, err = integ.hold(E.brake, not braked)
      if not ok then ctx.s:toast(tostring(err), "crit") end
    end,
  })

  -- Details beside the column on wide screens
  if info then
    local ix = x + colW + 3
    local iw = ctx.w - ix
    local iy = ctx.y + 1
    local function item(label, value, role)
      if iy + 1 > ctx.y + ctx.ch - 2 then return end
      W.text(ctx, ix, iy, label, R.muted, nil, iw)
      W.text(ctx, ix, iy + 1, value, role or R.text, nil, iw)
      iy = iy + 3
    end
    if moving then
      item("Car", ("moving, %d s"):format(math.floor((now() - track.moveStart) / 1000)))
    else
      item("Car", "at " .. cur, R.sea)
    end
    if w then
      if w.state == "failed" then
        item("Called to " .. w.spec.target, "not arriving", R.alert)
      else
        item("Called to " .. w.spec.target, ("due within %d s"):format(math.max(0, math.ceil(w.within - watch.elapsed(w)))))
      end
    end
    local eLabel = es == "running" and "running" or (es == "off" and "off" or "doesn't match its controls")
    item("Engine", eLabel, es == "running" and R.ok or (es == "off" and R.crit or R.alert))
    if track.lastTrip then item("Last trip", ("%.1f s"):format(track.lastTrip)) end
    W.button(ctx, ix, ctx.y + ctx.ch - 1, math.min(iw - 1, 15), "Switchboard \16", {
      fn = function() ctx.s:go("switchboard", { group = "Elevator" }) end,
    })
  end
end

return M
