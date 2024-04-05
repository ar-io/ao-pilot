-- Load JSON library for encoding and decoding JSON data
local json = require('json')

-- Initialize Balances with default value if not already defined
if not Balances then Balances = { [ao.id] = 1 } end

-- Set Name to 'Arweave Name Token' if it's not already set
if Name ~= 'Arweave Name Token' then Name = 'Arweave Name Token' end

-- Set Ticker to 'ANT' if it's not already set
if Ticker ~= 'ANT' then Ticker = 'ANT' end

-- Set Denomination to 1 if it's not already set
if Denomination ~= 1 then Denomination = 1 end

-- Initialize Records with default value if not already defined
if not Records then Records = { ['@'] = { transactionId = '', ttlSeconds = 3600 } } end

-- Handle 'info' messages and send information about the token
Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
    ao.send(
        {
            Target = msg.From,
            Tags = { Name = Name, Ticker = Ticker, Denomination = tostring(Denomination) },
            Records =
                json.encode(Records)
        })
end)

-- Handle 'balance' messages and send the balance information
Handlers.add('balance', Handlers.utils.hasMatchingTag('Action', 'Balance'), function(msg)
    local bal = '0'

    -- If Target is provided, send the balance corresponding to that Target, otherwise send Sender's balance
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

-- Handle 'balances' messages and send all balances
Handlers.add('balances', Handlers.utils.hasMatchingTag('Action', 'Balances'),
    function(msg) ao.send({ Target = msg.From, Data = json.encode(Balances) }) end)

-- Handle 'setRecord' messages and set a new record
Handlers.add('setRecord', Handlers.utils.hasMatchingTag('Action', 'SetRecord'), function(msg)
    local Payload = json.decode(msg.Data)
    -- Perform simple validation on Payload's data
    if not Payload.name or not Payload.transactionId then
        ao.send({
            Target = msg.From,
            Tags = { Name = Name, Ticker = Ticker, Error = "Unable to set record. Missing transactionId or name from data payload.", Result = 'error' }
        })
    end
    -- Check if the caller is the owner before setting the record
    if msg.Owner ~= Owner then
        ao.send({
            Target = msg.From,
            Tags = { Name = Name, Ticker = Ticker, Error = "Unable to set record as caller is not process owner", Result = 'error' }
        })
    end
    -- Set the record in Records table
    Records[Payload.name] = { transactionId = Payload.transactionId, ttlSeconds = 3600 }
    -- Send acknowledgment of the record being set
    ao.send(
        {
            Target = msg.From,
            Tags = { Name = Name, Ticker = Ticker, Result = 'ok' },
        })
end)
