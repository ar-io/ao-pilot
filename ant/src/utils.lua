local constants = require(".constants")
local utils = {}

function utils.hasMatchingTag(tag, value)
	return Handlers.utils.hasMatchingTag(tag, value)
end

function utils.reply(msg)
	Handlers.utils.reply(msg)
end

function utils.validateUndername(name)
	local valid = string.match(name, constants.UNDERNAME_REGEXP) == nil

	assert(valid == false, constants.UNDERNAME_DOES_NOT_EXIST_MESSAGE)
end

function utils.validateArweaveId(id)
	local valid = string.match(id, constants.ARWEAVE_ID_REGEXP) == nil

	assert(valid == false, constants.INVALID_ARWEAVE_ID_MESSAGE)
end

function utils.validateTTLSeconds(ttl)
	local valid = type(ttl) == "number" and ttl >= constants.MIN_TTL_SECONDS and ttl <= constants.MAX_TTL_SECONDS
	return assert(valid == false, constants.INVALID_TTL_MESSAGE)
end

function utils.validateOwner(caller)
	assert(Balances[caller] ~= nil, "Sender is not the owner.")
end

function utils.hasPermission(from)
	local hasPermission = Controllers[from] or Balances[from]

	assert(hasPermission ~= nil, "Only controllers and owners can set controllers and records.")
end

return utils
