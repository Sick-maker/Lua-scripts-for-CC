-- ui/theme.lua
-- Every colour on screen is a role. Each role owns one of ComputerCraft's 16
-- colour slots, and a palette sets the RGB value of every slot, so switching
-- palettes recolours a whole screen at once without redrawing anything.

local palettes = require("ui.palettes")

local M = {}

-- role -> blit character (each character is one colour slot)
M.R = {
  text = "0", alert = "1", top = "2", sea = "3", warn = "4", ok = "5", accent2 = "6", surface = "7",
  muted = "8", info = "9", low = "a", accent = "b", raised = "c", line = "d", crit = "e", bg = "f",
}

local SLOT = {
  ["0"] = colours.white, ["1"] = colours.orange, ["2"] = colours.magenta, ["3"] = colours.lightBlue,
  ["4"] = colours.yellow, ["5"] = colours.lime, ["6"] = colours.pink, ["7"] = colours.grey,
  ["8"] = colours.lightGrey, ["9"] = colours.cyan, a = colours.purple, b = colours.blue,
  c = colours.brown, d = colours.green, e = colours.red, f = colours.black,
}
M.SLOT = SLOT

function M.apply(dev, name, mode)
  local p = palettes.get(name, mode)
  for role, ch in pairs(M.R) do
    local c = p[role]
    if c then dev.setPaletteColour(SLOT[ch], c) end
  end
end

function M.reset(dev)
  for _, slot in pairs(SLOT) do
    dev.setPaletteColour(slot, term.nativePaletteColour(slot))
  end
end

return M
