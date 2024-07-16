local json = require("json")

-- Constants
-- Used to determine when to require name resolution
ARNS_TTL_MS = 7 * 24 * 60 * 60 * 1000    -- 7 days hours by default
ARNS_RECORD_TTL_MS = 24 * 60 * 60 * 1000 -- 24 hours by default
ANT_PROCESS_TTL_MS = 24 * 60 * 60 * 1000 -- 24 hours by default
ANT_DATA_TTL_MS = 24 * 60 * 60 * 1000    -- 24 hours by default
ANT_OWNER_TTL_MS = 24 * 60 * 60 * 1000   -- 24 hours by default

-- Process IDs for interacting with other services or processes
AR_IO_DEVNET_PROCESS_ID = "GaQrvEMKBpkjofgnBi_B3IgIDmY_XYelVLB6GcRGrHc"
AR_IO_TESTNET_PROCESS_ID = "agYcCFJtrMG6cqMuZfskIkFTGvUPddICmtQSBIoPdiA"
AR_IO_PROCESS_ID = AR_IO_PROCESS_ID or AR_IO_TESTNET_PROCESS_ID

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

function countResolvedNames()
	local count = 0
	for name, record in pairs(NAMES) do
		if PROCESSES[NAMES[name].processId] and PROCESSES[NAMES[name].processId].state then
			count = count + 1
		end
	end
	return count
end

function countResolvedProcesses()
	local count = 0
	for processId, process in pairs(PROCESSES) do
		if process.state then
			count = count + 1
		end
	end
	return count
end

local arnsMeta = {
	__index = function(t, key)
		if key == "resolve" then
			return function(name)
				name = string.lower(name)
				local rootName, underName = splitIntoTwoNames(name)
				ao.send({ Target = AR_IO_PROCESS_ID, Action = "Record", Name = rootName })
				return "Looking up and resolving: " .. rootName
			end
		elseif key == "data" then
			return function(name)
				name = string.lower(name)
				local rootName, underName = splitIntoTwoNames(name)
				if NAMES[rootName] == nil then
					print("Cannot get data for name " ..
						rootName .. ", it has not been looked up and resolved yet.  Resolving now...")
					ao.send({ Target = AR_IO_PROCESS_ID, Action = "Record", Name = rootName })
					return nil
				elseif PROCESSES[NAMES[rootName].processId].state == nil then
					print("Cannot get data for name " .. name .. ", it has not been resolved yet.  Resolving now...")
					ao.send({ Target = AR_IO_PROCESS_ID, Action = "Record", Name = rootName })
				elseif rootName and underName == nil then
					if PROCESSES[NAMES[rootName].processId] and (PROCESSES[NAMES[rootName].processId].state.Records["@"] or PROCESSES[NAMES[rootName].processId].state.records["@"]) then
						if Now - PROCESSES[NAMES[rootName].processId].state.lastUpdated >= ANT_DATA_TTL_MS then
							print(name .. " is stale.  Refreshing name process now...")
							ao.send({ Target = AR_IO_PROCESS_ID, Action = "Record", Name = name })
							return nil
						else
							return PROCESSES[NAMES[rootName].processId].state.Records["@"].transactionId or
								PROCESSES[NAMES[rootName].processId].state.records["@"].transactionId
						end
					end
				elseif rootName and underName then
					if PROCESSES[NAMES[rootName].processId] then
						if PROCESSES[NAMES[rootName].processId].state.Records[underName] ~= nil then
							if Now - PROCESSES[NAMES[rootName].processId].state.lastUpdated >= ANT_DATA_TTL_MS then
								print(name .. " is stale.  Refreshing name process now...")
								ao.send({ Target = AR_IO_PROCESS_ID, Action = "Record", Name = rootName })
								return nil
							else
								return PROCESSES[NAMES[rootName].processId].state.Records[underName].transactionId or
									PROCESSES[NAMES[rootName].processId].state.records[underName].transactionId
							end
						else
							print(underName .. ' is not a valid undername in the name ' .. rootName)
							return nil
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
					print("Cannot get owner for name " ..
						rootName .. ", it has not been looked up and resolved yet.  Resolving now...")
					ao.send({ Target = AR_IO_PROCESS_ID, Action = "Record", Name = rootName })
					return nil
				elseif PROCESSES[NAMES[rootName].processId].state == nil then
					print("Cannot get owner for name " .. rootName .. ", it has not been resolved yet.  Resolving now...")
					ao.send({ Target = AR_IO_PROCESS_ID, Action = "Record", Name = rootName })
				elseif PROCESSES[NAMES[rootName].processId] and (PROCESSES[NAMES[rootName].processId].state.Owner or PROCESSES[NAMES[rootName].processId].state.owner) then
					if Now - PROCESSES[NAMES[rootName].processId].state.lastUpdated >= ANT_OWNER_TTL_MS then
						print(name .. " is stale.  Refreshing name process now...")
						ao.send({ Target = AR_IO_PROCESS_ID, Action = "Record", Name = name })
						return nil
					else
						return PROCESSES[NAMES[rootName].processId].state.Owner or
							PROCESSES[NAMES[rootName].processId].state.owner
					end
				else
					return nil
				end
			end
		elseif key == "acl" then
			return function(owner)
				if ACL[owner] == nil then
					print("This owner address does not own any registered ANTs.")
					return nil
				else
					local result = {}
					for processId, info in pairs(ACL[owner]) do
						if Now - info.lastUpdated < ARNS_TTL_MS then
							-- Include roles (owner or controller) in the returned data for clarity
							result[processId] = {
								processId = processId,
								lastUpdated = info.lastUpdated,
								isOwner = info.isOwner or false,
								isController = info.isController or false
							}
						else
							print(processId .. " data is stale. Refreshing process now...")
							ao.send({ Target = processId, Action = "State" }) -- Resend the state request to update the data
							-- Consider whether to immediately remove stale entries or wait for an update
							-- ACL[owner][processId] = nil  -- Uncomment to remove stale entries immediately
						end
					end
					return result
				end
			end
		elseif key == "process" then
			return function(name)
				name = string.lower(name)
				local rootName, underName = splitIntoTwoNames(name)
				if NAMES[rootName] == nil then
					print("Cannot get process id for name " ..
						rootName .. ", it has not been looked up and resolved yet.  Resolving now...")
					ao.send({ Target = AR_IO_PROCESS_ID, Action = "Record", Name = rootName })
					return nil
				elseif Now - NAMES[rootName].lastUpdated >= ARNS_RECORD_TTL_MS then
					if PROCESSES[NAMES[rootName].processId] == nil then
						PROCESSES[NAMES[rootName].processId] = {
							Names = {}
						}
						PROCESSES[NAMES[rootName].processId].Names[name] = true
					end
					print(rootName .. " is stale.  Refreshing name data now...")
					ao.send({ Target = AR_IO_PROCESS_ID, Action = "Record", Name = rootName })
					return nil
				else
					return NAMES[rootName].processId or nil
				end
			end
		elseif key == "record" then
			return function(name)
				name = string.lower(name)
				local rootName, underName = splitIntoTwoNames(name)
				if NAMES[rootName] == nil or PROCESSES[NAMES[rootName].processId].state == nil then
					print("Cannot get full record details for this name " ..
						rootName .. ", it has not been looked up and resolved yet.  Resolving now...")
					ao.send({ Target = AR_IO_PROCESS_ID, Action = "Record", Name = rootName })
					return nil
				elseif Now - NAMES[rootName].lastUpdated >= ARNS_RECORD_TTL_MS or Now - PROCESSES[NAMES[rootName].processId].state.lastUpdated >= ANT_PROCESS_TTL_MS then
					print(rootName .. " is stale.  Refreshing name data now...")
					ao.send({ Target = AR_IO_PROCESS_ID, Action = "Record", Name = rootName })
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
				if NAMES == {} or PROCESSES == {} then
					print("ArNS Records have not been resolved yet...")
					print("Looking up and resolving all Records from ArNS Registry: " ..
						AR_IO_PROCESS_ID .. "...this may take a while!")
					ao.send({ Target = AR_IO_PROCESS_ID, Action = "Records" })
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
				return "ArNS local cache cleared."
			end
		elseif key == "resolveAll" then
			return function()
				ao.send({ Target = AR_IO_PROCESS_ID, Action = "Paginated-Records", Limit = "50" })
				return "Looking up and resolving all Records from ArNS Registry: " ..
					AR_IO_PROCESS_ID .. "...this may take a while!"
			end
		elseif key == "count" then
			return function(type)
				type = string.lower(type)
				if type == 'resolvednames' then
					return countResolvedNames()
				elseif type == 'processes' then
					return countResolvedProcesses()
				elseif type == 'acl' then
					return countTableItems(ACL)
				elseif type == 'names' then
					local names = countTableItems(NAMES)
					return names
				elseif type == 'unresolvednames' then
					local unresolvedNames = countTableItems(NAMES) - countResolvedNames()
					return unresolvedNames
				elseif type == 'unresolvedprocesses' then
					local unresolvedProcesses = countTableItems(PROCESSES) - countResolvedProcesses()
					return unresolvedProcesses
				else
					return
					'Invalid type entered.  Can only count names, resolvednames, unresolvednames, processes, unresolvedprocesses and acl.'
				end
			end
		elseif key == "help" then
			return function()
				return [[
				ARNS Resolver Help:
				
				Available Commands:
				- resolve(name): Resolves the given ARNS name. Returns process details about the name.
				- resolveAll(): Resolves all names registered in the ARNS.
				- data(name): Retrieves specific data associated with the ARNS name or undername.
				- owner(name): Fetches the owner of the ARNS name.
				- acl(owner): Fetches all registered ANT processes associated with this owner.
				- process(name): Obtains the process ID associated with the ARNS name.
				- record(name): Gets the detailed record for the ARNS name.
				- clear(): Clears the local cache of names, processes and acls.
				- count(type): Returns the count of items.
					Valid types are 'names', 'processes', 'acl', 'unresolvednames', and 'unresolvedprocesses'.
				- help(): Displays this help message.
				
				Usage Examples:
				- ARNS.resolve("example.ar"): Resolves the ARNS name "example.ar".
				- ARNS.data("example.ar"): Gets data for "example.ar".
				- ARNS.owner("example.ar"): Finds the owner of "example.ar".
								]]
			end
		else
			return nil
		end
	end,
}

ARNS = setmetatable({}, arnsMeta)

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

Handlers.add("ReceiveArNSSingleRecordMessage", function(msg)
	return msg.From == AR_IO_PROCESS_ID and msg.Tags.Action == 'Record-Notice'
end, function(msg)
	local data, err = json.decode(msg.Data)
	if not data or err then
		print("Error decoding JSON data from ArNS Registry: ", err)
		return
	end

	if msg.Tags.Name then
		NAMES[msg.Tags.Name] = {
			lastUpdated = msg.Timestamp,
			processId = data.processId,
			type = data.type,
			startTimestamp = data.startTimestamp,
			purchasePrice = data.purchasePrice,
			undernameLimit = data.undernameLimit
		}
		if data.endTimestamp then
			NAMES[msg.Tags.Name].endTimestamp = data.endTimestamp
		end
		if data.processId then
			print('Resolving ' .. msg.Tags.Name .. ' to ANT: ' .. data.processId)
			if PROCESSES[data.processId] == nil then
				PROCESSES[data.processId] = { Names = {} }
			end
			PROCESSES[data.processId].Names[msg.Tags.Name] = true
			ao.send({ Target = data.processId, Action = "State" })
		end
	end
end)

Handlers.add("ReceiveArNSMultipleRecordsMessage", function(msg)
	return msg.From == AR_IO_PROCESS_ID and msg.Tags.Action == 'Records-Notice'
end, function(msg)
	local data, err = json.decode(msg.Data)
	if not data or err then
		print("Error decoding JSON data from ArNS Registry: ", err)
		return
	end

	local namesFetched = 0
	local totalNamesProcessed = #NAMES -- Assuming NAMES is storing all names processed so far

	for _, record in pairs(data.items) do
		local name = record.name
		NAMES[name] = {
			lastUpdated = msg.Timestamp,
			processId = record.processId,
			type = record.type,
			startTimestamp = record.startTimestamp,
			purchasePrice = record.purchasePrice,
			undernameLimit = record.undernameLimit,
			endTimestamp = record.endTimestamp
		}

		if not PROCESSES[record.processId] or PROCESSES[record.processId].state == nil or (PROCESSES[record.processId].state and (Now - (PROCESSES[record.processId].state.lastUpdated or 0) > ARNS_RECORD_TTL_MS)) then
			if not PROCESSES[record.processId] then
				PROCESSES[record.processId] = { Names = {} }
			end
			PROCESSES[record.processId].Names[name] = true
			ao.send({ Target = record.processId, Action = "State" })
			namesFetched = namesFetched + 1
			print('Resolving ' .. name .. ' to ANT: ' .. record.processId)
		else
			print(name .. " is up-to-date and does not require resolving.")
		end
	end

	print(string.format("%d names processed in this batch. %d names needed resolution and are being processed.",
		#data.items, namesFetched))

	-- Continue fetching more records if there are more pages
	if data.hasMore then
		print(string.format("Fetching more records from next page. Approximately %d items remaining.",
			data.totalItems - totalNamesProcessed))
		ao.send({
			Target = AR_IO_PROCESS_ID,
			Action = "Paginated-Records",
			Tags = {
				Cursor = data.nextCursor,
				Limit = tostring(data.limit),
				["Sort-By"] = data.sortBy,
				["Sort-Order"] = data.sortOrder
			}
		})
	else
		print("All records have been fetched. ")
	end
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

	local owner = state.Owner or state.owner -- Normalize the owner property case

	-- Update the owner state if it has changed
	if PROCESSES[msg.From] and PROCESSES[msg.From].state then
		local currentOwner = PROCESSES[msg.From].state.Owner or PROCESSES[msg.From].state.owner
		if currentOwner and currentOwner ~= owner then
			-- Remove the old owner from ACL if it exists
			if ACL[currentOwner] then
				ACL[currentOwner][msg.From] = nil
			end
		end
	end

	-- Update ACL for the new owner
	if not ACL[owner] then
		ACL[owner] = {}
	end
	ACL[owner][msg.From] = {
		lastUpdated = msg.Timestamp,
		isOwner = true
	}

	-- Handle Controllers
	if state.Controllers and #state.Controllers > 0 then
		for _, controller in ipairs(state.Controllers) do
			if not ACL[controller] then
				ACL[controller] = {}
			end
			-- Assign controller with reference to the ANT process it controls
			ACL[controller][msg.From] = {
				lastUpdated = msg.Timestamp,
				isController = true
			}
		end
	end

	-- Update local state record for the ANT process
	PROCESSES[msg.From] = PROCESSES[msg.From] or {}
	PROCESSES[msg.From].state = state
	PROCESSES[msg.From].state.lastUpdated = msg.Timestamp

	print("Resolved " ..
		(state.Ticker or "UNKNOWN TICKER") .. " with Process ID " .. msg.From .. " with the latest state.")
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

Handlers.add("UpdateACL", Handlers.utils.hasMatchingTag("Action", "Update-ACL"), function(msg)
	local processId = msg.Tags.ProcessId or (NAMES[msg.Tags.Name] and NAMES[msg.Tags.Name].processId) or msg.From

	-- Verify that the processId is a valid and active process
	if not PROCESSES[processId] then
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "Invalid-ACL-Update-Notice",
				["Message-Id"] = msg.Id,
				Error = "Invalid request: Process does not exist.",
			},
		})
		return
	end

	-- Allow the process to update itself or check if msg.From is an owner or controller
	if processId == msg.From or (ACL[msg.From] and ACL[msg.From][processId] and (ACL[msg.From][processId].isOwner or ACL[msg.From][processId].isController)) then
		print(processId .. " data was requested to be updated by " .. msg.From .. ". Refreshing process now...")
		ao.send({ Target = processId, Action = "State" }) -- Resend the state request to update the data
	else
		-- msg.From is not authorized to update the process
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "Invalid-ACL-Update-Notice",
				["Message-Id"] = msg.Id,
				Error =
				"Unauthorized access: You do not have owner or controller rights, nor are you the process itself.",
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

Handlers.add(
	"CronResolveAll",                             -- handler name
	Handlers.utils.hasMatchingTag("Action", "Cron"), -- handler pattern to identify cron message
	function()                                    -- handler task to execute on cron message
		ao.send({ Target = AR_IO_PROCESS_ID, Action = "Paginated-Records", Limit = "50" })
	end
)
