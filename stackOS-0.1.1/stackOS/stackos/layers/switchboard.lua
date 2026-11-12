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
M.clockAware = true

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

-- Lay a group out as rows: a heading row, then cells three rows tall
local function layout(g, cols)
  local readings, controls = {}, {}
  for _, id in ipairs(g.ids) do
    local k = registry.integrators[id].kind
    if k == "read" or k == "analog" then readings[#readings + 1] = id else controls[#controls + 1] = id end
  end
  local rows = {}
  local function section(title, ids)
    if #ids == 0 then return end
    rows[#rows + 1] = { head = title, h = 1 }
    for i = 1, #ids, cols do
      local r = { cells = {}, h = 3 }
      for j = i, math.min(i + cols - 1, #ids) do r.cells[#r.cells + 1] = ids[j] end
      rows[#rows + 1] = r
    end
  end
  section(g.raw and "READINGS  (raw signal, sampled)" or "READINGS", readings)
  section("CONTROLS", controls)
  return rows
end

function M.draw(ctx)
  local R, st = ctx.R, ctx.state
  local groups = registry.groups
  if not st.group and ctx.params and ctx.params.group then
    for i, gr in ipairs(groups) do if gr.name == ctx.params.group then st.group = i end end
  end
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
  local rows = layout(g, cols)

  -- split the rows into pages that fit, never ending a page on a heading
  local pages, cur, used = {}, {}, 0
  local avail = ah - 1
  for i, r in ipairs(rows) do
    local need = r.h
    if r.head and rows[i + 1] then need = need + rows[i + 1].h end
    if used + need > avail and #cur > 0 then
      pages[#pages + 1] = cur
      cur, used = {}, 0
    end
    cur[#cur + 1] = r
    used = used + r.h
  end
  if #cur > 0 then pages[#pages + 1] = cur end
  st.page = math.max(1, math.min(st.page or 1, #pages))

  local y = ay
  for _, r in ipairs(pages[st.page] or {}) do
    if r.head then
      W.text(ctx, ax, y, r.head, R.muted, nil, aw)
    else
      for j, id in ipairs(r.cells) do drawCell(ctx, ax + (j - 1) * (cellW + 1), y, cellW, id) end
    end
    y = y + r.h
  end

  local by = ay + ah - 1
  if g.link then
    local label = ("%s page \16"):format(g.name)
    W.button(ctx, ax, by, #label + 2, label, { bg = R.accent, fg = R.bg,
      fn = function() ctx.s:go(g.link) end })
  end
  W.pager(ctx, ax + aw - 1, by, st.page, #pages, function(p) st.page = p end)
end

return M
