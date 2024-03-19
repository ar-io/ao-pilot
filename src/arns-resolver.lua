local json = require('json')

-- URL configurations
SW_CACHE_URL = "https://api.arns.app/v1/contract/"

-- Process IDs for interacting with other services or processes
ARNS_PROCESS_ID = "COnVYFiqpycAJrFQbrKIgUEAZ1L98sF0h_26G8GxRpQ"
_0RBIT_SEND_PROCESS_ID = "WSXUI2JjYUldJ7CKq9wE1MGwXs-ldzlUlHOQszwQe0s"
_0RBIT_RECEIVE = "8aE3_6NJ_MU_q3fbhz2S6dA8PKQOSCe95Gt7suQ3j7U"

-- Initialize the NAMES and ID_NAME_MAPPING tables
NAMES = NAMES or {}
ID_NAME_MAPPING = ID_NAME_MAPPING or {}

--- Splits a string into two parts based on the last underscore character, intended to separate ARNS names into undername and rootname components.
-- @param str The string to be split.
-- @return Two strings: the rootname (before the last underscore) and the undername (after the last underscore).
-- If no underscore is found, returns the original string and nil.
function splitIntoTwoNames(str)
    -- Pattern explanation:
    -- (.-) captures any character as few times as possible up to the last underscore
    -- _ captures the underscore itself
    -- ([^_]+)$ captures one or more characters that are not underscores at the end of the string
    local underName, rootName = str:match("(.-)_([^_]+)$")

    if underName and rootName then
        return tostring(rootName), tostring(underName)
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
                ao.send({ Target = ARNS_PROCESS_ID, Action = "Get-Record", Name = name })
                return "Getting information for name: " .. name
            end
        elseif key == "data" then
            return function(name)
                name = string.lower(name)
                local rootName, underName = splitIntoTwoNames(name)

                if NAMES[rootName] == nil then
                    ao.send({ Target = ARNS_PROCESS_ID, Action = "Get-Record", Name = rootName })
                    print(name .. ' has not been resolved yet.  Resolving now...')
                    return nil
                elseif rootName and underName == nil then
                    if NAMES[rootName].process then
                        return NAMES[rootName].process.records['@'].transactionId
                    else
                        return NAMES[rootName].contract.records['@'].transactionId or
                            NAMES[rootName].contract.records['@'] or
                            nil
                        -- NAMES[rootName].contract.records['@'] is used to capture old ANT contracts
                    end
                elseif rootName and underName then
                    if NAMES[rootName].process then
                        return NAMES[rootName].process.records[underName].transactionId
                    else
                        return NAMES[rootName].contract.records[underName].transactionId or
                            NAMES[rootName].contract.records[underName] or nil
                        -- NAMES[rootName].contract.records[underName] is used to capture old ANT contracts
                    end
                end
            end
        elseif key == "owner" then
            return function(name)
                name = string.lower(name)
                local rootName, underName = splitIntoTwoNames(name)

                if NAMES[rootName] == nil then
                    ao.send({ Target = ARNS_PROCESS_ID, Action = "Get-Record", Name = rootName })
                    print(name .. ' has not been resolved yet.  Cannot get owner.  Resolving now...')
                    return nil
                else
                    return NAMES[rootName].processOwner or NAMES[rootName].contractOwner or nil
                end
            end
        elseif key == "id" then
            return function(name)
                name = string.lower(name)
                local rootName, underName = splitIntoTwoNames(name)
                if NAMES[rootName] == nil then
                    ao.send({ Target = ARNS_PROCESS_ID, Action = "Get-Record", Name = name })
                    print(name .. ' has not been resolved yet.  Cannot get id.  Resolving now...')
                    return nil
                else
                    return NAMES[rootName].processId or NAMES[rootName].contractTxId or nil
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

--- Requests JSON data from a specified URL via the Orbit process, an external service.
-- @param url The URL from which JSON data is to be fetched.
function fetchJsonDataFromOrbit(url)
    -- Validate URL to prevent sending invalid requests
    if type(url) ~= "string" or url == "" then
        print("Invalid URL provided for fetching JSON data.")
        return
    end
    print("Getting orbit data from: " .. url)
    -- Send a request to the Orbit process with the specified URL.
    ao.send({ Target = _0RBIT_SEND_PROCESS_ID, Action = "Get-Real-Data", Url = url })
end

local function isArNSGetRecordMessage(msg)
    if msg.From == ARNS_PROCESS_ID and msg.Action == "Record-Resolved" then
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
        Url = SW_CACHE_URL .. data.contractTxId
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
    if msg.From == _0RBIT_RECEIVE_PROCESS_ID and msg.Action == 'Receive-data-feed' then
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
