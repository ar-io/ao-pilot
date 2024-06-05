package.path = "./src/?.lua;" .. package.path

local testProcessId = "NdZ3YRwMB2AMwwFYjKn1g88Y9nRybTo0qhS1ORq_E7g"
local balances = require("ant.srcb.balances")
local controllers = require("ant.srcb.controllers")
local initialize = require("ant.srcb.initialize")
local records = require("ant.srcb.records")
local utils = require("ant.srcb.utils")
local constants = require("ant.srcb.constants")

_G.ao = {
	send = function()
		return true
	end,
	id = "test",
}
_G.Balances = {}
_G.Records = {}
_G.Controllers = {}
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
	controllers = { "bob" },
	records = { ["@"] = { transactionId = "test", ttlSeconds = 900 } },
	balances = { ["bob"] = 1 },
}

describe("Arweave Name Token", function()
	local original_clock = os.clock
	local timestamp = os.clock()

	setup(function() end)

	teardown(function() end)

	it("Initializes the state of the process", function()
		local encodedState = json.encode(originalState)
		local badState = {
			name = "Arweave Name Token",
			ticker = "ANT",
			controllers = { "bob" },
			-- missing records
		}
		local replySpy = spy.new(utils.reply)
		local initMsg = {
			Data = encodedState,
		}
		initialize.initialize(initMsg) -- happy
		initialize.initialize({ Data = json.encode(badState) }) -- missing records
		initialize.initialize({ Data = nil }) -- no state provided

		assert.spy(replySpy).was_called_with("Invalid State: state is missing required fields", "State not provided")
		assert.are.same(_G.Balances, originalState.balances)
		assert.are.same(_G.Records, originalState.records)
		assert.are.same(_G.Controllers, originalState.controllers)
		assert.are.same(_G.Name, originalState.name)
		assert.are.same(_G.Ticker, originalState.ticker)
	end)
end)
