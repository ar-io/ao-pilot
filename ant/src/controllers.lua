local json = require(".json")
local utils = require(".utils")

Controllers = Controllers or {}

local controllers = {}

function controllers.setController(controller)
	utils.validateArweaveId(controller)

	for _, c in ipairs(Controllers) do
		assert(c ~= controller, "Controller already exists")
	end

	table.insert(Controllers, controller)
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
end

function controllers.getControllers(msg)
	utils.reply(json.encode(Controllers))
end

return controllers
