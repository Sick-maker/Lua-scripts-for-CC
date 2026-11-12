-- stackos-install.lua
-- Downloads stackOS from GitHub onto this computer, keeping your settings and
-- history (they live in /stackos-data and are never touched).
--
-- Usage:  stackos-install            (main branch)
--         stackos-install <branch>

local args = { ... }
local BRANCH = args[1] or "main"
local BASE = "https://raw.githubusercontent.com/Sick-maker/Lua-scripts-for-CC/" .. BRANCH .. "/stackOS/"

local function get(url)
  local h, err = http.get(url)
  if not h then return nil, err end
  local body = h.readAll()
  h.close()
  return body
end

if not http then
  printError("HTTP is disabled on this server, so the installer can't download.")
  return
end

print("stackOS installer (" .. BRANCH .. ")")
local manifest, err = get(BASE .. "manifest.txt")
if not manifest then
  printError("Couldn't read the manifest: " .. tostring(err))
  printError(BASE .. "manifest.txt")
  return
end

local files, launcher = {}, nil
for line in manifest:gmatch("[^\r\n]+") do
  line = line:gsub("^%s+", ""):gsub("%s+$", "")
  if line ~= "" and line:sub(1, 1) ~= "#" then
    files[#files + 1] = line
    if line:match("^stackOS%-v") then launcher = line end
  end
end

for i, f in ipairs(files) do
  write(("[%d/%d] %s "):format(i, #files, f))
  local body, e = get(BASE .. f)
  if not body then
    print("")
    printError("failed: " .. tostring(e))
    return
  end
  local path = "/" .. f
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then fs.makeDir(dir) end
  local h = fs.open(path, "w")
  h.write(body)
  h.close()
  print("ok")
end
print(("Installed %d files."):format(#files))

if launcher then
  -- older launchers would only run these same new files, so tidy them away
  for _, f in ipairs(fs.list("/")) do
    if f:match("^stackOS%-v") and f ~= launcher then
      fs.delete("/" .. f)
      print("Removed old launcher " .. f)
    end
  end
  -- if autostart already runs stackOS, point it at this version
  if fs.exists("/startup.lua") then
    local h = fs.open("/startup.lua", "r")
    local body = h.readAll()
    h.close()
    if body:find("stackOS%-v") then
      local updated = body:gsub("stackOS%-v[%w%.]+", launcher)
      local w = fs.open("/startup.lua", "w")
      w.write(updated)
      w.close()
      print("Autostart now starts " .. launcher .. ".")
      print("Type " .. launcher .. " to start stackOS now, or reboot.")
      return
    end
  end
  write("Start stackOS automatically when the world loads? (y/n) ")
  local a = read()
  if a and a:lower():sub(1, 1) == "y" then
    if fs.exists("/startup.lua") then
      if fs.exists("/startup.lua.bak") then fs.delete("/startup.lua.bak") end
      fs.copy("/startup.lua", "/startup.lua.bak")
      print("Your old startup.lua is saved as startup.lua.bak.")
    end
    local h = fs.open("/startup.lua", "w")
    h.write(('shell.run("/%s")\n'):format(launcher))
    h.close()
    print("Autostart is on.")
  end
  print("Type " .. launcher .. " to start stackOS.")
end
