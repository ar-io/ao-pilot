local balances = require("ant.src.balances")
local controllers = require("ant.src.controllers")
local initialize = require("ant.src.initialize")
local records = require("ant.src.records")

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
	controllers = { fake_address},
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
		initialize.initialize(originalState) -- happy

		assert.are.same(_G.Balances, originalState.balances)
		assert.are.same(_G.Records, originalState.records)
		assert.are.same(_G.Controllers, originalState.controllers)
		assert.are.same(_G.Name, originalState.name)
		assert.are.same(_G.Ticker, originalState.ticker)
	end)

	it("Transfers tokens between accounts", function()
		local to = "1111111111111111111111111111111111111111112"
		local transferMsg = {
			From = fake_address,
			Tags = {
				Recipient = to,
			},
		}
		balances.transfer(transferMsg) -- happy path

		assert.are.same(_G.Balances[fake_address], nil)
		assert.are.same(_G.Balances[to], 1)
	end)

	it("sets a controller", function()
		local newController = "1111111111111111111111111111111111111111112"
		local controllerMsg = {
			From = fake_address,
			Tags = {
				Controller = newController,
			},
		}
		controllers.setController(controllerMsg) -- happy path

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
		local controllerMsg = {
			From = fake_address,
			Tags = {
				Controller = controllerToRemove,
			},
		}
		controllers.removeController(controllerMsg) -- happy path

		local hasController = nil
		for _, controller in ipairs(_G.Controllers) do
			if controller == controllerToRemove then
				hasController = false
			end
		end
		assert.is_false(hasController)
	end
	)

	it("sets a record", function()
		-- TODO: not sure why failing,
		local recordMsg = {
			From = fake_address,
			Tags = {
				Name = "@",
				["Transaction-Id"] = fake_address,
				["TTL-Seconds"] = 900,
			},
		}
		records.setRecord(recordMsg) -- happy path

		assert.are.same(_G.Records["@"].transactionId, fake_address)
		assert.are.same(_G.Records["@"].ttlSeconds, 900)
	end)

	it("removes a record", function()
		local recordMsg = {
			From = fake_address,
			Tags = {
				Name = "@",
			},
		}
		records.removeRecord(recordMsg) -- happy path

		assert.are.same(_G.Records["@"], nil)
	end)

	it("sets the name", function()
		local newName = "New Name"
		local nameMsg = {
			From = fake_address,
			Tags = {
				Name = newName,
			},
		}
		balances.setName(nameMsg) -- happy path

		assert.are.same(_G.Name, newName)
	end)

	it("sets the ticker", function()
		local newTicker = "NEW"
		local tickerMsg = {
			From = fake_address,
			Tags = {
				Ticker = newTicker,
			},
		}
		balances.setTicker(tickerMsg) -- happy path

		assert.are.same(_G.Ticker, newTicker)
	end)


end)
