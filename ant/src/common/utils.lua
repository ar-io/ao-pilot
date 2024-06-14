-- the majority of this file came from https://github.com/permaweb/aos/blob/main/process/utils.lua

local constants = require(".common.constants")
local utils = { _version = "0.0.1" }

local function isArray(table)
	if type(table) == "table" then
		local maxIndex = 0
		for k, v in pairs(table) do
			if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
				return false -- If there's a non-integer key, it's not an array
			end
			maxIndex = math.max(maxIndex, k)
		end
		-- If the highest numeric index is equal to the number of elements, it's an array
		return maxIndex == #table
	end
	return false
end

-- @param {function} fn
-- @param {number} arity
utils.curry = function(fn, arity)
	assert(type(fn) == "function", "function is required as first argument")
	arity = arity or debug.getinfo(fn, "u").nparams
	if arity < 2 then
		return fn
	end

	return function(...)
		local args = { ... }

		if #args >= arity then
			return fn(table.unpack(args))
		else
			return utils.curry(function(...)
				return fn(table.unpack(args), ...)
			end, arity - #args)
		end
	end
end

--- Concat two Array Tables.
-- @param {table<Array>} a
-- @param {table<Array>} b
utils.concat = utils.curry(function(a, b)
	assert(type(a) == "table", "first argument should be a table that is an array")
	assert(type(b) == "table", "second argument should be a table that is an array")
	assert(isArray(a), "first argument should be a table")
	assert(isArray(b), "second argument should be a table")

	local result = {}
	for i = 1, #a do
		result[#result + 1] = a[i]
	end
	for i = 1, #b do
		result[#result + 1] = b[i]
	end
	return result
end, 2)

--- reduce applies a function to a table
-- @param {function} fn
-- @param {any} initial
-- @param {table<Array>} t
utils.reduce = utils.curry(function(fn, initial, t)
	assert(type(fn) == "function", "first argument should be a function that accepts (result, value, key)")
	assert(type(t) == "table" and isArray(t), "third argument should be a table that is an array")
	local result = initial
	for k, v in pairs(t) do
		if result == nil then
			result = v
		else
			result = fn(result, v, k)
		end
	end
	return result
end, 3)

-- @param {function} fn
-- @param {table<Array>} data
utils.map = utils.curry(function(fn, data)
	assert(type(fn) == "function", "first argument should be a unary function")
	assert(type(data) == "table" and isArray(data), "second argument should be an Array")

	local function map(result, v, k)
		result[k] = fn(v, k)
		return result
	end

	return utils.reduce(map, {}, data)
end, 2)

-- @param {function} fn
-- @param {table<Array>} data
utils.filter = utils.curry(function(fn, data)
	assert(type(fn) == "function", "first argument should be a unary function")
	assert(type(data) == "table" and isArray(data), "second argument should be an Array")

	local function filter(result, v, _k)
		if fn(v) then
			table.insert(result, v)
		end
		return result
	end

	return utils.reduce(filter, {}, data)
end, 2)

-- @param {function} fn
-- @param {table<Array>} t
utils.find = utils.curry(function(fn, t)
	assert(type(fn) == "function", "first argument should be a unary function")
	assert(type(t) == "table", "second argument should be a table that is an array")
	for _, v in pairs(t) do
		if fn(v) then
			return v
		end
	end
end, 2)

-- @param {string} propName
-- @param {string} value
-- @param {table} object
utils.propEq = utils.curry(function(propName, value, object)
	assert(type(propName) == "string", "first argument should be a string")
	-- assert(type(value) == "string", "second argument should be a string")
	assert(type(object) == "table", "third argument should be a table<object>")

	return object[propName] == value
end, 3)

-- @param {table<Array>} data
utils.reverse = function(data)
	assert(type(data) == "table", "argument needs to be a table that is an array")
	return utils.reduce(function(result, v, i)
		result[#data - i + 1] = v
		return result
	end, {}, data)
end

-- @param {function} ...
utils.compose = utils.curry(function(...)
	local mutations = utils.reverse({ ... })

	return function(v)
		local result = v
		for _, fn in pairs(mutations) do
			assert(type(fn) == "function", "each argument needs to be a function")
			result = fn(result)
		end
		return result
	end
end, 2)

-- @param {string} propName
-- @param {table} object
utils.prop = utils.curry(function(propName, object)
	return object[propName]
end, 2)

-- @param {any} val
-- @param {table<Array>} t
utils.includes = utils.curry(function(val, t)
	assert(type(t) == "table", "argument needs to be a table")
	return utils.find(function(v)
		return v == val
	end, t) ~= nil
end, 2)

-- @param {table} t
utils.keys = function(t)
	assert(type(t) == "table", "argument needs to be a table")
	local keys = {}
	for key in pairs(t) do
		table.insert(keys, key)
	end
	return keys
end

-- @param {table} t
utils.values = function(t)
	assert(type(t) == "table", "argument needs to be a table")
	local values = {}
	for _, value in pairs(t) do
		table.insert(values, value)
	end
	return values
end

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

	assert(valid == true, constants.INVALID_ARWEAVE_ID_MESSAGE)
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

function utils.assertHasPermission(from)
	local isController = false
	for _, c in ipairs(Controllers) do
		if c == from then
			isController = true
			break
		end
	end
	local hasPermission = isController == true or Balances[from] or Owner == from or ao.env.Process.Id == from
	assert(hasPermission == true, "Only controllers and owners can set controllers and records.")
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
