local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local clear = require("@utils/clear")
local common = require("./common")
local fatalError = require("@utils/fatalError")
local getExtra = require("@utils/getExtra")
local path = require("@utils/path")

local errorCodes = common.ERROR_CODES
local userOS = common.USER_OS
local LOCAL_USER = common.ENV.USERNAME or "frostproject"

local DEBUG = _G.DEBUG
local DEBUG_PRINT = common.DEBUG_MESSAGE

local color = stdio.color
local style = stdio.style
local prompt = stdio.prompt
local format = stdio.format
local outWrite = stdio.write
local readFile = fs.readFile
local writeFile = fs.writeFile
local copy = fs.copy
local exec = process.exec
local PROJECT_TYPES = common.PROJECT_TYPES
local PROJECT_TYPES_FORMATTED = common.PROJECT_TYPES_FORMATTED
local TEMPLATE_TYPES_FORMATTED = common.TEMPLATE_TYPES_FORMATTED

outWrite(color("black") .. "Initializing script..." .. color("reset"))

if not _G.PESDE_ROOT then
   fatalError(errorCodes.missing_G, "PESDE_ROOT environment variable is not set", true)
end

local options = table.clone(common.OPTIONS)

local finishedLoop = false
local resetLoop = false
local blockedLoop = false
local optionIndex = 1

local function getProjectPath(): ()
   local input = prompt("text", "Where should we create your new project?", "./intergalactic-ice")
   if not input then
      fatalError(errorCodes.emptyPrompt, "Project path is invalid: " .. `{input or "nil"}`)
   elseif input == "" then
      optionIndex = 1
      resetLoop = true
      blockedLoop = true
      outWrite(color("red") .. "You must enter a valid path!" .. color("reset"))
      task.delay(1, function()
         blockedLoop = false
      end)
   else
      local targetPath = path.normalizePath(path.resolveTargetPath(input))
      local isValid, message = path.validatePath(targetPath)

      if isValid == true then
         options.projectName = path.getBasename(targetPath)
         options.path = targetPath
         options.originalPath = input
      else
         optionIndex = 1
         resetLoop = true
         blockedLoop = true
         outWrite(color("red") .. message or "You must enter a valid path!" .. color("reset"))
         task.delay(1, function()
            blockedLoop = false
         end)
      end
   end
end

local function getProjectType(): ()
   local input = prompt("select", "What project are you building?", PROJECT_TYPES_FORMATTED)
   if not input then
      fatalError(errorCodes.emptyPrompt, "Project type is nil")
   else
      if input == 4 then
         optionIndex = 1
         resetLoop = true
      elseif input == 2 then
         options.projectType = input
      else
         fatalError(errorCodes.unsupportedOption, "This option (" .. input .. ") is not supported by the script yet!", true)
      end
   end
end

local function getTemplateType(): ()
   local input = prompt("select", "How would you like to start your new project?", TEMPLATE_TYPES_FORMATTED)
   if not input then
      fatalError(errorCodes.emptyPrompt, "Project template type is invalid: " .. `{input or "nil"}`)
   else
      if input == 3 then
         optionIndex = 2
         resetLoop = true
      else
         options.templateType = input
      end
   end
end

local function getInitializeGit(): ()
   local input = prompt("confirm", "Initialize a new git repository?", true)
   if input == nil then
      fatalError(errorCodes.emptyPrompt, "Initialize git repository is invalid: nil")
   else
      options.initializeGit = input
      finishedLoop = true
   end
end

local callbacks = {
   [1] = getProjectPath,
   [2] = getProjectType,
   [3] = getTemplateType,
   [4] = getInitializeGit,
}

if DEBUG then
   outWrite(DEBUG_PRINT)
   outWrite("LOCAL_USER: " .. LOCAL_USER)
   outWrite("\nOS: " .. userOS)
   outWrite("\nARCH: " .. process.arch)
   outWrite("\nCWD: " .. process.cwd)
   outWrite("\nENV: " .. format(process.env))
   outWrite("\nARGS: " .. format(common.ARGS))
   outWrite("\n_G: " .. format(_G))
   outWrite("\nStarting in 10 seconds...")
   task.wait(10)
end

clear()

while true do
   for index = optionIndex, #callbacks + 1 do
      if blockedLoop then
         while blockedLoop do
            task.wait()
         end
         clear()
      end

      if resetLoop then
         resetLoop = false
         break
      elseif finishedLoop then
         break
      end

      callbacks[index]()
      if not blockedLoop then
         clear()
      end
   end

   if finishedLoop then
      outWrite(color("cyan") .. style("bold") .. "⏳ Initializing project..." .. style("reset"))
      break
   end
end

local templatePath = path.getTemplatePath(options)

if DEBUG then
   outWrite(DEBUG_PRINT)
   outWrite("Options selected: " .. stdio.format(options))
   outWrite("\nStarting in 5 seconds...\n")
   task.wait(5)
end

outWrite(color("black") .. style("dim"))

path.createPath(options.path)
outWrite("\n■ Created directory")

local ok, err = pcall(function(): any
   copy(templatePath, options.path, true)
   return
end)

if not ok then
   fatalError(
      errorCodes.fsCopy,
      "Failed copying template: " .. templatePath .. `{err ~= nil and ("\n\n" .. stdio.format(err)) or ""}`
   )
end

outWrite("\n■ Template copied")

local LOCAL_USER_FORMATTED = LOCAL_USER:gsub("%-", "_")
local projectNameFormatted = options.projectName:gsub("%-", "_")
local projectScope = LOCAL_USER .. "/" .. options.projectName
local projectScopeFormatted = LOCAL_USER_FORMATTED .. "/" .. projectNameFormatted

local pathToPesdeToml = options.path .. "/pesde.toml"
local pesdeTomlFile: string = getExtra(PROJECT_TYPES[options.projectType] .. "/pesde_toml")

pesdeTomlFile = pesdeTomlFile:gsub("{{PROJECT_SCOPE_FORMATTED}}", projectScopeFormatted)
pesdeTomlFile = pesdeTomlFile:gsub("{{PROJECT_SCOPE}}", projectScope)
pesdeTomlFile = pesdeTomlFile:gsub("{{LOCAL_USER}}", LOCAL_USER)

ok, err = pcall(function(): any
   writeFile(pathToPesdeToml, pesdeTomlFile)
   return
end)

if not ok then
   fatalError(
      errorCodes.fsWrite,
      "Failed writing pesde.toml: " .. pathToPesdeToml .. `{err ~= nil and ("\n\n" .. stdio.format(err)) or ""}`
   )
end

outWrite("\n■ Copied pesde.toml")

local pathToDefaultProject = options.path .. "/default.project.json"
local defaultProjectJson: string =
   getExtra(PROJECT_TYPES[options.projectType] .. "/default_project_json"):gsub("{{PROJECT_NAME}}", options.projectName)

ok, err = pcall(function(): any
   writeFile(pathToDefaultProject, defaultProjectJson)
   return
end)

if not ok then
   fatalError(
      errorCodes.fsWrite,
      "Failed writing default.project.json: " .. pathToDefaultProject .. `{err ~= nil and ("\n\n" .. stdio.format(err)) or ""}`
   )
end

outWrite("\n■ Copied default.project.json")

local EXEC_OPTIONS = {
   cwd = options.path,
   shell = true,
   stdio = "default",
} :: process.ExecOptions

local execResult = exec("pesde", { "install" }, EXEC_OPTIONS)

if not execResult.ok then
   fatalError(errorCodes.exec, execResult.stderr)
end

outWrite("\n■ Dependencies installed")

if options.initializeGit then
   execResult = exec("git", { "init" }, EXEC_OPTIONS)

   if not execResult.ok then
      fatalError(errorCodes.exec, execResult.stderr)
   end

   outWrite("\n■ Git initialized")
end

local pathToLicense = options.path .. "/LICENSE"
local LicenseFile: string
ok, err = pcall(function(): any
   LicenseFile = readFile(pathToLicense)
   return
end)

if not ok then
   fatalError(
      errorCodes.fsRead,
      "Failed reading LICENSE: " .. pathToLicense .. `{err ~= nil and ("\n\n" .. stdio.format(err)) or ""}`
   )
end

LicenseFile = LicenseFile:gsub("{{YEAR}}", tostring(os.date("%Y")))
LicenseFile = LicenseFile:gsub("{{LOCAL_USER}}", LOCAL_USER)

ok, err = pcall(function(): any
   writeFile(pathToLicense, LicenseFile)
   return
end)

if not ok then
   fatalError(
      errorCodes.fsWrite,
      "Failed writing LICENSE: " .. pathToLicense .. `{err ~= nil and ("\n\n" .. stdio.format(err)) or ""}`
   )
end

outWrite("\n■ Updated LICENSE")

local pathToReadme = options.path .. "/README.md"
local ReadmeFile: string
ok, err = pcall(function(): any
   ReadmeFile = readFile(pathToReadme)
   return
end)

if not ok then
   fatalError(
      errorCodes.fsRead,
      "Failed reading README.md: " .. pathToReadme .. `{err ~= nil and ("\n\n" .. stdio.format(err)) or ""}`
   )
end

ReadmeFile = ReadmeFile:gsub("{{PROJECT_NAME}}", options.projectName)
ReadmeFile = ReadmeFile:gsub("{{LOCAL_USER_FORMATTED}}", LOCAL_USER_FORMATTED)
ReadmeFile = ReadmeFile:gsub("{{PROJECT_NAME_FORMATTED}}", projectNameFormatted)
ReadmeFile = ReadmeFile:gsub("{{PROJECT_SCOPE}}", projectScope)

ok, err = pcall(function(): any
   writeFile(pathToReadme, ReadmeFile)
   return
end)

if not ok then
   fatalError(
      errorCodes.fsWrite,
      "Failed writing README.md: " .. pathToReadme .. `{err ~= nil and ("\n\n" .. stdio.format(err)) or ""}`
   )
end

outWrite("\n■ Updated README.md")

if options.projectType == 2 then
   local pathToPackageProject = options.path .. "/package.project.json"
   local PackageProjectFile: string
   ok, err = pcall(function(): any
      PackageProjectFile = readFile(pathToPackageProject)
      return
   end)

   if not ok then
      fatalError(
         errorCodes.fsRead,
         "Failed reading package.project.json: "
            .. pathToPackageProject
            .. `{err ~= nil and ("\n\n" .. stdio.format(err)) or ""}`
      )
   end

   PackageProjectFile = PackageProjectFile:gsub("{{PROJECT_NAME}}", options.projectName)

   ok, err = pcall(function(): any
      writeFile(pathToPackageProject, PackageProjectFile)
      return
   end)

   if not ok then
      fatalError(
         errorCodes.fsWrite,
         "Failed writing package.project.json: "
            .. pathToPackageProject
            .. `{err ~= nil and ("\n\n" .. stdio.format(err)) or ""}`
      )
   end

   outWrite("\n■ Updated package.project.json")
end

outWrite(style("reset"))

if DEBUG then
   outWrite("\nWaiting 10 seconds...")
   task.wait(10)
end

clear()

outWrite(color("green") .. style("bold") .. "✅ Project initialized!" .. style("reset"))
if options.originalPath ~= "." then
   outWrite("\n\nEnter your project directory using " .. color("cyan") .. "cd " .. options.originalPath .. color("reset"))
else
   outWrite("\n")
end
outWrite(
   "\nRun "
      .. color("cyan")
      .. "pesde run dev"
      .. color("reset")
      .. " to start the argon sync server. "
      .. color("cyan")
      .. "CTRL+C"
      .. color("reset")
      .. " to stop."
)
outWrite(
   "\nAdd frameworks and libraries like "
      .. color("cyan")
      .. "react"
      .. color("reset")
      .. " or "
      .. color("cyan")
      .. "jecs"
      .. color("reset")
      .. " using "
      .. color("cyan")
      .. "pesde add"
      .. color("reset")
      .. ".\n "
)
