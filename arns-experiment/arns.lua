-- arns-experiment-1
local json = require('json')

Name = Name or 'Names-Experiment-1'
Ticker = Ticker or 'EXP1'
Denomination = Denomination or 1
Logo = Logo or 'Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A'
Listeners = Listeners or {}

DEFAULT_UNDERNAME_COUNT = 10
NamePrice = 1000
-- Uses 'token-experiement-1' process
TokenProcessId = 'gAC5hpUPh1v-oPJLnK3Km6-atrYlvI271bI-q0yZOnw'

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

-- Setup the default empty balances
if not Credits then
    Credits = {}
end

Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg, env)
    ao.send(
        { Target = msg.From, Tags = { Name = Name, Ticker = Ticker, Logo = Logo, ProcessOwner = Owner, Denomination = tostring(Denomination), NamesRegistered = tableCount(Records) } })
end)

Handlers.add('get-credits', Handlers.utils.hasMatchingTag('Action', 'Get-Credits'),
    function(msg) ao.send({ Target = msg.From, Data = json.encode(Credits) }) end)

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
    print("Valid? ", isValidBuyRecord)
    local name = msg.Tags.Name
    local namePrice = 1000
    -- local namePrice = calculateNamePrice(name)  -- Function to determine the price based on name length or other criteria

    -- Check if the user has enough credit
    if Credits[msg.From] and Credits[msg.From] >= namePrice then
        -- Deduct the name price from the user's credit
        Credits[msg.From] = Credits[msg.From] - namePrice

        -- Register the name to the user
        if msg.Tags.Type == 'permabuy' then
            Names[name] = {
                contractTxId = msg.Tags.contractTxId,
                type = msg.Tags.Type,
                startTimestamp = 0,
                undernames = DEFAULT_UNDERNAME_COUNT,
                purchasePrice = namePrice,
            }
        elseif msg.Tags.type == 'lease' then
            Names[name] = {
                contractTxId = msg.Tags.contractTxId,
                type = msg.Tags.Type,
                startTimestamp = 0,
                endTimestamp = 1000000000,
                undernames = DEFAULT_UNDERNAME_COUNT,
                purchasePrice = namePrice,
            }
        end
        -- Acknowledge the purchase
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Purchase-Ack', Name = name, RemainingBalance = tostring(Credits[msg.From]) }
        })
    else
        -- Insufficient balance to purchase the name
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Purchase-Error', ['Message-Id'] = msg.Id, Error = 'Insufficient Credit!' }
        })
    end
end)

-- Handler to receive deposits
Handlers.add('initiateDeposit', Handlers.utils.hasMatchingTag('Action', 'InitiateDeposit'), function(msg, env)
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

Handlers.add('Credit-Notice', Handlers.utils.hasMatchingTag('Action', 'Credit-Notice'), function(msg, env)
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
