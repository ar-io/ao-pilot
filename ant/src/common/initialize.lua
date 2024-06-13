local utils = require(".common.utils")
local json = require(".common.json")
local initialize = {}

function initialize.initializeANTState(state)
	local encoded = json.decode(state)
	local balances = encoded.balances
	local controllers = encoded.controllers
	local records = encoded.records
	local name = encoded.name
	local ticker = encoded.ticker
	assert(type(name) == "string", "name must be a string")
	assert(type(ticker) == "string", "ticker must be a string")
	assert(type(balances) == "table", "balances must be a table")
	for k, v in pairs(balances) do
		balances[k] = tonumber(v)
	end
	assert(type(controllers) == "table", "controllers must be a table")
	assert(type(records) == "table", "records must be a table")
	for k, v in pairs(records) do
		utils.validateUndername(k)
		assert(type(v) == "table", "records values must be tables")
		utils.validateArweaveId(v.transactionId)
		utils.validateTTLSeconds(v.ttlSeconds)
	end

	Name = name
	Ticker = ticker
	Balances = balances
	Controllers = controllers
	Records = records
	Initialized = true

	return {
		name = Name,
		ticker = Ticker,
		balances = Balances,
		controllers = Controllers,
		records = Records,
	}
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
