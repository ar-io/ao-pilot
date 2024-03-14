-- arns-experiment-1
local json = require('json')
local base64 = require(".base64")

Name = Name or 'Names-Experiment-1'
Ticker = Ticker or 'EXP1'
Denomination = Denomination or 1
Logo = Logo or 'Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A'
Listeners = Listeners or {}

DEFAULT_UNDERNAME_COUNT = 10
NamePrice = 1000

CacheUrl = "https://api.arns.app/v1/contract/"
ArNSCacheUrl = "https://api.arns.app/v1/contract/bLAgYxAdX2Ry-nt6aH2ixgvJXbpsEYm28NgJgyqfs-U/records/"

_0RBIT = "WSXUI2JjYUldJ7CKq9wE1MGwXs-ldzlUlHOQszwQe0s"

-- Uses 'token-experiement-1' process
TokenProcessId = 'gAC5hpUPh1v-oPJLnK3Km6-atrYlvI271bI-q0yZOnw'

-- Setup the default record pointing to the ArNS landing page
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
        endTimestamp = 1711122739,
        startTimestamp = 1694101828,
        type = "lease",
        undernames = 100
    }
end

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

-- Setup the default empty credit balances
if not Credits then
    Credits = {}
end

Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
    ao.send(
        { Target = msg.From, Tags = { Name = Name, Ticker = Ticker, Logo = Logo, ProcessOwner = Owner, Denomination = tostring(Denomination), NamesRegistered = tableCount(Records) } })
end)

Handlers.add('getFees', Handlers.utils.hasMatchingTag('Action', 'Get-Fees'),
    function(msg)
        ao.send({ Target = msg.From, Data = json.encode(Fees) })
    end)

Handlers.add('getCredits', Handlers.utils.hasMatchingTag('Action', 'Get-Credits'),
    function(msg) ao.send({ Target = msg.From, Data = json.encode(Credits) }) end)

Handlers.add('getRecord', Handlers.utils.hasMatchingTag('Action', 'Get-Record'), function(msg)
    if msg.Tags.Name and Records[msg.Tags.Name] then
        recordOwner = Records[msg.Tags.Name]
        ao.send({
            Target = msg.From,
            Tags = { Name = msg.Tags.Name, ContractId = Records[msg.Tags.Name].ContractId, Data = json.encode(Records[msg.Tags.Name]) }
        })
    else
        ao.send({
            Target = msg.From,
            Tags = { Action = 'GetRecord-Error', ['Message-Id'] = msg.Id, Error = 'Requested non-existant record' }
        })
    end
end)

Handlers.add('initiateLoadRecords', Handlers.utils.hasMatchingTag('Action', 'Initiate-Load-Records'), function(msg, env)
    assert(type(msg.Tags.ArweaveTxId) == 'string', 'Arweave Tx Id is required!')
    if msg.From == env.Process.Id then
        ao.send({
            Target = env.Process.Id,
            Tags = { Action = 'Data', Load = msg.Tags.ArweaveTxId }
        })
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Initiate-Load-Records-Received', Load = msg.Tags.ArweaveTxId }
        })
    else
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Initiate-Load-Records-Error', ['Message-Id'] = msg.Id, Error = 'Not being run by Process' }
        })
    end
end)

Handlers.add('dataNotice', Handlers.utils.hasMatchingTag('Action', 'Data'), function(msg, env)
    if msg.From == env.Process.Id then
        -- Update or initialize the sender's credit balance
        local rawJsonData = base64.decode(msg.Data.Data)
        local data, _, err = json.decode(rawJsonData)
        -- Counter for added/updated records
        local recordsAddedOrUpdated = 0

        -- Merge or set the decoded records into your Records table
        for key, value in pairs(data.records) do
            if not Records[key] or (Records[key] and Records[key] ~= value) then
                recordsAddedOrUpdated = recordsAddedOrUpdated + 1
            end
            Records[key] = value
            Records[key].processId = ""
        end
        ao.send({
            Target = env.Process.Id,
            Tags = { Action = 'Loaded-Records', Sender = msg.From }
        })
    end
end)

Handlers.add('initiateRecordUpdate', Handlers.utils.hasMatchingTag('Action', 'Initiate-Record-Update'),
    function(msg, env)
        assert(type(msg.Tags.Name) == 'string', 'Name is required!')
        assert(type(msg.Tags.ProcessId) == 'string', 'Process ID is required!'
        )
        if Records[msg.Tags.Name] then
            -- GET CURRENT NAME OWNER
            local url = CacheUrl .. Records[msg.Tags.Name].contractTxId

            RecordUpdates[msg.From] = {
                nameRequested = msg.Tags.Name,
                url = url,
                timeStamp = os.time()
            }
            ao.send({ Target = _0RBIT, Action = "Get-Real-Data", Url = url })
        end
    end)

-- Handler to receive deposits
Handlers.add('initiateDeposit', Handlers.utils.hasMatchingTag('Action', 'Initiate-Deposit'), function(msg, env)
    assert(type(msg.Tags.Quantity) == 'string', 'Quantity is required!')

    local qty = tonumber(msg.Tags.Quantity)
    assert(type(qty) == 'number' and qty > 0, 'Quantity must be a positive number')

    print("Initiating deposit from: " .. msg.From)
    ao.send({
        Target = TokenProcessId, -- Address/identifier of the Token process
        Tags = {
            Action = 'Transfer',
            Recipient = env.Process.Id, -- The ARNS Registry's address within the Token process
            Quantity = tostring(qty),
        }
    })
    ao.send({
        Target = msg.From,
        Tags = { Action = 'Deposit-Initiated', Quantity = tostring(qty) }
    })
end)

Handlers.add('creditNotice', Handlers.utils.hasMatchingTag('Action', 'Credit-Notice'), function(msg, env)
    print("Woa we got a credit notice message")
    print("Sender: " .. msg.Tags.Sender)
    if msg.From == TokenProcessId then
        -- Update or initialize the sender's credit balance
        Credits[msg.Tags.Sender] = (Credits[msg.Tags.Sender] or 0) + msg.Tags.Quantity
        -- Send Credit-Notice to the Recipient
        ao.send({
            Target = msg.Tags.Sender,
            Tags = { Action = 'Credit-Notice', Sender = msg.Tags.Sender, Quantity = tostring(msg.Tags.Quantity) }
        })
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


function validateBuyRecord(msg)
    -- Check for required field 'name'
    if not msg.Tags.name or type(msg.Tags.name) ~= "string" then
        return false, "name is required and must be a string."
    end

    -- Validate 'name' pattern
    if not string.match(msg.Tags.name, "^([a-zA-Z0-9][a-zA-Z0-9-]{0,49}[a-zA-Z0-9]|[a-zA-Z0-9]{1})$") then
        return false, "name pattern is invalid."
    end

    -- Validate 'contractTxId' if present
    if msg.Tags.contractTxId and not string.match(msg.Tags.contractTxId, "^(atomic|[a-zA-Z0-9-_]{43})$") then
        return false, "contractTxId pattern is invalid."
    end

    -- Validate 'years' if present
    if msg.Tags.years then
        if type(msg.Tags.years) ~= "number" or msg.Tags.years % 1 ~= 0 or msg.Tags.years < 1 or msg.Tags.years > 5 then
            return false, "years must be an integer between 1 and 5."
        end
    end

    -- Validate 'type' if present
    if msg.Tags.type and not string.match(msg.Tags.type, "^(lease|permabuy)$") then
        return false, "type pattern is invalid."
    end

    -- Validate 'auction' if present
    if msg.Tags.auction and type(msg.Tags.auction) ~= "boolean" then
        return false, "auction must be a boolean."
    end

    return true, ""
end

function tableCount(table)
    local count = 0
    for _ in pairs(table) do count = count + 1 end
    return count
end

function fetchJsonDataFromOrbit(url)
    ao.send({ Target = _0RBIT, Action = "Get-Real-Data", Url = url })
end
