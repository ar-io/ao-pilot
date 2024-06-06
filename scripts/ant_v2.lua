local json = require("json")
local bint = require('.bint')(256)

MIN_TTL_SECONDS = 3600
NON_PROCESS_OWNER_CONTROLLER_MESSAGE = "Caller is not the owner or controller of the ANT!"

Name = Name or "ANT-Experiment-1"
Ticker = Ticker or "ANT-AO-EXP1"
Denomination = Denomination or 1
Logo = Logo or "Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A"

-- Set the initial token balance to 1 and give it to the process owner
if not Balances then
    Balances = {}
    Balances[Owner] = "1"
end

-- Set empty controllers
if not Controllers then
    Controllers = {}
end

-- Setup the default record pointing to the ArNS landing page
if not Records then
    Records = {}
    Records["@"] = {
        transactionId = "UyC5P5qKPZaltMmmZAWdakhlDXsBF6qmyrbWYFchRTk",
        ttlSeconds = 3600,
    }
end

local utils = {
    add = function(a, b)
        return tostring(bint(a) + bint(b))
    end,
    subtract = function(a, b)
        return tostring(bint(a) - bint(b))
    end,
    toBalanceValue = function(a)
        return tostring(bint(a))
    end,
    toNumber = function(a)
        return tonumber(a)
    end
}

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
    if not (msg.Tags.SubDomain == "@" or string.match(msg.Tags.SubDomain, "^[%w-_]+$")) then
        return false, "Record (subDomain) pattern is invalid."
    end

    if msg.Tags.SubDomain == "www" then
        return false, "Invalid ArNS Record Subdomain"
    end

    -- Validate transactionId
    -- if not validArweaveId(msg.Tags.TransactionId) then
    --    return false, "TransactionId pattern is invalid."
    -- end

    -- Validate ttlSeconds
    local ttlSeconds = tonumber(msg.Tags.TtlSeconds)
    if not ttlSeconds or ttlSeconds < 900 or ttlSeconds > 2592000 or ttlSeconds % 1 ~= 0 then
        return false, "TtlSeconds is invalid."
    end

    -- If all checks pass
    return true, "Valid"
end

-- Utility function to check if a string matches an arweave id
local function validArweaveId(inputString)
    local pattern = "^[a-zA-Z0-9-_]{43}$"
    return string.match(inputString, pattern) ~= nil
end

Handlers.add("info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg, env)
    local info = {
        name = Name,
        ticker = Ticker,
        logo = Logo,
        owner = Owner,
        denomination = tostring(Denomination),
        controllers = json.encode(Controllers),
        records = Records,
    }
    ao.send({
        Target = msg.From,
        Tags = {
            Action = "Info-Notice",
            Name = Name,
            Ticker = Ticker,
            Logo = Logo,
            ProcessOwner = Owner,
            Denomination = tostring(Denomination),
            Controllers = json.encode(Controllers),
        },
        Data = json.encode(info),
    })
end)

Handlers.add("balance", Handlers.utils.hasMatchingTag("Action", "Balance"), function(msg)
    local bal = "0"

    -- If not Target is provided, then return the Senders balance
    if msg.Tags.Target and Balances[msg.Tags.Target] then
        bal = tostring(Balances[msg.Tags.Target])
    elseif Balances[msg.From] then
        bal = tostring(Balances[msg.From])
    end

    ao.send({
        Target = msg.From,
        Tags = { Target = msg.From, Balance = bal, Ticker = Ticker, Data = json.encode(tonumber(bal)) },
    })
end)

Handlers.add("balances", Handlers.utils.hasMatchingTag("Action", "Balances"), function(msg)
    ao.send({ Target = msg.From, Data = json.encode(Balances) })
end)

-- Transfer balance to recipient (Data - { Recipient, Quantity })
-- temporarily changed to capital T to work with AO Bazar
Handlers.add('Transfer', Handlers.utils.hasMatchingTag('Action', 'Transfer'), function(msg, env)
    assert(type(msg.Recipient) == 'string', 'Recipient is required!')
    -- Quantity is not required for an ANT, as we will default to a single token per ANT
    -- assert(type(msg.Quantity) == 'string', 'Quantity is required!')
    -- assert(bint.__lt(0, bint(msg.Quantity)), 'Quantity must be greater than 0')
    local quantity = "1" -- We only allow a single token in the ANT process.
    if msg.From == Owner or msg.From == env.Process.Id or tonumber(Balances[msg.From]) >= 0 then
        Balances[msg.From] = nil
        Balances[Owner] = nil
        Balances[msg.Recipient] = quantity
        Owner = msg.Recipient -- change ownership to the new recipient
        Controllers = {}      -- empty previous controller list

        if not msg.Cast then
            -- Debit-Notice message template, that is sent to the Sender of the transfer
            local debitNotice = {
                Target = msg.From,
                Action = 'Debit-Notice',
                Recipient = msg.Recipient,
                Quantity = quantity,
                Data = Colors.gray ..
                    "You transferred " ..
                    Colors.blue .. quantity .. Colors.gray .. " to " .. Colors.green .. msg.Recipient .. Colors
                    .reset
            }
            -- Credit-Notice message template, that is sent to the Recipient of the transfer
            local creditNotice = {
                Target = msg.Recipient,
                Action = 'Credit-Notice',
                Sender = msg.From,
                Quantity = quantity,
                Data = Colors.gray ..
                    "You received " ..
                    Colors.blue .. quantity .. Colors.gray .. " from " .. Colors.green .. msg.From .. Colors.reset
            }

            -- Add forwarded tags to the credit and debit notice messages
            for tagName, tagValue in pairs(msg) do
                -- Tags beginning with "X-" are forwarded
                if string.sub(tagName, 1, 2) == "X-" then
                    debitNotice[tagName] = tagValue
                    creditNotice[tagName] = tagValue
                end
            end
            -- Send Debit-Notice and Credit-Notice
            ao.send(debitNotice)
            ao.send(creditNotice)
        end
    else
        ao.send({
            Target = msg.From,
            Action = 'Transfer-Error',
            ['Message-Id'] = msg.Id,
            Error = 'Insufficient Balance!'
        })
    end
end)

Handlers.add("getRecord", Handlers.utils.hasMatchingTag("Action", "Get-Record"), function(msg)
    if msg.Tags.SubDomain and Records[msg.Tags.SubDomain] then
        ao.send({
            Target = msg.From,
            Tags = {
                Action = "Record-Resolved",
                SubDomain = msg.Tags.SubDomain,
                TransactionId = Records[msg.Tags.SubDomain].transactionId,
                TtlSeconds = tostring(Records[msg.Tags.SubDomain].ttlSeconds),
            },
        })
    elseif Records["@"] then -- If no SubDomain is provided, then return the root subdomain
        ao.send({
            Target = msg.From,
            Tags = {
                Action = "Record-Resolved",
                SubDomain = "@",
                TransactionId = Records["@"].transactionId,
                TtlSeconds = tostring(Records["@"].ttlSeconds),
            },
        })
    else
        ao.send({
            Target = msg.From,
            Tags = { Action = "Get-Record-Error", ["Message-Id"] = msg.Id, Error = "Requested non-existant record" },
        })
    end
end)

Handlers.add("getRecords", Handlers.utils.hasMatchingTag("Action", "Get-Records"), function(msg)
    ao.send({ Target = msg.From, Data = json.encode(Records) })
end)

Handlers.add("setRecord", Handlers.utils.hasMatchingTag("Action", "Set-Record"), function(msg, env)
    local isValidRecord, responseMsg = validateSetRecord(msg)
    if isValidRecord then
        if msg.From == env.Process.Id then
            Records[msg.Tags.SubDomain] = {
                transactionId = msg.Tags.TransactionId,
                ttlSeconds = msg.Tags.TtlSeconds,
            }
            if not msg.Tags.Cast then
                -- Send SetRecord-Notice to the Sender if cast is not provided
                ao.send({
                    Target = msg.From,
                    Tags = {
                        Action = "SetRecord-Notice",
                        SubDomain = msg.Tags.SubDomain,
                        TransactionId = msg.Tags.TransactionId,
                        TtlSeconds = msg.Tags.TtlSeconds,
                    },
                })
            end
        elseif Controllers[msg.From] then
            Records[msg.Tags.SubDomain] = {
                transactionId = msg.Tags.TransactionId,
                ttlSeconds = msg.Tags.TtlSeconds,
            }
            if not msg.Tags.Cast then
                -- Send SetRecord-Notice to the Sender if cast is not provided
                ao.send({
                    Target = msg.From,
                    Tags = {
                        Action = "SetRecord-Notice",
                        SubDomain = msg.Tags.SubDomain,
                        TransactionId = msg.Tags.TransactionId,
                        TtlSeconds = msg.Tags.TtlSeconds,
                    },
                })
                -- Send SetRecord-Notice to the Owner if cast is not provided
                ao.send({
                    Target = env.Process.Id,
                    Tags = {
                        Action = "SetRecord-Notice",
                        Controller = msg.From,
                        SubDomain = msg.Tags.SubDomain,
                        TransactionId = msg.Tags.TransactionId,
                        TtlSeconds = msg.Tags.TtlSeconds,
                    },
                })
            end
        else
            ao.send({
                Target = msg.From,
                Tags = {
                    Action = "SetRecord-Error",
                    ["Message-Id"] = msg.Id,
                    Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE,
                },
            })
        end
    else
        ao.send({
            Target = msg.From,
            Tags = { Action = "SetRecord-Error", ["Message-Id"] = msg.Id, Error = responseMsg },
        })
    end
end)

Handlers.add("removeRecord", Handlers.utils.hasMatchingTag("Action", "Remove-Record"), function(msg, env)
    if msg.From == env.Process.Id or Controllers[msg.From] then
        if Records[msg.Tags.SubDomain] then
            Records[msg.Tags.SubDomain] = nil
            if not msg.Tags.Cast then
                -- Send SetRecord-Notice to the Sender if cast is not provided
                ao.send({
                    Target = msg.From,
                    Tags = { Action = "RemoveRecord-Notice", SubDomain = msg.Tags.SubDomain },
                })
            end
        else
            ao.send({
                Target = msg.From,
                Tags = {
                    Action = "RemoveRecord-Error",
                    ["Message-Id"] = msg.Id,
                    Error = "Subdomain does not exist in this process",
                },
            })
        end
    else
        ao.send({
            Target = msg.From,
            Tags = {
                Action = "RemoveRecord-Error",
                ["Message-Id"] = msg.Id,
                Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE,
            },
        })
    end
end)

Handlers.add("setController", Handlers.utils.hasMatchingTag("Action", "Set-Controller"), function(msg, env)
    if msg.From == env.Process.Id then
        Controllers[msg.Tags.Target] = true
        if not msg.Tags.Cast then
            -- Send SetController-Notice to the Sender if cast is not provided
            ao.send({
                Target = msg.From,
                Tags = { Action = "SetController-Notice", Target = msg.Tags.Target },
            })
            -- Send SetController-Notice to the Target
            ao.send({
                Target = msg.Tags.Target,
                Tags = { Action = "SetController-Notice", Sender = msg.From, Target = msg.Tags.Target },
            })
        end
    else
        ao.send({
            Target = msg.From,
            Tags = {
                Action = "SetController-Error",
                ["Message-Id"] = msg.Id,
                Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE,
            },
        })
    end
end)

Handlers.add("removeController", Handlers.utils.hasMatchingTag("Action", "Remove-Controller"), function(msg, env)
    if msg.From == env.Process.Id then
        Controllers[msg.Tags.Target] = nil
        if not msg.Tags.Cast then
            -- Send RemoveController-Notice to the Sender if cast is not provided
            ao.send({
                Target = msg.From,
                Tags = { Action = "RemoveController-Notice", Target = msg.Tags.Target },
            })
            -- Send RemoveController-Notice to the Target
            ao.send({
                Target = msg.Tags.Target,
                Tags = { Action = "RemoveController-Notice", Sender = msg.From, Target = msg.Tags.Target },
            })
        end
    else
        ao.send({
            Target = msg.From,
            Tags = {
                Action = "RemoveController-Error",
                ["Message-Id"] = msg.Id,
                Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE,
            },
        })
    end
end)
