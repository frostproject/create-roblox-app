local process = require("@lune/process")
local stdio = require("@lune/stdio")

local color = stdio.color

local PROJECT_TYPES = {
   [1] = "game",
   [2] = "library",
   [3] = "plugin",
}

local TEMPLATE_TYPES = {
   [1] = "full",
   [2] = "minimal",
}

local PROJECT_TYPES_FORMATTED = {
   [1] = "Game",
   [2] = "Library",
   [3] = "Plugin",
   [4] = "Go Back",
}

local TEMPLATE_TYPES_FORMATTED = {
   [1] = "Full (Recommended)",
   [2] = "Minimal",
   [3] = "Go Back",
}

local OPTIONS = {
   projectType = 0,
   projectName = "",
   path = "",
   originalPath = "",
   templateType = 0,
   initializeGit = false,
}

export type options = typeof(OPTIONS)

local ERROR_CODES = {
   ["fsWrite"] = 2,
   ["fsRead"] = 3,
   ["fsCheck"] = 4,
   ["fsCopy"] = 5,
   ["exec"] = 10,
   ["emptyPrompt"] = 11,
   ["unsupportedOption"] = 12,
   ["invalidProjectType"] = 13,
   ["invalidTemplateType"] = 14,
   ["missingTemplate"] = 15,
   ["missing_G"] = 16,
   ["missingArgument"] = 17,
   ["missingEnv"] = 18,
}

local DEBUG_MESSAGE = color("yellow") .. "\n\nDEBUG MODE:\n" .. color("reset")

local ARGS = process.args
if table.find(ARGS, "--debug") then
   _G.DEBUG = true
end

return {
   PROJECT_TYPES = PROJECT_TYPES,
   TEMPLATE_TYPES = TEMPLATE_TYPES,
   PROJECT_TYPES_FORMATTED = PROJECT_TYPES_FORMATTED,
   TEMPLATE_TYPES_FORMATTED = TEMPLATE_TYPES_FORMATTED,
   OPTIONS = OPTIONS,
   ERROR_CODES = ERROR_CODES,
   DEBUG_MESSAGE = DEBUG_MESSAGE,
   ARGS = ARGS,
   ENV = process.env,
   USER_OS = process.os,
}
