local json = require('json')

if not Balances then
    Balances = {}

    -- Direct assignment for simple key
    Balances[ao.id] = 100000000000000

    -- Assignments for complex keys
    Balances["1H7WZIWhzwTH9FIcnuMqYkTsoyv1OTfGa_amvuYwrgo"] = 95464
    Balances["6Z-ifqgVi1jOwMvSNwKWs6ewUEQ0gU9eo4aHYC3rN1M"] = 5000
    Balances["7waR8v4STuwPnTck1zFVkQqJh5K9q9Zik4Y5-5dV7nk"] = 24169584
    Balances["QGWqtJdLLgm2ehFWiiPzMaoFLD50CnGuzZIPEdoDRGQ"] = 924859926
    Balances["iKryOeZQMONi2965nKz528htMMN_sBcjlhc-VncoRjA"] = 99688
    Balances["wlcEhTQY_qjDKTvTDZsb53aX8wivbOJZKnhLswdueZw"] = 168047
    Balances["xN_aVln30LmoCffwmk5_kRkcyQZyZWy1o_TNtM_CTm0"] = 181964
    Balances["ySqMsg7O0R-BcUw35R3nxJJKJyIdauLCQ4DUZqPCiYo"] = 14000
end

if Name ~= 'Token-Experiment-1' then Name = 'Token-Experiment-1' end

if Ticker ~= 'TOKENEXP1' then Ticker = 'TOKENEXP1' end

if Denomination ~= 1000000 then Denomination = 1000000 end

Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
    ao.send(
        { Target = msg.From, Tags = { Name = Name, Ticker = Ticker, Logo = Logo, Denomination = tostring(Denomination) } })
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

Handlers.add('transfer', Handlers.utils.hasMatchingTag('Action', 'Transfer'), function(msg)
    assert(type(msg.Tags.Recipient) == 'string', 'Recipient is required!')
    assert(type(msg.Tags.Quantity) == 'string', 'Quantity is required!')

    if not Balances[msg.From] then Balances[msg.From] = 0 end

    if not Balances[msg.Tags.Recipient] then Balances[msg.Tags.Recipient] = 0 end

    local qty = tonumber(msg.Tags.Quantity)
    assert(type(qty) == 'number', 'qty must be number')

    if Balances[msg.From] >= qty then
        Balances[msg.From] = Balances[msg.From] - qty
        Balances[msg.Tags.Recipient] = Balances[msg.Tags.Recipient] + qty

        --[[
        Only Send the notifications to the Sender and Recipient
        if the Cast tag is not set on the Transfer message
        ]]
        --
        if not msg.Tags.Cast then
            -- Send Debit-Notice to the Sender
            ao.send({
                Target = msg.From,
                Tags = { Action = 'Debit-Notice', Recipient = msg.Tags.Recipient, Quantity = tostring(qty) }
            })
            -- Send Credit-Notice to the Recipient
            ao.send({
                Target = msg.Tags.Recipient,
                Tags = { Action = 'Credit-Notice', Sender = msg.From, Quantity = tostring(qty) }
            })
        end
    else
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Transfer-Error', ['Message-Id'] = msg.Id, Error = 'Insufficient Balance!' }
        })
    end
end)

Handlers.add('mint', Handlers.utils.hasMatchingTag('Action', 'Mint'), function(msg, env)
    assert(type(msg.Tags.Quantity) == 'string', 'Quantity is required!')

    if msg.From == env.Process.Id then
        -- Add tokens to the token pool, according to Quantity
        local qty = tonumber(msg.Tags.Quantity)
        Balances[env.Process.Id] = Balances[env.Process.Id] + qty
    else
        ao.send({
            Target = msg.From,
            Tags = {
                Action = 'Mint-Error',
                ['Message-Id'] = msg.Id,
                Error = 'Only the Process Owner can mint new ' .. Ticker .. ' tokens!'
            }
        })
    end
end)
