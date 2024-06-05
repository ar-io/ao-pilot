local constants = require(".constants")
local utils = {}

function utils.hasMatchingTag(tag, value)
	return Handlers.utils.hasMatchingTag(tag, value)
end

function utils.reply(msg)
	Handlers.utils.reply(msg)
end
function utils.walletHasSufficientBalance(wallet, quantity)
	return Balances[wallet] ~= nil and Balances[wallet] >= quantity
end

function utils.ensureMilliseconds(timestamp)
	-- Assuming any timestamp before 100000000000 is in seconds
	-- This is a heuristic approach since determining the exact unit of a timestamp can be ambiguous
	local threshold = 100000000000
	if timestamp < threshold then
		-- If the timestamp is below the threshold, it's likely in seconds, so convert to milliseconds
		return timestamp * 1000
	else
		-- If the timestamp is above the threshold, assume it's already in milliseconds
		return timestamp
	end
end

function utils.isExistingActiveRecord(record)
	if not record then
		return false
	end

    return true
end


function utils.assertAvailableRecord(name)
	local isActiveRecord = utils.isExistingActiveRecord(Records[name])
	if isActiveRecord then
		return false, constants.ARNS_NON_EXPIRED_NAME_MESSAGE
	end

	return true
end

function utils.validateUndername(name)
    local valid = string.match(name, constants.UNDERNAME_REGEXP) ~= nil
    if valid == false then
        return valid, constants.UNDERNAME_DOES_NOT_EXIST_MESSAGE
    end
    return valid
end

function utils.validateArweaveId(id)
    local valid = string.match(id, constants.ARWEAVE_ID_REGEXP) ~= nil
    if valid == false then
        return valid, constants.INVALID_ARWEAVE_ID_MESSAGE
    end
    return valid
end

function utils.validateTTLSeconds(ttl)
    local valid = type(ttl) == 'number' and ttl >= constants.MIN_TTL_SECONDS and ttl <= constants.MAX_TTL_SECONDS
    if valid == false then
        return valid, constants.INVALID_TTL_MESSAGE
    end
    return valid
end

function utils.validateTransfer(msg)
    local isOwner = Balances[msg.From] ~= nil

    if not isOwner then
        return false, "Sender is not the owner."
    end
end

function utils.hasPermission(msg)
    local hasPermission = Controllers[msg.From] or Balances[msg.From]
    if not hasPermission then
        return false, "Only controllers and owners can set controllers and records."
    end
end

return utils
