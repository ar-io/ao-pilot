local json = require("json")

-- Constants
-- Used to determine when to require name resolution
ID_TTL_MS = 24 * 60 * 60 * 1000    -- 24 hours by default
DATA_TTL_MS = 24 * 60 * 60 * 1000  -- 24 hours by default
OWNER_TTL_MS = 24 * 60 * 60 * 1000 -- 24 hours by default

-- Process IDs for interacting with other services or processes
AR_IO_DEVNET_PROCESS_ID = "GaQrvEMKBpkjofgnBi_B3IgIDmY_XYelVLB6GcRGrHc"
AR_IO_TESTNET_PROCESS_ID = ""
PROCESS_ID = AR_IO_DEVNET_PROCESS_ID

-- Initialize the NAMES and ID_NAME_MAPPING tables
NAMES = NAMES or {}
Now = Now or 0

--- Splits a string into two parts based on the last underscore character, intended to separate ARNS names into undername and rootname components.
-- @param str The string to be split.
-- @return Two strings: the rootname (before the last underscore) and the undername (after the last underscore).
-- If no underscore is found, returns the original string and nil.
function splitIntoTwoNames(str)
	-- Pattern explanation:
	-- (.-) captures any character as few times as possible up to the last underscore
	-- _ captures the underscore itself
	-- ([^_]+)$ captures one or more characters that are not underscores at the end of the string
	local underName, rootName = str:match("(.-)_([^_]+)$")

	if underName and rootName then
		return tostring(rootName), tostring(underName)
	else
		-- If the pattern does not match (e.g., there's no underscore in the string),
		-- return the original string as the first chunk and nil as the second
		return str, nil
	end
end

local arnsMeta = {
	__index = function(t, key)
		if key == "resolve" then
			return function(name)
				name = string.lower(name)
				ao.send({ Target = PROCESS_ID, Action = "Record", Name = name })
				return "Getting information for name: " .. name
			end
		elseif key == "data" then
			return function(name)
				name = string.lower(name)
				local rootName, underName = splitIntoTwoNames(name)
				if NAMES[rootName] == nil then
					ao.send({ Target = PROCESS_ID, Action = "Record", Name = rootName })
					print(name .. " has not been resolved yet.  Resolving now...")
					return nil
				elseif rootName and underName == nil then
					if NAMES[rootName].process and NAMES[rootName].process.records["@"] then
						if Now - NAMES[rootName].process.lastUpdated >= DATA_TTL_MS then
							ao.send({ Target = PROCESS_ID, Action = "Record", Name = name })
							print(name .. " is stale.  Refreshing name process now...")
							return nil
						else
							return NAMES[rootName].process.records["@"].transactionId
						end
					elseif NAMES[rootName].contract and NAMES[rootName].contract.records["@"] then
						if Now - NAMES[rootName].contract.lastUpdated >= DATA_TTL_MS then
							ao.send({ Target = PROCESS_ID, Action = "Record", Name = name })
							print(name .. " is stale.  Refreshing name contract now...")
							return nil
						else
							return NAMES[rootName].contract.records["@"].transactionId
								or NAMES[rootName].contract.records["@"]
								or nil
							-- NAMES[rootName].contract.records['@'] is used to capture old ANT contracts
						end
					end
				elseif rootName and underName then
					if NAMES[rootName].process and NAMES[rootName].process.records[underName] then
						if Now - NAMES[rootName].process.lastUpdated >= DATA_TTL_MS then
							ao.send({ Target = PROCESS_ID, Action = "Record", Name = name })
							print(name .. " is stale.  Refreshing name process now...")
							return nil
						else
							return NAMES[rootName].process.records[underName].transactionId
						end
					elseif NAMES[rootName].contract and NAMES[rootName].contract.records[underName] then
						if Now - NAMES[rootName].contract.lastUpdated >= DATA_TTL_MS then
							ao.send({ Target = PROCESS_ID, Action = "Record", Name = name })
							print(name .. " is stale.  Refreshing name contract now...")
							return nil
						else
							return NAMES[rootName].contract.records[underName].transactionId
								or NAMES[rootName].contract.records[underName]
							-- NAMES[rootName].contract.records[underName] is used to capture old ANT contracts
						end
					else
						return nil
					end
				end
			end
		elseif key == "owner" then
			return function(name)
				name = string.lower(name)
				local rootName, underName = splitIntoTwoNames(name)
				if NAMES[rootName] == nil then
					ao.send({ Target = PROCESS_ID, Action = "Record", Name = rootName })
					print(name .. " has not been resolved yet.  Cannot get owner.  Resolving now...")
					return nil
				elseif NAMES[rootName].process and NAMES[rootName].process.owner then
					if Now - NAMES[rootName].process.lastUpdated >= OWNER_TTL_MS then
						ao.send({ Target = PROCESS_ID, Action = "Record", Name = name })
						print(name .. " is stale.  Refreshing name process now...")
						return nil
					else
						return NAMES[rootName].process.owner
					end
				elseif NAMES[rootName].contract and NAMES[rootName].contract.owner then
					if Now - NAMES[rootName].contract.lastUpdated >= OWNER_TTL_MS then
						ao.send({ Target = PROCESS_ID, Action = "Record", Name = name })
						print(name .. " is stale.  Refreshing name contract now...")
						return nil
					else
						return NAMES[rootName].contract.owner
					end
				else
					return nil
				end
			end
		elseif key == "id" then
			return function(name)
				name = string.lower(name)
				local rootName, underName = splitIntoTwoNames(name)
				if NAMES[rootName] == nil then
					ao.send({ Target = PROCESS_ID, Action = "Record", Name = name })
					print(name .. " has not been resolved yet.  Cannot get id.  Resolving now...")
					return nil
				elseif Now - NAMES[rootName].lastUpdated >= ID_TTL_MS then
					ao.send({ Target = PROCESS_ID, Action = "Record", Name = name })
					print(name .. " is stale.  Refreshing name data now...")
					return nil
				else
					return NAMES[rootName].processId or NAMES[rootName].contractTxId or nil
				end
			end
		elseif key == "clear" then
			NAMES = {}
			return "ArNS local name cache cleared."
		elseif key == "resolveAll" then
			return function()
				ao.send({ Target = PROCESS_ID, Action = "Records" })
				return "Getting entire ArNS registry"
			end
		else
			return nil
		end
	end,
}

ARNS = setmetatable({}, arnsMeta)

--- Determines if a given message is a record response from the ARNS process.
-- @param msg The message to evaluate.
-- @return boolean True if the message is from the ARNS process and action is 'Record-Resolved', otherwise false.
function isArNSGetRecordMessage(msg)
	if msg.From == PROCESS_ID and (msg.Tags.Action == 'Record-Notice' or msg.Tags.Action == 'Records-Notice') then
		return true
	else
		return false
	end
end

--- Determines if a message is an 'State' message from an ANT or related process.
-- Checks if the sender's ID exists within the ID_NAME_MAPPING.
-- @param msg The message object to check.
-- @return boolean True if the sender's ID is recognized, false otherwise.
function isANTStateMessage(msg)
	if msg.Tags.Action == 'State-Notice' then
		return true
	else
		return false
	end
end

Handlers.prepend("ArNS-Timers", function(msg)
	return "continue"
end, function(msg)
	Now = msg.Timestamp
end)

--- Handles received ArNS "Record-Resolved" messages by updating the local NAMES table.
-- Updates or initializes the record for the given name with the latest information.
-- Fetches additional information from SmartWeave Cache or ANT-AO process if necessary.
Handlers.add("ReceiveArNSGetRecordMessage", isArNSGetRecordMessage, function(msg)
	print("Received message from ArNS Registry")
	local data, err = json.decode(msg.Data)
	if not data or err then
		print("Error decoding JSON data: ", err)
		return
	end

	if msg.Tags.Action == 'Record-Notice' then
		print("Received a single Record response")
		-- Update or initialize the record with the latest information.
		--NAMES[msg.Tags.Name] = NAMES[msg.Tags.Name]
		--	or {
		--		lastUpdated = msg.Timestamp,
		--		contractTxId = data.contractTxId,
		--		-- Assuming these fields are placeholders for future updates.
		--		contractOwner = nil,
		--		contract = nil,
		--		processOwner = nil,
		--		process = nil,
		--	}
		--NAMES[msg.Tags.Name].processId = data.processId
		--NAMES[msg.Tags.Name].record = data
		--NAMES[msg.Tags.Name].lastUpdated = msg.Timestamp
	elseif msg.Tags.Action == 'Records-Notice' then
		print("Received multiple Records responses")
		for name, record in pairs(data) do
			NAMES[name] = {
				lastUpdated = msg.Timestamp,
				processId = record.processId,
				type = record.type,
				startTimestamp = record.startTimestamp,
				purchasePrice = record.purchasePrice,
				undernameLimit = record.undernameLimit
			}
			if record.endTimestamp ~= nil then
				NAMES[name].endTimestamp = record.endTimestamp
			end
			-- print('Resolving ' .. name .. ' to ANT: ' .. record.processId)
			if NAMES[name].processId then
				print('Resolving ' .. name .. ' to ANT: ' .. NAMES[name].processId)
				ao.send({ Target = NAMES[name].processId, ["X-Resolved-Name"] = name, Action = "State" })
			else
				print('Cant resolve ' .. name .. ' without an AO ANT Process ID')
			end
		end
	end
	print("Updated with the latest ArNS Registry info!")
end)

--- Updates stored information with the latest data from ANT-AO process "Info-Notice" messages.
-- @param msg The received message object containing updated process info.
Handlers.add("ReceiveANTProcessStateMessage", isANTStateMessage, function(msg)
	print('Got ANT State Notice from ANT ' .. msg.From)

	-- Attempt to decode the JSON data from the message.
	local state, err = json.decode(msg.Data)
	if err then
		print("Error decoding process info: ", err)
		return
	end

	-- Ensure it contains the X-Resolved-Name tag
	-- Ensure the registered process matches
	if ARNS[msg.Tags["X-Resolved-Name"]] ~= nil and msg.From ~= ARNS[msg.Tags["X-Resolved-Name"]].processId then
		print("Name resolution is not authorized")
	end

	local name = msg.Tags["X-Resolved-Name"]
	local updatedInfo = NAMES[name]

	-- Ensure the decoded data is a valid table before updating.
	if type(state) == "table" and type(state.records) == "table" then
		updatedInfo.process.Name = state.Name
		updatedInfo.process.Ticker = state.Ticker
		updatedInfo.process.Owner = state.Owner
		updatedInfo.process.Controllers = state.Controllers
		updatedInfo.process.Records = state.Records
		updatedInfo.process.lastUpdated = msg.Timestamp
		NAMES[name] = updatedInfo
		print("Updated " .. name .. " with the latest state from AO ANT " .. msg.From)
	else
		print("Invalid process info format received from " .. msg.From)
	end
end)
