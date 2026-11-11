-- kernel/sched.lua
-- Runs every stackOS task as a coroutine on one event loop. A task that crashes
-- is logged and, if it asked for it, restarted after a back-off (2, 4, 8 ... 30 s),
-- so one broken screen or service can't take the rest of stackOS down.

local log = require("kernel.log")

local M = { tasks = {}, running = false, started = os.epoch("utc") }

local function make(t)
  t.co = coroutine.create(t.fn)
  t.filter = nil
  t.status = "running"
  t.begun = false
end

local resume

-- opts: restart (bool), keep (stay listed after dying), maxRestarts (number)
function M.spawn(name, fn, opts)
  local t = { name = name, fn = fn, opts = opts or {}, restarts = 0 }
  make(t)
  M.tasks[#M.tasks + 1] = t
  if M.running then
    t.begun = true
    resume(t)
  end
  return t
end

resume = function(t, ...)
  local ok, res = coroutine.resume(t.co, ...)
  if not ok then
    t.lastError = tostring(res)
    log.error(("task %s crashed: %s"):format(t.name, t.lastError))
    local limit = t.opts.maxRestarts or 50
    if t.opts.restart and t.restarts < limit then
      t.restarts = t.restarts + 1
      t.status = "waiting"
      t.timer = os.startTimer(math.min(2 ^ math.min(t.restarts, 5), 30))
    else
      t.status = "dead"
    end
  elseif coroutine.status(t.co) == "dead" then
    t.status = "done"
  else
    t.filter = res
  end
end

function M.run()
  M.running = true
  M.started = os.epoch("utc")
  for i = 1, #M.tasks do
    local t = M.tasks[i]
    if t.status == "running" and not t.begun then
      t.begun = true
      resume(t)
    end
  end
  while M.running do
    local ev = table.pack(os.pullEventRaw())
    local name = ev[1]
    if name == "terminate" then
      log.info("terminate received")
      M.running = false
      break
    end
    local n = #M.tasks
    for i = 1, n do
      local t = M.tasks[i]
      if t then
        if t.status == "waiting" then
          if name == "timer" and ev[2] == t.timer then
            make(t)
            t.begun = true
            log.info(("task %s restarted (%d)"):format(t.name, t.restarts))
            resume(t)
          end
        elseif t.status == "running" and (t.filter == nil or t.filter == name) then
          resume(t, table.unpack(ev, 1, ev.n))
        end
      end
    end
    for i = #M.tasks, 1, -1 do
      local t = M.tasks[i]
      if t.status == "done" or (t.status == "dead" and not t.opts.keep) then
        table.remove(M.tasks, i)
      end
    end
  end
end

function M.stop()
  M.running = false
  os.queueEvent("stackos_stop")
end

function M.uptime()
  return (os.epoch("utc") - M.started) / 1000
end

return M
