-- ui/session.lua
-- Each monitor is its own session: its own page, Back/Forward history, palette,
-- text scale and tap zones. Sessions never affect each other.

local theme = require("ui.theme")
local canvas = require("ui.canvas")
local store = require("kernel.store")
local log = require("kernel.log")

local S = {}
S.__index = S

function S.new(name, dev, ui)
  local s = setmetatable({ name = name, dev = dev, ui = ui, hist = {}, pos = 0, hot = {}, dirty = true }, S)
  s.cfg = store.monitor(name)
  s:applyDisplay()
  return s
end

function S:applyDisplay()
  local c = self.cfg
  pcall(self.dev.setTextScale, c.scale or 1)
  theme.apply(self.dev, c.palette or "Lush", c.mode or "dark")
  self.w, self.h = self.dev.getSize()
  self.canvas = canvas.new(self.w, self.h, theme.R.bg)
  self.dirty = true
end

function S:defaultPage()
  return self.cfg.default or "home"
end

function S:go(id, params, replace)
  local entry = { id = id, params = params or {}, state = {} }
  if replace and self.pos > 0 then
    self.hist[self.pos] = entry
  else
    for i = #self.hist, self.pos + 1, -1 do table.remove(self.hist, i) end
    self.hist[#self.hist + 1] = entry
    if #self.hist > 30 then table.remove(self.hist, 1) end
    self.pos = #self.hist
  end
  if id ~= "splash" then
    self.cfg.last = id
    store.touch()
  end
  self.armed = nil
  self.dirty = true
end

function S:current() return self.hist[self.pos] end
function S:back() if self.pos > 1 then self.pos = self.pos - 1; self.armed = nil; self.dirty = true end end
function S:forward() if self.pos < #self.hist then self.pos = self.pos + 1; self.armed = nil; self.dirty = true end end
function S:home() self:go("home") end

function S:toast(text, role, seconds)
  self.toastText = text
  self.toastRole = role or "accent"
  self.toastUntil = os.epoch("utc") + (seconds or 3) * 1000
  self.dirty = true
end

function S:touch(x, y)
  for i = #self.hot, 1, -1 do
    local h = self.hot[i]
    if x >= h.x1 and x <= h.x2 and y >= h.y1 and y <= h.y2 then
      if h.confirm then
        local now = os.epoch("utc")
        if self.armed == h.key and now < (self.armedUntil or 0) then
          self.armed = nil
          h.fn()
        else
          self.armed = h.key
          self.armedUntil = now + 3000
        end
      else
        self.armed = nil
        h.fn()
      end
      self.dirty = true
      return true
    end
  end
  if self.armed then
    self.armed = nil
    self.dirty = true
  end
  return false
end

function S:ctx(entry, page)
  local chrome = not page.fullscreen
  local top = chrome and 2 or 1
  local bottom = chrome and self.h - 1 or self.h
  entry.state = entry.state or {}
  return {
    s = self, c = self.canvas, R = theme.R, w = self.w, h = self.h,
    x = 1, y = top, cw = self.w, ch = bottom - top + 1,
    state = entry.state, params = entry.params, ui = self.ui, page = page, id = entry.id,
  }
end

function S:render()
  local R = theme.R
  local c = self.canvas
  self.hot = {}
  c:clear(R.bg)
  local entry = self:current()
  if not entry then
    self:go(self:defaultPage())
    entry = self:current()
  end
  local page = self.ui.pages[entry.id] or self.ui.pages.home
  local ctx = self:ctx(entry, page)
  if not page.fullscreen then self.ui.chrome.top(ctx) end
  local ok, err = pcall(page.draw, ctx)
  if not ok then
    log.error(("page %s on %s: %s"):format(tostring(entry.id), self.name, tostring(err)))
    c:fill(1, ctx.y, self.w, ctx.ch, R.bg)
    c:put(2, ctx.y + 1, "This page hit an error. It's in the log.", R.crit)
    c:put(2, ctx.y + 2, tostring(err):sub(1, self.w - 3), R.muted)
  end
  if not page.fullscreen then self.ui.chrome.bottom(ctx) end
  if self.toastText and os.epoch("utc") < (self.toastUntil or 0) then
    local y = page.fullscreen and self.h or 1
    local role = R[self.toastRole] or R.accent
    c:fill(1, y, self.w, 1, role)
    c:put(2, y, self.toastText:sub(1, self.w - 2), R.bg, role)
  end
  c:flush(self.dev)
  self.dirty = false
  self.animating = (page.animated and page.animated(ctx)) or self.armed ~= nil
end

return S
