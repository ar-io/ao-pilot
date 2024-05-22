local vaults = require("vaults")
local constants = require("constants")
local startTimestamp = 0

describe("vaults", function()
	before_each(function()
		_G.Balances = {
			Bob = 100,
		}
		_G.Vaults = {}
	end)

	it("should create vault", function()
		local status, result =
			pcall(vaults.createVault, "Bob", 100, constants.MIN_TOKEN_LOCK_TIME, startTimestamp, "msgId")
		local expectation = {
			balance = 100,
			startTimestamp = startTimestamp,
			endTimestamp = startTimestamp + constants.MIN_TOKEN_LOCK_TIME,
		}
		assert.is_true(status)
		assert.are.same(expectation, result)
		assert.are.same(expectation, vaults.getVault("Bob", "msgId"))
	end)

	it("should throw an insufficient balance error if not enough tokens to create the vault", function()
		Balances.Bob = 50
		local status, result =
			pcall(vaults.createVault, "Bob", 100, constants.MIN_TOKEN_LOCK_TIME, startTimestamp, "msgId")
		assert.is_false(status)
		assert.match("Insufficient balance", result)
	end)
end)