-- gateway-network.lua: A process script for managing a network of gateways and their associated records.
local json = require("json")

-- Default configurations
Name = Name or "GAR-AO-Experiment"
Ticker = Ticker or "GAR-EXP-1"
Denomination = Denomination or 1
Logo = Logo or "Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A"
LastGARSyncTimestamp = LastGARSyncTimestamp or 0

-- Initialize listeners for updates
Listeners = Listeners or {}

-- Constants
DEFAULT_UNDERNAME_COUNT = 10
DEADLINE_DURATION_MS = 60 * 60 * 1000 -- One hour of miliseconds
MS_IN_A_YEAR = 31536000 * 1000
MIN_OPERATOR_STAKE = 10000 * 1000000 -- Ten thousand IO
MIN_DELEGATED_STAKE = 50 * 1000000 -- Fifty IO
JOINED_STATUS = "joined"

-- Three weeks, 7 days per week, 24 hours per day, sixty minutes per hour, sixty seconds per minute
MS_IN_GRACE_PERIOD = 3 * 7 * 24 * 60 * 60 * 1000

-- URL configurations
SW_CACHE_URL = "https://api.arns.app/v1/contract/"
ARNS_SW_CACHE_URL = "https://api.arns.app/v1/contract/bLAgYxAdX2Ry-nt6aH2ixgvJXbpsEYm28NgJgyqfs-U/records/"

-- Process IDs for interacting with other services or processes
TOKEN_PROCESS_ID = "gAC5hpUPh1v-oPJLnK3Km6-atrYlvI271bI-q0yZOnw"

-- Initialize the Records table with default values if it's not already set
if not Gateways then
	Gateways = {}
end

--- Counts the number of entries in a Lua table.
-- This function iterates over all key-value pairs in the provided table and returns the total number of entries. It is useful for tables
-- where the keys are not necessarily continuous integers, which means #table or table.getn() might not return the expected count.
-- @param table The table for which the entry count is to be determined.
-- @return number The total number of entries (key-value pairs) in the table.
function tableCount(table)
	local count = 0
	for _ in pairs(table) do
		count = count + 1
	end
	return count
end

--- Checks if a specified controller is present in a list of controllers.
-- This function iterates over a given table of controller identifiers and compares each
-- with a specified controller identifier. If a match is found, it returns true, indicating
-- the specified controller is present in the list. Otherwise, it returns false.
-- @param controllers A table of controller identifiers to search through.
-- @param controller The controller identifier to be checked for presence in the controllers table.
-- @return boolean Returns true if the specified controller is found in the controllers table; otherwise, returns false.
function isControllerPresent(controllers, controller)
	-- Validate input to ensure the 'controllers' parameter is a table.
	if type(controllers) ~= "table" then
		print("Invalid input: 'controllers' should be a table.")
		return false
	end

	-- Iterate through each controller id in the 'controllers' table.
	for _, id in ipairs(controllers) do
		-- Check if the current id matches the 'controller' parameter.
		if id == controller then
			return true -- Controller found, return true.
		end
	end
	return false -- No matching controller found, return false.
end

function ensureMilliseconds(timestamp)
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

-- TODO: we shouldn't need this and can instead use crons
function tick(currentTimestamp)
	-- tick records
	for key, record in pairs(Records) do
		if isExistingActiveRecord(record, currentTimestamp) == false then
			recordsTicked = recordsTicked + 1
			-- Remove the record that is expired TO DO
			-- Records[key] = nil
		end
	end
end

--- Responds to an 'Info' action request with process details.
-- This handler is triggered by messages tagged with the 'Action' of 'Info'.
-- It sends back a message containing key details about the process, such as its name,
-- ticker symbol, logo, process owner, denomination, last ArNS sync timestamp and the number of names registered.
-- This can be used by clients or other processes to retrieve metadata about this process.
-- @param msg The incoming message that triggered the handler.
Handlers.add("info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
	ao.send({
		Target = msg.From,
		Tags = {
			Name = Name,
			Ticker = Ticker,
			Logo = Logo,
			ProcessOwner = Owner,
			Denomination = tostring(Denomination),
			LastGARSyncTimestamp = tostring(LastGARSyncTimestamp),
			GatewaysRegistered = tostring(tableCount(Gateways)),
		},
	})
end)

Handlers.add("tick", Handlers.utils.hasMatchingTag("Action", "Tick"), function(msg)
	tick(msg.Timestamp)
	ao.send({
		Target = msg.From,
		Tags = { Action = "State-Ticked" },
	})
end)

Handlers.add("getGateway", Handlers.utils.hasMatchingTag("Action", "Get-Gateway"), function(msg)
	-- Ensure the 'Name' tag is present and the record exists before proceeding.
	if msg.Tags.Name and Records[msg.Tags.Name] then
		-- Prepare and send a response with the found record's details.
		local recordDetails = Records[msg.Tags.Name]
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "Record-Resolved",
				Name = msg.Tags.Name,
				ContractTxId = recordDetails.ContractTxId,
				ProcessId = recordDetails.ProcessId,
			},
			Data = json.encode(recordDetails),
		})
	else
		-- Send an error response if the record name is not provided or the record does not exist.
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "Get-Record-Error",
				["Message-Id"] = msg.Id, -- Ensure message ID is passed for traceability.
				Error = "Requested non-existent record",
			},
		})
	end
end)

Handlers.add("getGateways", Handlers.utils.hasMatchingTag("Action", "Get-Gateways"), function(msg)
	ao.send({
		Action = "Records-Resolved",
		Target = msg.From,
		Data = json.encode(Records),
	})
end)

Handlers.add("creditNotice", Handlers.utils.hasMatchingTag("Action", "Credit-Notice"), function(msg)
	-- Ensure the message originates from the designated TOKEN_PROCESS_ID to authenticate the source.
	if msg.From == TOKEN_PROCESS_ID then
		-- Tick the state before going further
		tick(msg.Timestamp)
		if msg.Tags.Function and msg.Tags.Parameters then
			local quantity = tonumber(msg.Tags.Quantity) or 0
			local parameters = json.decode(msg.Tags.Parameters)

			if msg.Tags.Function == "joinNetwork" and parameters.name and parameters.processId then
				local name = string.lower(parameters.name)
				local validRecord, validRecordErr = validateBuyRecord(parameters)
				if validRecord == false then
					print("Error for name: " .. name)
					print(validRecordErr)
					ao.send({
						Target = msg.Tags.Sender,
						Tags = {
							Action = "ArNS-Invalid-Record-Notice",
							Sender = msg.Tags.Sender,
							Name = tostring(parameters.name),
							ProcessId = tostring(parameters.processId),
						},
					})
					-- Send the tokens back
					ao.send({
						Target = TOKEN_PROCESS_ID,
						Tags = {
							Action = "Transfer",
							Recipient = msg.Tags.Sender,
							Quantity = tostring(msg.Tags.Quantity),
						},
					})
					return
				end

				local namePrice = getNamePrice(name)
				if namePrice > quantity then
					print("Not enough tokens for this name")
					ao.send({
						Target = msg.Tags.Sender,
						Tags = {
							Action = "ArNS-Insufficient-Funds",
							Sender = msg.Tags.Sender,
							Name = tostring(parameters.name),
							ProcessId = tostring(parameters.processId),
						},
					})
					-- Send the tokens back
					ao.send({
						Target = TOKEN_PROCESS_ID,
						Tags = {
							Action = "Transfer",
							Recipient = msg.Tags.Sender,
							Quantity = tostring(msg.Tags.Quantity),
						},
					})
					return
				end

				if Records[parameters.name] then
					-- Notify the original purchaser
					print("Name is already taken")
					ao.send({
						Target = msg.Tags.Sender,
						Tags = {
							Action = "ArNS-Deny-Notice",
							Sender = msg.Tags.Sender,
							Name = tostring(parameters.name),
							ProcessId = tostring(parameters.processId),
						},
					})
					-- Send the tokens back
					ao.send({
						Target = TOKEN_PROCESS_ID,
						Tags = {
							Action = "Transfer",
							Recipient = msg.Tags.Sender,
							Quantity = tostring(msg.Tags.Quantity),
						},
					})
				else
					print("This name is available for purchase!")

					Records[name] = {
						processId = parameters.processId,
						endTimestamp = msg.Timestamp + MS_IN_A_YEAR, -- One year lease only
						startTimestamp = msg.Timestamp,
						type = "lease",
						undernames = 10,
					}

					print("Added record: " .. name)

					-- Check if any remaining balance to send back
					local remainingQuantity = quantity - namePrice
					if remainingQuantity > 1 then
						-- Send the tokens back
						ao.send({
							Target = TOKEN_PROCESS_ID,
							Tags = {
								Action = "Transfer",
								Recipient = msg.Tags.Sender,
								Quantity = tostring(remainingQuantity),
							},
						})
						ao.send({
							Target = msg.Tags.Sender,
							Tags = {
								Action = "ArNS-Purchase-Notice-Remainder",
								Sender = msg.Tags.Sender,
								Name = tostring(parameters.name),
								ProcessId = tostring(parameters.processId),
								Quantity = tostring(remainingQuantity),
							},
						})
					else
						ao.send({
							Target = msg.Tags.Sender,
							Tags = {
								Action = "ArNS-Purchase-Notice",
								Sender = msg.Tags.Sender,
								Name = tostring(parameters.name),
								ProcessId = tostring(parameters.processId),
							},
						})
					end
				end
			end
		end
	else
		-- Optional: Handle or log unauthorized credit notice attempts.
		print("Unauthorized Credit-Notice attempt detected from: ", msg.From)
	end
end)

Handlers.add("register", Handlers.utils.hasMatchingTag("Action", "Register"), function(msg)
	if Listeners[msg.From] then
		return
	end
	print("Registering " .. msg.From .. "for updates.")
	table.insert(Listeners, msg.From)
end)

Handlers.add("unregister", Handlers.utils.hasMatchingTag("Action", "Unregister"), function(msg)
	-- TODO: Check remove from table semantics
	print("Unregistering " .. msg.From .. "for updates.")
	Listeners[msg.From] = nil
end)

Handlers.add("Cron", function(msg) -- return m.Cron
	return msg.Action == "Cron"
end, function(msg)
	local cache = json.encode(Records)
	for i = 1, #Listeners do
		local listener = Listeners[i]
		ao.send({ Target = listener, Action = "ARNS-Update", Data = cache })
	end
end)
