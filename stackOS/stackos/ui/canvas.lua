-- ui/canvas.lua
-- An off-screen buffer of characters and colours. Pages draw into it, then
-- flush() sends only the rows that changed, so screens never flicker.

local C = {}
C.__index = C

function C.new(w, h, bg)
  local c = setmetatable({ w = w, h = h, ch = {}, fg = {}, bg = {}, last = {} }, C)
  c:clear(bg or "f")
  return c
end

function C:clear(bg)
  for y = 1, self.h do
    local a, b, d = {}, {}, {}
    for x = 1, self.w do
      a[x], b[x], d[x] = " ", "0", bg
    end
    self.ch[y], self.fg[y], self.bg[y] = a, b, d
  end
end

-- Write text; fg/bg nil keeps what's already there
function C:put(x, y, s, fg, bg)
  if y < 1 or y > self.h then return end
  s = tostring(s)
  local row, frow, brow = self.ch[y], self.fg[y], self.bg[y]
  for i = 1, #s do
    local xx = x + i - 1
    if xx >= 1 and xx <= self.w then
      row[xx] = s:sub(i, i)
      if fg then frow[xx] = fg end
      if bg then brow[xx] = bg end
    end
  end
end

function C:fill(x, y, w, h, bg, ch, fg)
  for yy = y, y + h - 1 do
    if yy >= 1 and yy <= self.h then
      local row, frow, brow = self.ch[yy], self.fg[yy], self.bg[yy]
      for xx = x, x + w - 1 do
        if xx >= 1 and xx <= self.w then
          brow[xx] = bg
          row[xx] = ch or " "
          if fg then frow[xx] = fg end
        end
      end
    end
  end
end

function C:flush(dev, force)
  for y = 1, self.h do
    local t, f, b = table.concat(self.ch[y]), table.concat(self.fg[y]), table.concat(self.bg[y])
    local key = t .. "|" .. f .. "|" .. b
    if force or self.last[y] ~= key then
      dev.setCursorPos(1, y)
      dev.blit(t, f, b)
      self.last[y] = key
    end
  end
end

function C:invalidate() self.last = {} end

-- Plain text of a row, for tests and debugging
function C:row(y) return table.concat(self.ch[y]) end

return C
