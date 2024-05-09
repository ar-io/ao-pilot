local token = require("token")
local constants = require("constants")

-- local constants = require("constants")
local testSettings = {
    testTransferQuantity = 100
}
local startTimestamp = 0

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

describe("vaults", function()
    it("should create vault", function()
        Balances["Bob"] = testSettings.testTransferQuantity
        local reply, err = token.createVault("Bob", testSettings.testTransferQuantity, constants.MIN_TOKEN_LOCK_TIME,
            startTimestamp,
            "msgId")
        print(err)
        assert.are.same(reply, {
            balance = testSettings.testTransferQuantity,
            startTimestamp = startTimestamp,
            endTimestamp = startTimestamp + constants.MIN_TOKEN_LOCK_TIME
        })
    end)
end)
