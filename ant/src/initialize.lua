local json = require(".json")
local utils = require(".utils")

local initialize = {}

function initialize.initialize(msg)
	local state = msg.Data and json.decode(msg.Data)
	if not state then
		return utils.reply("State not provided")
	end

	local name, ticker, balances, controllers, records =
		state.name, state.ticker, state.balances, state.controllers, state.records

	if not name or not ticker or not balances or not controllers or not records then
		return utils.reply("Invalid State: state is missing required fields")
	end

	Name = name
	Ticker = ticker
	Balances = balances
	Controllers = controllers
	Records = records
end

return initialize
