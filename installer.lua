-- GTNH Auto Bees installer
-- Based on Navatusein's GTNH-OC-Installer (MIT). Installs into /home.
--
--   wget -f https://raw.githubusercontent.com/dronf/GTNH-Auto-Bees/main/installer.lua && installer
--
-- Downloads the latest release archive from GitHub; if no release exists yet
-- it falls back to fetching the files from the main branch one by one.
local shell = require("shell")
local term = require("term")
local filesystem = require("filesystem")
local internet = require("internet")

local repository = "dronf/GTNH-Auto-Bees" -- change to your fork ("owner/repo")
local archiveName = "AutoBees"
local HOME = "/home"

local releaseUrl = "https://github.com/" .. repository .. "/releases/latest/download/" .. archiveName .. ".tar"
local rawBase = "https://raw.githubusercontent.com/" .. repository .. "/main/"

local tarManUrl = "https://raw.githubusercontent.com/mpmxyz/ocprograms/master/usr/man/tar.man"
local tarBinUrl = "https://raw.githubusercontent.com/mpmxyz/ocprograms/master/home/bin/tar.lua"

-- files fetched when no release archive is available
local files = {
  "main.lua", "config.lua", "version.lua",
  "lib/program-lib.lua", "lib/gui-lib.lua", "lib/logger-lib.lua", "lib/state-machine-lib.lua",
  "lib/component-discover-lib.lua", "lib/list-lib.lua", "lib/gui-widgets/scroll-list.lua",
  "lib/logger-handler/discord-logger-handler-lib.lua", "lib/logger-handler/file-logger-handler-lib.lua",
  "lib/logger-handler/scroll-list-logger-handler-lib.lua",
  "src/util.lua", "src/json.lua", "src/conditions.lua", "src/catalog.lua", "src/climate.lua",
  "src/genome.lua", "src/graph.lua", "src/housing.lua", "src/ae2.lua", "src/net.lua", "src/http.lua",
  "src/discord.lua", "src/connect.lua", "src/settings.lua", "src/setup.lua", "src/needs.lua",
  "src/breeder.lua", "src/survey.lua", "src/controller.lua", "src/cell.lua", "src/species_uids.lua",
}

local function fileSize(path)
  if not filesystem.exists(path) then return 0 end
  return filesystem.size(path) or 0
end

local function checkIsOsInstall()
  local file = io.open(HOME .. "/.installer.test", "w")
  if file == nil then error("OpenOS is not installed") end
  file:close()
  filesystem.remove(HOME .. "/.installer.test")
end

local function checkGithub()
  local ok, request = pcall(internet.request, rawBase .. "version.lua")
  if not ok then error("GitHub is unreachable: " .. tostring(request)) end
  local okRead, result = pcall(request)
  if not okRead then
    if tostring(result):match("PKIX") then
      error("GitHub's SSL certificate was rejected by Java. Update Java or install the certificate manually.")
    end
    error("GitHub is unreachable: " .. tostring(result))
  end
end

--- Download url into an absolute path with wget. Returns bytes written.
local function download(url, dest)
  local dir = filesystem.path(dest)
  if dir and dir ~= "" and not filesystem.exists(dir) then filesystem.makeDirectory(dir) end
  local temporary = dest .. ".download"
  if filesystem.exists(temporary) then filesystem.remove(temporary) end
  local ok = shell.execute("wget -fq " .. url .. " " .. temporary)
  local size = fileSize(temporary)
  if ok and size > 0 then
    local backup = dest .. ".previous"
    local hadFile = filesystem.exists(dest)
    if not hadFile or (not filesystem.exists(backup) and filesystem.rename(dest, backup)) then
      if filesystem.rename(temporary, dest) then
        if hadFile then filesystem.remove(backup) end
        return size
      end
      if hadFile then filesystem.rename(backup, dest) end
    end
  end
  if filesystem.exists(temporary) then filesystem.remove(temporary) end
  return 0
end

local function downloadTarUtility()
  if filesystem.exists("/bin/tar.lua") then return true end
  download(tarManUrl, "/usr/man/tar.man")
  return download(tarBinUrl, "/bin/tar.lua") > 0
end

local function installFromRelease()
  local tarPath = HOME .. "/program.tar"
  local size = download(releaseUrl, tarPath)
  if size < 1000 then
    if filesystem.exists(tarPath) then filesystem.remove(tarPath) end
    return false, "release download returned " .. size .. " bytes"
  end
  if not downloadTarUtility() then
    filesystem.remove(tarPath)
    return false, "could not download the tar utility"
  end
  shell.setWorkingDirectory(HOME)
  local extracted, err = shell.execute("tar -xf " .. tarPath)
  filesystem.remove(tarPath)
  if not extracted then return false, "archive extraction failed: " .. tostring(err) end
  if fileSize(HOME .. "/main.lua") == 0 then return false, "archive extracted nothing" end
  return true
end

local function installFromMain()
  local failed = 0
  for _, rel in ipairs(files) do
    local size = download(rawBase .. rel, HOME .. "/" .. rel)
    term.write((size > 0 and "  ok   " or "  FAIL ") .. rel .. "\n")
    if size == 0 then failed = failed + 1 end
  end
  return failed == 0, failed
end

local function makeAutoRun()
  term.write("\nStart the program automatically on boot [y/n]\n===>")
  local userInput = io.read() or "n"
  if string.lower(userInput) == "y" then
    local file = assert(io.open(HOME .. "/.shrc", "w"))
    file:write("main")
    file:close()
    term.write("Auto run created\n")
  else
    term.write("Auto run skipped\n")
  end
end

local function main()
  checkIsOsInstall()
  checkGithub()

  term.clear()
  term.write("GTNH Auto Bees installer\n\n")
  shell.setWorkingDirectory(HOME)

  local configPath = HOME .. "/config.lua"
  local backupPath = configPath .. ".installer-backup"
  local hadConfig = filesystem.exists(configPath)
  if filesystem.exists(backupPath) then
    error("Previous install left " .. backupPath .. "; restore it before retrying")
  end
  if hadConfig then assert(filesystem.rename(configPath, backupPath)) end

  term.write("Downloading the latest release archive...\n")
  local ok, why = installFromRelease()
  if ok then
    term.write("Installed from the release archive\n")
  else
    term.write("No usable release archive (" .. tostring(why) .. "), fetching files from the main branch\n")
    local allOk, failed = installFromMain()
    if not allOk then
      ok = false
      why = tostring(failed) .. " file(s) failed to download. Check the internet card and try again."
    else
      ok = true
    end
  end

  if hadConfig then
    -- keep the user's configuration, ship the fresh template next to it
    local templatePath = HOME .. "/config.new.lua"
    if filesystem.exists(configPath) then
      if filesystem.exists(templatePath) then filesystem.remove(templatePath) end
      assert(filesystem.rename(configPath, templatePath))
    end
    assert(filesystem.rename(backupPath, configPath))
    term.write("Kept your config.lua\n")
  end

  if not ok then error(why) end
  makeAutoRun()
  term.write("\nDone. Edit config.lua if you like, then run: main\n")
  term.write("(the setup guide runs on first start; on a robot `main` starts the cell worker)\n")
end

main()
