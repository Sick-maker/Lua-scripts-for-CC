-- layers/switchboard.lua
-- A control-room board for every redstone integrator, grouped by system.
-- Sensors are lamps, pulse integrators are buttons, holds are switches, analog
-- outputs are dials. Risky switches need a second tap. The last resort sits
-- under a flip cover: open it, arm it, then fire, each a separate tap.

local W = require("ui.widgets")
local registry = require("data.registry")
local integ = require("services.integrators")
local store = require("kernel.store")

local M = {}

function M.title(ctx)
  local g = registry.groups[ctx.state.group or 1]
  local name = g and g.name or ""
  if ctx.w < 36 then return name end
  return "Switchboard \16 " .. name
end

function M.animated(ctx) return ctx.state.cover ~= nil end

local function manual()
  local m = store.get("manual")
  if type(m) ~= "table" then
    m = {}
    store.set("manual", m)
  end
  return m
end

local function lampRole(R, d, st)
  if not st.present then return R.crit end
  local k = d.kind
  if k == "read" or k == "analog" then return st.on and R.ok or R.line end
  if k == "hold" then return st.out > 0 and R.warn or R.line end
  if k == "pulse" then return st.out > 0 and R.accent or R.line end
  if k == "aout" then return st.out > 0 and R.info or R.line end
  if k == "cover" then return st.out > 0 and R.crit or R.line end
  return R.line
end

local function drawCell(ctx, x, y, w, id)
  local R = ctx.R
  local d, st = registry.integrators[id], integ.state[id]
  W.lamp(ctx, x, y, lampRole(R, d, st))
  W.text(ctx, x + 3, y, ("#%d %s"):format(id, d.short), d.kind == "cover" and R.crit or R.text, nil, w - 3)
  local y2 = y + 1
  if not st.present then
    W.text(ctx, x + 3, y2, "offline", R.crit, nil, w - 3)
    return
  end
  local k = d.kind
  if k == "read" then
    W.text(ctx, x + 3, y2, st.on and "ON" or "off", st.on and R.ok or R.muted)
  elseif k == "analog" then
    local bw = math.max(3, w - 7)
    W.bar(ctx, x + 3, y2, bw, st.level, 15, R.ok)
    W.text(ctx, x + 4 + bw, y2, tostring(st.level), R.text)
  elseif k == "pulse" then
    W.button(ctx, x + 3, y2, math.min(9, w - 3), "PULSE", {
      bg = R.accent, fg = R.bg, confirm = d.confirm, key = "p" .. id,
      fn = function()
        local ok, err = integ.pulse(id)
        ctx.s:toast(ok and ("Pulsed #%d %s"):format(id, d.short) or tostring(err), ok and "accent" or "crit")
      end,
    })
  elseif k == "hold" then
    local on = st.out > 0
    W.button(ctx, x + 3, y2, math.min(7, w - 3), on and "ON" or "OFF", {
      bg = on and R.warn or R.raised, fg = on and R.bg or R.text,
      confirm = d.confirm, key = "h" .. id, armedLabel = on and "OFF?" or "ON?",
      fn = function()
        local ok, err = integ.hold(id, not on)
        manual()[id] = true
        store.touch()
        if not ok then ctx.s:toast(tostring(err), "crit") end
      end,
    })
    if manual()[id] and w >= 15 then W.text(ctx, x + 11, y2, "MAN", R.info) end
  elseif k == "aout" then
    local lvl = st.out
    local function set(v)
      integ.analogOut(id, v)
      manual()[id] = true
      store.touch()
    end
    W.button(ctx, x + 3, y2, 3, "-", { fn = function() set(lvl - 1) end, disabled = lvl <= 0 })
    W.text(ctx, x + 7, y2, ("%2d"):format(lvl), R.text)
    W.button(ctx, x + 10, y2, 3, "+", { fn = function() set(lvl + 1) end, disabled = lvl >= 15 })
    W.text(ctx, x + 3, y2 + 1, registry.rainbow[lvl] or "", R.muted, nil, w - 3)
  elseif k == "cover" then
    local cs = ctx.state.cover
    if cs and os.epoch("utc") > cs.untilMs then
      cs = nil
      ctx.state.cover = nil
    end
    local bw = math.min(11, w - 3)
    if not cs then
      W.button(ctx, x + 3, y2, bw, "\4 COVER \4", { bg = R.line, fg = R.crit,
        fn = function() ctx.state.cover = { stage = "open", untilMs = os.epoch("utc") + 10000 } end })
    elseif cs.stage == "open" then
      W.button(ctx, x + 3, y2, bw, "ARM", { bg = R.warn, fg = R.bg,
        fn = function() ctx.state.cover = { stage = "armed", untilMs = os.epoch("utc") + 5000 } end })
    else
      W.button(ctx, x + 3, y2, bw, "FIRE", { bg = R.crit, fg = R.text,
        fn = function()
          ctx.state.cover = nil
          local ok, err = integ.pulse(id)
          ctx.s:toast(ok and "LAST RESORT FIRED" or ("Failed: " .. tostring(err)), "crit", 8)
        end })
    end
  end
end

function M.draw(ctx)
  local R, st = ctx.R, ctx.state
  local groups = registry.groups
  st.group = math.max(1, math.min(st.group or 1, #groups))
  local g = groups[st.group]
  local ax, ay, aw, ah

  if ctx.w >= 45 then
    local lw = 11
    for i, gr in ipairs(groups) do
      local y = ctx.y + i - 1
      if y > ctx.y + ctx.ch - 2 then break end
      local sel = i == st.group
      W.button(ctx, 1, y, lw, (" " .. gr.name .. (" "):rep(lw)):sub(1, lw), {
        bg = sel and R.accent or R.surface, fg = sel and R.bg or R.text,
        fn = function() st.group = i; st.page = 1 end,
      })
    end
    local held = 0
    for _ in pairs(manual()) do held = held + 1 end
    if held > 0 then
      W.button(ctx, 1, ctx.y + ctx.ch - 1, lw, ("Release %d"):format(held), {
        bg = R.info, fg = R.bg,
        fn = function()
          store.set("manual", {})
          ctx.s:toast("Manual holds released; outputs unchanged", "info")
        end,
      })
    end
    ax, ay, aw, ah = lw + 2, ctx.y, ctx.w - lw - 2, ctx.ch
  else
    W.button(ctx, 1, ctx.y, 3, "\17", { fn = function() st.group = (st.group - 2) % #groups + 1; st.page = 1 end })
    W.center(ctx, 4, ctx.w - 6, ctx.y, g.name, R.accent)
    W.button(ctx, ctx.w - 2, ctx.y, 3, "\16", { fn = function() st.group = st.group % #groups + 1; st.page = 1 end })
    ax, ay, aw, ah = 1, ctx.y + 1, ctx.w, ctx.ch - 1
  end

  local cols = aw >= 54 and 3 or (aw >= 30 and 2 or 1)
  local cellW = math.floor((aw - (cols - 1)) / cols)
  local rows = math.max(1, math.floor((ah - 1) / 3))
  local per = cols * rows
  local pages = math.max(1, math.ceil(#g.ids / per))
  st.page = math.max(1, math.min(st.page or 1, pages))
  for k = 1, per do
    local id = g.ids[(st.page - 1) * per + k]
    if not id then break end
    local col, row = (k - 1) % cols, math.floor((k - 1) / cols)
    drawCell(ctx, ax + col * (cellW + 1), ay + row * 3, cellW, id)
  end
  W.pager(ctx, ax + aw - 1, ay + ah - 1, st.page, pages, function(p) st.page = p end)
end

return M
