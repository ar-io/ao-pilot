local json = require('json')

if not Balances then
    Balances = {}

    -- ao.id is the protocol balance
    Balances[ao.id] = 20000

    -- Assignments for complex keys
    Balances["iKryOeZQMONi2965nKz528htMMN_sBcjlhc-VncoRjA"] = 1000
end

-- Setup the default record pointing to the ArNS landing page
if not Records then
    Records = {}
    Records['@'] = {
        transactionId = 'UyC5P5qKPZaltMmmZAWdakhlDXsBF6qmyrbWYFchRTk',
        ttlSeconds = 3600
    }
end

-- Set empty controllers
if not Controllers then
    Controllers = {}
    Controllers['ecJ9HQzdzIELyEC6JZKO2awNEz23VYgVP5jVcdmIyRI'] = true
    Controllers['QGWqtJdLLgm2ehFWiiPzMaoFLD50CnGuzZIPEdoDRGQ'] = true
end

Name = Name or 'AR.IO EXP'
Ticker = Ticker or 'EXP'
Denomination = Denomination or 1
Logo = Logo or 'Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A'

-- Merged token info and ANT info
Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg, env)
    local info = {
        name = Name,
        ticker = Ticker,
        logo = Logo,
        owner = Owner,
        denomination = tostring(Denomination),
        controllers = json.encode(Controllers),
        records = Records
    }
    ao.send(
        {
            Target = msg.From,
            Tags = { Action = 'Info-Notice', Name = Name, Ticker = Ticker, Logo = Logo, ProcessOwner = Owner, Denomination = tostring(Denomination), Controllers = json.encode(Controllers) },
            Data = json.encode(info)
        })
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
                Data = Colors.gray ..
                    "You transferred " ..
                    Colors.blue ..
                    msg.Tags.Quantity .. Colors.gray .. " to " .. Colors.green .. msg.Tags.Recipient .. Colors
                    .reset
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
                    Data = Colors.gray ..
                        "You received " ..
                        Colors.blue ..
                        msg.Tags.Quantity ..
                        Colors.gray .. " from " .. Colors.green .. msg.Tags.Recipient .. Colors.reset ..
                        " with the instructions for function " .. Colors.green .. msg.Tags.Function .. Colors.reset ..
                        " with the parameters " .. Colors.green .. msg.Tags.Parameters
                })
            else
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
            end
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
    assert(type(msg.Tags.Recipient) == 'string', 'Recipient is required!')

    if msg.From == env.Process.Id or Controllers[msg.From] == true then
        -- Add tokens to the token pool, according to Quantity
        local qty = tonumber(msg.Tags.Quantity)
        assert(type(qty) == 'number', 'qty must be number')
        assert(qty > 0, 'Quantity must be greater than 0')
        print("Minting " .. qty .. " EXP")
        if not Balances[msg.Tags.Recipient] then Balances[msg.Tags.Recipient] = 0 end

        Balances[msg.Tags.Recipient] = Balances[msg.Tags.Recipient] + qty

        -- Send Mint-Notice to the Sender
        ao.send({
            Target = msg.From,
            Action = 'Mint-Notice',
            Recipient = msg.Tags.Recipient,
            Quantity = tostring(qty),
            Data = Colors.gray ..
                "You minted " ..
                Colors.blue ..
                msg.Tags.Quantity .. Colors.gray .. " to " .. Colors.green .. msg.Tags.Recipient .. Colors.reset
        })

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
    else
        ao.send({
            Target = msg.From,
            Tags = {
                Action = 'Mint-Error',
                ['Message-Id'] = msg.Id,
                Error = 'Only the Process Owner or Controller can mint new ' .. Ticker .. ' tokens!'
            }
        })
    end
end)

Handlers.add('getRecord', Handlers.utils.hasMatchingTag('Action', 'Get-Record'), function(msg)
    if msg.Tags.SubDomain and Records[msg.Tags.SubDomain] then
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Record-Resolved', SubDomain = msg.Tags.SubDomain, TransactionId = Records[msg.Tags.SubDomain].transactionId, TtlSeconds = tostring(Records[msg.Tags.SubDomain].ttlSeconds) }
        })
    elseif Records['@'] then -- If no SubDomain is provided, then return the root subdomain
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Record-Resolved', SubDomain = '@', TransactionId = Records['@'].transactionId, TtlSeconds = tostring(Records['@'].ttlSeconds) }
        })
    else
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Get-Record-Error', ['Message-Id'] = msg.Id, Error = 'Requested non-existant record' }
        })
    end
end)

Handlers.add('getRecords', Handlers.utils.hasMatchingTag('Action', 'Get-Records'),
    function(msg) ao.send({ Action = 'Records-Resolved', Target = msg.From, Data = json.encode(Records) }) end)

Handlers.add('setRecord', Handlers.utils.hasMatchingTag('Action', 'Set-Record'), function(msg, env)
    local isValidRecord, responseMsg = validateSetRecord(msg)
    if isValidRecord then
        if msg.From == env.Process.Id then
            Records[msg.Tags.SubDomain] = {
                transactionId = msg.Tags.TransactionId,
                ttlSeconds = msg.Tags.TtlSeconds
            }
            if not msg.Tags.Cast then
                -- Send SetRecord-Notice to the Sender if cast is not provided
                ao.send({
                    Target = msg.From,
                    Tags = { Action = 'SetRecord-Notice', SubDomain = msg.Tags.SubDomain, TransactionId = msg.Tags.TransactionId, TtlSeconds = msg.Tags.TtlSeconds }
                })
            end
        elseif Controllers[msg.From] then
            Records[msg.Tags.SubDomain] = {
                transactionId = msg.Tags.TransactionId,
                ttlSeconds = msg.Tags.TtlSeconds
            }
            if not msg.Tags.Cast then
                -- Send SetRecord-Notice to the Sender if cast is not provided
                ao.send({
                    Target = msg.From,
                    Tags = { Action = 'SetRecord-Notice', SubDomain = msg.Tags.SubDomain, TransactionId = msg.Tags.TransactionId, TtlSeconds = msg.Tags.TtlSeconds }
                })
                -- Send SetRecord-Notice to the Owner if cast is not provided
                ao.send({
                    Target = env.Process.Id,
                    Tags = { Action = 'SetRecord-Notice', Controller = msg.From, SubDomain = msg.Tags.SubDomain, TransactionId = msg.Tags.TransactionId, TtlSeconds = msg.Tags.TtlSeconds }
                })
            end
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

Handlers.add('removeRecord', Handlers.utils.hasMatchingTag('Action', 'Remove-Record'), function(msg, env)
    if msg.From == env.Process.Id or Controllers[msg.From] then
        if Records[msg.Tags.SubDomain] then
            Records[msg.Tags.SubDomain] = nil
            if not msg.Tags.Cast then
                -- Send SetRecord-Notice to the Sender if cast is not provided
                ao.send({
                    Target = msg.From,
                    Tags = { Action = 'RemoveRecord-Notice', SubDomain = msg.Tags.SubDomain }
                })
            end
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

Handlers.add('setController', Handlers.utils.hasMatchingTag('Action', 'Set-Controller'), function(msg, env)
    if msg.From == env.Process.Id then
        Controllers[msg.Tags.Target] = true
        if not msg.Tags.Cast then
            -- Send SetController-Notice to the Sender if cast is not provided
            ao.send({
                Target = msg.From,
                Tags = { Action = 'SetController-Notice', Target = msg.Tags.Target }
            })
            -- Send SetController-Notice to the Target
            ao.send({
                Target = msg.Tags.Target,
                Tags = { Action = 'SetController-Notice', Sender = msg.From, Target = msg.Tags.Target }
            })
        end
    else
        ao.send({
            Target = msg.From,
            Tags = { Action = 'SetController-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
        })
    end
end)

Handlers.add('removeController', Handlers.utils.hasMatchingTag('Action', 'Remove-Controller'), function(msg, env)
    if msg.From == env.Process.Id then
        Controllers[msg.Tags.Target] = nil
        if not msg.Tags.Cast then
            -- Send RemoveController-Notice to the Sender if cast is not provided
            ao.send({
                Target = msg.From,
                Tags = { Action = 'RemoveController-Notice', Target = msg.Tags.Target }
            })
            -- Send RemoveController-Notice to the Target
            ao.send({
                Target = msg.Tags.Target,
                Tags = { Action = 'RemoveController-Notice', Sender = msg.From, Target = msg.Tags.Target }
            })
        end
    else
        ao.send({
            Target = msg.From,
            Tags = { Action = 'RemoveController-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
        })
    end
end)