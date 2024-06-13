local utils = require(".common.utils")
local json = require(".common.json")
local records = {}
-- defaults to landing page txid
Records = Records or { ["@"] = { transactionId = "UyC5P5qKPZaltMmmZAWdakhlDXsBF6qmyrbWYFchRTk", ttlSeconds = 3600 } }

function records.setRecord(name, transactionId, ttlSeconds)
	local nameValidity, nameValidityError = pcall(utils.validateUndername, name)
	assert(nameValidity ~= false, nameValidityError)
	local targetIdValidity, targetValidityError = pcall(utils.validateArweaveId, transactionId)
	assert(targetIdValidity ~= false, targetValidityError)
	local ttlSecondsValidity, ttlValidityError = pcall(utils.validateTTLSeconds, ttlSeconds)
	assert(ttlSecondsValidity ~= false, ttlValidityError)

	Records[name] = {
		transactionId = transactionId,
		ttlSeconds = ttlSeconds,
	}

	return "Record set"
end

function records.removeRecord(name)
	local nameValidity, nameValidityError = pcall(utils.validateUndername, name)
	assert(nameValidity ~= false, nameValidityError)
	Records[name] = nil

	return "Record removed"
end

function records.getRecord(name)
	utils.validateUndername(name)
	assert(Records[name] ~= nil, "Record does not exist")

	return json.encode(Records[name])
end

function records.getRecords()
	return json.encode(Records)
end

return records
