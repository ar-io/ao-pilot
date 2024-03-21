-- arns-experiment-1
local json = require('json')
local base64 = require(".base64")

-- Default configurations
Name = Name or 'ArNS-AO-Experiment'
Ticker = Ticker or 'ARNS-EXP-1'
Denomination = Denomination or 1
Logo = Logo or 'Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A'
LastArNSSyncTimestamp = LastArNSSyncTimestamp or 0

-- Initialize listeners for updates
Listeners = Listeners or {}

-- Constants
DEFAULT_UNDERNAME_COUNT = 10
DEADLINE_DURATION_MS = 60 * 60 * 1000 -- One hour of miliseconds

-- URL configurations
SW_CACHE_URL = "https://api.arns.app/v1/contract/"
ARNS_SW_CACHE_URL = "https://api.arns.app/v1/contract/bLAgYxAdX2Ry-nt6aH2ixgvJXbpsEYm28NgJgyqfs-U/records/"

-- Process IDs for interacting with other services or processes
_0RBIT_SEND_PROCESS_ID = "WSXUI2JjYUldJ7CKq9wE1MGwXs-ldzlUlHOQszwQe0s"
_0RBIT_RECEIVE_PROCESS_ID = "8aE3_6NJ_MU_q3fbhz2S6dA8PKQOSCe95Gt7suQ3j7U"
TOKEN_PROCESS_ID = 'gAC5hpUPh1v-oPJLnK3Km6-atrYlvI271bI-q0yZOnw'

-- Initialize the Records table with default values if it's not already set
if not Records then
    Records = {}

    Records["test-ao-process"] = {
        contractTxId = "gh673M0Koh941OIITVXl9hKabRaYWABQUedZxW-swIA",
        processId = "YRK5D_VjPxhMRoCuC1jZNovUe5lZOiSLW74zU5MNMK8",
        endTimestamp = 1711122739,
        startTimestamp = 1694101828,
        type = "lease",
        undernames = 100
    }

    Records["claim-this"] = {
        contractTxId = "2UREsZfvie2MMBCfA_YgxWl8ucybRjfYnc8H3SeZ2b8",
        processId = "YRK5D_VjPxhMRoCuC1jZNovUe5lZOiSLW74zU5MNMK8",
        endTimestamp = 1711122739,
        startTimestamp = 1694101828,
        type = "lease",
        undernames = 100
    }
end

-- Initialize Auctions, Fees, DemandFactoring, RecordUpdates, RecordSyncRequests, and Credits tables
if not Auctions then
    Auctions = {}
end

if not Fees then
    Fees = {
        [1] = 5000000,
        [2] = 500000,
        [3] = 100000,
        [4] = 25000,
        [5] = 10000,
        [6] = 5000,
        [7] = 2500,
        [8] = 1500,
        [9] = 1250,
        [10] = 1250,
        [11] = 1250,
        [12] = 1250,
        [13] = 1000,
        [14] = 1000,
        [15] = 1000,
        [16] = 1000,
        [17] = 1000,
        [18] = 1000,
        [19] = 1000,
        [20] = 1000,
        [21] = 1000,
        [22] = 1000,
        [23] = 1000,
        [24] = 1000,
        [25] = 1000,
        [26] = 1000,
        [27] = 1000,
        [28] = 1000,
        [29] = 1000,
        [30] = 1000,
        [31] = 1000,
        [32] = 1000,
        [33] = 1000,
        [34] = 1000,
        [35] = 1000,
        [36] = 1000,
        [37] = 1000,
        [38] = 1000,
        [39] = 1000,
        [40] = 1000,
        [41] = 1000,
        [42] = 1000,
        [43] = 1000,
        [44] = 1000,
        [45] = 1000,
        [46] = 1000,
        [47] = 1000,
        [48] = 1000,
        [49] = 1000,
        [50] = 1000,
        [51] = 1000
    }
end

if not DemandFactoring then
    DemandFactoring = {
        consecutivePeriodsWithMinDemandFactor = 0,
        currentPeriod = 106,
        demandFactor = 0.6310005898072405,
        periodZeroBlockHeight = 1306341,
        purchasesThisPeriod = 0,
        revenueThisPeriod = 0,
        trailingPeriodPurchases = { 1, 0, 4, 0, 0, 0, 4 },
        trailingPeriodRevenues = { 1941.5402763299708, 0, 8200.407359278961, 0, 0, 0, 16456.865199368323 }
    }
end

if not RecordUpdates then
    RecordUpdates = {}
end

if not RecordSyncRequests then
    RecordSyncRequests = {}
end

-- Setup the default empty credit balances
if not Credits then
    Credits = {}
end

--- Validates the fields of a 'buy record' message for compliance with expected formats and value ranges.
-- This function checks the following fields in the message:
-- 1. 'name' - Required and must be a string matching specific naming conventions.
-- 2. 'contractTxId' - Optional, must match a predefined pattern (including a special case 'atomic' or a standard 43-character base64url string).
-- 3. 'years' - Optional, must be an integer between 1 and 5.
-- 4. 'type' - Optional, must be either 'lease' or 'permabuy'.
-- 5. 'auction' - Optional, must be a boolean value.
-- @param msg The message table containing the Tags field with all necessary data.
-- @return boolean, string First return value indicates whether the message is valid (true) or not (false),
--                         and the second return value provides an error message in case of validation failure.
function validateBuyRecord(msg)
    -- Validate the presence and type of the 'name' field
    if not msg.Tags.name or type(msg.Tags.name) ~= "string" then
        return false, "name is required and must be a string."
    end

    -- Validate the pattern of the 'name' field to ensure it follows specific naming conventions
    if not string.match(msg.Tags.name, "^([a-zA-Z0-9][a-zA-Z0-9-]{0,49}[a-zA-Z0-9]|[a-zA-Z0-9]{1})$") then
        return false, "name pattern is invalid."
    end

    -- If 'contractTxId' is present, validate its pattern to match expected formats
    -- This includes a check for a special case 'atomic' or a 43 character base64url string
    if msg.Tags.contractTxId and not string.match(msg.Tags.contractTxId, "^(atomic|[a-zA-Z0-9-_]{43})$") then
        return false, "contractTxId pattern is invalid."
    end

    -- If 'years' is present, validate it as an integer between 1 and 5
    if msg.Tags.years then
        if type(msg.Tags.years) ~= "number" or msg.Tags.years % 1 ~= 0 or msg.Tags.years < 1 or msg.Tags.years > 5 then
            return false, "years must be an integer between 1 and 5."
        end
    end

    -- Validate 'type' field if present, ensuring it is either 'lease' or 'permabuy'
    if msg.Tags.type and not string.match(msg.Tags.type, "^(lease|permabuy)$") then
        return false, "type pattern is invalid."
    end

    -- Validate the 'auction' field if present, ensuring it is a boolean value
    if msg.Tags.auction and type(msg.Tags.auction) ~= "boolean" then
        return false, "auction must be a boolean."
    end

    -- If all validations pass, return true with an empty message indicating success
    return true, ""
end

--- Counts the number of entries in a Lua table.
-- This function iterates over all key-value pairs in the provided table and returns the total number of entries. It is useful for tables
-- where the keys are not necessarily continuous integers, which means #table or table.getn() might not return the expected count.
-- @param table The table for which the entry count is to be determined.
-- @return number The total number of entries (key-value pairs) in the table.
function tableCount(table)
    local count = 0
    for _ in pairs(table) do count = count + 1 end
    return count
end

--- Requests JSON data from a specified URL via the Orbit process, an external service.
-- @param url The URL from which JSON data is to be fetched.
function fetchJsonDataFromOrbit(url)
    -- Validate URL to prevent sending invalid requests
    if type(url) ~= "string" or url == "" then
        print("Invalid URL provided for fetching JSON data.")
        return
    end
    print("Getting orbit data from: " .. url)
    -- Send a request to the Orbit process with the specified URL.
    ao.send({ Target = _0RBIT_SEND_PROCESS_ID, Action = "Get-Real-Data", Url = url })
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

--- Responds to an 'Info' action request with process details.
-- This handler is triggered by messages tagged with the 'Action' of 'Info'.
-- It sends back a message containing key details about the process, such as its name,
-- ticker symbol, logo, process owner, denomination, last ArNS sync timestamp and the number of names registered.
-- This can be used by clients or other processes to retrieve metadata about this process.
-- @param msg The incoming message that triggered the handler.
Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
    ao.send(
        { Target = msg.From, Tags = { Name = Name, Ticker = Ticker, Logo = Logo, ProcessOwner = Owner, Denomination = tostring(Denomination), LastArNSSyncTimestamp = tostring(LastArNSSyncTimestamp), NamesRegistered = tableCount(Records) } })
end)

--- Responds to a 'Get-Fees' action request by providing the fee structure.
-- This handler is activated when a message with the 'Action' tag set to 'Get-Fees' is received.
-- It sends back the process's current fee structure encoded in JSON format.
-- The fee structure is predefined in the 'Fees' table.
-- @param msg The incoming message that triggered the handler, expected to contain the sender's information in 'msg.From'.
Handlers.add('getFees', Handlers.utils.hasMatchingTag('Action', 'Get-Fees'),
    function(msg)
        -- Encode the Fees table into a JSON string and send it to the requester.
        local feesJson, err = json.encode(Fees)
        if not feesJson then
            print("Error encoding fees: ", err)
            -- Consider handling the error more gracefully, potentially notifying the requester of the issue.
            return
        end

        ao.send({
            Target = msg.From,
            Tags = { Action = 'Fees-Response' },
            Data = feesJson
        })
    end)

--- Responds to a 'Get-All-Credits' action request with the entire credits balance information.
-- This handler is triggered when a message with the 'Action' tag of 'Get-All-Credits' is received.
-- It sends back a JSON-encoded representation of all user credit balances stored in the 'Credits' table.
-- @param msg The incoming message that triggered the handler, expected to contain the sender's information in 'msg.From'.
Handlers.add('getAllCredits', Handlers.utils.hasMatchingTag('Action', 'Get-All-Credits'),
    function(msg)
        -- Attempt to encode the 'Credits' table to a JSON string.
        local creditsJson, err = json.encode(Credits)
        if not creditsJson then
            -- Log an error if encoding fails and consider how to handle this failure more gracefully.
            print("Error encoding credits: ", err)
            return
        end

        -- Send the encoded credits information back to the requester.
        ao.send({
            Target = msg.From,
            Tags = { Action = 'All-Credits-Response' },
            Data = creditsJson
        })
    end)

--- Responds to a 'Get-Credits' action request by providing the credit balance for a specified target or the sender.
-- This handler is triggered by messages tagged with the 'Action' of 'Get-Credits'.
-- It checks if a specific target is mentioned and returns that target's credit balance. If no target is specified,
-- it returns the sender's credit balance. The balance is sent back in both the Tags and as encoded JSON data.
-- @param msg The incoming message that triggered the handler, containing 'msg.From' and optionally 'msg.Tags.Target'.
Handlers.add('getCredits', Handlers.utils.hasMatchingTag('Action', 'Get-Credits'), function(msg)
    local credits = '0' -- Default credit balance to '0'

    -- Check if a target is specified and has a credit balance; otherwise, use the sender's balance.
    if msg.Tags.Target and Credits[msg.Tags.Target] then
        credits = tostring(Credits[msg.Tags.Target])
    elseif Credits[msg.From] then
        credits = tostring(Credits[msg.From]) -- Fixed incorrect function call to proper assignment.
    end

    -- Send the credit balance back to the sender, including it in both Tags and Data for flexibility.
    ao.send({
        Target = msg.From,
        Tags = { Target = msg.From, Credits = credits, Ticker = Ticker }, -- Assuming Ticker is a global variable defined elsewhere.
        Data = json.encode({ Credits = tonumber(credits) })
    })
end)


--- Responds to 'Get-Record' action requests by providing details of a specified record.
-- When triggered by a message tagged with 'Action' of 'Get-Record', this handler checks if the requested
-- record name exists in the 'Records' table. If found, it sends back record details, including its
-- contract transaction ID and process ID, encoded in JSON format. Otherwise, it reports an error indicating the requested record does not exist.
-- @param msg The incoming message that triggered the handler, expected to contain 'msg.Tags.Name'.
Handlers.add('getRecord', Handlers.utils.hasMatchingTag('Action', 'Get-Record'), function(msg)
    -- Ensure the 'Name' tag is present and the record exists before proceeding.
    if msg.Tags.Name and Records[msg.Tags.Name] then
        -- Prepare and send a response with the found record's details.
        local recordDetails = Records[msg.Tags.Name]
        ao.send({
            Target = msg.From,
            Tags = {
                Action = 'Record-Resolved',
                Name = msg.Tags.Name,
                ContractTxId = recordDetails.ContractTxId,
                ProcessId = recordDetails.ProcessId
            },
            Data = json.encode(recordDetails)
        })
    else
        -- Send an error response if the record name is not provided or the record does not exist.
        ao.send({
            Target = msg.From,
            Tags = {
                Action = 'Get-Record-Error',
                ['Message-Id'] = msg.Id, -- Ensure message ID is passed for traceability.
                Error = 'Requested non-existent record'
            }
        })
    end
end)

Handlers.add('getRecords', Handlers.utils.hasMatchingTag('Action', 'Get-Records'),
    function(msg)
        ao.send({
            Action = 'Records-Resolved',
            Target = msg.From,
            Data =
                json.encode(Records)
        })
    end)

--- Initiates the loading of records from an Arweave transaction.
-- This handler is triggered by messages tagged with 'Action' of 'Initiate-Load-Records'.
-- It verifies if the request comes from the process owner (by comparing 'msg.From' and 'env.Process.Id').
-- If the request is valid, it sends a message to self to load data from the specified Arweave transaction ID.
-- Additionally, it acknowledges the initiation to the requester. If the request is invalid,
-- it sends an error response indicating the action is not being run by the process owner.
-- @param msg The incoming message containing 'ArweaveTxId' in its tags.
-- @param env The environment object containing process details, including its ID.
Handlers.add('initiateLoadRecords', Handlers.utils.hasMatchingTag('Action', 'Initiate-Load-Records'), function(msg, env)
    -- Ensure the Arweave transaction ID is provided and valid.
    assert(type(msg.Tags.ArweaveTxId) == 'string', 'Arweave Tx Id is required!')

    -- Check if the request is made by the process itself.
    if msg.From == env.Process.Id then
        -- Trigger the process to load data based on the provided Arweave transaction ID.
        ao.send({
            Target = env.Process.Id,
            Tags = { Action = 'Data', Load = msg.Tags.ArweaveTxId }
        })
        -- Acknowledge the initiation of the load operation.
        ao.send({
            Target = msg.From, -- This could essentially be the same as env.Process.Id in this context.
            Tags = { Action = 'Initiate-Load-Records-Received', Load = msg.Tags.ArweaveTxId }
        })
    else
        -- Respond with an error if the request does not come from the process owner.
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Initiate-Load-Records-Error', ['Message-Id'] = msg.Id, Error = 'Action not initiated by process owner.' }
        })
    end
end)

--- Processes and integrates received record data into the local Records table.
-- Triggered by messages tagged with 'Action' of 'Data', this handler decodes and merges JSON-encoded record data into the existing Records table.
-- It is specifically designed to update or add records based on data received, presumably after initiating a load
-- operation. It updates records if new data is received for an existing key or adds new
-- records otherwise. This handler is intended to be invoked by the process itself as a follow-up to a 'Load-Records' action.
-- @param msg The incoming message containing encoded record data.
-- @param env The environment object containing process details.
Handlers.add('dataNotice', Handlers.utils.hasMatchingTag('Action', 'Data'), function(msg, env)
    -- Ensure the message is sent by the process itself to avoid processing external data updates.
    if msg.From == env.Process.Id then
        -- Decode the base64 encoded JSON data contained within the message.
        local rawJsonData = base64.decode(msg.Data.Data)
        local data, err = json.decode(rawJsonData)

        if not data or err then
            print("Error decoding JSON data: ", err)
            return
        end

        local recordsAddedOrUpdated = 0 -- Counter for added or updated records.

        -- Iterate through the decoded data and update the Records table accordingly.
        for key, value in pairs(data.records or {}) do
            -- Check if the record either doesn't exist or differs from the new value.
            -- Additionally, preserve the existing processId if the record already exists.
            if not Records[key] then
                recordsAddedOrUpdated = recordsAddedOrUpdated + 1
                value.processId = value.processId or nil -- Initialize processId if new record.
                Records[key] = value
            elseif Records[key] and json.encode(Records[key]) ~= json.encode(value) then
                recordsAddedOrUpdated = recordsAddedOrUpdated + 1
                value.processId = Records[key].processId or value.processId -- Preserve existing processId.
                Records[key] = value
            end
        end

        -- Update the global sync timestamp
        LastArNSSyncTimestamp = msg.Timestamp

        -- Notify the process of the successful update.
        ao.send({
            Target = env.Process.Id,
            Tags = { Action = 'Loaded-Records', RecordsUpdated = tostring(recordsAddedOrUpdated) }
        })
    else
        -- Optionally handle or log unauthorized data notices.
        print("Unauthorized data update attempt detected from: ", msg.From)
    end
end)


--- Initiates the process of updating a record's associated process ID.
-- This handler is triggered by messages tagged with 'Action' of 'Initiate-Record-Update'.
-- It checks for existing update attempts on the same record and handles them according to their timestamps relative to a deadline.
-- If no recent attempt exists or if the previous attempt is past its deadline, it proceeds to initiate a new update by fetching the current
-- record owner details from an external source and logging the update attempt.
-- @param msg The incoming message containing the record name and the new process ID.
-- @param env The environment object containing process details.
Handlers.add('initiateRecordUpdate', Handlers.utils.hasMatchingTag('Action', 'Initiate-Record-Update'),
    function(msg)
        -- Validate required fields are present and correctly formatted.
        assert(type(msg.Tags.Name) == 'string', 'Name is required!')
        assert(type(msg.Tags.ProcessId) == 'string', 'Process ID is required!')

        -- Calculate deadline for update attempts.
        local deadline = msg.Timestamp - DEADLINE_DURATION_MS -- The response must come back within five minutes.

        -- Check for an existing update attempt that is still within its deadline.
        if RecordUpdates[msg.Tags.Name] and RecordUpdates[msg.Tags.Name].timeStamp >= deadline then
            ao.send({
                Target = msg.From,
                Tags = { Action = 'Already-Initiated', Name = msg.Tags.Name }
            })
        elseif RecordUpdates[msg.Tags.Name] and RecordUpdates[msg.Tags.Name].timeStamp < deadline then
            -- If an existing update attempt is past its deadline, notify the original requester and clear it.
            ao.send({
                Target = RecordUpdates[msg.Tags.Name].requestor,
                Tags = { Action = 'Record-Update-Cleaned', Name = msg.Tags.Name, ProcessId = RecordUpdates[msg.Tags.Name].processId, Deadline = tostring(deadline) }
            })
            RecordUpdates[msg.Tags.Name] = nil -- Clear past-due record update attempt.
        end

        -- Proceed with initiating a new update if the record exists.
        if Records[msg.Tags.Name] then
            if msg.From == Records[msg.Tags.Name].processId
                or (Records[msg.Tags.Name].contract and isControllerPresent(Records[msg.Tags.Name].contract.controllers, msg.From))
                or (Records[msg.Tags.Name].contract and Records[msg.Tags.Name].contract.owner == msg.From) then
                Records[msg.Tags.Name].processId = msg.Tags.ProcessId -- Update process ID.
                ao.send({
                    Target = msg.From,
                    Tags = { Action = 'Record-Update-Complete', Name = msg.Tags.Name }
                })
            else
                -- Valid update; modify Records accordingly and notify requester.
                local url = SW_CACHE_URL .. Records[msg.Tags.Name].contractTxId
                fetchJsonDataFromOrbit(url) -- Fetch current name owner data from an external source.

                -- Log the new update attempt.
                RecordUpdates[msg.Tags.Name] = {
                    name = msg.Tags.Name,
                    processId = msg.Tags.ProcessId,
                    url = url,
                    timeStamp = msg.Timestamp,
                    requestor = msg.From
                }

                -- Acknowledge the initiation of the update process to the requester.
                ao.send({
                    Target = msg.From,
                    Tags = { Action = 'Initiate-Record-Update-Notice', Name = msg.Tags.Name }
                })
            end
        else
            ao.send({
                Target = msg.From,
                Tags = {
                    Action = 'Update-Record-Error',
                    ['Message-Id'] = msg.Id, -- Ensure message ID is passed for traceability.
                    Error = 'Requested non-existent record'
                }
            })
        end
    end)

--- Initiates the process for syncing a single, new record name.
-- Triggered by messages tagged with 'Action' of 'Initiate-Record-Claim'.
-- It ensures no active sync attempts on the same record name are within a deadline.
-- For new syncs or syncs past their deadlines, it initiates a new claim process by fetching the current record details from an external source.
-- @param msg The incoming message containing the record name to claim.
Handlers.add('initiateRecordSync', Handlers.utils.hasMatchingTag('Action', 'Initiate-Record-Sync'),
    function(msg)
        -- Validate required fields are present and correctly formatted.
        assert(type(msg.Tags.Name) == 'string', 'Name is required!')

        -- Calculate deadline for claim attempts.
        local deadline = msg.Timestamp - DEADLINE_DURATION_MS -- The response must come back within five minutes.

        -- Check for an existing claim attempt that is still within its deadline.
        if RecordSyncRequests[msg.Tags.Name] and RecordSyncRequests[msg.Tags.Name].timeStamp >= deadline then
            ao.send({
                Target = msg.From,
                Tags = { Action = 'Already-Initiated-Record-Sync', Name = msg.Tags.Name }
            })
        elseif RecordSyncRequests[msg.Tags.Name] and RecordSyncRequests[msg.Tags.Name].timeStamp < deadline then
            -- If an existing claim attempt is past its deadline, notify the original requester and clear it.
            ao.send({
                Target = RecordSyncRequests[msg.Tags.Name].requestor,
                Tags = { Action = 'Record-Sync-Cleaned', Name = msg.Tags.Name, Deadline = tostring(deadline) }
            })
            RecordSyncRequests[msg.Tags.Name] = nil -- Clear past-due record claim attempt.
        elseif Records[msg.Tags.Name].contractId == nil then
            -- Proceed with initiating a new record sync if the record name does not exist.
            local url = ARNS_SW_CACHE_URL .. msg.Tags.Name
            fetchJsonDataFromOrbit(url) -- Fetch current record details from an external source.

            -- Log the new claim attempt.
            RecordSyncRequests[msg.Tags.Name] = {
                name = msg.Tags.Name,
                url = url,
                timeStamp = msg.Timestamp,
                requestor = msg.From
            }

            -- Acknowledge the initiation of the claim process to the requester.
            ao.send({
                Target = msg.From,
                Tags = { Action = 'Initiate-Record-Sync-Notice', Name = msg.Tags.Name }
            })
        else
            print('Record already exists')
        end
    end)

--- Handles the reception of a data feed, typically from an external process (Orbit in this cont..
-- @param msg The message containing the data feed, including record information.
-- @param env The environment object containing process details.
Handlers.add('receiveDataFeed', Handlers.utils.hasMatchingTag('Action', 'Receive-data-feed'), function(msg, env)
    print("Received Data...")
    if msg.From == _0RBIT_RECEIVE_PROCESS_ID then
        print("Data received from Orbit.")
        local data, err = json.decode(msg.Data)

        -- Check if there was an error in decoding the data.
        if err then
            print("Error decoding data: ", err)
            return
        end

        local deadline = tonumber(msg.Timestamp) - DEADLINE_DURATION_MS -- Deadline calculation for response timeliness.

        -- Process data for record sync requests.
        if data.name and RecordSyncRequests[data.name] then
            local claim = RecordSyncRequests[data.name]
            if claim.timeStamp >= deadline then
                -- Valid sync request; update Records and notify requester.
                Records[data.name] = data.record
                ao.send({
                    Target = claim.requestor,
                    Tags = { Action = 'Record-Sync-Complete', Name = data.name }
                })
            else
                -- Invalid sync request due to late timestamp
                ao.send({
                    Target = claim.requestor,
                    Tags = { Action = 'Record-Sync-Error', Name = data.name, Error = 'Data request was returned past the deadline.' }
                })
            end
            RecordSyncRequests[data.name] = nil -- Clear processed claim.
        end

        -- Process data for record updates.
        if data.contractTxId and RecordUpdates[data.contractTxId] then
            local update = RecordUpdates[data.contractTxId]
            if update.timeStamp >= deadline and (update.requestor == env.Process.Id or isControllerPresent(data.state.controllers, update.requestor)) then
                -- Valid update; modify Records accordingly and notify requester.
                if not Records[update.name] then Records[update.name] = {} end -- Ensure record exists.
                Records[update.name].processId = update.processId              -- Update process ID.
                ao.send({
                    Target = update.requestor,
                    Tags = { Action = 'Record-Update-Complete', Name = update.name }
                })
            else
                -- Invalid update due to ownership issues; notify requester.
                ao.send({
                    Target = update.requestor,
                    Tags = { Action = 'Record-Update-Error', Name = update.name, Error = 'Not ANT Owner or Controller!' }
                })
            end
            RecordUpdates[data.contractTxId] = nil -- Clear processed update.
        end
    else
        print("Unauthorized data feed received from: ", msg.From)
    end
end)

--- Processes a 'Credit-Notice' action to update user credits based on transactions.
-- This handler is triggered by messages with a 'Credit-Notice' tag originating from the TOKEN_PROCESS_ID.
-- It updates the credit balance for the sender specified in the message and sends a confirmation back.
-- @param msg The incoming message containing the credit transaction details.
Handlers.add('creditNotice', Handlers.utils.hasMatchingTag('Action', 'Credit-Notice'), function(msg, env)
    if msg.From == TOKEN_PROCESS_ID then
        -- Update or initialize the sender's credit balance
        Credits[msg.Tags.Sender] = (Credits[msg.Tags.Sender] or 0) + msg.Tags.Quantity
        -- Send Credit-Notice to the Recipient
        ao.send({
            Target = msg.Tags.Sender,
            Tags = { Action = 'Credit-Notice', Sender = msg.Tags.Sender, Quantity = tostring(msg.Tags.Quantity) }
        })
    end

    -- Ensure the message originates from the designated TOKEN_PROCESS_ID to authenticate the source.
    if msg.From == TOKEN_PROCESS_ID then
        -- Parse the quantity from the message as a number. Ensure it handles both string and number types gracefully.
        local quantity = tonumber(msg.Tags.Quantity) or 0

        -- Safely retrieve the current credits for the sender or initialize to 0 if not present.
        local currentCredits = Credits[msg.Tags.Sender] or 0

        -- Update the sender's credit balance with the new quantity.
        Credits[msg.Tags.Sender] = currentCredits + quantity

        -- Send a confirmation notice back to the sender with the updated credit quantity.
        -- This acts as an acknowledgment of the credit update.
        ao.send({
            Target = msg.Tags.Sender,
            Tags = { Action = 'Credit-Notice', Sender = msg.Tags.Sender, Quantity = tostring(Credits[msg.Tags.Sender]) }
        })
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

Handlers.add("Cron",
    function(msg) -- return m.Cron
        return msg.Action == "Cron"
    end,
    function(msg)
        local cache = json.encode(Records)
        for i = 1, #Listeners do
            local listener = Listeners[i]
            ao.send({ Target = listener, Action = "ARNS-Update", Data = cache })
        end
    end
)
