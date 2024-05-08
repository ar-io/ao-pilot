require("state")
local token = require("token")
-- local constants = require("constants")
local testSettings = {
    testTransferQuantity = 100
}

describe("token", function()
    it("should transfer tokens", function()
        Balances["Bob"] = testSettings.testTransferQuantity
        local reply, err = token.transfer("Alice", "Bob", testSettings.testTransferQuantity)
        assert.is_true(reply)
        assert.are.same(testSettings.testTransferQuantity, Balances["Alice"])
        assert.are.same(0, Balances["Bob"])
        assert.are.same(nil, err)
    end)

    it("should handle insufficient balance", function()
        Balances["Bob"] = 0
        local success, err = token.transfer("Alice", "Bob", 100)
        assert.are.same(success, false)
        assert.are.equal(err, "Insufficient funds!")
    end)
end)
