-- kernel/boot.lua
-- Brings stackOS up: log, settings, devices, integrators, screens, then the
-- scheduler. When the scheduler stops (Ctrl+T or Stop), it saves and tidies up.

local M = {}

function M.run()
  local log = require("kernel.log")
  log.init()
  local version = require("version")
  log.info(("stackOS %s starting on computer %d"):format(version.version, os.getComputerID()))

  local store = require("kernel.store")
  store.init()

  local sched = require("kernel.sched")
  local devices = require("services.devices")
  devices.scan()
  log.info(("devices: %d of %d registered answer, %d unknown"):format(
    devices.okCount, devices.expCount, #devices.unknown))

  local integ = require("services.integrators")
  integ.init()

  local ui = require("ui.ui")
  ui.init()

  sched.spawn("devices", devices.task, { restart = true, keep = true })
  sched.spawn("integrators", integ.task, { restart = true, keep = true })
  sched.spawn("screens", ui.task, { restart = true, keep = true })
  sched.spawn("settings", store.task, { restart = true, keep = true })
  sched.spawn("console", require("kernel.console").task, { restart = true, keep = true })

  local ok, err = pcall(sched.run)
  if not ok then log.crit("scheduler stopped: " .. tostring(err)) end
  pcall(store.save)
  pcall(ui.shutdown)
  log.info("stackOS stopped")

  term.setBackgroundColour(colours.black)
  term.setTextColour(colours.white)
  term.clear()
  term.setCursorPos(1, 1)
  if ok then
    print("stackOS stopped.")
  else
    printError("stackOS stopped after an error:")
    printError(tostring(err))
  end
end

return M
