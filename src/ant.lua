-- Load JSON library for encoding and decoding JSON data
local json = require('json')
-- Minimum time-to-live (TTL) in seconds
MIN_TTL_SECONDS = 3600
-- Message for non-process owners/controllers
NON_PROCESS_OWNER_CONTROLLER_MESSAGE = "Caller is not the owner or controller of the ANT!"

-- Default values for various parameters
Name = Name or 'ANT-Experiment-1'
Ticker = Ticker or 'ANT-AO-EXP1'
Denomination = Denomination or 1
Logo = Logo or 'Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A'

-- URL for caching data
CacheUrl = "https://api.arns.app/v1/contract/"
-- Constants for sending and receiving data
_0RBIT_SEND = "WSXUI2JjYUldJ7CKq9wE1MGwXs-ldzlUlHOQszwQe0s"
_0RBIT_RECEIVE = "8aE3_6NJ_MU_q3fbhz2S6dA8PKQOSCe95Gt7suQ3j7U"

-- Initialize Balances if not already defined
if not Balances then
    Balances = {}
    Balances[Owner] = 1  -- Set initial balance to 1 for the process owner
end

-- Initialize Controllers if not already defined
if not Controllers then
    Controllers = {}  -- Empty controllers initially
end

-- Initialize Records if not already defined
if not Records then
    Records = {}
    -- Setup default record with a transaction ID and TTL
    Records['@'] = {
        transactionId = 'UyC5P5qKPZaltMmmZAWdakhlDXsBF6qmyrbWYFchRTk',
        ttlSeconds = 3600
    }
end

-- Initialize MirrorANTRequests if not already defined
if not MirrorANTRequests then
    MirrorANTRequests = {}  -- Empty mirror requests initially
end

-- Custom validation function for setting records
function validateSetRecord(msg)
    -- Check for required fields in the message
    local requiredFields = { "SubDomain", "TransactionId", "TtlSeconds" }
    for _, field in ipairs(requiredFields) do
        if not msg.Tags[field] then
            return false, field .. " is required!"
        end
    end

    -- Validate the subDomain (Record)
    if not (msg.Tags.SubDomain == "@" or string.match(msg.Tags.SubDomain, "^[%w-_]+$")) then
        return false, "Record (subDomain) pattern is invalid."
    end

    -- Check for invalid subDomain
    if msg.Tags.SubDomain == 'www' then
        return false, "Invalid ArNS Record Subdomain"
    end

    -- Validate the transactionId
    -- if not validArweaveId(msg.Tags.TransactionId) then
    --    return false, "TransactionId pattern is invalid."
    -- end

    -- Validate the TTL (time-to-live) in seconds
    local ttlSeconds = tonumber(msg.Tags.TtlSeconds)
    if not ttlSeconds or ttlSeconds < 900 or ttlSeconds > 2592000 or ttlSeconds % 1 ~= 0 then
        return false, "TtlSeconds is invalid."
    end

    -- If all checks pass, return true
    return true, "Valid"
end

-- Utility function to check if a string matches an arweave id pattern
function validArweaveId(inputString)
    local pattern = "^[a-zA-Z0-9-_]{43}$"
    return string.match(inputString, pattern) ~= nil
end

-- Function to fetch JSON data from Orbit
function fetchJsonDataFromOrbit(url)
    ao.send({ Target = _0RBIT_SEND, Action = "Get-Real-Data", Url = url })
end

-- Handler to provide information about the ANT token
Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg, env)
    -- Construct info object with token details
    local info = {
        name = Name,
        ticker = Ticker,
        logo = Logo,
        owner = Owner,
        denomination = tostring(Denomination),
        controllers = json.encode(Controllers),
        records = Records
    }
    -- Send the info object as JSON data to the requester
    ao.send(
        {
            Target = msg.From,
            Tags = { Action = 'Info-Notice', Name = Name, Ticker = Ticker, Logo = Logo, ProcessOwner = Owner, Denomination = tostring(Denomination), Controllers = json.encode(Controllers) },
            Data = json.encode(info)
        })
end)

-- Handler to get the balance of the token
Handlers.add('balance', Handlers.utils.hasMatchingTag('Action', 'Balance'), function(msg)
    local bal = '0'

    -- Check if a specific Target is provided, else return sender's balance
    if (msg.Tags.Target and Balances[msg.Tags.Target]) then
        bal = tostring(Balances[msg.Tags.Target])
    elseif Balances[msg.From] then
        bal = tostring(Balances[msg.From])
    end

    -- Send the balance information as JSON data
    ao.send({
        Target = msg.From,
        Tags = { Target = msg.From, Balance = bal, Ticker = Ticker, Data = json.encode(tonumber(bal)) }
    })
end)

-- Handler to get all balances
Handlers.add('balances', Handlers.utils.hasMatchingTag('Action', 'Balances'),
    function(msg) ao.send({ Target = msg.From, Data = json.encode(Balances) }) end)

-- Handler to get a specific record
Handlers.add('getRecord', Handlers.utils.hasMatchingTag('Action', 'Get-Record'), function(msg)
    if msg.Tags.SubDomain and Records[msg.Tags.SubDomain] then
        -- Send the record details to the requester
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Record-Resolved', SubDomain = msg.Tags.SubDomain, TransactionId = Records[msg.Tags.SubDomain].transactionId, TtlSeconds = tostring(Records[msg.Tags.SubDomain].ttlSeconds) }
        })
    elseif Records['@'] then -- If no SubDomain is provided, return the root subdomain
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Record-Resolved', SubDomain = '@', TransactionId = Records['@'].transactionId, TtlSeconds = tostring(Records['@'].ttlSeconds) }
        })
    else
        -- Send error message for non-existent record
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Get-Record-Error', ['Message-Id'] = msg.Id, Error = 'Requested non-existent record' }
        })
    end
end)

-- Handler to get all records
Handlers.add('getRecords', Handlers.utils.hasMatchingTag('Action', 'Get-Records'),
    function(msg) ao.send({ Target = msg.From, Data = json.encode(Records) }) end)

-- Handler for processing transfer requests, ensuring recipient is specified and handling token transfers
Handlers.add('transfer', Handlers.utils.hasMatchingTag('Action', 'Transfer'), function(msg, env)
    assert(type(msg.Tags.Recipient) == 'string', 'Recipient is required!') -- Ensure recipient is specified

    if not Balances[msg.From] then Balances[msg.From] = 0 end -- Initialize sender balance if not exist
    if not Balances[msg.Tags.Recipient] then Balances[msg.Tags.Recipient] = 0 end -- Initialize recipient balance if not exist

    -- Validate sender and process ownership before proceeding with the transfer
    if not msg.From == env.Process.Id or not msg.From == Owner or not Balances[msg.From] == 1 then
        -- Notify sender of transfer error due to ownership or balance issues
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Transfer-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
        })
    else
        -- Clear old balances and set new balances for sender and recipient
        Balances[Owner] = nil
        Balances[env.Process.Id] = nil
        Balances[msg.From] = nil
        Balances[msg.Tags.Recipient] = 1 -- single token only in this process
        Controllers = {} -- empty previous controller list
        Owner = msg.Tags.Recipient -- change ownership to the new recipient

        -- Notify sender and recipient about the transfer unless it's a casted transfer
        if not msg.Tags.Cast then
            -- Send Debit-Notice to the Sender
            ao.send({
                Target = msg.From,
                Tags = { Action = 'ANT-Debit-Notice', Recipient = msg.Tags.Recipient, Quantity = '1' }
            })
            -- Send Credit-Notice to the Recipient
            ao.send({
                Target = msg.Tags.Recipient,
                Tags = { Action = 'ANT-Credit-Notice', Sender = msg.From, Quantity = '1' }
            })
        end
    end
end)

-- Handler for processing set record requests, validating the request and handling notifications
Handlers.add('setRecord', Handlers.utils.hasMatchingTag('Action', 'Set-Record'), function(msg, env)
    local isValidRecord, responseMsg = validateSetRecord(msg) -- Validate the set record request
    if isValidRecord then
        -- Process valid record request based on sender or controller
        if msg.From == env.Process.Id then
            -- Update records and notify sender if not a casted request
            Records[msg.Tags.SubDomain] = {
                transactionId = msg.Tags.TransactionId,
                ttlSeconds = msg.Tags.TtlSeconds
            }
            if not msg.Tags.Cast then
                -- Send SetRecord-Notice to the Sender
                ao.send({
                    Target = msg.From,
                    Tags = { Action = 'SetRecord-Notice', SubDomain = msg.Tags.SubDomain, TransactionId = msg.Tags.TransactionId, TtlSeconds = msg.Tags.TtlSeconds }
                })
            end
        elseif Controllers[msg.From] then
            -- Update records and notify sender and owner if not a casted request
            Records[msg.Tags.SubDomain] = {
                transactionId = msg.Tags.TransactionId,
                ttlSeconds = msg.Tags.TtlSeconds
            }
            if not msg.Tags.Cast then
                -- Send SetRecord-Notice to the Sender and Owner
                ao.send({
                    Target = msg.From,
                    Tags = { Action = 'SetRecord-Notice', SubDomain = msg.Tags.SubDomain, TransactionId = msg.Tags.TransactionId, TtlSeconds = msg.Tags.TtlSeconds }
                })
                ao.send({
                    Target = env.Process.Id,
                    Tags = { Action = 'SetRecord-Notice', Controller = msg.From, SubDomain = msg.Tags.SubDomain, TransactionId = msg.Tags.TransactionId, TtlSeconds = msg.Tags.TtlSeconds }
                })
            end
        else
            -- Notify sender of error due to ownership or controller issues
            ao.send({
                Target = msg.From,
                Tags = { Action = 'SetRecord-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
            })
        end
    else
        -- Notify sender of error in the set record request
        ao.send({
            Target = msg.From,
            Tags = { Action = 'SetRecord-Error', ['Message-Id'] = msg.Id, Error = responseMsg }
        })
    end
end)

-- Handler for removing records, validating the request and handling notifications
Handlers.add('removeRecord', Handlers.utils.hasMatchingTag('Action', 'Remove-Record'), function(msg, env)
    -- Process record removal request based on sender or controller
    if msg.From == env.Process.Id or Controllers[msg.From] then
        if Records[msg.Tags.SubDomain] then
            -- Remove the record and notify sender if not a casted request
            Records[msg.Tags.SubDomain] = nil
            if not msg.Tags.Cast then
                -- Send RemoveRecord-Notice to the Sender
                ao.send({
                    Target = msg.From,
                    Tags = { Action = 'RemoveRecord-Notice', SubDomain = msg.Tags.SubDomain }
                })
            end
        else
            -- Notify sender of error if the subdomain does not exist
            ao.send({
                Target = msg.From,
                Tags = { Action = 'RemoveRecord-Error', ['Message-Id'] = msg.Id, Error = 'Subdomain does not exist in this process' }
            })
        end
    else
        -- Notify sender of error due to ownership or controller issues
        ao.send({
            Target = msg.From,
            Tags = { Action = 'RemoveRecord-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
        })
    end
end)

-- Handler for setting controllers, validating the request and handling notifications
Handlers.add('setController', Handlers.utils.hasMatchingTag('Action', 'Set-Controller'), function(msg, env)
    -- Process set controller request from the owner
    if msg.From == env.Process.Id then
        -- Update controllers and notify sender and target if not a casted request
        Controllers[msg.Tags.Target] = true
        if not msg.Tags.Cast then
            -- Send SetController-Notice to the Sender and Target
            ao.send({
                Target = msg.From,
                Tags = { Action = 'SetController-Notice', Target = msg.Tags.Target }
            })
            ao.send({
                Target = msg.Tags.Target,
                Tags = { Action = 'SetController-Notice', Sender = msg.From, Target = msg.Tags.Target }
            })
        end
    else
        -- Notify sender of error due to ownership or controller issues
        ao.send({
            Target = msg.From,
            Tags = { Action = 'SetController-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
        })
    end
end)

-- Handler for removing controllers, validating the request and handling notifications
Handlers.add('removeController', Handlers.utils.hasMatchingTag('Action', 'Remove-Controller'), function(msg, env)
    -- Process remove controller request from the owner
    if msg.From == env.Process.Id then
        -- Remove controller and notify sender and target if not a casted request
        Controllers[msg.Tags.Target] = nil
        if not msg.Tags.Cast then
            -- Send RemoveController-Notice to the Sender and Target
            ao.send({
                Target = msg.From,
                Tags = { Action = 'RemoveController-Notice', Target = msg.Tags.Target }
            })
            ao.send({
                Target = msg.Tags.Target,
                Tags = { Action = 'RemoveController-Notice', Sender = msg.From, Target = msg.Tags.Target }
            })
        end
    else
        -- Notify sender of error due to ownership or controller issues
        ao.send({
            Target = msg.From,
            Tags = { Action = 'RemoveController-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
        })
    end
end)

-- Handler for mirroring ANT configurations, validating the request and handling notifications
Handlers.add('mirrorANT', Handlers.utils.hasMatchingTag('Action', 'Mirror-ANT'), function(msg, env)
    assert(msg.From == env.Process.Id, 'Only the Process can request ANT mirroring') -- Ensure only process can request ANT mirroring
    assert(type(msg.Tags.ContractTxId) == 'string', 'ANT Contract ID is required!') -- Ensure ANT Contract ID is specified
    local url = CacheUrl .. msg.Tags.ContractTxId -- Build URL for ANT mirroring
    MirrorANTRequests[msg.Tags.ContractTxId] = true -- Set flag for mirroring request
    fetchJsonDataFromOrbit(url) -- Fetch JSON data from the specified URL
    ao.send({
        Target = msg.From,
        Tags = { Action = 'Mirror-ANT-Notice', ContractId = msg.Tags.ContractTxId } -- Notify process of ANT mirroring request
    })
end)

-- Handler for receiving data feed, processing data from 0rbit and updating process state
Handlers.add('receiveDataFeed', Handlers.utils.hasMatchingTag('Action', 'Receive-data-feed'), function(msg, env)
    local data, _, err = json.decode(msg.Data) -- Decode received JSON data
    print('got data from 0rbit') -- Log receipt of data from 0rbit
    if msg.From == _0RBIT_RECEIVE and MirrorANTRequests[data.contractTxId] == true then
        -- Mirror the configuration found in the ANT if relevant to the current request
        if data.state.controllers then
            Controllers = data.state.controllers -- Update controllers based on received data
        end
        if data.state.name then
            Name = data.state.name -- Update process name based on received data
        end
        if data.state.ticker then
            Ticker = data.state.ticker -- Update process ticker based on received data
        end
        if data.state.records then
            Records = {} -- Reset records and merge or set the received records
            for key, value in pairs(data.state.records) do
                Records[key] = value
            end
        end
        -- Notify process of ANT mirroring completion
        ao.send({
            Target = env.Process.Id,
            Tags = { Action = 'Mirror-ANT-Complete', ContractTxId = data.contractTxId, Records = json.encode(Records) }
        })
        MirrorANTRequests[data.contractTxId] = nil -- Clear mirroring request flag after completion
    end
end)
