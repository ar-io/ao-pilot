local vaults = require("vaults")
local constants = require("constants")
local startTimestamp = 0

describe("vaults", function()
	before_each(function()
		_G.Balances = {
			["test-this-is-valid-arweave-wallet-address-1"] = 100,
		}
		_G.Vaults = {}
	end)

	it("should create vault", function()
		local status, result = pcall(
			vaults.createVault,
			"test-this-is-valid-arweave-wallet-address-1",
			100,
			constants.MIN_TOKEN_LOCK_TIME,
			startTimestamp,
			"msgId"
		)
		local expectation = {
			balance = 100,
			startTimestamp = startTimestamp,
			endTimestamp = startTimestamp + constants.MIN_TOKEN_LOCK_TIME,
		}
		assert.is_true(status)
		assert.are.same(expectation, result)
		assert.are.same(expectation, vaults.getVault("test-this-is-valid-arweave-wallet-address-1", "msgId"))
	end)

	it("should throw an insufficient balance error if not enough tokens to create the vault", function()
		Balances["test-this-is-valid-arweave-wallet-address-1"] = 50
		local status, result = pcall(
			vaults.createVault,
			"test-this-is-valid-arweave-wallet-address-1",
			100,
			constants.MIN_TOKEN_LOCK_TIME,
			startTimestamp,
			"msgId"
		)
		assert.is_false(status)
		assert.match("Insufficient balance", result)
	end)
end)
