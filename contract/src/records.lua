local records = { _version = '0.0.0 '}

-- A class like structure for fees that manages its state internally and can be injected into other classes depedenent on fees
Records = {}
Records.__index = Records
function Records:new()
	local self = setmetatable({}, Records) -- make Account handle lookup
	return self
end

function Records:saveRecord(record)
end

function Records:getRecords()
end

function Records:getRecord(name)
end

function Records:deleteRecord(name)
end

function Records:extendRecord()
end

return records
