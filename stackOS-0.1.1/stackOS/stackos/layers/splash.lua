-- layers/splash.lua
-- LOW, SEA and TOP grow into place from the bottom up, the wordmark types itself
-- out, then the screen moves to its start page. A tap skips it.

local W = require("ui.widgets")
local version = require("version")
local devices = require("services.devices")

local M = { fullscreen = true }
local DURATION = 3.8

function M.title() return "stackOS" end
function M.animated() return true end

local function grow(t, start, len)
  if t <= start then return 0 end
  return math.min(1, (t - start) / len)
end

function M.draw(ctx)
  local c, R, w, h, st = ctx.c, ctx.R, ctx.w, ctx.h, ctx.state
  st.t0 = st.t0 or os.epoch("utc")
  local t = (os.epoch("utc") - st.t0) / 1000
  c:fill(1, 1, w, h, R.bg)

  local slabH = h >= 24 and 3 or (h >= 15 and 2 or 1)
  local gap = h >= 15 and 1 or 0
  local stackH = slabH * 3 + gap * 2
  local top = math.max(1, math.floor((h - (stackH + 4)) / 2) + 1)
  local maxW = math.max(9, math.floor(w * 0.6))
  local slabs = { { "TOP", R.top, 1.4 }, { "SEA", R.sea, 0.8 }, { "LOW", R.low, 0.2 } }
  for i, s in ipairs(slabs) do
    local y = top + (i - 1) * (slabH + gap)
    local p = grow(t, s[3], 0.45)
    local sw = math.floor(maxW * p + 0.5)
    if sw > 0 then
      local x = math.floor((w - sw) / 2) + 1
      c:fill(x, y, sw, slabH, s[2])
    end
  end

  local word = "stackOS"
  local n = math.floor(grow(t, 2.0, 0.5) * #word + 0.5)
  if n > 0 then
    local wy = top + stackH + 1
    local wx = math.floor((w - #word) / 2) + 1
    c:put(wx, wy, word:sub(1, math.min(n, 5)), R.text)
    if n > 5 then c:put(wx + 5, wy, word:sub(6, n), R.accent) end
  end

  if t > 2.7 then
    local line = ("v%s  \7  %d devices  \7  layers built on layers"):format(version.version, devices.okCount or 0)
    if #line > w - 2 then line = ("v%s  \7  %d devices"):format(version.version, devices.okCount or 0) end
    W.center(ctx, 1, w, top + stackH + 3, line, R.muted)
  end

  local function finish()
    if st.done then return end
    st.done = true
    ctx.s:go(ctx.s:defaultPage(), nil, true)
  end
  W.hot(ctx, 1, 1, w, h, finish)
  if t >= DURATION then finish() end
end

return M
