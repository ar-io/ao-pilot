-- package.path = './src/?.lua;' .. package.path


local token = require 'token'
local testProcessId = 'NdZ3YRwMB2AMwwFYjKn1g88Y9nRybTo0qhS1ORq_E7g'

describe("arns", function()
    local arns = {}
    local constants = {}
    local original_clock = os.clock

    setup(function()
        Balances = {}
        Records = {}
        arns = require 'contract.src.arns'
        constants = require 'contract.src.constants'
        os.clock = function() return 0 end
    end)

    after_each(function()
        Balances = {}
        Records = {}
    end)

    teardown(function()
        os.clock = original_clock
    end)

    it("adds a record to the global balance object", function()
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
        local result = arns.buyRecord(msg)
        assert.are.same({
            purchasePrice = 0,
            type = "lease",
            undernameCount = 10,
            processTxId = testProcessId,
            endTimestamp = msg.Timestamp + constants.MS_IN_A_YEAR * msg.Tags.Years,
        }, result)
    end)

    it('should allow you to lease a record', function ()
        local timestamp = os.clock()
        local msg = {
            Action = "BuyRecord",
            From = "Bob",
            Timestamp = timestamp,
            Tags = {
                Name = "test-name-2",
                Years = 1,
                PurchaseType = 'lease',
                ProcessId = testProcessId
            }
        }
        local result = arns.buyRecord(msg)
        assert.are.same({
            purchasePrice = 0,
            type = "lease",
            undernameCount = 10,
            processTxId = testProcessId,
            endTimestamp = timestamp + constants.MS_IN_A_YEAR * msg.Tags.Years,
        }, result)
    end)
end)




-- function testPermaBuyRecord()
--     Balances['Bob'] = 5000
--     local msg = {
--         Action = "BuyRecord",
--         From = "Bob",
--         Timestamp = os.clock(),
--         Tags = {
--             Name = "test-name-test",
--             PurchaseType = 'permabuy',
--             ProcessId = testProcessId
--         }
--     }
--     local reply = arns.buyRecord(msg)
--     luaunit.assertEquals(reply, true)
--     luaunit.assertEquals(Records['test-name-test'].processId, testProcessId)
--     luaunit.assertEquals(Records['test-name-test'].endTimestamp, nil)
--     luaunit.assertEquals(Balances['Bob'], 2000)
--     Balances = {}
--     Records = {}
-- end

-- function testIncreaseUndernameCount()
--     Balances['Bob'] = 1000
--     Records['test-name'] = {
--         endTimestamp = os.clock() + constants.MS_IN_A_YEAR,
--         processId = testProcessId,
--         purchasePrice = 1500,
--         startTimestamp = 0,
--         type = 'lease',
--         undernames = 10
--     }
--     local msg = {
--         Action = "IncreaseUndernameCount",
--         From = "Bob",
--         Timestamp = os.clock(),
--         Tags = {
--             Name = 'test-name',
--             Qty = 50,
--         }
--     }
--     local reply = arns.increaseUndernameCount(msg)
--     luaunit.assertEquals(reply, true)
--     luaunit.assertEquals(Records['test-name'].undernames, 60)

--     -- This test should fail as you cannot add more than 10k undernames
--     msg = {
--         Action = "IncreaseUndernameCount",
--         From = "Bob",
--         Timestamp = os.clock(),
--         Tags = {
--             Name = 'test-name',
--             Qty = 10000,
--         }
--     }
--     reply = arns.increaseUndernameCount(msg)
--     luaunit.assertEquals(reply, false)

--     -- This test should fail as the user should not have enough funds
--     msg = {
--         Action = "IncreaseUndernameCount",
--         From = "Bob",
--         Timestamp = os.clock(),
--         Tags = {
--             Name = 'test-name',
--             Qty = 9000,
--         }
--     }
--     reply = arns.increaseUndernameCount(msg)
--     luaunit.assertEquals(reply, false)
--     Balances = {}
--     Records = {}
-- end

-- os.exit(luaunit.LuaUnit.run())

-- end)
