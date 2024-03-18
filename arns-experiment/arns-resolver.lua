local json = require('json')
ARNS_PROCESS = "COnVYFiqpycAJrFQbrKIgUEAZ1L98sF0h_26G8GxRpQ"
ARNS_CACHE = "https://api.arns.app/v1/contract/"
_0RBIT_SEND = "WSXUI2JjYUldJ7CKq9wE1MGwXs-ldzlUlHOQszwQe0s"
_0RBIT_RECEIVE = "8aE3_6NJ_MU_q3fbhz2S6dA8PKQOSCe95Gt7suQ3j7U"

NAMES = NAMES or {}
ID_NAME_MAPPING = ID_NAME_MAPPING or {}

function splitIntoTwoNames(str)
    -- Pattern explanation:
    -- (.-) captures any character as few times as possible up to the last underscore
    -- _ captures the underscore itself
    -- ([^_]+)$ captures one or more characters that are not underscores at the end of the string
    local underName, rootName = str:match("(.-)_([^_]+)$")

    if underName and rootName then
        return tostring(underName), tostring(rootName)
    else
        -- If the pattern does not match (e.g., there's no underscore in the string),
        -- return the original string as the first chunk and nil as the second
        return str, nil
    end
end

local arnsMeta = {
    __index = function(t, key)
        -- sends Get-Record request
        if key == "resolve" then
            return function(name)
                name = string.lower(name)
                ao.send({ Target = ARNS_PROCESS, Action = "Get-Record", Name = name })
                return "Getting information for name: " .. name
            end
        elseif key == "data" then
            return function(name, contract)
                name = string.lower(name)
                local underName, rootName = splitIntoTwoNames(name)
                if underName ~= nil and rootName ~= nil and contract ~= nil then
                    if NAMES[rootName].contract.records[underName].transactionId then
                        return NAMES[rootName].contract.records[underName].transactionId
                    else
                        return NAMES[rootName].contract.records[underName]
                    end
                elseif underName ~= nil and rootName ~= nil and contract == nil then
                    if NAMES[rootName].process.records[underName].transactionId then
                        return NAMES[rootName].process.records[underName].transactionId
                    else
                        return NAMES[rootName].process.records[underName]
                    end
                elseif underName ~= nil and rootName == nil and contract ~= nil then
                    if NAMES[underName].contract.records['@'].transactionId then
                        return NAMES[underName].contract.records['@'].transactionId
                    else
                        return NAMES[underName].contract.records['@']
                    end
                elseif underName ~= nil and rootName == nil and contract == nil then
                    if NAMES[underName].process.records['@'].transactionId then
                        return NAMES[underName].process.records['@'].transactionId
                    else
                        return NAMES[underName].process.records['@']
                    end
                else
                    if rootName then
                        underName = rootName -- this is weird because the splitIntoTwoNames is funky
                    end
                    ao.send({ Target = ARNS_PROCESS, Action = "Get-Record", Name = underName })
                    return name .. ' has not been resolved yet.  Resolving now...'
                end
            end
        elseif key == "owner" then
            return function(name, contract)
                name = string.lower(name)
                local rootName, underName = splitIntoTwoNames(name)
                if underName then
                    rootName = underName
                end
                if NAMES[rootName] == nil then
                    ao.send({ Target = ARNS_PROCESS, Action = "Get-Record", Name = rootName })
                    return name .. ' has not been resolved yet.  Cannot get owner.  Resolving now...'
                end
                if contract == nil then
                    return NAMES[rootName].processOwner
                else
                    return NAMES[rootName].contractOwner
                end
            end
        elseif key == "id" then
            return function(name, contract)
                name = string.lower(name)
                local rootName, underName = splitIntoTwoNames(name)
                if underName then
                    rootName = underName
                end
                if NAMES[rootName] == nil then
                    ao.send({ Target = ARNS_PROCESS, Action = "Get-Record", Name = name })
                    return name .. ' has not been resolved yet.  Cannot get id.  Resolving now...'
                end
                if contract == nil then
                    return NAMES[rootName].processId
                else
                    return NAMES[rootName].contractTxId
                end
            end
        elseif key == "clear" then
            NAMES = {}
            return 'ArNS local name cache cleared.'
        else
            return nil
        end
    end
}

ARNS = setmetatable({}, arnsMeta)

local function fetchJsonDataFromOrbit(url)
    ao.send({ Target = _0RBIT_SEND, Action = "Get-Real-Data", Url = url })
end

local function isArNSGetRecordMessage(msg)
    if msg.From == ARNS_PROCESS and msg.Action == "Record-Resolved" then
        return true
    else
        return false
    end
end

Handlers.add("ReceiveArNSGetRecordMessage", isArNSGetRecordMessage, function(msg)
    local data = json.decode(msg.Data)
    if NAMES[msg.Tags.Name] == nil then
        NAMES[msg.Tags.Name] = {
            lastUpdated = msg.Timestamp,
            contractTxId = data.contractTxId,
            contractOwner = nil,
            contract = nil,
            processId = data.processId,
            processOwner = nil,
            process = nil,
            record = data
        }
    else
        NAMES[msg.Tags.Name].processId = data.processId
        NAMES[msg.Tags.Name].record = data
        NAMES[msg.Tags.Name].lastUpdated = msg.Timestamp
    end
    print("   Updated " .. msg.Tags.Name .. " with the latest ArNS-AO Registry info!")
    if data.contractTxId ~= nil then
        Url = ARNS_CACHE .. data.contractTxId
        print("   ...fetching more info from SmartWeave Cache (via Orbit)")
        fetchJsonDataFromOrbit(Url)
        ID_NAME_MAPPING[data.contractTxId] = msg.Tags.Name
    end
    if data.processId ~= nil and data.processId ~= '' then
        print("   ...fetching more info from ANT-AO process")
        ID_NAME_MAPPING[data.processId] = msg.Tags.Name
        ao.send({ Target = data.processId, Action = "Info" })
    end
end)

local function isANTInfoMessage(msg)
    if ID_NAME_MAPPING[msg.From] ~= nil then
        return true
    else
        return false
    end
end

Handlers.add("ReceiveANTProcessInfoMessage", isANTInfoMessage, function(msg)
    if msg.Action == 'Info-Notice' and NAMES[ID_NAME_MAPPING[msg.From]] then
        UpdatedInfo = NAMES[ID_NAME_MAPPING[msg.From]]
        UpdatedInfo.process = json.decode(msg.Data)
        UpdatedInfo.process.owner = msg.Tags.ProcessOwner
        UpdatedInfo.process.lastUpdated = msg.Timestamp
        NAMES[ID_NAME_MAPPING[msg.From]] = UpdatedInfo
        print("   Updated " .. ID_NAME_MAPPING[msg.From] .. " from the latest ANT-AO process!")
        ID_NAME_MAPPING[msg.From] = nil
    end
end)

local function is0rbitMessage(msg)
    if msg.From == _0RBIT_RECEIVE and msg.Action == 'Receive-data-feed' then
        return true
    else
        return false
    end
end

Handlers.add("Receive0rbitMessage", is0rbitMessage, function(msg)
    local data, _, err = json.decode(msg.Data)
    if NAMES[ID_NAME_MAPPING[data.contractTxId]] then
        UpdatedInfo = NAMES[ID_NAME_MAPPING[data.contractTxId]]
        UpdatedInfo.contract = data.state
        UpdatedInfo.contract.owner = data.state.owner
        UpdatedInfo.contract.lastUpdated = msg.Timestamp
        NAMES[ID_NAME_MAPPING[data.contractTxId]] = UpdatedInfo
        print("   Updated " .. ID_NAME_MAPPING[data.contractTxId] .. " from the SmartWeave Cache (via 0rbit)!")
        ID_NAME_MAPPING[data.contractTxId] = nil
    end
end)
