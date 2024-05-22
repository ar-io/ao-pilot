local balances = require("balances")

describe("balances", function()
	before_each(function()
		_G.Balances = {
			Bob = 100,
		}
	end)

	it("should transfer tokens", function()
		local status, result = pcall(balances.transfer, "Alice", "Bob", 100)
		assert.is_true(status)
		assert.are.same(result["Alice"], balances.getBalance("Alice"))
		assert.are.same(result["Bob"], balances.getBalance("Bob"))
		assert.are.equal(100, balances.getBalance("Alice"))
		assert.are.equal(0, balances.getBalance("Bob"))
	end)

	it("should error on insufficient balance", function()
		local status, result = pcall(balances.transfer, "Alice", "Bob", 101)
		assert.is_false(status)
		assert.match("Insufficient balance", result)
		assert.are.equal(0, balances.getBalance("Alice"))
		assert.are.equal(100, balances.getBalance("Bob"))
	end)
end)
