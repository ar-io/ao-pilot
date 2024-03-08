local json = require('json')
MIN_TTL_SECONDS = 3600
NON_PROCESS_OWNER_CONTROLLER_MESSAGE = "Caller is not the owner or controller of the ANT!"

Name = Name or 'ANT-Experiment-1'
Ticker = Ticker or 'ANT-AO-EXP1'
Denomination = Denomination or 1
Logo = Logo or 'Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A'


-- Set the initial token balance to 1 and give it to the process owner
if not Balances then
    Balances = {}
    Balances[ao.id] = 1
end

-- Set empty controllers
if not Controllers then
    Controllers = {}
end

-- Setup the default record pointing to the ArNS landing page
if not Records then
    Records = {}
    Records['@'] = {
        transactionId = 'UyC5P5qKPZaltMmmZAWdakhlDXsBF6qmyrbWYFchRTk',
        ttlSeconds = 3600
    }
end

Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
    ao.send(
        { Target = msg.From, Tags = { Name = Name, Ticker = Ticker, Logo = Logo, Denomination = tostring(Denomination), Data = json.econde(Controllers) } })
end)

Handlers.add('balance', Handlers.utils.hasMatchingTag('Action', 'Balance'), function(msg)
    local bal = '0'

    -- If not Target is provided, then return the Senders balance
    if (msg.Tags.Target and Balances[msg.Tags.Target]) then
        bal = tostring(Balances[msg.Tags.Target])
    elseif Balances[msg.From] then
        bal = tostring(Balances[msg.From])
    end

    ao.send({
        Target = msg.From,
        Tags = { Target = msg.From, Balance = bal, Ticker = Ticker, Data = json.encode(tonumber(bal)) }
    })
end)

Handlers.add('balances', Handlers.utils.hasMatchingTag('Action', 'Balances'),
    function(msg) ao.send({ Target = msg.From, Data = json.encode(Balances) }) end)

Handlers.add('record', Handlers.utils.hasMatchingTag('Action', 'Record'), function(msg)
    -- If no SubDomain is provided, then return the root balance
    if (msg.Tags.Target and Records[msg.Tags.Target]) then
        local record = Records[msg.Tags.Target]
        local ttlSeconds = record.ttlSeconds
        local subDomain = msg.Tags.Target
        ao.send({
            Target = msg.From,
            Tags = { Target = msg.From, SubDomain = subDomain, TtlSeconds = ttlSeconds, Data = json.encode(record) }
        })
    elseif Records['@'] then
        local record = Records['@']
        local ttlSeconds = record.ttlSeconds
        local subDomain = '@'
        ao.send({
            Target = msg.From,
            Tags = { Target = msg.From, SubDomain = subDomain, TtlSeconds = ttlSeconds, Data = json.encode(record) }
        })
    else
        ao.send({
            Target = msg.From,
            Tags = { Action = 'GetRecord-Error', ['Message-Id'] = msg.Id, Error = 'Requested non-existant record' }
        })
    end
end)

Handlers.add('records', Handlers.utils.hasMatchingTag('Action', 'Records'),
    function(msg) ao.send({ Target = msg.From, Data = json.encode(Records) }) end)

Handlers.add('transfer', Handlers.utils.hasMatchingTag('Action', 'Transfer'), function(msg, env)
    assert(type(msg.Tags.Recipient) == 'string', 'Recipient is required!')

    if not Balances[msg.From] then Balances[msg.From] = 0 end

    if not Balances[msg.Tags.Recipient] then Balances[msg.Tags.Recipient] = 0 end

    if msg.From == Owner and Balances[msg.From] >= 1 then
        Balances[msg.From] = 0
        Balances[msg.Tags.Recipient] = 1 -- single token only in this process
        Controllers = {}                 -- empty previous controller list
        Owner = msg.Tags.Recipient       -- change ownership to the new recipient

        --[[
        Only Send the notifications to the Sender and Recipient
        if the Cast tag is not set on the Transfer message
        ]]
        --
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
    else
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Transfer-Error', ['Message-Id'] = msg.Id, Error = 'Insufficient Balance!' }
        })
    end
end)

Handlers.add('setRecord', Handlers.utils.hasMatchingTag('Action', 'SetRecord'), function(msg, env)
    local isValidRecord, responseMsg = validateSetRecord(msg)
    if isValidRecord then
        if msg.From == env.Process.owner or Controllers[msg.From] then
            Records[msg.Tags.SubDomain] = {
                transactionId = msg.Tags.TransactionId,
                ttlSeconds = msg.Tags.TtlSeconds
            }
        else
            ao.send({
                Target = msg.From,
                Tags = { Action = 'SetRecord-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
            })
        end
    else
        ao.send({
            Target = msg.From,
            Tags = { Action = 'SetRecord-Error', ['Message-Id'] = msg.Id, Error = responseMsg }
        })
    end
end)

Handlers.add('removeRecord', Handlers.utils.hasMatchingTag('Action', 'RemoveRecord'), function(msg, env)
    if msg.From == Owner or Controllers[msg.From] then
        if Records[msg.Tags.SubDomain] then
            Records[msg.Tags.SubDomain] = nil
        else
            ao.send({
                Target = msg.From,
                Tags = { Action = 'RemoveRecord-Error', ['Message-Id'] = msg.Id, Error = 'Subdomain does not exist in this process' }
            })
        end
    else
        ao.send({
            Target = msg.From,
            Tags = { Action = 'RemoveRecord-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
        })
    end
end)

Handlers.add('setController', Handlers.utils.hasMatchingTag('Action', 'SetController'), function(msg, env)
    if not stringMatchesPattern(msg.Tags.Target, "^[a-zA-Z0-9_-]{43}$") then
        ao.send({
            Target = msg.From,
            Tags = { Action = 'SetController-Error', ['Message-Id'] = msg.Id, Error = "Invalid target ID pattern." }
        })
    elseif msg.From == Owner then
        Controllers[msg.Tags.Target] = true
        if not msg.Tags.Cast then
            -- Send SetController notice to the Sender
            ao.send({
                Target = msg.From,
                Tags = { Action = 'ANT-SetController-Notice', Recipient = msg.Tags.Target }
            })
            -- Send SetController Notice to the Recipient
            ao.send({
                Target = msg.Tags.Target,
                Tags = { Action = 'ANT-SetController-Notice', Sender = msg.From }
            })
        end
    else
        ao.send({
            Target = msg.From,
            Tags = { Action = 'SetController-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
        })
    end
end)

-- Custom validateSetRecord function in Lua
function validateSetRecord(msg)
    -- Check for required fields
    local requiredFields = { "SubDomain", "TransactionId", "TtlSeconds" }
    for _, field in ipairs(requiredFields) do
        if not msg.Tags[field] then
            return false, field .. " is required!"
        end
    end

    -- Validate subDomain (Record)
    if not stringMatchesPattern(msg.Tags.SubDomain, "^([a-zA-Z0-9][a-zA-Z0-9-_]{0,59}[a-zA-Z0-9]|[a-zA-Z0-9]{1})$") then
        return false, "Record (subDomain) pattern is invalid."
    end

    if msg.Tags.SubDomain == 'www' then
        return false, "Invalid ArNS Record Subdomain"
    end

    -- Validate transactionId
    if not stringMatchesPattern(msg.Tags.TransactionId, "^[a-zA-Z0-9_-]{43}$") then
        return false, "TransactionId pattern is invalid."
    end

    -- Validate ttlSeconds
    local ttlSeconds = tonumber(msg.Tags.TtlSeconds)
    if not ttlSeconds or ttlSeconds < 900 or ttlSeconds > 2592000 or ttlSeconds % 1 ~= 0 then
        return false, "TtlSeconds is invalid."
    end

    -- If all checks pass
    return true, "Valid"
end

-- Utility function to check if a string matches a given Lua pattern
function stringMatchesPattern(s, pattern)
    return string.match(s, pattern) ~= nil
end
