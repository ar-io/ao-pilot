local utils = require(".utils")
local json = require(".json")
local records = {}

if not Records then
	Records = {}
end

function records.setRecord(msg)
	local hasPermission, permissionErr = utils.hasPermission(msg)
	if not hasPermission then
		return utils.reply(permissionErr)
	end

	local name = msg.Tags.Name
	local targetId = msg.Tags["Transaction-Id"]
	local ttlSeconds = msg.Tags["TTL-Seconds"]

	local nameValidity, nameValidityError = utils.validateUndername(name)
	if nameValidity == false then
		return utils.reply(nameValidityError)
	end

	local targetIdValidity, targetValidityError = utils.validateArweaveId(targetId)
	if targetIdValidity == false then
		return utils.reply(targetValidityError)
	end

	local ttlSecondsValidity, ttlValidityError = utils.validateTTLSeconds(ttlSeconds)
	if ttlSecondsValidity == false then
		return utils.reply(ttlValidityError)
	end

	Records[name] = {
		targetId = targetId,
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
