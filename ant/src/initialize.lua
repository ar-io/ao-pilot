local utils = require(".ant-utils")
local initialize = {}

function initialize.initializeANTState(state)
	local name, ticker, balances, controllers, records =
		state.name, state.ticker, state.balances, state.controllers, state.records

	assert(type(name) == "string", "name must be a string")
	assert(type(ticker) == "string", "ticker must be a string")
	assert(type(balances) == "table", "balances must be a table")
	for k, v in pairs(balances) do
		local idValidity, idRes = pcall(utils.validateArweaveId, k)
		assert(idValidity ~= false, idRes)
		assert(type(v) == "number", "balances values must be numbers")
	end
	assert(type(controllers) == "table", "controllers must be a table")
	for _, v in ipairs(controllers) do
		local controllerValidity, _ = pcall(utils.validateArweaveId, v)
		assert(controllerValidity ~= false, "controllers must be a list of arweave id's")
	end
	assert(type(records) == "table", "records must be a table")
	for k, v in pairs(records) do
		local nameValidity, _ = pcall(utils.validateUndername, k)
		assert(nameValidity ~= false, "records keys must be strings")
		assert(type(v) == "table", "records values must be tables")
		local idValidity, _ = pcall(utils.validateArweaveId, k)
		assert(idValidity ~= false, "records transactionId must be a string")
		local ttlValidity, _ = pcall(utils.validateTTLSeconds, v.ttlSeconds)
		assert(ttlValidity ~= false, "Invalid ttlSeconds on records")
	end

	Name = name
	Ticker = ticker
	Balances = balances
	Controllers = controllers
	Records = records
	Initialized = true

	return "State initialized"
end

local function findObject(array, key, value)
	for i, object in ipairs(array) do
		if object[key] == value then
			return object
		end
	end
	return nil
end

function initialize.initializeProcessState(msg, env)
	Errors = Errors or {}
	Inbox = Inbox or {}

	-- temporary fix for Spawn
	if not Owner then
		local _from = findObject(env.Process.Tags, "name", "From-Process")
		if _from then
			Owner = _from.value
		else
			Owner = msg.From
		end
	end

	if not Name then
		local taggedName = findObject(env.Process.Tags, "name", "Name")
		if taggedName then
			Name = taggedName.value
		else
			Name = "ANT"
		end
	end
end

return initialize
