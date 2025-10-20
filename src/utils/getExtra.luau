local stdio = require("@lune/stdio")

local common = require("../common")
local fatalError = require("./fatalError")

local errorCodes = common.ERROR_CODES

local function getExtra(name: string): any
   local path = "../extra/" .. name

   local result
   local ok, err = pcall(function()
      result = require(path) :: any
   end)

   if not ok then
      fatalError(
         errorCodes.unknownExtra,
         "Failed reading path (extra): " .. path .. `{err ~= nil and ("\n\n" .. stdio.format(err)) or ""}`
      )
   end

   return result
end

return getExtra
