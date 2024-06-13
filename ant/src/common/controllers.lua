local json = require(".common.json")
local utils = require(".common.utils")

local controllers = {}

function controllers.setController(controller)
	utils.validateArweaveId(controller)

	for _, c in ipairs(Controllers) do
		assert(c ~= controller, "Controller already exists")
	end

	table.insert(Controllers, controller)
	return "Controller added"
end

function controllers.removeController(controller)
	utils.validateArweaveId(controller)
	local controllerExists = false

	for i, v in ipairs(Controllers) do
		if v == controller then
			table.remove(Controllers, i)
			controllerExists = true
			break
		end
	end

	assert(controllerExists ~= nil, "Controller does not exist")
	return "Controller removed"
end

function controllers.getControllers()
	return json.encode(Controllers)
end

return controllers
