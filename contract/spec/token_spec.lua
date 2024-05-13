local token = require("token")
local constants = require("constants")
local startTimestamp = 0

describe("token", function()
	before_each(function()
		token.balances = {
			Bob = 100,
		}
		token.vaults = {}
	end)

	it("should transfer tokens", function()
		local status, result = pcall(token.transfer, "Alice", "Bob", 100)
		assert.is_true(status)
		assert.are.same(result["Alice"], token.getBalance("Alice"))
		assert.are.same(result["Bob"], token.getBalance("Bob"))
	end)

	it("should error on insufficient balance", function()
		local status, result = pcall(token.transfer, "Alice", "Bob", 101)
		assert.is_false(status)
		assert.match("Insufficient balance", result)
		assert.are.equal(0, token.getBalance("Alice"))
		assert.are.equal(100, token.getBalance("Bob"))
	end)
end)

describe("vaults", function()
	before_each(function()
		token.balances = {
			Bob = 100,
		}
		token.vaults = {}
	end)

	it("should create vault", function()
		local status, result =
			pcall(token.createVault, "Bob", 100, constants.MIN_TOKEN_LOCK_TIME, startTimestamp, "msgId")
		local expectation = {
			balance = 100,
			startTimestamp = startTimestamp,
			endTimestamp = startTimestamp + constants.MIN_TOKEN_LOCK_TIME,
		}
		assert.is_true(status)
		assert.are.same(expectation, result)
		assert.are.same(expectation, token.getVault("Bob", "msgId"))
	end)
end)
