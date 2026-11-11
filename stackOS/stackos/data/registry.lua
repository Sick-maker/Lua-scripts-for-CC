-- data/registry.lua
-- The base registry for 0.1: what every redstone integrator does, how the
-- switchboard groups them, and the full device roll call from the day-87 survey.
--
-- Integrator kinds:
--   read    on/off sensor            analog  sensor with a 0-15 strength
--   pulse   one short pulse          hold    stays on until switched off
--   aout    analog output 0-15       cover   last resort, behind a flip cover

local I = {}
local function def(id, kind, label, short, extra)
  local d = { kind = kind, label = label, short = short or label }
  if extra then for k, v in pairs(extra) do d[k] = v end end
  I[id] = d
end

-- Elevator
def(0, "read", "Elevator motor turning", "Motor")
def(1, "read", "Car at LOW", "Car at LOW")
def(2, "read", "Car at SEA", "Car at SEA")
def(3, "read", "Car at TOP", "Car at TOP")
def(6, "read", "Elevator status lamp", "Status lamp")
def(26, "hold", "Elevator brake", "Car brake", { confirm = true })
def(28, "pulse", "Call the car to LOW", "Call LOW")
def(29, "pulse", "Call the car to SEA", "Call SEA")
def(30, "pulse", "Call the car to TOP", "Call TOP")

-- Power
for g = 1, 6 do def(6 + g, "read", ("Generator %d running"):format(g), ("Generator %d"):format(g)) end
def(15, "read", "FE latch: generators enabled", "Latch ON")
def(16, "read", "FE latch: generators disabled", "Latch OFF")

-- Chunk loaders
def(4, "read", "Chunk loader 599, middle", "Loader 599")
def(13, "read", "Chunk loader 598, north", "Loader 598")
def(14, "read", "Chunk loader 597, south", "Loader 597")
def(43, "read", "Chunk loader 596, barn", "Loader 596")

-- Clocks
def(5, "read", "Fast clock (10 ticks)", "Fast clock")
def(17, "read", "Slow clock (2 seconds)", "Slow clock")
def(39, "pulse", "Start both clocks", "Clocks on")
def(40, "pulse", "Stop both clocks", "Clocks off", { confirm = true })

-- Lights
def(18, "read", "Vanilla workshop light switch", "Vanilla sw")
def(19, "read", "Kitchen light switch", "Kitchen sw")
def(20, "read", "Create workshop light switch", "Create sw")
def(22, "hold", "Force vanilla workshop lights off", "Vanilla off")
def(23, "hold", "Force kitchen lights off", "Kitchen off")
def(24, "hold", "Force Create workshop lights off", "Create off")

-- Brakes
def(25, "hold", "Create workshop brake", "Workshop", { confirm = true })
def(27, "hold", "Bulk storage brake", "Storage", { confirm = true })

-- Doors
def(31, "pulse", "Lock the computer room door", "Lock comp")
def(32, "pulse", "Unlock the computer room door", "Unlock comp")
def(33, "pulse", "Lock the bedroom door", "Lock bed")
def(34, "pulse", "Unlock the bedroom door", "Unlock bed")
def(35, "read", "Computer room door locked", "Comp locked")
def(36, "read", "Computer room door unlocked", "Comp open")
def(37, "read", "Bedroom door locked", "Bed locked")
def(38, "read", "Bedroom door unlocked", "Bed open")

-- Entrance lamps
def(41, "aout", "Entrance rainbow lamp A", "Lamp A")
def(42, "aout", "Entrance rainbow lamp B", "Lamp B")

-- Computer-create factory
def(44, "hold", "Factory FE gate", "Factory FE", { confirm = true })
def(45, "read", "Factory truly running", "Running")
def(46, "pulse", "Force the crafters to craft", "Craft")

-- Seasons
def(21, "analog", "Season sensor: spring", "Spring")
def(47, "analog", "Season sensor: summer", "Summer")
def(48, "analog", "Season sensor: fall", "Fall")
def(49, "analog", "Season sensor: winter", "Winter")

-- Reactor
def(51, "analog", "Reactor comparator (backup sensor)", "Comparator")
def(50, "cover", "LAST RESORT: delete the reactor core", "Core delete")

local R = {}
R.integrators = I

R.groups = {
  { name = "Power", ids = { 15, 16, 7, 8, 9, 10, 11, 12 } },
  { name = "Elevator", ids = { 0, 1, 2, 3, 6, 28, 29, 30, 26 } },
  { name = "Doors", ids = { 35, 36, 31, 32, 37, 38, 33, 34 } },
  { name = "Lights", ids = { 18, 22, 19, 23, 20, 24 } },
  { name = "Brakes", ids = { 25, 26, 27 } },
  { name = "Clocks", ids = { 5, 17, 39, 40 } },
  { name = "Factory", ids = { 44, 45, 46 } },
  { name = "Loaders", ids = { 4, 13, 14, 43 } },
  { name = "Seasons", ids = { 21, 47, 48, 49 } },
  { name = "Entrance", ids = { 41, 42 } },
  { name = "Reactor", ids = { 51, 50 } },
}

-- Rainbow lamp colours by signal strength (from your notes)
R.rainbow = {
  [0] = "black", "gray", "light gray", "brown", "green", "light green", "cyan", "blue",
  "light blue", "purple", "pink", "light pink", "red", "orange", "yellow", "white",
}

-- Every registered peripheral (day-87 survey). { prefix, first, last } or { exact }
R.expected = {
  { "Create_RotationSpeedController_", 0, 0 }, { "Create_Speedometer_", 0, 2 },
  { "Create_Stressometer_", 0, 1 }, { "basin_", 0, 3 }, { "blazeBurner_", 0, 0 },
  { "create:deployer_", 0, 0 }, { "create:depot_", 0, 1 }, { "create:item_vault_", 0, 3 },
  { "create:mechanical_crafter_", 0, 8 }, { "create:millstone_", 0, 0 }, { "create:saw_", 0, 0 },
  { "create_connected:item_silo_", 0, 12 }, { "create_new_age:carbon_brushes_", 1, 6 },
  { "create_new_age:reinforced_motor_", 0, 3 }, { "createaddition:large_connector_", 1, 4 },
  { "draconic_reactor_", 0, 0 }, { "draconic_rf_storage_", 0, 0 }, { "drive_", 0, 0 },
  { "environmentDetector_", 0, 6 }, { "farmersdelight:cooking_pot_", 1, 3 },
  { "flow_gate_", 0, 1 }, { "geoScanner_", 0, 0 }, { "inventoryManager_", 0, 0 },
  { "mcwfurnitures:furniture_storage_", 0, 27 }, { "mechanicalMixer_", 0, 3 },
  { "minecraft:barrel_", 0, 49 }, { "minecraft:blast_furnace_", 0, 5 },
  { "minecraft:brewing_stand_", 0, 1 }, { "minecraft:chest_", 0, 10 },
  { "minecraft:furnace_", 0, 5 }, { "minecraft:smoker_", 0, 3 },
  { "monitor_0" }, { "monitor_1" }, { "monitor_2" }, { "monitor_4" }, { "monitor_6" }, { "monitor_7" },
  { "nbtStorage_", 0, 204 }, { "printer_1" }, { "quark:feeding_trough_", 4, 7 },
  { "quark:variant_chest_", 0, 4 }, { "quark:variant_furnace_", 0, 0 },
  { "redstoneIntegrator_", 0, 51 }, { "speaker_", 0, 14 },
  { "supplementaries:notice_board_", 0, 2 }, { "tconstruct:cast_chest_", 0, 0 },
  { "tconstruct:crafting_station_", 0, 0 }, { "tconstruct:modifier_chest_", 0, 0 },
  { "tconstruct:modifier_worktable_", 0, 0 }, { "tconstruct:part_builder_", 0, 0 },
  { "tconstruct:part_chest_", 0, 0 }, { "tconstruct:tinker_station_", 0, 1 },
}

-- Where each monitor is, for labels
R.monitors = {
  top = "Control suite (desk)",
  monitor_0 = "LOW, by the generators",
  monitor_1 = "SEA, workshop hallway",
  monitor_2 = "SEA, Create workshop (left)",
  monitor_4 = "TOP, control suite (big)",
  monitor_6 = "SEA, Create workshop (right)",
  monitor_7 = "LOW, storage room",
}

return R
