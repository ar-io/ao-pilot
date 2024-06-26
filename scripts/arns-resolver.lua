local json = require("json")

-- Constants
-- Used to determine when to require name resolution
ID_TTL_MS = 24 * 60 * 60 * 1000    -- 24 hours by default
DATA_TTL_MS = 24 * 60 * 60 * 1000  -- 24 hours by default
OWNER_TTL_MS = 24 * 60 * 60 * 1000 -- 24 hours by default

-- Process IDs for interacting with other services or processes
AR_IO_DEVNET_PROCESS_ID = "GaQrvEMKBpkjofgnBi_B3IgIDmY_XYelVLB6GcRGrHc"
AR_IO_TESTNET_PROCESS_ID = "agYcCFJtrMG6cqMuZfskIkFTGvUPddICmtQSBIoPdiA"
PROCESS_ID = PROCESS_ID or AR_IO_DEVNET_PROCESS_ID

-- Initialize the NAMES and ID_NAME_MAPPING tables
NAMES = NAMES or {}
PROCESSES = PROCESSES or {}
ACL = ACL or {}
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

function countTableItems(tbl)
	local count = 0
	for _ in pairs(tbl) do
		count = count + 1
	end
	return count
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
					if PROCESSES[NAMES[rootName].processId] and (PROCESSES[NAMES[rootName].processId].state.Records["@"] or PROCESSES[NAMES[rootName].processId].state.records["@"]) then
						if Now - PROCESSES[NAMES[rootName].processId].state.lastUpdated >= DATA_TTL_MS then
							ao.send({ Target = PROCESS_ID, Action = "Record", Name = name })
							print(name .. " is stale.  Refreshing name process now...")
							return nil
						else
							return PROCESSES[NAMES[rootName].processId].state.Records["@"].transactionId or
								PROCESSES[NAMES[rootName].processId].state.records["@"].transactionId
						end
					end
				elseif rootName and underName then
					if PROCESSES[NAMES[rootName].processId] and (PROCESSES[NAMES[rootName].processId].state.Records[underName] or PROCESSES[NAMES[rootName].processId].state.records[underName]) then
						if Now - PROCESSES[NAMES[rootName].processId].lastUpdated >= DATA_TTL_MS then
							ao.send({ Target = PROCESS_ID, Action = "Record", Name = name })
							print(name .. " is stale.  Refreshing name process now...")
							return nil
						else
							return PROCESSES[NAMES[rootName].processId].Records[underName].transactionId or
								PROCESSES[NAMES[rootName].processId].records[underName].transactionId
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
				elseif PROCESSES[NAMES[rootName].processId] and (PROCESSES[NAMES[rootName].processId].state.Owner or PROCESSES[NAMES[rootName].processId].state.owner) then
					if Now - PROCESSES[NAMES[rootName].processId].state.lastUpdated >= OWNER_TTL_MS then
						ao.send({ Target = PROCESS_ID, Action = "Record", Name = name })
						print(name .. " is stale.  Refreshing name process now...")
						return nil
					else
						return PROCESSES[NAMES[rootName].processId].state.Owner or
							PROCESSES[NAMES[rootName].processId].state.owner
					end
				else
					return nil
				end
			end
		elseif key == "process" then
			return function(name)
				name = string.lower(name)
				local rootName, underName = splitIntoTwoNames(name)
				if NAMES[rootName] == nil then
					ao.send({ Target = PROCESS_ID, Action = "Record", Name = name })
					print(name .. " has not been resolved yet.  Cannot get process id.  Resolving now...")
					return nil
				elseif Now - NAMES[rootName].lastUpdated >= ID_TTL_MS then
					ao.send({ Target = PROCESS_ID, Action = "Record", Name = name })
					print(name .. " is stale.  Refreshing name data now...")
					return nil
				else
					return NAMES[rootName].processId or nil
				end
			end
		elseif key == "record" then
			return function(name)
				name = string.lower(name)
				local rootName, underName = splitIntoTwoNames(name)
				if NAMES[rootName] == nil and PROCESSES[NAMES[rootName].processId].state == nil then
					ao.send({ Target = PROCESS_ID, Action = "Record", Name = name })
					print(name .. " has not been resolved yet.  Cannot get process id.  Resolving now...")
					return nil
				elseif Now - NAMES[rootName].lastUpdated >= ID_TTL_MS or Now - PROCESSES[NAMES[rootName].processId].state.lastUpdated >= ID_TTL_MS then
					ao.send({ Target = PROCESS_ID, Action = "Record", Name = name })
					print(name .. " is stale.  Refreshing name data now...")
					return nil
				else
					local record = NAMES[rootName]
					record.state = PROCESSES[NAMES[rootName].processId].state or
						PROCESSES[NAMES[rootName].processId].State
					return record or nil
				end
			end
		elseif key == "records" then
			return function()
				if NAMES == nil or PROCESSES == nil then
					ao.send({ Target = PROCESS_ID, Action = "Records" })
					print("ArNS Records have not been resolved yet... Resolving now...")
					return nil
				else
					local records = {}
					for name, record in pairs(NAMES) do
						records[name] = NAMES[name]
						if PROCESSES[NAMES[name].processId].state ~= nil then
							records[name].state = PROCESSES[NAMES[name].processId].state
						end
					end
					return records or nil
				end
			end
		elseif key == "clear" then
			return function()
				NAMES = {}
				ACL = {}
				PROCESSES = {}
				return "ArNS local name cache cleared."
			end
		elseif key == "resolveAll" then
			return function()
				ao.send({ Target = PROCESS_ID, Action = "Records" })
				return "Getting entire ArNS registry"
			end
		elseif key == "count" then
			return function()
				return countTableItems(NAMES)
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
	if PROCESSES[msg.From] ~= nil and msg.Tags.Action == 'State-Notice' then
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
	local namesFetched = 0
	local antsResolved = 0

	if msg.Tags.Action == 'Record-Notice' and msg.Tags.Name ~= nil then
		NAMES[msg.Tags.Name] = {
			lastUpdated = msg.Timestamp,
			processId = data.processId,
			type = data.type,
			startTimestamp = data.startTimestamp,
			purchasePrice = data.purchasePrice,
			undernameLimit = data.undernameLimit
		}
		if data.endTimestamp ~= nil then
			NAMES[msg.Tags.Name].endTimestamp = data.endTimestamp
		end
		if data.processId then
			print('Resolving ' .. msg.Tags.Name .. ' to ANT: ' .. data.processId)
			namesFetched = namesFetched + 1
			if PROCESSES[data.processId] == nil then
				PROCESSES[data.processId] = {
					Names = {}
				}
			end
			PROCESSES[data.processId].Names[msg.Tags.Name] = true
			ao.send({ Target = data.processId, Action = "State" })
			antsResolved = antsResolved + 1
		end
	elseif msg.Tags.Action == 'Records-Notice' then
		for name, record in pairs(data) do
			-- TODO: CHECK FOR A NEW NAME
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
			if NAMES[name].processId then
				print('Resolving ' .. name .. ' to ANT: ' .. NAMES[name].processId)
				namesFetched = namesFetched + 1
				if PROCESSES[NAMES[name].processId] == nil then
					PROCESSES[NAMES[name].processId] = {
						Names = {}
					}
				end
				PROCESSES[NAMES[name].processId].Names[name] = true
			else
				print('Cant resolve ' .. name .. ' without an AO ANT Process ID')
			end
		end
		for processId, process in pairs(PROCESSES) do
			ao.send({ Target = processId, Action = "State" })
			antsResolved = antsResolved + 1
		end
	end
	print("Updated " .. antsResolved .. " ANTs across " .. namesFetched .. " names with the latest ArNS Registry info!")
end)

--- Updates stored information with the latest data from ANT-AO process "Info-Notice" messages.
-- @param msg The received message object containing updated process info.
Handlers.add("ReceiveANTProcessStateMessage", isANTStateMessage, function(msg)
	-- Attempt to decode the JSON data from the message.
	local state, err = json.decode(msg.Data)
	if err then
		print("Error decoding process info: ", err)
		return
	end

	local owner = state.owner or state.Owner

	if PROCESSES[msg.From] ~= nil and PROCESSES[msg.From].Owner ~= nil and PROCESSES[msg.From].Owner ~= owner then
		ACL[PROCESSES[msg.From].Owner][msg.From] = nil
	end
	if ACL[owner] == nil then
		ACL[owner] = {
			[msg.From] = msg.Timestamp
		}
	else
		ACL[owner][msg.From] = msg.Timestamp
	end
	PROCESSES[msg.From].state = state
	PROCESSES[msg.From].state.lastUpdated = msg.Timestamp

	print("Updated " .. msg.From .. " with the latest state.")
end)

Handlers.add("ACL", Handlers.utils.hasMatchingTag("Action", "ACL"), function(msg)
	if ACL[msg.Tags.Address] ~= nil then
		local ownedNames = {}
		for processId, lastUpdated in pairs(ACL[msg.Tags.Address]) do
			for name, process in pairs(PROCESSES[processId].Names) do
				ownedNames[name] = NAMES[name]
				ownedNames[name].state = PROCESSES[processId].state
			end
		end
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "ACL-Notice",
				Address = msg.Tags.Address,
			},
			Data = json.encode(ownedNames),
		})
	else
		-- Send an error response if the record name is not provided or the record does not exist.
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "Invalid-ACL-Notice",
				["Message-Id"] = msg.Id, -- Ensure message ID is passed for traceability.
				Error = "Requested non-existent Owner",
			},
		})
	end
end)

Handlers.add("Record", Handlers.utils.hasMatchingTag("Action", "Record"), function(msg)
	if NAMES[msg.Tags.Name] ~= nil and PROCESSES[NAMES[msg.Tags.Name].processId] ~= nil and PROCESSES[NAMES[msg.Tags.Name].processId].state ~= nil then
		local record = NAMES[msg.Tags.Name]
		record.state = PROCESSES[NAMES[msg.Tags.Name].processId].state
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "Record-Notice",
				Name = msg.Tags.Name,
			},
			Data = json.encode(record),
		})
	else
		-- Send an error response if the record name is not provided or the record does not exist.
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "Invalid-Record-Notice",
				["Message-Id"] = msg.Id, -- Ensure message ID is passed for traceability.
				Error = "Requested non-existent Record",
			},
		})
	end
end)

Handlers.add("Records", Handlers.utils.hasMatchingTag("Action", "Records"), function(msg)
	local records = {}
	for name, record in pairs(NAMES) do
		records[name] = NAMES[name]
		if PROCESSES[NAMES[name].processId] ~= nil then
			records[name].state = PROCESSES[NAMES[name].processId].state
		end
	end

	ao.send({
		Target = msg.From,
		Tags = {
			Action = "Records-Notice",
		},
		Data = json.encode(records),
	})
end)

Handlers.add("Process", Handlers.utils.hasMatchingTag("Action", "Process"), function(msg)
	if PROCESSES[msg.Tags.ProcessId] ~= nil and PROCESSES[msg.Tags.ProcessId].state ~= nil then
		local processNames = {}
		for name, process in pairs(PROCESSES[msg.Tags.ProcessId].Names) do
			processNames[name] = NAMES[name]
			processNames[name].state = PROCESSES[msg.Tags.ProcessId].state
		end
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "Process-Notice",
				ProcessId = msg.Tags.ProcessId,
			},
			Data = json.encode(processNames),
		})
	else
		-- Send an error response if the record name is not provided or the record does not exist.
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "Invalid-Process-Notice",
				["Message-Id"] = msg.Id, -- Ensure message ID is passed for traceability.
				Error = "Requested non-existent Process",
			},
		})
	end
end)

Handlers.add("Processes", Handlers.utils.hasMatchingTag("Action", "Processes"), function(msg)
	local processes = {}
	for processId, process in pairs(PROCESSES) do
		local processNames = {}
		for name, process in pairs(PROCESSES[processId].Names) do
			processNames[name] = NAMES[name]
			processNames[name].state = PROCESSES[processId].state
		end
		processes[processId] = processNames
	end
	ao.send({
		Target = msg.From,
		Tags = {
			Action = "Processes-Notice",
		},
		Data = json.encode(processes),
	})
end)
