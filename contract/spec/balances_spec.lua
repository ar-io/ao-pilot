local balances = require("balances")

describe("balances", function()
	before_each(function()
		_G.Balances = {
			["test-this-is-valid-arweave-wallet-address-1"] = 100,
		}
	end)

	it("should transfer tokens", function()
		local status, result = pcall(balances.transfer, "test-this-is-valid-arweave-wallet-address-2", "test-this-is-valid-arweave-wallet-address-1", 100)
		assert.is_true(status)
		assert.are.same(result["test-this-is-valid-arweave-wallet-address-2"], balances.getBalance("test-this-is-valid-arweave-wallet-address-2"))
		assert.are.same(result["test-this-is-valid-arweave-wallet-address-1"], balances.getBalance("test-this-is-valid-arweave-wallet-address-1"))
		assert.are.equal(100, balances.getBalance("test-this-is-valid-arweave-wallet-address-2"))
		assert.are.equal(0, balances.getBalance("test-this-is-valid-arweave-wallet-address-1"))
	end)

	it("should error on insufficient balance", function()
		local status, result = pcall(balances.transfer, "test-this-is-valid-arweave-wallet-address-2", "test-this-is-valid-arweave-wallet-address-1", 101)
		assert.is_false(status)
		assert.match("Insufficient balance", result)
		assert.are.equal(0, balances.getBalance("test-this-is-valid-arweave-wallet-address-2"))
		assert.are.equal(100, balances.getBalance("test-this-is-valid-arweave-wallet-address-1"))
	end)
end)
