-- ui/widgets.lua
-- Drawing helpers shared by every page. Anything tappable registers a hot zone
-- on the session. Monitors report taps but not holds, so risky buttons use a
-- two-tap confirm: the first tap arms (the button turns yellow), the second fires.

local W = {}

function W.trunc(s, n)
  s = tostring(s)
  if n <= 0 then return "" end
  if #s <= n then return s end
  return s:sub(1, n)
end

function W.hot(ctx, x1, y1, x2, y2, fn, opts)
  local h = { x1 = x1, y1 = y1, x2 = x2, y2 = y2, fn = fn }
  if opts and opts.confirm then
    h.confirm = true
    h.key = opts.key or (x1 .. ":" .. y1)
  end
  ctx.s.hot[#ctx.s.hot + 1] = h
end

function W.isArmed(ctx, key)
  return key ~= nil and ctx.s.armed == key and os.epoch("utc") < (ctx.s.armedUntil or 0)
end

-- opts: bg, fg, fn, confirm, key, armedLabel, disabled, h
function W.button(ctx, x, y, w, label, opts)
  opts = opts or {}
  local R = ctx.R
  local bg, fg = opts.bg or R.raised, opts.fg or R.text
  local h = opts.h or 1
  local key = opts.key or ("btn:" .. x .. ":" .. y)
  local armed = opts.confirm and W.isArmed(ctx, key)
  if opts.disabled then bg, fg = R.surface, R.line end
  if armed then bg, fg = R.warn, R.bg end
  ctx.c:fill(x, y, w, h, bg)
  local text = W.trunc(armed and (opts.armedLabel or "Sure?") or label, w)
  ctx.c:put(x + math.floor((w - #text) / 2), y + math.floor((h - 1) / 2), text, fg, bg)
  if opts.fn and not opts.disabled then
    W.hot(ctx, x, y, x + w - 1, y + h - 1, opts.fn, opts.confirm and { confirm = true, key = key } or nil)
  end
end

function W.text(ctx, x, y, s, fg, bg, maxw)
  if maxw then s = W.trunc(s, maxw) end
  ctx.c:put(x, y, s, fg or ctx.R.text, bg)
end

function W.right(ctx, xr, y, s, fg, bg)
  s = tostring(s)
  ctx.c:put(xr - #s + 1, y, s, fg or ctx.R.text, bg)
end

function W.center(ctx, x, w, y, s, fg, bg)
  s = W.trunc(s, w)
  ctx.c:put(x + math.floor((w - #s) / 2), y, s, fg or ctx.R.text, bg)
end

-- A two-cell indicator light
function W.lamp(ctx, x, y, role)
  ctx.c:fill(x, y, 2, 1, role)
end

-- A horizontal bar showing value/max
function W.bar(ctx, x, y, w, value, max, role, back)
  local R = ctx.R
  local filled = 0
  if max and max > 0 then filled = math.floor(w * math.max(0, math.min(1, value / max)) + 0.5) end
  ctx.c:fill(x, y, w, 1, back or R.line)
  if filled > 0 then ctx.c:fill(x, y, filled, 1, role or R.accent) end
end

-- "< 1/3 >" drawn right-aligned at xr; returns nothing
function W.pager(ctx, xr, y, page, pages, onChange)
  if pages <= 1 then return end
  local R = ctx.R
  local label = (" %d/%d "):format(page, pages)
  local x = xr - (#label + 6) + 1
  W.button(ctx, x, y, 3, "\17", { bg = R.raised, fn = page > 1 and function() onChange(page - 1) end or nil,
    disabled = page <= 1 })
  ctx.c:put(x + 3, y, label, R.muted)
  W.button(ctx, x + 3 + #label, y, 3, "\16", { bg = R.raised, fn = page < pages and function() onChange(page + 1) end or nil,
    disabled = page >= pages })
end

return W
