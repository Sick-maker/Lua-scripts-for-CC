-- layers/settings.lua
-- Per-monitor settings. Palette: pick any of the palettes, dark or light, with a
-- live preview on this screen and a button to copy it to every screen.
-- Display: text scale, start page and whether the splash plays.

local W = require("ui.widgets")
local palettes = require("ui.palettes")
local registry = require("data.registry")
local store = require("kernel.store")

local M = {}

local TABS = { "Palette", "Display" }

function M.title(ctx) return "Settings \16 " .. TABS[ctx.state.tab or 1] end

local function chip(ctx, x, y, label, selected, fn)
  local R = ctx.R
  W.button(ctx, x, y, #label + 2, label, { bg = selected and R.accent or R.raised, fg = selected and R.bg or R.text, fn = fn })
  return x + #label + 3
end

local function paletteTab(ctx, y0)
  local R, s, st = ctx.R, ctx.s, ctx.state
  local cur, mode = s.cfg.palette or "Lush", s.cfg.mode or "dark"
  local x = chip(ctx, 2, y0, "Dark", mode ~= "light", function()
    s.cfg.mode = "dark"; store.touch(); s:applyDisplay()
  end)
  chip(ctx, x, y0, "Light", mode == "light", function()
    s.cfg.mode = "light"; store.touch(); s:applyDisplay()
  end)

  local gridY = y0 + 2
  local bw = ctx.w >= 48 and 15 or 13
  local cols = math.max(1, math.floor((ctx.w - 1) / (bw + 1)))
  local step = ctx.ch >= 15 and 2 or 1
  local rows = math.max(1, math.floor((ctx.y + ctx.ch - 2 - gridY) / step))
  local per = cols * rows
  local names = palettes.order
  local pages = math.max(1, math.ceil(#names / per))
  st.ppage = math.max(1, math.min(st.ppage or 1, pages))
  local gridW = cols * (bw + 1) - 1
  local x0 = math.floor((ctx.w - gridW) / 2) + 1
  for k = 1, per do
    local name = names[(st.ppage - 1) * per + k]
    if not name then break end
    local col, row = (k - 1) % cols, math.floor((k - 1) / cols)
    local sel = name == cur
    W.button(ctx, x0 + col * (bw + 1), gridY + row * step, bw, name, {
      bg = sel and R.accent or R.raised, fg = sel and R.bg or R.text,
      fn = function()
        s.cfg.palette = name
        store.touch()
        s:applyDisplay()
        s:toast("Palette: " .. name, "accent", 2)
      end,
    })
  end
  local by = ctx.y + ctx.ch - 1
  W.button(ctx, 2, by, 20, "Copy to all screens", {
    bg = R.info, fg = R.bg, confirm = true, key = "copyall", armedLabel = "Tap again",
    fn = function()
      for _, other in pairs(s.ui.sessions) do
        other.cfg.palette, other.cfg.mode = cur, mode
        other:applyDisplay()
      end
      store.touch()
      s:toast("Every screen now uses " .. cur, "accent")
    end,
  })
  W.pager(ctx, ctx.w - 1, by, st.ppage, pages, function(p) st.ppage = p end)
end

local function displayTab(ctx, y0)
  local R, s = ctx.R, ctx.s
  local y = y0
  W.text(ctx, 2, y, "Text scale", R.muted)
  local x = 14
  for _, v in ipairs({ 0.5, 1, 1.5, 2, 3 }) do
    x = chip(ctx, x, y, tostring(v), (s.cfg.scale or 1) == v, function()
      s.cfg.scale = v; store.touch(); s:applyDisplay()
    end)
  end
  y = y + 2
  W.text(ctx, 2, y, "Start page", R.muted)
  x = 14
  for _, p in ipairs({ { "home", "Home" }, { "switchboard", "Switchboard" }, { "system", "System" } }) do
    x = chip(ctx, x, y, p[2], s:defaultPage() == p[1], function()
      s.cfg.default = p[1]; store.touch()
    end)
  end
  y = y + 2
  W.text(ctx, 2, y, "Splash", R.muted)
  x = chip(ctx, 14, y, "On", s.cfg.splash ~= false, function() s.cfg.splash = true; store.touch() end)
  chip(ctx, x, y, "Off", s.cfg.splash == false, function() s.cfg.splash = false; store.touch() end)
  y = y + 2
  W.text(ctx, 2, y, "This screen", R.muted)
  W.text(ctx, 14, y, s.name, R.text, nil, ctx.w - 15)
  if registry.monitors[s.name] and y + 1 < ctx.y + ctx.ch then
    W.text(ctx, 14, y + 1, registry.monitors[s.name], R.muted, nil, ctx.w - 15)
  end
  if y + 2 < ctx.y + ctx.ch then
    W.text(ctx, 14, y + 2, ("%d x %d characters"):format(s.w, s.h), R.muted)
  end
end

function M.draw(ctx)
  local R, st = ctx.R, ctx.state
  st.tab = st.tab or 1
  local x = 2
  for i, name in ipairs(TABS) do
    local sel = st.tab == i
    W.button(ctx, x, ctx.y, #name + 2, name, { bg = sel and R.accent or R.surface, fg = sel and R.bg or R.text,
      fn = function() st.tab = i end })
    x = x + #name + 3
  end
  if st.tab == 1 then paletteTab(ctx, ctx.y + 2) else displayTab(ctx, ctx.y + 2) end
end

return M
