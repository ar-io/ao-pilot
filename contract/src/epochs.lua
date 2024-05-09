local epochs = { _version = '0.0.0 '}

-- A class like structure for fees that manages its state internally and can be injected into other classes depedenent on fees
Epochs = {}
Epochs.__index = Epochs
function Epochs:new(settings)
	local self = setmetatable({}, Epochs) -- make Account handle lookup
    self.settings = settings
	return self
end

function Epochs:getEpochPeriod()
    -- based on settings, return the current epoch period
end

return epochs
