-- ui/palettes.lua
-- Every palette is a full set of 16 colours, one per role. Dark versions are
-- written out; light versions are derived from them. Status colours (ok, warn,
-- alert, crit, info) default to a shared set unless a palette overrides them.

local M = { order = {}, byName = {} }

local STATUS = { ok = 0x4ade80, warn = 0xfacc15, alert = 0xfb923c, crit = 0xf43f5e, info = 0x38bdf8 }

local function add(name, p)
  p.name = name
  for k, v in pairs(STATUS) do
    if p[k] == nil then p[k] = v end
  end
  M.byName[name] = p
  M.order[#M.order + 1] = name
end

add("Lush", { bg = 0x0f1a14, surface = 0x1b2b22, raised = 0x26402f, line = 0x3a5a45, text = 0xe6f2e9, muted = 0x8fae99,
  accent = 0x5fd38d, accent2 = 0xf2c94c, low = 0xe07a5f, sea = 0x4cc9f0, top = 0xc3a6ff })
add("Midnight", { bg = 0x0b1020, surface = 0x151c33, raised = 0x1f2947, line = 0x34436e, text = 0xe5e9f5, muted = 0x8c96b5,
  accent = 0x7aa2f7, accent2 = 0xbb9af7, low = 0xf7768e, sea = 0x7dcfff, top = 0xe0af68 })
add("Forest", { bg = 0x101710, surface = 0x1a2618, raised = 0x243522, line = 0x3a5333, text = 0xe8efe1, muted = 0x9aab8c,
  accent = 0x8fbc5a, accent2 = 0xd9a441, low = 0xc96f3b, sea = 0x5aa9a3, top = 0xb9cf7a })
add("Aqua", { bg = 0x061a1f, surface = 0x0d2a31, raised = 0x133a43, line = 0x22586a, text = 0xe0f7fa, muted = 0x80b6bf,
  accent = 0x26c6da, accent2 = 0x80deea, low = 0xff8a65, sea = 0x4dd0e1, top = 0xb2ebf2 })
add("Cyberpunk", { bg = 0x0d0221, surface = 0x1a0b3b, raised = 0x261447, line = 0x452478, text = 0xf8f8ff, muted = 0xa59fc9,
  accent = 0xf72585, accent2 = 0x00f5d4, low = 0xff9e00, sea = 0x4cc9f0, top = 0xfee440 })
add("Mono", { bg = 0x101010, surface = 0x1c1c1c, raised = 0x2a2a2a, line = 0x454545, text = 0xf0f0f0, muted = 0x9a9a9a,
  accent = 0xd0d0d0, accent2 = 0xffffff, low = 0xb0b0b0, sea = 0xc8c8c8, top = 0xe0e0e0 })
add("Synthwave", { bg = 0x1a1033, surface = 0x2a1b4d, raised = 0x3a2563, line = 0x56388f, text = 0xfdf0ff, muted = 0xb49fd1,
  accent = 0xff6ad5, accent2 = 0x8795e8, low = 0xff9a8b, sea = 0x94d0ff, top = 0xffd166 })
add("Starry", { bg = 0x070b1a, surface = 0x10172e, raised = 0x1a2342, line = 0x2c3961, text = 0xf5f3e7, muted = 0x9aa3c2,
  accent = 0xffd56b, accent2 = 0xa5b4fc, low = 0xf59e0b, sea = 0x60a5fa, top = 0xe9d5ff })
add("Pastel", { bg = 0x22212b, surface = 0x2e2c3a, raised = 0x3b3849, line = 0x564f6b, text = 0xf4f1fb, muted = 0xb3aecb,
  accent = 0xa0c4ff, accent2 = 0xffc6ff, low = 0xffadad, sea = 0x9bf6ff, top = 0xfdffb6 })
add("Matte", { bg = 0x1e1e1e, surface = 0x282828, raised = 0x333333, line = 0x4a4a4a, text = 0xe4e0d8, muted = 0xa29d93,
  accent = 0xc9a27e, accent2 = 0x8fa9a3, low = 0xb5735a, sea = 0x6f9aa8, top = 0xd4c19c })
add("Nordic", { bg = 0x2e3440, surface = 0x3b4252, raised = 0x434c5e, line = 0x5a657c, text = 0xeceff4, muted = 0xa3adbf,
  accent = 0x88c0d0, accent2 = 0xb48ead, low = 0xd08770, sea = 0x81a1c1, top = 0xebcb8b,
  ok = 0xa3be8c, warn = 0xebcb8b, alert = 0xd08770, crit = 0xbf616a, info = 0x88c0d0 })
add("American", { bg = 0x0a1630, surface = 0x13234a, raised = 0x1c3160, line = 0x2f4d86, text = 0xffffff, muted = 0xa8b6d6,
  accent = 0xe63946, accent2 = 0xf1faee, low = 0xb22234, sea = 0x457b9d, top = 0xdfe7f2 })
add("Matcha", { bg = 0x1b1f17, surface = 0x262c20, raised = 0x323a2a, line = 0x4a563d, text = 0xf1efe2, muted = 0xa9ad94,
  accent = 0x9cc069, accent2 = 0xe8d8b0, low = 0xc58b5c, sea = 0x7fb3a0, top = 0xd9e4a6 })
add("Arcade", { bg = 0x000000, surface = 0x111133, raised = 0x1d1d55, line = 0x33338a, text = 0xffffff, muted = 0x9999cc,
  accent = 0x00e5ff, accent2 = 0xffea00, low = 0xff3d00, sea = 0x2979ff, top = 0xe040fb })
add("Abyss", { bg = 0x020611, surface = 0x07122a, raised = 0x0c1c3d, line = 0x173265, text = 0xcfe3ff, muted = 0x6f8bb5,
  accent = 0x2dd4bf, accent2 = 0x6366f1, low = 0xf97316, sea = 0x0ea5e9, top = 0xa78bfa })
add("Ember", { bg = 0x1a0d08, surface = 0x2a1610, raised = 0x3a1f16, line = 0x5c3522, text = 0xfbe9dc, muted = 0xc49a83,
  accent = 0xff7a3d, accent2 = 0xffd166, low = 0xff4d2e, sea = 0x6cb6c9, top = 0xffb703 })
add("Glacier", { bg = 0x0e1a22, surface = 0x172833, raised = 0x213746, line = 0x335268, text = 0xeaf6fb, muted = 0x9bbccc,
  accent = 0x9ad7ff, accent2 = 0xe0f2ff, low = 0xf4a261, sea = 0x5fb7e5, top = 0xd6eefc })
add("Brass", { bg = 0x17130d, surface = 0x241d13, raised = 0x33291a, line = 0x524129, text = 0xf3e9d2, muted = 0xbba882,
  accent = 0xc8a04a, accent2 = 0x8fb3a3, low = 0xb5651d, sea = 0x5f8f8b, top = 0xe3c77a })
add("Draconic", { bg = 0x10061a, surface = 0x1d0d2e, raised = 0x2a1342, line = 0x46216b, text = 0xf2e6ff, muted = 0xab90c9,
  accent = 0xa64dff, accent2 = 0xff9f1c, low = 0xff4e8a, sea = 0x55c1ff, top = 0xffd23f })
add("Terminal", { bg = 0x000a00, surface = 0x021a04, raised = 0x062a0a, line = 0x0f4a16, text = 0x33ff66, muted = 0x1fae46,
  accent = 0x66ff99, accent2 = 0xccffdd, low = 0xffb000, sea = 0x00ccff, top = 0xa6ff00 })
add("Amber CRT", { bg = 0x0d0700, surface = 0x1a0f00, raised = 0x261700, line = 0x452a00, text = 0xffb000, muted = 0xb37a00,
  accent = 0xffcc33, accent2 = 0xffe199, low = 0xff6a00, sea = 0xffd27a, top = 0xfff1c2 })
add("Sakura", { bg = 0x1f1418, surface = 0x2c1d23, raised = 0x3a262e, line = 0x583a47, text = 0xfff0f5, muted = 0xc9a1b1,
  accent = 0xffb7c5, accent2 = 0x9dd9c5, low = 0xe5677e, sea = 0x8ecae6, top = 0xf9dcc4 })
add("Nether", { bg = 0x190707, surface = 0x2a0d0d, raised = 0x3b1212, line = 0x5e1d1d, text = 0xffe6d9, muted = 0xc08b7a,
  accent = 0xff5a36, accent2 = 0x4fd1c5, low = 0xff2e2e, sea = 0x2dd4bf, top = 0xffb347 })
add("High Contrast", { bg = 0x000000, surface = 0x111111, raised = 0x262626, line = 0x8a8a8a, text = 0xffffff, muted = 0xdddddd,
  accent = 0x00ffff, accent2 = 0xffff00, low = 0xff8800, sea = 0x00aaff, top = 0xff66ff,
  ok = 0x00ff00, warn = 0xffff00, alert = 0xff8800, crit = 0xff0000, info = 0x00ffff })

-- colour arithmetic without bitwise operators (ComputerCraft runs Lua 5.2)
local function split(c) return math.floor(c / 65536) % 256, math.floor(c / 256) % 256, c % 256 end
local function join(r, g, b) return math.floor(r + 0.5) * 65536 + math.floor(g + 0.5) * 256 + math.floor(b + 0.5) end
local function mix(a, b, t)
  local r1, g1, b1 = split(a)
  local r2, g2, b2 = split(b)
  return join(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t)
end
M.mix = mix

local WHITE, BLACK = 0xffffff, 0x000000

local function deriveLight(p)
  local l = { name = p.name }
  l.bg = mix(p.accent, WHITE, 0.92)
  l.surface = mix(p.accent, WHITE, 0.80)
  l.raised = mix(p.accent, WHITE, 0.66)
  l.line = mix(p.accent, WHITE, 0.45)
  l.text = mix(p.bg, BLACK, 0.4)
  l.muted = mix(l.text, l.bg, 0.45)
  l.accent = mix(p.accent, BLACK, 0.35)
  l.accent2 = mix(p.accent2, BLACK, 0.35)
  for _, k in ipairs({ "low", "sea", "top", "ok", "warn", "alert", "crit", "info" }) do
    l[k] = mix(p[k], BLACK, 0.3)
  end
  return l
end

local cache = {}
function M.get(name, mode)
  local p = M.byName[name] or M.byName.Lush
  if mode ~= "light" then return p end
  local key = p.name
  if not cache[key] then cache[key] = deriveLight(p) end
  return cache[key]
end

return M
