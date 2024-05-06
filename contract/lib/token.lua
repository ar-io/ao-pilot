-- arns.lua
local utils = require '.utils'
local json = require '.json'


if not Balances then
    Balances = {}
end

local token = {}

function token.transfer(msg)
    assert(type(msg.Tags.Recipient) == 'string', 'Recipient is required!')
    assert(type(msg.Tags.Quantity) == 'string', 'Quantity is required!')

    if not Balances[msg.From] then Balances[msg.From] = 0 end

    if not Balances[msg.Tags.Recipient] then Balances[msg.Tags.Recipient] = 0 end

    local qty = tonumber(msg.Tags.Quantity)
    assert(type(qty) == 'number', 'qty must be number')
    assert(qty > 0, 'Quantity must be greater than 0')

    if Balances[msg.From] >= qty then
        Balances[msg.From] = Balances[msg.From] - qty
        Balances[msg.Tags.Recipient] = Balances[msg.Tags.Recipient] + qty

        --[[
        Only Send the notifications to the Sender and Recipient
        if the Cast tag is not set on the Transfer message
        ]]
        --
        if not msg.Cast then
            -- Send Debit-Notice to the Sender
            ao.send({
                Target = msg.From,
                Action = 'Debit-Notice',
                Recipient = msg.Tags.Recipient,
                Quantity = tostring(qty),
                Data = "You transferred " .. msg.Tags.Quantity .. " to " .. msg.Tags.Recipient
            })
            if msg.Tags.Function and msg.Tags.Parameters then
                -- Send Credit-Notice to the Recipient and include the function and parameters tags
                ao.send({
                    Target = msg.Tags.Recipient,
                    Action = 'Credit-Notice',
                    Sender = msg.From,
                    Quantity = tostring(qty),
                    Function = tostring(msg.Tags.Function),
                    Parameters = msg.Tags.Parameters,
                    Data = "You received " ..
                        msg.Tags.Quantity .. " from " .. msg.Tags.Recipient ..
                        " with the instructions for function " .. msg.Tags.Function ..
                        " with the parameters " .. msg.Tags.Parameters
                })
            else
                -- Send Credit-Notice to the Recipient
                ao.send({
                    Target = msg.Tags.Recipient,
                    Action = 'Credit-Notice',
                    Sender = msg.From,
                    Quantity = tostring(qty),
                    Data = "You received " ..
                        msg.Tags.Quantity ..
                        " from " .. msg.Tags.Recipient
                })
            end
        end
    else
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Transfer-Error', ['Message-Id'] = msg.Id, Error = 'Insufficient Balance!' }
        })
        return false;
    end
    return true
end

function token.vault()
    -- TODO: implement
    utils.reply("vault is not implemented yet")
end

function token.getBalance(msg)
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
    utils.reply("getBalance completed")
end

function token.getBalances(msg)
    ao.send({ Target = msg.From, Data = json.encode(Balances) })
    utils.reply("getBalance completed")
end

return token
