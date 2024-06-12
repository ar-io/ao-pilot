local utils = require(".ant-utils")
local json = require(".json")
local records = {}

Records = Records or {}

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
end

function records.removeRecord(name)
	local nameValidity, nameValidityError = pcall(utils.validateUndername, name)
	assert(nameValidity ~= false, nameValidityError)
	Records[name] = nil
end

function records.getRecord(name)
	local nameValidity, nameValidityError = pcall(utils.validateUndername, name)
	if nameValidity == false then
		return utils.reply(nameValidityError)
	end

	assert(Records[name] ~= nil, "Record does not exist")
	local parsedRecord = json.encode(Records[name])
	utils.reply(parsedRecord)
end

function records.getRecords()
	local parsedRecords = json.encode(Records)
	utils.reply(parsedRecords)
end

return records
