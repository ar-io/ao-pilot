-- Adjust package.path to include the current directory
package.path = package.path .. ';./lib/?.lua'

ao = {}
ao.id = 'test-id'
ao.send = function() return end

local token = require '.lib.token'
local arns = require '.lib.arns'
local luaunit = require 'luaunit' -- Corrected the variable name

local testProcessId = 'NdZ3YRwMB2AMwwFYjKn1g88Y9nRybTo0qhS1ORq_E7g'

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
    Balances = {}
end

function testBuyRecord()
    Balances['Bob'] = 5000
    local msg = {
        Action = "BuyRecord",
        From = "Bob",
        Timestamp = os.clock(),
        Tags = {
            Name = "test-name",
            Years = 1,
            PurchaseType = 'lease',
            ProcessId = testProcessId
        }
    }
    local reply = arns.buyRecord(msg)
    luaunit.assertEquals(reply, true)
    luaunit.assertEquals(Records['test-name'].processId, testProcessId)
    luaunit.assertEquals(Balances['Bob'], 3500)
    Balances = {}
end

os.exit(luaunit.LuaUnit.run())
