local process = require("@lune/process")

local common = require("../common")
local fatalError = require("./fatalError")

local userOS = common.USER_OS
local errorCodes = common.ERROR_CODES
local exec = process.exec

local EXEC_OPTIONS = { shell = true } :: process.ExecOptions

local function clear(): ()
   local execResult: process.ExecResult
   if userOS == "windows" then
      execResult = exec("cls", {}, EXEC_OPTIONS)
   else
      execResult = exec("clear", {}, EXEC_OPTIONS)
   end

   if not execResult.ok then
      fatalError(errorCodes.exec, execResult.stderr)
   end
end

return clear
