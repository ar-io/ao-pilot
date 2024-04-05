-- Define a JSON module for encoding and decoding JSON data
local json = require('json')

-- Initialize a table to store balances if it doesn't exist
if not Balances then
    Balances = {}

    -- Set initial balances for specific keys
    -- ao.id is the protocol balance
    Balances[ao.id] = 920000000

    -- Assignments for complex keys
    Balances["1H7WZIWhzwTH9FIcnuMqYkTsoyv1OTfGa_amvuYwrgo"] = 10000000
    Balances["6Z-ifqgVi1jOwMvSNwKWs6ewUEQ0gU9eo4aHYC3rN1M"] = 10000000
    Balances["7waR8v4STuwPnTck1zFVkQqJh5K9q9Zik4Y5-5dV7nk"] = 10000000
    Balances["QGWqtJdLLgm2ehFWiiPzMaoFLD50CnGuzZIPEdoDRGQ"] = 10000000
    Balances["iKryOeZQMONi2965nKz528htMMN_sBcjlhc-VncoRjA"] = 10000000
    Balances["wlcEhTQY_qjDKTvTDZsb53aX8wivbOJZKnhLswdueZw"] = 10000000
    Balances["xN_aVln30LmoCffwmk5_kRkcyQZyZWy1o_TNtM_CTm0"] = 10000000
    Balances["ySqMsg7O0R-BcUw35R3nxJJKJyIdauLCQ4DUZqPCiYo"] = 10000000
end

-- Set default values for certain variables if they are not already defined
Name = Name or 'Token-Experiment-1'
Ticker = Ticker or 'TOKEN-EXP-1'
Denomination = Denomination or 6
Logo = Logo or 'Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A'

-- Add a handler for 'info' messages that sends information about the token to the requester
Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
    ao.send(
        { Target = msg.From, Tags = { Name = Name, Ticker = Ticker, Logo = Logo, Denomination = tostring(Denomination) } })
end)

-- Add a handler for 'balance' messages that sends the balance of the requester
Handlers.add('balance', Handlers.utils.hasMatchingTag('Action', 'Balance'), function(msg)
    local bal = '0'

    -- If a specific target is provided in the message, return its balance; otherwise, return sender's balance
    if (msg.Tags.Target and Balances[msg.Tags.Target]) then
        bal = tostring(Balances[msg.Tags.Target])
    elseif Balances[msg.From] then
        bal = tostring(Balances[msg.From])
    end

    -- Send the balance information back to the requester
    ao.send({
        Target = msg.From,
        Tags = { Target = msg.From, Balance = bal, Ticker = Ticker, Data = json.encode(tonumber(bal)) }
    })
end)

-- Add a handler for 'balances' messages that sends the balances of all accounts
Handlers.add('balances', Handlers.utils.hasMatchingTag('Action', 'Balances'),
    function(msg) ao.send({ Target = msg.From, Data = json.encode(Balances) }) end)

-- Add a handler for 'transfer' messages that handles token transfers between accounts
Handlers.add('transfer', Handlers.utils.hasMatchingTag('Action', 'Transfer'), function(msg)
    assert(type(msg.Tags.Recipient) == 'string', 'Recipient is required!')
    assert(type(msg.Tags.Quantity) == 'string', 'Quantity is required!')

    -- Ensure the sender has enough balance for the transfer
    if not Balances[msg.From] then Balances[msg.From] = 0 end
    if not Balances[msg.Tags.Recipient] then Balances[msg.Tags.Recipient] = 0 end

    local qty = tonumber(msg.Tags.Quantity)
    assert(type(qty) == 'number', 'qty must be number')
    assert(qty > 0, 'Quantity must be greater than 0')

    -- Process the transfer if the sender has enough balance
    if Balances[msg.From] >= qty then
        Balances[msg.From] = Balances[msg.From] - qty
        Balances[msg.Tags.Recipient] = Balances[msg.Tags.Recipient] + qty

        -- Send notifications to sender and recipient unless the Cast tag is set on the Transfer message
        if not msg.Cast then
            -- Send Debit-Notice to the Sender
            ao.send({
                Target = msg.From,
                Action = 'Debit-Notice',
                Recipient = msg.Tags.Recipient,
                Quantity = tostring(qty),
                Data = Colors.gray ..
                    "You transferred " ..
                    Colors.blue ..
                    msg.Tags.Quantity .. Colors.gray .. " to " .. Colors.green .. msg.Tags.Recipient .. Colors
                    .reset
            })
            -- Send Credit-Notice to the Recipient and include the function and parameters tags if available
            if msg.Tags.Function and msg.Tags.Parameters then
                ao.send({
                    Target = msg.Tags.Recipient,
                    Action = 'Credit-Notice',
                    Sender = msg.From,
                    Quantity = tostring(qty),
                    Function = tostring(msg.Tags.Function),
                    Parameters = msg.Tags.Parameters,
                    Data = Colors.gray ..
                        "You received " ..
                        Colors.blue ..
                        msg.Tags.Quantity ..
                        Colors.gray .. " from " .. Colors.green .. msg.Tags.Recipient .. Colors.reset ..
                        " with the instructions for function " .. Colors.green .. msg.Tags.Function .. Colors.reset ..
                        " with the parameters " .. Colors.green .. msg.Tags.Parameters
                })
            else
                -- Send Credit-Notice to the Recipient
                ao.send({
                    Target = msg.Tags.Recipient,
                    Action = 'Credit-Notice',
                    Sender = msg.From,
                    Quantity = tostring(qty),
                    Data = Colors.gray ..
                        "You received " ..
                        Colors.blue ..
                        msg.Tags.Quantity ..
                        Colors.gray .. " from " .. Colors.green .. msg.Tags.Recipient .. Colors.reset
                })
            end
        end
    else
        -- Send an error message if the sender does not have enough balance
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Transfer-Error', ['Message-Id'] = msg.Id, Error = 'Insufficient Balance!' }
        })
    end
end)

-- Add a handler for 'mint' messages that allows minting new tokens (only for the process owner)
Handlers.add('mint', Handlers.utils.hasMatchingTag('Action', 'Mint'), function(msg, env)
    assert(type(msg.Tags.Quantity) == 'string', 'Quantity is required!')

    -- Only the process owner can mint new tokens
    if msg.From == env.Process.Id then
        -- Add tokens to the token pool, according to Quantity
        local qty = tonumber(msg.Tags.Quantity)
        Balances[env.Process.Id] = Balances[env.Process.Id] + qty
    else
        -- Send an error message if someone other than the process owner tries to mint tokens
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
