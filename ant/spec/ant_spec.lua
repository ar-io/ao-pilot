local balances = require("src.common.balances")
local controllers = require("src.common.controllers")
local initialize = require("src.common.initialize")
local records = require("src.common.records")
local json = require("src.common.json")

local fake_address = "1111111111111111111111111111111111111111111"

_G.ao = {
	send = function()
		return true
	end,
	id = "test",
}
_G.Balances = { [fake_address] = 1 }
_G.Records = {}
_G.Controllers = { fake_address }
_G.Name = "Arweave Name Token"
_G.Ticker = "ANT"
_G.Logo = "LOGO"
_G.Denomination = 1

os.clock = function()
	return 0
end

local originalState = {
	name = "Arweave Name Token",
	ticker = "ANT",
	controllers = { fake_address },
	records = { ["@"] = { transactionId = "test", ttlSeconds = 900 } },
	balances = { [fake_address] = 1 },
}

describe("Arweave Name Token", function()
	before_each(function()
		_G.Balances = { [fake_address] = 1 }
		_G.Records = {}
		_G.Controllers = { fake_address }
		_G.Name = "Arweave Name Token"
		_G.Ticker = "ANT"
	end)

	setup(function() end)

	teardown(function() end)

	it("Initializes the state of the process", function()
		initialize.initializeANTState(json.encode(originalState)) -- happy

		assert.are.same(_G.Balances, originalState.balances)
		assert.are.same(_G.Records, originalState.records)
		assert.are.same(_G.Controllers, originalState.controllers)
		assert.are.same(_G.Name, originalState.name)
		assert.are.same(_G.Ticker, originalState.ticker)
	end)

	it("Transfers tokens between accounts", function()
		local to = "1111111111111111111111111111111111111111112"
		balances.transfer(to) -- happy path

		assert.are.same(_G.Balances[fake_address], nil)
		assert.are.same(_G.Balances[to], 1)
	end)

	it("sets a controller", function()
		local newController = "1111111111111111111111111111111111111111112"
		controllers.setController(newController) -- happy path

		local hasController = nil
		for _, controller in ipairs(_G.Controllers) do
			if controller == newController then
				hasController = true
			end
		end
		assert.is_true(hasController)
	end)

	it("removes a controller", function()
		local controllerToRemove = fake_address
		controllers.removeController(fake_address) -- happy path

		local hasController = false
		for _, controller in ipairs(_G.Controllers) do
			if controller == controllerToRemove then
				hasController = true
			end
		end
		assert.is_false(hasController)
	end)

	it("sets a record", function()
		local name, transactionId, ttlSeconds = "@", fake_address, 900
		records.setRecord(name, transactionId, ttlSeconds) -- happy path
		assert.are.same(_G.Records["@"].transactionId, fake_address)
		assert.are.same(_G.Records["@"].ttlSeconds, 900)
	end)

	it("removes a record", function()
		local name = "@"
		records.removeRecord(name) -- happy path

		assert.are.same(_G.Records[name], nil)
	end)

	it("sets the name", function()
		local newName = "New Name"
		balances.setName(newName) -- happy path

		assert.are.same(_G.Name, newName)
	end)

	it("sets the ticker", function()
		local newTicker = "NEW"
		balances.setTicker(newTicker) -- happy path

		assert.are.same(_G.Ticker, newTicker)
	end)
end)
