local initialize = {}

function initialize.initialize(state)
	local name, ticker, balances, controllers, records =
		state.name, state.ticker, state.balances, state.controllers, state.records

	assert(type(name) == "string", "name must be a string")
	assert(type(ticker) == "string", "ticker must be a string")
	assert(type(balances) == "table", "balances must be a table")
	assert(type(controllers) == "table", "controllers must be a table")
	assert(type(records) == "table", "records must be a table")

	Name = name
	Ticker = ticker
	Balances = balances
	Controllers = controllers
	Records = records
end

return initialize
