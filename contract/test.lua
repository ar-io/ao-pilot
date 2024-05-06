

-- Adjust package.path to include the current directory
package.path = package.path .. ';./lib/?.lua'

local arns = require 'arns'
local luaunit = require 'luaunit' -- Corrected the variable name

function testBuyRecord()
    local reply = arns.buyRecord("name", "type", "processTxId", "owner")
    luaunit.assertEquals(reply, {
        owner = "owner",
        price = 0,
        type = "type",
        undernameCount = 10,
        processTxId = "processTxId"
    })
end

os.exit(luaunit.LuaUnit.run())
