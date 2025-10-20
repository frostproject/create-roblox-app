local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local common = require("../common")
local fatalError = require("./fatalError")

local errorCodes = common.ERROR_CODES

local DEBUG = _G.DEBUG
local PROJECT_TYPES = common.PROJECT_TYPES
local TEMPLATE_TYPES = common.TEMPLATE_TYPES

local function isWindowsAbsolute(path: string): boolean
   return path:match("^[A-Za-z]:[\\/]") ~= nil
end

local function isUnixAbsolute(path: string): boolean
   return path:sub(1, 1) == "/"
end

local function stripLongPathPrefix(path: string): string
   if path:sub(1, 4) == "\\\\?\\" then
      return path:sub(5)
   end

   return path
end

local function normalizeSeparators(path: string): string
   return (path:gsub("\\", "/"))
end

local function normalizePath(path: string): string
   local normalizedPath = path:gsub("\\", "/")
   local prefix = ""
   local drive = normalizedPath:match("^([A-Za-z]:)/")

   if drive then
      prefix = drive .. "/"
      normalizedPath = normalizedPath:sub(#prefix + 1)
   elseif normalizedPath:sub(1, 1) == "/" then
      prefix = "/"
      normalizedPath = normalizedPath:sub(2)
   end

   local stack = {}
   for part in normalizedPath:gmatch("[^/]+") do
      if part == ".." then
         if #stack > 0 then
            table.remove(stack)
         end
      elseif part ~= "." and part ~= "" then
         table.insert(stack, part)
      end
   end

   return prefix .. table.concat(stack, "/")
end

local function join(a: string, b: string): string
   a = normalizeSeparators(a)
   b = normalizeSeparators(b)

   if a == "" then
      return b
   end

   if b == "" then
      return a
   end

   if a:sub(-1) == "/" then
      return a .. b
   else
      return a .. "/" .. b
   end
end
local function resolveTargetPath(input: string): string
   input = normalizeSeparators(input)
   local cwd = normalizeSeparators(process.cwd)

   if input == "." then
      return cwd
   end

   if isUnixAbsolute(input) or isWindowsAbsolute(input) then
      return input
   end

   if input:sub(1, 2) == "./" then
      return join(cwd, input:sub(3))
   end

   return join(cwd, input)
end

local function getBasename(path: string): string
   local normalizedPath = normalizeSeparators(path)
   if normalizedPath ~= "/" and normalizedPath:sub(-1) == "/" then
      normalizedPath = normalizedPath:sub(1, -2)
   end

   local last = normalizedPath:match("([^/]+)$")

   return last or normalizedPath
end

local function validatePath(path: string): (boolean, string)
   if path == normalizePath(process.cwd) then
      return false, "You cannot use the current directory ('.') as the project path!"
   end

   local result: any
   local ok, err = pcall(function(): any
      result = fs.isDir(path) :: boolean
      return
   end)

   if not ok then
      if DEBUG then
         fatalError(
            errorCodes.fsCheck,
            "Failed reading path (dir): " .. path .. `{err ~= nil and ("\n\n" .. stdio.format(err)) or ""}`
         )
      else
         return false, "Failed reading path (dir)"
      end
   elseif result then
      ok, err = pcall(function(): any
         result = fs.readDir(path) :: { string }
         return
      end)

      if #result ~= 0 then
         return false, "You must choose an empty directory!"
      end

      return true, "Success"
   end

   ok, err = pcall(function(): any
      result = fs.isFile(path) :: boolean
      return
   end)

   if not ok then
      if DEBUG then
         fatalError(
            errorCodes.fsCheck,
            "Failed reading path (file): " .. path .. `{err ~= nil and ("\n\n" .. stdio.format(err)) or ""}`
         )
      else
         return false, "Failed reading path (file)"
      end
   elseif result then
      return false, "A file with this name already exists!"
   end

   return true, "Success"
end

local function createPath(path: string): ()
   local ok, err = pcall(function(): any
      fs.writeDir(path)
      return
   end)

   if not ok then
      fatalError(
         errorCodes.fsWrite,
         "Failed to create directory: " .. path .. `{err ~= nil and ("\n\n" .. stdio.format(err)) or ""}`
      )
   end
end

local function getTemplatePath(options: common.options): string
   local projectType = PROJECT_TYPES[options.projectType]
   local templateType = TEMPLATE_TYPES[options.templateType]

   if projectType == "Go Back" then
      fatalError(errorCodes.invalidProjectType, "Invalid project type selected: " .. projectType)
   end

   if templateType == "Go Back" then
      fatalError(errorCodes.invalidTemplateType, "Invalid template type selected: " .. templateType)
   end

   local templatePath = normalizePath(
      join(normalizePath(stripLongPathPrefix(_G.PESDE_ROOT)), "src/templates/" .. projectType .. "/" .. templateType)
   )

   local result: boolean
   local ok, err = pcall(function(): any
      result = fs.isDir(templatePath)
      return
   end)

   if not ok then
      fatalError(
         errorCodes.fsCheck,
         "Failed reading path (template dir): " .. templatePath .. `{err ~= nil and ("\n\n" .. stdio.format(err)) or ""}`
      )
   elseif not result then
      fatalError(
         errorCodes.missingTemplate,
         "Template folder not found: " .. templatePath .. `{err ~= nil and ("\n\n" .. stdio.format(err)) or ""}`
      )
   end

   return templatePath
end

return table.freeze {
   isWindowsAbsolute = isWindowsAbsolute,
   isUnixAbsolute = isUnixAbsolute,
   stripLongPathPrefix = stripLongPathPrefix,
   normalizeSeparators = normalizeSeparators,
   normalizePath = normalizePath,
   join = join,
   resolveTargetPath = resolveTargetPath,
   getBasename = getBasename,
   validatePath = validatePath,
   createPath = createPath,
   getTemplatePath = getTemplatePath,
}
