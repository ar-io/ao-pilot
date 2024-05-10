local token = require("token")
local constants = require("constants")
local startTimestamp = 0

describe("token", function()

    	-- stub out the global state for these tests
	before_each(function()
		_G.Balances = {
            Bob = 100
        }
        _G.Vaults = {}
	end)

    it("should transfer tokens", function()
        local status, result = pcall(token.transfer, "Alice", "Bob", 100)
        assert.is_true(status)
        assert.are.same(result["Alice"], Balances["Alice"])
        assert.are.same(result["Bob"], Balances["Bob"])
    end)

    it("should handle insufficient balance", function()
        local status, result = pcall(token.transfer, "Alice", "Bob", 101)
        assert.is_false(status)
        assert.match("Insufficient balance", result)
    end)
end)

describe("vaults", function()
    it("should create vault", function()
        local status, result = pcall(token.createVault, "Bob", 100, constants.MIN_TOKEN_LOCK_TIME, startTimestamp, "msgId")
        local expectation = {
            balance = 100,
            startTimestamp = startTimestamp,
            endTimestamp = startTimestamp + constants.MIN_TOKEN_LOCK_TIME
        }
        assert.is_true(status)
        assert.are.same(expectation, result)
        assert.are.same(expectation, _G.Vaults["Bob"]["msgId"])
    end)
end)
