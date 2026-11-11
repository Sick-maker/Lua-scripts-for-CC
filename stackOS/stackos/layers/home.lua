-- layers/home.lua
-- The launch page: one tile per app. Tiles that are ready carry a live status
-- lamp; tiles still to come show which build brings them.

local W = require("ui.widgets")
local integ = require("services.integrators")
local devices = require("services.devices")

local M = {}

local APPS = {
  { id = "switchboard", name = "Switchboard" },
  { id = "system", name = "System" },
  { id = "settings", name = "Settings" },
  { name = "Overview", build = "0.3" }, { name = "Power", build = "0.2" }, { name = "Reactor", build = "0.2" },
  { name = "Notifications", short = "Alerts", build = "0.2" }, { name = "Elevator", build = "0.3" }, { name = "Access", build = "0.3" },
  { name = "Items", build = "0.4" }, { name = "Storage", build = "0.4" }, { name = "Player", build = "0.4" },
  { name = "Devices", build = "1.0" }, { name = "Routines", build = "1.1" }, { name = "Factory", build = "1.1" },
  { name = "Barn", build = "1.2" }, { name = "Environment", short = "Outside", build = "1.2" }, { name = "Kitchen", build = "1.3" },
  { name = "Workshop", build = "1.3" }, { name = "Music", build = "1.4" },
}

function M.title() return "Home" end

local function status(ctx, app)
  local R = ctx.R
  if app.id == "switchboard" then
    local on, total = integ.counts()
    local role = on == total and R.ok or (on == 0 and R.crit or R.warn)
    return role, (ctx.tileW - 5 >= 8 and "%d/%d on" or "%d/%d"):format(on, total)
  elseif app.id == "system" then
    local miss = #(devices.missing or {})
    return miss == 0 and R.ok or R.warn, miss == 0 and "all ok" or (miss .. " gone")
  elseif app.id == "settings" then
    return R.info, ctx.s.cfg.palette or "Lush"
  end
  return R.line, ""
end

function M.draw(ctx)
  local c, R, st = ctx.c, ctx.R, ctx.state
  local tileW = ctx.w >= 48 and 15 or (ctx.w >= 36 and 12 or 14)
  local cols = math.max(1, math.floor((ctx.w + 1) / (tileW + 1)))
  ctx.tileW = tileW
  local tileH = ctx.ch >= 16 and 4 or 3
  local rows = math.max(1, math.floor(ctx.ch / (tileH + 1)))
  local per = cols * rows
  local pages = math.max(1, math.ceil(#APPS / per))
  st.page = math.max(1, math.min(st.page or 1, pages))
  local gridW = cols * (tileW + 1) - 1
  local x0 = math.floor((ctx.w - gridW) / 2) + 1

  for k = 1, per do
    local app = APPS[(st.page - 1) * per + k]
    if not app then break end
    local col, row = (k - 1) % cols, math.floor((k - 1) / cols)
    local x, y = x0 + col * (tileW + 1), ctx.y + row * (tileH + 1)
    local ready = app.id ~= nil
    local bg = ready and R.raised or R.surface
    c:fill(x, y, tileW, tileH, bg)
    local ny = y + (tileH >= 4 and 1 or 0)
    local label = (#app.name > tileW - 2 and app.short) or app.name
    W.text(ctx, x + 1, ny, label, ready and R.text or R.muted, bg, tileW - 1)
    if ready then
      local role, sub = status(ctx, app)
      W.lamp(ctx, x + tileW - 3, ny + 1, role)
      W.text(ctx, x + 1, ny + 1, sub, R.muted, bg, tileW - 5)
      W.hot(ctx, x, y, x + tileW - 1, y + tileH - 1, function() ctx.s:go(app.id) end)
    else
      W.text(ctx, x + 1, ny + 1, "in " .. app.build, R.line, bg, tileW - 2)
      W.hot(ctx, x, y, x + tileW - 1, y + tileH - 1, function()
        ctx.s:toast(app.name .. " arrives in stackOS " .. app.build, "info")
      end)
    end
  end
  W.pager(ctx, ctx.w - 1, ctx.y + ctx.ch - 1, st.page, pages, function(p) st.page = p end)
end

return M
