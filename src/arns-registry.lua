-- arns-experiment-1
local json = require('json')

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
MS_IN_A_YEAR = 31536000 * 1000
PERMABUY_LEASE_FEE_LENGTH = 10
ANNUAL_PERCENTAGE_FEE = 0.2
ARNS_NAME_DOES_NOT_EXIST_MESSAGE = "Name does not exist in the ArNS Registry!"
ARNS_MAX_UNDERNAME_MESSAGE = "Name has reached undername limit of 10000"
MAX_ALLOWED_UNDERNAMES = 10000
UNDERNAME_LEASE_FEE_PERCENTAGE = 0.001
UNDERNAME_PERMABUY_FEE_PERCENTAGE = 0.005

-- Three weeks, 7 days per week, 24 hours per day, sixty minutes per hour, sixty seconds per minute
MS_IN_GRACE_PERIOD = 3 * 7 * 24 * 60 * 60 * 1000

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

--- Validates the fields of a 'buy record' message for compliance with expected formats and value ranges.
-- This function checks the following fields in the message:
-- 1. 'name' - Required and must be a string matching specific naming conventions.
-- 2. 'processId' - Optional, must match a predefined pattern (including a special case 'atomic' or a standard 43-character base64url string).
-- 3. 'years' - Optional, must be an integer between 1 and 5.
-- 4. 'type' - Optional, must be either 'lease' or 'permabuy'.
-- 5. 'auction' - Optional, must be a boolean value.
-- @param msg The message table containing the Tags field with all necessary data.
-- @return boolean, string First return value indicates whether the message is valid (true) or not (false),
-- and the second return value provides an error message in case of validation failure.
function validateBuyRecord(parameters)
    -- Validate the presence and type of the 'name' field
    if type(parameters.name) ~= "string" then
        return false, "name is required and must be a string."
    end

    -- Validate the character count 'name' field to ensure names 4 characters or below are excluded
    if string.len(parameters.name) <= 4 then
        return false, "1-4 character names are not allowed"
    end

    -- Validate the pattern of the 'name' field to ensure it follows specific naming conventions
    --if not string.match(tostring(parameters.name), "^([a-zA-Z0-9][a-zA-Z0-9-]{0,49}[a-zA-Z0-9]|[a-zA-Z0-9]{1})$") then
    --    return false, "name pattern is invalid."
    --end

    local name = tostring(parameters.name)
    local startsWithAlphanumeric = name:match("^%w")
    local endsWithAlphanumeric = name:match("%w$")
    local middleValid = name:match("^[%w-]+$")
    local validLength = #name >= 5 and #name <= 51

    if not (startsWithAlphanumeric and endsWithAlphanumeric and middleValid and validLength) then
        return false, "name pattern is invalid."
    end

    -- First, check for the 'atomic' special case.
    local processId = tostring(parameters.processId)
    local isAtomic = processId == "atomic"

    -- Then, check for a 43-character base64url pattern.
    -- The pattern checks for a string of length 43 containing alphanumeric characters, hyphens, or underscores.
    local isValidBase64Url = string.match(processId, "^[%w-_]+$") and #processId == 43

    if not isValidBase64Url and not isAtomic then
        return false, "processId pattern is invalid."
    end

    -- If 'years' is present, validate it as an integer between 1 and 5
    if parameters.years then
        if type(parameters.years) ~= "number" or parameters.years % 1 ~= 0 or parameters.years < 1 or parameters.years > 5 then
            return false, "years must be an integer between 1 and 5."
        end
    end

    -- Validate 'purchaseType' field if present, ensuring it is either 'lease' or 'permabuy'
    if parameters.purchaseType then
        if not (parameters.purchaseType == 'lease' or parameters.purchaseType == 'permabuy') then
            return false, "type pattern is invalid."
        end

        -- Do not allow permabuying names 11 characters or below for this experimentation period
        if parameters.purchaseType == 'permabuy' and string.len(parameters.name) <= 11 then
            return false, "cannot permabuy name 11 characters or below at this time"
        end
    end

    -- Validate the 'auction' field if present, ensuring it is a boolean value
    if parameters.auction then
        if type(parameters.auction) ~= "boolean" then
            return false, "auction must be a boolean."
        end
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

function calculateLeaseFee(name, years)
    -- Initial cost to register a name
    -- TODO: Harden the types here to make fees[name.length] an error
    local initialNamePurchaseFee = Fees[string.len(name)]

    -- total cost to purchase name (no demand factor)
    return (
        initialNamePurchaseFee +
        calculateAnnualRenewalFee(
            name,
            years
        )
    );
end

function calculateAnnualRenewalFee(name, years)
    -- Determine annual registration price of name
    local initialNamePurchaseFee = Fees[string.len(name)]

    -- Annual fee is specific % of initial purchase cost
    local nameAnnualRegistrationFee =
        initialNamePurchaseFee * ANNUAL_PERCENTAGE_FEE;

    local totalAnnualRenewalCost = nameAnnualRegistrationFee * years;

    return totalAnnualRenewalCost;
end

function calculatePermabuyFee(name)
    -- genesis price
    local initialNamePurchaseFee = Fees[string.len(name)]

    -- calculate the annual fee for the name for default of 10 years
    local permabuyPrice =
    --  No demand factor
        initialNamePurchaseFee +
        -- total renewal cost pegged to 10 years to purchase name
        calculateAnnualRenewalFee(
            name,
            PERMABUY_LEASE_FEE_LENGTH
        );
    return permabuyPrice
end

function calculateRegistrationFee(purchaseType, name, years)
    if purchaseType == 'lease' then
        return calculateLeaseFee(
            name,
            years
        );
    elseif purchaseType == 'permabuy' then
        return calculatePermabuyFee(
            name
        );
    end
end

function calculateUndernameCost(name, increaseQty, registrationType, years)
    local initialNameFee = Fees[string.len(name)] -- Get the fee based on the length of the name
    if initialNameFee == nil then
        -- Handle the case where there is no fee for the given name length
        return 0
    end

    local undernamePercentageFee = 0
    if registrationType == 'lease' then
        undernamePercentageFee = UNDERNAME_LEASE_FEE_PERCENTAGE
    elseif registrationType == 'permabuy' then
        undernamePercentageFee = UNDERNAME_PERMABUY_FEE_PERCENTAGE
    end

    local totalFeeForQtyAndYears = initialNameFee * undernamePercentageFee * increaseQty * years
    return totalFeeForQtyAndYears
end

function isLeaseRecord(record)
    return record.type == 'lease'
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

function isNameInGracePeriod(record, currentTimestamp)
    if not record or not record.endTimestamp then
        return false
    end -- if it has no timestamp, it is a permabuy
    if (ensureMilliseconds(record.endTimestamp) + MS_IN_GRACE_PERIOD) < currentTimestamp then
        return false
    end
    return true
end

function isExistingActiveRecord(record, currentTimestamp)
    if not record then return false end

    if not isLeaseRecord(record) then
        return true
    end

    if isNameInGracePeriod(record, currentTimestamp) then
        return true
    else
        return false
    end
end

function validateIncreaseUndernames(record, qty, currentTimestamp)
    if qty < 1 or qty > 9990 then
        return false, 'Qty is invalid'
    end

    if record == nil then
        return false, ARNS_NAME_DOES_NOT_EXIST_MESSAGE;
    end

    -- This name's lease has expired and cannot have undernames increased
    if not isExistingActiveRecord(record, currentTimestamp) then
        return false, "This name has expired and must renewed before its undername support can be extended."
    end

    -- the new total qty
    if record.undernames + qty > MAX_ALLOWED_UNDERNAMES then
        return false, ARNS_MAX_UNDERNAME_MESSAGE
    end

    return true, ""
end

function calculateYearsBetweenTimestamps(startTimestamp, endTimestamp)
    local yearsRemainingFloat =
        (endTimestamp - startTimestamp) / MS_IN_A_YEAR;
    return string.format("%.2f", yearsRemainingFloat)
end

function tick(currentTimestamp)
    -- tick records
    local recordsTicked = 0
    for key, record in pairs(Records) do
        if isExistingActiveRecord(record, currentTimestamp) == false then
            recordsTicked = recordsTicked + 1
            -- Remove the record that is expired TO DO
            -- Records[key] = nil
        end
    end
    return true
end

--- Responds to an 'Info' action request with process details.
-- This handler is triggered by messages tagged with the 'Action' of 'Info'.
-- It sends back a message containing key details about the process, such as its name,
-- ticker symbol, logo, process owner, denomination, last ArNS sync timestamp and the number of names registered.
-- This can be used by clients or other processes to retrieve metadata about this process.
-- @param msg The incoming message that triggered the handler.
Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
    ao.send(
        { Target = msg.From, Tags = { Name = Name, Ticker = Ticker, Logo = Logo, ProcessOwner = Owner, Denomination = tostring(Denomination), LastArNSSyncTimestamp = tostring(LastArNSSyncTimestamp), NamesRegistered = tostring(tableCount(Records)) } })
end)

Handlers.add('tick', Handlers.utils.hasMatchingTag('Action', 'Tick'), function(msg)
    tick(msg.Timestamp)
    ao.send({
        Target = msg.From,
        Tags = { Action = 'State-Ticked' }
    })
end)

--- Responds to a 'Get-Fees' action request by providing the fee structure.
-- This handler is activated when a message with the 'Action' tag set to 'Get-Fees' is received.
-- It sends back the process's current fee structure encoded in JSON format.
-- The fee structure is predefined in the 'Fees' table.
-- @param msg The incoming message that triggered the handler, expected to contain the sender's information in 'msg.From'.
Handlers.add('getFees', Handlers.utils.hasMatchingTag('Action', 'Get-Fees'), function(msg)
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

Handlers.add('getRecords', Handlers.utils.hasMatchingTag('Action', 'Get-Records'), function(msg)
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
Handlers.add('loadRecords', Handlers.utils.hasMatchingTag('Action', 'Load-Records'), function(msg, env)
    print("Received a message for loading records from " .. msg.From)

    -- Validate if the message is from the process owner to ensure that only authorized updates are processed.
    if msg.From ~= env.Process.Id and msg.From ~= Owner then
        print("Unauthorized data update attempt detected from: " .. msg.From)
        -- Sending an error notice back to the sender might be a security concern in some contexts, consider this based on your application's requirements.
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Load-Records-Error', Error = 'Unauthorized attempt detected' }
        })
        return
    end

    local data, err = json.decode(msg.Data)
    if not data or err then
        print("Error decoding JSON data: " .. err)
        -- Handle error (e.g., send an error response)
        return
    end

    -- Counter for added or updated records.
    local recordsAddedOrUpdated = 0

    -- Ensure 'data.records' is present and iterate through the decoded data to update the Records table accordingly.
    if type(data.records) == 'table' then
        for key, value in pairs(data.records) do
            -- Preserve the existing processId if the record already exists.
            local existingProcessId = Records[key] and Records[key].processId

            -- Check if the record either doesn't exist or differs from the new value.
            if not Records[key] or (Records[key] and json.encode(Records[key]) ~= json.encode(value)) then
                recordsAddedOrUpdated = recordsAddedOrUpdated + 1
                Records[key] = value
                Records[key].processId = existingProcessId or value.processId -- Preserve or initialize processId.
            end
        end

        -- Update the global sync timestamp to mark the latest successful update.
        LastArNSSyncTimestamp = msg.Timestamp

        -- Notify the process owner about the successful update.
        ao.send({
            Target = env.Process.Id,
            Tags = { Action = 'Loaded-Records', RecordsUpdated = tostring(recordsAddedOrUpdated) }
        })
    else
        -- Handle the case where 'data.records' is not in the expected format.
        print("The 'records' field is missing or not in the expected format.")
        print(data)
        -- Notify the process owner about the issue.
        ao.send({
            Target = env.Process.Id,
            Tags = { Action = 'Load-Records-Failure', Error = "'records' field missing or invalid" }
        })
    end
end)

--- Initiates the process of updating a record's associated process ID.
-- This handler is triggered by messages tagged with 'Action' of 'Initiate-Record-Update'.
-- It checks for existing update attempts on the same record and handles them according to their timestamps relative to a deadline.
-- If no recent attempt exists or if the previous attempt is past its deadline, it proceeds to initiate a new update by fetching the current
-- record owner details from an external source and logging the update attempt.
-- @param msg The incoming message containing the record name and the new process ID.
-- @param env The environment object containing process details.
Handlers.add('initiateRecordUpdate', Handlers.utils.hasMatchingTag('Action', 'Initiate-Record-Update'), function(msg)
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

            -- Log the new update attempt, using the contract tx id
            RecordUpdates[Records[msg.Tags.Name].contractTxId] = {
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
Handlers.add('initiateRecordSync', Handlers.utils.hasMatchingTag('Action', 'Initiate-Record-Sync'), function(msg)
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
    elseif Records[msg.Tags.Name].contractTxId == nil then
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
        print(data)
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
                Records[data.name].contract.owner = data.owner
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
        else

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
Handlers.add('creditNotice', Handlers.utils.hasMatchingTag('Action', 'Credit-Notice'), function(msg)
    -- Ensure the message originates from the designated TOKEN_PROCESS_ID to authenticate the source.
    if msg.From == TOKEN_PROCESS_ID then
        -- Tick the state before going further
        tick(msg.Timestamp)
        if msg.Tags.Function and msg.Tags.Parameters then
            local quantity = tonumber(msg.Tags.Quantity) or 0
            local parameters = json.decode(msg.Tags.Parameters)

            if msg.Tags.Function == 'buyRecord' and parameters.name and parameters.processId then
                local name = string.lower(parameters.name)
                local validRecord, validRecordErr = validateBuyRecord(parameters)
                if parameters.purchaseType == nil then
                    parameters.purchaseType = 'lease' -- set to lease by default
                end

                if parameters.years == nil then
                    parameters.years = 1 -- set to 1 year by default
                end

                if validRecord == false then
                    print("Error for name: " .. name)
                    print(validRecordErr)
                    ao.send({
                        Target = msg.Tags.Sender,
                        Tags = { Action = 'ArNS-Invalid-Record-Notice', Sender = msg.Tags.Sender, Name = tostring(parameters.name), ProcessId = tostring(parameters.processId) }
                    })
                    -- Send the tokens back
                    ao.send({
                        Target = TOKEN_PROCESS_ID,
                        Tags = { Action = 'Transfer', Recipient = msg.Tags.Sender, Quantity = tostring(msg.Tags.Quantity) }
                    })
                    return
                end

                local totalRegistrationFee = calculateRegistrationFee(parameters.purchaseType, name, parameters.years)
                if totalRegistrationFee > quantity then
                    print('Not enough tokens for this name')
                    ao.send({
                        Target = msg.Tags.Sender,
                        Tags = { Action = 'ArNS-Insufficient-Funds', Sender = msg.Tags.Sender, Name = tostring(parameters.name), ProcessId = tostring(parameters.processId) }
                    })
                    -- Send the tokens back
                    ao.send({
                        Target = TOKEN_PROCESS_ID,
                        Tags = { Action = 'Transfer', Recipient = msg.Tags.Sender, Quantity = tostring(msg.Tags.Quantity) }
                    })
                    return
                end

                if isExistingActiveRecord(Records[name], msg.Timestamp) then
                    -- Notify the original purchaser
                    print('Name is already taken')
                    ao.send({
                        Target = msg.Tags.Sender,
                        Tags = { Action = 'ArNS-Deny-Notice', Sender = msg.Tags.Sender, Name = tostring(parameters.name), ProcessId = tostring(parameters.processId) }
                    })
                    -- Send the tokens back
                    ao.send({
                        Target = TOKEN_PROCESS_ID,
                        Tags = { Action = 'Transfer', Recipient = msg.Tags.Sender, Quantity = tostring(msg.Tags.Quantity) }
                    })
                else
                    print('This name is available for purchase!')

                    if parameters.purchaseType == 'lease' then
                        Records[name] = {
                            processId = parameters.processId,
                            endTimestamp = msg.Timestamp + MS_IN_A_YEAR * parameters.years,
                            startTimestamp = msg.Timestamp,
                            type = "lease",
                            undernames = DEFAULT_UNDERNAME_COUNT,
                            purchasePrice = totalRegistrationFee
                        }
                    elseif parameters.purchaseType == 'permabuy' then
                        Records[name] = {
                            processId = parameters.processId,
                            startTimestamp = msg.Timestamp,
                            type = "permabuy",
                            undernames = DEFAULT_UNDERNAME_COUNT,
                            purchasePrice = totalRegistrationFee
                        }
                    end

                    print('Added record: ' .. name)

                    -- Check if any remaining balance to send back
                    local remainingQuantity = quantity - totalRegistrationFee
                    if remainingQuantity > 1 then
                        -- Send the tokens back
                        print('Sending back remaining tokens: ' .. remainingQuantity)
                        ao.send({
                            Target = TOKEN_PROCESS_ID,
                            Tags = { Action = 'Transfer', Recipient = msg.Tags.Sender, Quantity = tostring(remainingQuantity) }
                        })
                        ao.send({
                            Target = msg.Tags.Sender,
                            Tags = { Action = 'ArNS-Purchase-Notice-Remainder', Sender = msg.Tags.Sender, Name = tostring(parameters.name), ProcessId = tostring(parameters.processId), Quantity = tostring(remainingQuantity) }
                        })
                    else
                        ao.send({
                            Target = msg.Tags.Sender,
                            Tags = { Action = 'ArNS-Purchase-Notice', Sender = msg.Tags.Sender, Name = tostring(parameters.name), ProcessId = tostring(parameters.processId) }
                        })
                    end
                end
            elseif msg.Tags.Function == 'increaseUndernameCount' and parameters.name and parameters.qty then
                local name = string.lower(parameters.name)
                -- validate record can increase undernames
                local validIncrease, err = validateIncreaseUndernames(Records[name], parameters.qty, msg.Timestamp)
                if validIncrease == false then
                    print("Error for name: " .. name)
                    print(err)
                    ao.send({
                        Target = msg.Tags.Sender,
                        Tags = { Action = 'ArNS-Invalid-Undername-Increase-Notice', Sender = msg.Tags.Sender, Name = tostring(parameters.name), ProcessId = tostring(parameters.processId) }
                    })
                    -- Send the tokens back
                    ao.send({
                        Target = TOKEN_PROCESS_ID,
                        Tags = { Action = 'Transfer', Recipient = msg.Tags.Sender, Quantity = tostring(msg.Tags.Quantity) }
                    })
                    return
                end

                local record = Records[name]
                local endTimestamp
                if isLeaseRecord(record) then
                    endTimestamp = ensureMilliseconds(record.endTimestamp)
                else
                    endTimestamp = nil
                end

                local yearsRemaining
                if endTimestamp then
                    yearsRemaining = calculateYearsBetweenTimestamps(msg.Timestamp, endTimestamp)
                else
                    yearsRemaining = PERMABUY_LEASE_FEE_LENGTH -- Assuming PERMABUY_LEASE_FEE_LENGTH is defined somewhere
                end

                local existingUndernames = record.undernames

                local additionalUndernameCost = calculateUndernameCost(name, parameters.qty, record.type,
                    yearsRemaining)

                if additionalUndernameCost > quantity then
                    print('Not enough tokens for adding undernames.')
                    ao.send({
                        Target = msg.Tags.Sender,
                        Tags = { Action = 'ArNS-Insufficient-Funds', Sender = msg.Tags.Sender, Name = tostring(parameters.name), ProcessId = tostring(parameters.processId) }
                    })
                    -- Send the tokens back
                    ao.send({
                        Target = TOKEN_PROCESS_ID,
                        Tags = { Action = 'Transfer', Recipient = msg.Tags.Sender, Quantity = tostring(msg.Tags.Quantity) }
                    })
                    return
                end

                local incrementedUndernames = existingUndernames + parameters.qty
                Records[name].undernames = incrementedUndernames
                print('Increased undernames for: ' .. name .. " to " .. incrementedUndernames .. " undernames")

                -- Check if any remaining balance to send back
                local remainingQuantity = quantity - additionalUndernameCost
                if remainingQuantity > 1 then
                    -- Send the tokens back
                    print('Sending back remaining tokens: ' .. remainingQuantity)
                    ao.send({
                        Target = TOKEN_PROCESS_ID,
                        Tags = { Action = 'Transfer', Recipient = msg.Tags.Sender, Quantity = tostring(remainingQuantity) }
                    })
                    ao.send({
                        Target = msg.Tags.Sender,
                        Tags = { Action = 'ArNS-Increase-Undername-Notice-Remainder', Sender = msg.Tags.Sender, Name = tostring(parameters.name), ProcessId = tostring(parameters.processId), Quantity = tostring(remainingQuantity), IncrementedUndernames = tostring(incrementedUndernames) }
                    })
                else
                    ao.send({
                        Target = msg.Tags.Sender,
                        Tags = { Action = 'ArNS-Increase-Undername-Notice', Sender = msg.Tags.Sender, Name = tostring(parameters.name), ProcessId = tostring(parameters.processId), IncrementedUndernames = tostring(incrementedUndernames) }
                    })
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
