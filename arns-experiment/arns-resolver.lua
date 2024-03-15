local json = require('json')
ARNS_PROCESS = "COnVYFiqpycAJrFQbrKIgUEAZ1L98sF0h_26G8GxRpQ"
ARNS_CACHE = "https://api.arns.app/v1/contract/"
_0RBIT_SEND = "WSXUI2JjYUldJ7CKq9wE1MGwXs-ldzlUlHOQszwQe0s"
_0RBIT_RECEIVE = "8aE3_6NJ_MU_q3fbhz2S6dA8PKQOSCe95Gt7suQ3j7U"

_ARNS = {}
ID_NAME_MAPPING = {}

local arnsMeta = {
    __index = function(t, key)
        -- sends Get-Record request
        if key == "resolve" then
            return function(name)
                print("resolving " .. name)
                Send({ Target = ARNS_PROCESS, Action = "Get-Record", Tags = { Name = name } })
                return "ArNS Name resolution requested."
            end
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
    Url = nil
    _ARNS[msg.Tags.Name] = {
        record = json.decode(msg.Data)
    }
    print("Updated record info")
    if msg.Tags.ContractTxId then
        Url = ARNS_CACHE .. msg.Tags.ContractTxId
        print("Fetching ownership info from smartweave cache")
        fetchJsonDataFromOrbit(Url)
        ID_NAME_MAPPING[msg.Tags.ContractTxId] = msg.Tags.Name
    end
    if msg.Tags.ProcessId then
        print("Fetching ownership info from process")
        ID_NAME_MAPPING[msg.Tags.ProcessId] = msg.Tags.Name
        ao.send({ Target = msg.Tags.ProcessId, Action = "Info" })
    end
end)

local function isANTInfoMessage(msg)
    local data, _, err = json.decode(msg.Data)
    print('got ant data')
    print(data)
    if msg.Tags.ProcessOwner and data.records then
        return true
    else
        return false
    end
end

Handlers.add("ReceiveANTProcessInfoMessage", isANTInfoMessage, function(msg)
    UpdatedInfo = {
        record = nil,
        process = nil,
        contract = nil
    }
    if _ARNS[ID_NAME_MAPPING[msg.From]].record then
        UpdatedInfo.record = ARNS[ID_NAME_MAPPING[msg.From]].record
    end
    if _ARNS[ID_NAME_MAPPING[msg.From]].contract then
        UpdatedInfo.contract = ARNS[ID_NAME_MAPPING[msg.From]].contract
    end
    UpdatedInfo.process = {
        processOwner = msg.Tags.ProcessOwner,
        records = json.decode(msg.Data)
    }
    _ARNS[ID_NAME_MAPPING[msg.From]] = UpdatedInfo
    print("Updated Process info")
    ID_NAME_MAPPING[msg.From] = nil
end)

local function is0rbitMessage(msg)
    local data, _, err = json.decode(msg.Data)
    print('got orbit data')
    print(data)
    if msg.From == _0RBIT_RECEIVE and msg.Action == 'Receive-data-feed' then
        return true
    else
        return false
    end
end

Handlers.add("Receive0rbitMessage", is0rbitMessage, function(msg)
    local data, _, err = json.decode(msg.Data)

    UpdatedInfo = {
        record = nil,
        process = nil,
        contract = nil
    }
    if _ARNS[ID_NAME_MAPPING[data.contractTxId]].record then
        UpdatedInfo.record = ARNS[ID_NAME_MAPPING[data.contractTxId]].record
    end
    if _ARNS[ID_NAME_MAPPING[data.contractTxId]].process then
        UpdatedInfo.process = ARNS[ID_NAME_MAPPING[data.contractTxId]].process
    end
    UpdatedInfo.contract = data.state
    _ARNS[ID_NAME_MAPPING[data.contractTxId]] = UpdatedInfo
    print("Updated Contract info")
    ID_NAME_MAPPING[data.contractTxId] = nil
end)
