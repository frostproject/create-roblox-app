local process = require("@lune/process")
local stdio = require("@lune/stdio")

local common = require("../common")

local color = stdio.color
local style = stdio.style
local ewrite = stdio.ewrite

local DEBUG = _G.DEBUG
local DEBUG_MESSAGE = common.DEBUG_MESSAGE

local function fatalError(code: number?, message: string?, bypassDebugMode: boolean?): ()
   local isDebug = bypassDebugMode and true or DEBUG
   local codeDisplay = code or 1
   local codeNumber = (codeDisplay >= 1 and codeDisplay <= 255) and codeDisplay or 1

   ewrite(style("reset") .. color("red") .. style("bold"))
   ewrite(
      `\n{"   An unexpected error has occurred. If you believe this is a bug, please report it on our GitHub repository so we can investigate. (Error Code: " .. codeDisplay .. ")"}{not isDebug and style(
         "reset"
      ) .. color("yellow") .. "\n   You can enable debug mode by passing the --debug flag." or ""}`
   )
   ewrite(style("reset"))

   if message and isDebug then
      ewrite(DEBUG_MESSAGE)
      ewrite(message)
   end

   process.exit(codeNumber)
end

return fatalError
