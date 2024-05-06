package.path = package.path .. ';../lib/?.lua'

local arns = require 'arns'
local constants = require 'constants'

describe("arns", function()
    it("adds a record to the global balance object", function()
        os.clock = function () return 100 end
        local result = arns.buyRecord("name", "lease", "processTxId", "owner")
        assert.are.same(result, {
            owner = "owner",
            price = 0,
            type = "lease",
            undernameCount = 10,
            processTxId = "processTxId",
            endTimestamp = 100 + (constants.oneYearSeconds * 1000)
        })
    end)
end)
