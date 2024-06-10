local utils = require(".utils")
local initialize = {}

function initialize.initialize(state)
	local name, ticker, balances, controllers, records =
		state.name, state.ticker, state.balances, state.controllers, state.records

	assert(type(name) == "string", "name must be a string")
	assert(type(ticker) == "string", "ticker must be a string")
	assert(type(balances) == "table", "balances must be a table")
	for k, v in pairs(balances) do
		assert(utils.validateArweaveId(k), "balances keys must be strings")
		assert(type(v) == "number", "balances values must be numbers")
	end
	assert(type(controllers) == "table", "controllers must be a table")
	for _, v in ipairs(controllers) do
		assert(utils.validateArweaveId(v), "controllers must be a list of arweave id's")
	end
	assert(type(records) == "table", "records must be a table")
	for k, v in pairs(records) do
		assert(utils.validateUndername(k), "records keys must be strings")
		assert(type(v) == "table", "records values must be tables")
		assert(utils.validateArweaveId(v.transactionId), "records transactionId must be a string")
		assert(type(v.ttlSeconds) == "number", "records ttlSeconds must be a number")
	end

	Name = name
	Ticker = ticker
	Balances = balances
	Controllers = controllers
	Records = records
end

return initialize
