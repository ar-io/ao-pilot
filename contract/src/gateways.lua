local gateways = { _version = '0.0.0 '}

-- A class like structure for fees that manages its state internally and can be injected into other classes depedenent on fees
Gateways = {}
Gateways.__index = Gateways
function Gateways:new(settings)
	local self = setmetatable({}, Gateways) -- make Account handle lookup
    self.gateways = {}
    self.settings = settings
	return self
end

function Gateways:saveGateway(gateway)
    self.gateways[gateway.address] = gateway
end

function Gateways:getGateways()
    return self.gateways
end

function Gateways:getGateway(address)
    if(self.gateways[address]) then
        return self.gateways[address]
    end
    return nil
end

function Gateways:setLeaving(address)
    if(self.gateways[address]) then
        self.gateways[address]:setLeaving()
    end
end

function Gateways:getPrescribedObservers()
    local observers = {}
    for address, gateway in pairs(self.gateways) do
        if(gateway:isActive()) then
            table.insert(observers, gateway.observerWallet)
        end
    end
    return observers
end

function Gateways:deleteGateway(address)
    if(self.gateways[address]) then
        self.gateways[address] = nil
    end
end


Gateway = {}
Gateway.__index = Gateways
function Gateway:new(address, observerWallet, settings)
	local self = setmetatable({}, Gateway) -- make Account handle lookup
    self.observerWallet = observerWallet
    self.address = address
    self.settings = settings
	return self
end

function Gateway:updateSettings(settings)
    self.settings = settings
end

function Gateway:updateObserverWallet(observerWallet)
    self.observerWallet = observerWallet
end

function Gateway:setLeaving()
    self.status = 'leaving'
    self.endTimestamp = os.clock() + self.settings.leaveLength
end

function Gateway:isLeaving()
    return self.status == 'leaving'
end

function Gateway:isActive()
    return self.status == 'active'
end

return gateways
