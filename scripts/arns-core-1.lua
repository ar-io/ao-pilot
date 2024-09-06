local json = require("json")
local ao = require('ao')

-- ARNS-CORE-1 Constants and Objects
local constants = {}

constants.UNDERNAME_DOES_NOT_EXIST_MESSAGE = "Record does not exist!"
constants.MAX_UNDERNAME_LENGTH = 61
constants.UNDERNAME_REGEXP = "^(?:@|[a-zA-Z0-9][a-zA-Z0-9-_]{0,"
	.. (constants.MAX_UNDERNAME_LENGTH - 2)
	.. "}[a-zA-Z0-9])$"

if not Records then
	Records = {}
	Records["@"] = {
		transactionId = "UyC5P5qKPZaltMmmZAWdakhlDXsBF6qmyrbWYFchRTk", -- Setup the default record pointing to the ArNS landing page
		ttlSeconds = 3600,
	}
end

local ARNSCoreSpecActionMap = {
	-- read actions
	Record = "Record",
	Records = "Records",
	State = "State",
}

local records = {}
function records.validateUndername(name)
	local valid = string.match(name, constants.UNDERNAME_REGEXP) == nil
	assert(valid ~= false, constants.UNDERNAME_DOES_NOT_EXIST_MESSAGE)
end

function records.getRecord(name)
	records.validateUndername(name)
	assert(Records[name] ~= nil, constants.UNDERNAME_DOES_NOT_EXIST_MESSAGE)

	return json.encode(Records[name])
end

function records.getRecords()
	return json.encode(Records)
end

-- ARNS-CORE-1 Handlers
Handlers.add(ARNSCoreSpecActionMap.Record, Handlers.utils.hasMatchingTag("Action", ARNSCoreSpecActionMap.Record),
	function(msg)
		local nameStatus, nameRes = pcall(records.getRecord, msg.Tags["Sub-Domain"])

		if not nameStatus then
			ao.send({
				Target = msg.From,
				Action = "Invalid-Record-Notice",
				Data = nameRes,
				Error = "Record-Error",
				["Message-Id"] = msg.Id,
			})
			return
		end

		local recordNotice = {
			Target = msg.From,
			Action = "Record-Notice",
			Name = msg.Tags["Sub-Domain"],
			Data = nameRes,
		}

		-- Add forwarded tags to the Record Notice messages
		for tagName, tagValue in pairs(msg) do
			-- Tags beginning with "X-" are forwarded
			if string.sub(tagName, 1, 2) == "X-" then
				recordNotice[tagName] = tagValue
			end
		end

		-- Send Record-Notice
		ao.send(recordNotice)
	end)

Handlers.add(ARNSCoreSpecActionMap.Records, Handlers.utils.hasMatchingTag("Action", ARNSCoreSpecActionMap.Records),
	function(msg)
		local records = records.getRecords()

		-- Credit-Notice message template, that is sent to the Recipient of the transfer
		local recordsNotice = {
			Target = msg.From,
			Action = "Records-Notice",
			Data = records,
		}

		-- Add forwarded tags to the Records Notice messages
		for tagName, tagValue in pairs(msg) do
			-- Tags beginning with "X-" are forwarded
			if string.sub(tagName, 1, 2) == "X-" then
				recordsNotice[tagName] = tagValue
			end
		end

		-- Send Records-Notice
		ao.send(recordsNotice)
	end)

Handlers.add(ARNSCoreSpecActionMap.State, Handlers.utils.hasMatchingTag("Action", ARNSCoreSpecActionMap.State),
	function(msg)
		local state = {
			Records = Records,
			Owner = Owner,
		}

		-- Add forwarded tags to the State Notice messages
		for tagName, tagValue in pairs(msg) do
			-- Tags beginning with "X-" are forwarded
			if string.sub(tagName, 1, 2) == "X-" then
				state[tagName] = tagValue
			end
		end

		-- Send State-Notice
		ao.send({ Target = msg.From, Action = "State-Notice", Data = json.encode(state) })
	end)
