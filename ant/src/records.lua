local utils = require("ant.src.utils")
local json = require("ant.src.json")
local records = {}


	Records = Records or {}


function records.setRecord(msg)
	local hasPermission, permissionErr = utils.hasPermission(msg)
	if hasPermission == false then
		print("permissionErr", permissionErr)
		return utils.reply(permissionErr)
	end

	local name = msg.Tags.Name
	local transactionId = msg.Tags["Transaction-Id"]
	local ttlSeconds = msg.Tags["TTL-Seconds"]

	local nameValidity, nameValidityError = utils.validateUndername(name)
	if nameValidity == false then
		print("nameValidityError", nameValidityError)
		return utils.reply(nameValidityError)
	end

	local targetIdValidity, targetValidityError = utils.validateArweaveId(transactionId)
	if targetIdValidity == false then
		print("targetValidityError", targetValidityError)
		return utils.reply(targetValidityError)
	end

	local ttlSecondsValidity, ttlValidityError = utils.validateTTLSeconds(ttlSeconds)
	if ttlSecondsValidity == false then
		print("ttlValidityError", ttlValidityError)
		return utils.reply(ttlValidityError)
	end

	Records[name] = {
		transactionId = transactionId,
		ttlSeconds = ttlSeconds,
	}
end

function records.removeRecord(msg)
	local hasPermission, permissionErr = utils.hasPermission(msg)
	if not hasPermission then
		return utils.reply(permissionErr)
	end
	local name = msg.Tags.Name
	local nameValidity, nameValidityError = utils.validateUndername(name)
	if nameValidity == false then
		return utils.reply(nameValidityError)
	end

	Records[name] = nil
end

function records.getRecord(msg)
	local name = msg.Tags.Name
	local nameValidity, nameValidityError = utils.validateUndername(name)
	if nameValidity == false then
		return utils.reply(nameValidityError)
	end

	if Records[name] == nil then
		return nil
	end
	local parsedRecord = json.encode(Records[name])
	utils.reply(parsedRecord)
end

function records.getRecords()
	local parsedRecords = json.encode(Records)
	utils.reply(parsedRecords)
end

return records
