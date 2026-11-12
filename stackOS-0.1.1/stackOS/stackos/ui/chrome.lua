-- ui/chrome.lua
-- The frame every page shares. Top: the stackOS mark, the page title, the
-- season and Minecraft time. Bottom: Back, Forward, Home, and the monitor's name.

local W = require("ui.widgets")
local version = require("version")
local integ = require("services.integrators")

local M = {}

function M.top(ctx)
  local c, R, w = ctx.c, ctx.R, ctx.w
  c:fill(1, 1, w, 1, R.surface)
  c:put(2, 1, "\30", R.accent, R.surface)
  local x = 4
  if w >= 40 then
    c:put(x, 1, "stack", R.text, R.surface)
    c:put(x + 5, 1, "OS", R.accent, R.surface)
    x = x + 9
  end
  local right = ("D%d %s"):format(os.day(), textutils.formatTime(os.time(), true))
  local _, short = integ.season()
  if short and w >= 30 then right = short .. "  " .. right end
  local rx = w - #right
  c:put(rx, 1, right, R.muted, R.surface)
  local title = ctx.page.title and ctx.page.title(ctx) or ctx.id
  c:put(x, 1, W.trunc(title, rx - x - 1), R.text, R.surface)
end

function M.bottom(ctx)
  local c, R, w, h, s = ctx.c, ctx.R, ctx.w, ctx.h, ctx.s
  c:fill(1, h, w, 1, R.surface)
  local canBack, canFwd = s.pos > 1, s.pos < #s.hist
  local narrow = w < 36
  local items = {
    { narrow and " \17 " or " \17 Back ", canBack, function() s:back() end },
    { narrow and " \16 " or " Fwd \16 ", canFwd, function() s:forward() end },
    { narrow and " \30 " or " \30 Home ", true, function() s:home() end },
  }
  local x = 1
  for _, it in ipairs(items) do
    W.button(ctx, x, h, #it[1], it[1], {
      bg = R.surface, fg = it[2] and R.text or R.line,
      fn = it[2] and it[3] or nil,
    })
    x = x + #it[1] + 1
  end
  local tag = s.name
  if w - x >= #tag + 8 then tag = tag .. "  v" .. version.version end
  if w - x > #tag then c:put(w - #tag, h, tag, R.muted, R.surface) end
end

return M
