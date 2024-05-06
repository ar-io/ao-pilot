-- Adjust package.path to include the current directory
package.path = package.path .. ';./lib/?.lua'

ao = {}
ao.send = function() return end

local token = require '.lib.token'
local luaunit = require 'luaunit' -- Corrected the variable name

function testTokenTransfer()
    Balances["Bob"] = 100
    local msg = {
        Action = "Transfer",
        From = "Bob",
        Tags = {
            Recipient = "Alice",
            Quantity = "100"
        }
    }
    local reply = token.transfer(msg)
    luaunit.assertEquals(reply, true)
    luaunit.assertEquals(Balances["Alice"], 100)
    luaunit.assertEquals(Balances["Bob"], 0)

    Balances["Carol"] = 100
    msg = {
        Action = "Transfer",
        From = "Carol",
        Tags = {
            Recipient = "Alice",
            Quantity = "200"
        }
    }
    reply = token.transfer(msg)
    luaunit.assertEquals(reply, false)
    luaunit.assertEquals(Balances["Alice"], 100)
    luaunit.assertEquals(Balances["Carol"], 100)
end

os.exit(luaunit.LuaUnit.run())
