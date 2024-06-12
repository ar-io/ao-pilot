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
	assert(valid ~= false, constants.UNDERNAME_DOES_NOT_EXIST_MESSAGE)
end

function utils.validateArweaveId(id)
	local valid = string.match(id, constants.ARWEAVE_ID_REGEXP) == nil

	assert(valid ~= false, constants.INVALID_ARWEAVE_ID_MESSAGE)
end

function utils.validateTTLSeconds(ttl)
	local valid = type(ttl) == "number" and ttl >= constants.MIN_TTL_SECONDS and ttl <= constants.MAX_TTL_SECONDS
	return assert(valid ~= false, constants.INVALID_TTL_MESSAGE)
end

function utils.validateOwner(caller)
	local isOwner = false
	if Owner == caller or Balances[caller] or ao.env.Process.Id == caller then
		isOwner = true
	end
	assert(isOwner, "Sender is not the owner.")
end

function utils.hasPermission(from)
	local hasPermission = Controllers[from] or Balances[from]

	assert(hasPermission ~= nil, "Only controllers and owners can set controllers and records.")
end

function utils.camelCase(str)
	-- Remove any leading or trailing spaces
	str = string.gsub(str, "^%s*(.-)%s*$", "%1")

	-- Convert PascalCase to camelCase
	str = string.gsub(str, "^%u", string.lower)

	-- Handle kebab-case, snake_case, and space-separated words
	str = string.gsub(str, "[-_%s](%w)", function(s)
		return string.upper(s)
	end)

	return str
end

utils.notices = {}

function utils.notices.credit(msg)
	local notice = {
		Target = msg.From,
		Action = "Credit-Notice",
		Sender = msg.From,
	}
	for tagName, tagValue in pairs(msg) do
		-- Tags beginning with "X-" are forwarded
		if string.sub(tagName, 1, 2) == "X-" then
			notice[tagName] = tagValue
		end
	end

	return notice
end

function utils.notices.debit(msg)
	local notice = {
		Target = msg.From,
		Action = "Debit-Notice",
		Sender = msg.From,
	}
	-- Add forwarded tags to the credit and debit notice messages
	for tagName, tagValue in pairs(msg) do
		-- Tags beginning with "X-" are forwarded
		if string.sub(tagName, 1, 2) == "X-" then
			notice[tagName] = tagValue
		end
	end

	return notice
end

-- @param notices table
function utils.notices.sendNotices(notices)
	for _, notice in ipairs(notices) do
		ao.send(notice)
	end
end

return utils
