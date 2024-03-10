local json = require('json')

Name = Name or 'Names-Experiment-1'
Ticker = Ticker or 'EXP1'
Denomination = Denomination or 1
Logo = Logo or 'Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A'
Listeners = Listeners or {}

TokenProcessId = 'R1EeI1Y23Qj1rOl2hnP7XW2DWNGYTEy4ZGpZIgBwYbk'

-- Setup the default record pointing to the ArNS landing page
if not Records then
    Records = {}

    Records["1984"] = {
        contractTxId = "I-cxQhfh0Zb9UqQNizC9PiLC41KpUeA9hjiVV02rQRw",
        endTimestamp = 1711122739,
        startTimestamp = 1694101828,
        type = "lease",
        undernames = 100,
        purchasePrice = 10000,
    }

    Records["warp-contracts"] = {
        contractTxId = "94hahtk_c6SENmICoZIqRrbQgam5jeRjZmsSBMGa_b4",
        purchasePrice = 2100,
        startTimestamp = 1700658387,
        type = "permabuy",
        undernames = 10
    }

    Records["vilenarios"] = {
        contractTxId = "l2gbTIYDmdEt8R6DsPndInjwTpfcRPcKhyzNpDqV-0",
        endTimestamp = 1711122739,
        startTimestamp = 1694101828,
        type = "lease",
        undernames = 100
    }

    Records["test-ant-1"] = {
        contractTxId = "YRK5D_VjPxhMRoCuC1jZNovUe5lZOiSLW74zU5MNMK8",
        endTimestamp = 1711122739,
        startTimestamp = 1694101828,
        type = "lease",
        undernames = 100
    }
end

Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg, env)
    ao.send(
        { Target = msg.From, Tags = { Name = Name, Ticker = Ticker, Logo = Logo, ProcessOwner = Owner, Denomination = tostring(Denomination), NamesRegistered = tableCount(Records) } })
end)

Handlers.add('record', Handlers.utils.hasMatchingTag('Action', 'Record'), function(msg)
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

Handlers.add('records', Handlers.utils.hasMatchingTag('Action', 'Records'),
    function(msg) ao.send({ Target = msg.From, Data = json.encode(Records) }) end)

Handlers.add('buyRecord', Handlers.utils.hasMatchingTag('Action', 'BuyRecord'), function(msg, env)
    local isValidBuyRecord, responseMsg = validateBuyRecord(msg)
    ao.send({ Target = msg.From, isValidBuyRecord = tostring(isValidBuyRecord), responseMsg = responseMsg })
end)

Handlers.add("Register", Handlers.utils.hasMatchingTag("Action", "Register"), function(msg)
    if Listeners[msg.From] then
        return
    end
    print("Registering " .. msg.From .. "for updates.")
    table.insert(Listeners, msg.From)
end)

Handlers.add("Unregister", Handlers.utils.hasMatchingTag("Action", "Unregister"), function(msg)
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
    if not msg.name or type(msg.name) ~= "string" then
        return false, "name is required and must be a string."
    end

    -- Validate 'name' pattern
    if not string.match(msg.name, "^([a-zA-Z0-9][a-zA-Z0-9-]{0,49}[a-zA-Z0-9]|[a-zA-Z0-9]{1})$") then
        return false, "name pattern is invalid."
    end

    -- Validate 'contractTxId' if present
    if msg.contractTxId and not string.match(msg.contractTxId, "^(atomic|[a-zA-Z0-9-_]{43})$") then
        return false, "contractTxId pattern is invalid."
    end

    -- Validate 'years' if present
    if msg.years then
        if type(msg.years) ~= "number" or msg.years % 1 ~= 0 or msg.years < 1 or msg.years > 5 then
            return false, "years must be an integer between 1 and 5."
        end
    end

    -- Validate 'type' if present
    if msg.type and not string.match(msg.type, "^(lease|permabuy)$") then
        return false, "type pattern is invalid."
    end

    -- Validate 'auction' if present
    if msg.auction and type(msg.auction) ~= "boolean" then
        return false, "auction must be a boolean."
    end

    return true, ""
end

function tableCount(table)
    local count = 0
    for _ in pairs(table) do count = count + 1 end
    return count
end
