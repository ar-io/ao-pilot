local json = require(".json")
local utils = require(".utils")

Controllers = Controllers or {}

local controllers = {}

function controllers.setController(controller)
	local controllerValidity, controllerValidityError = utils.validateArweaveId(controller)
	if controllerValidity == false then
		utils.reply(controllerValidityError)
		return
	end

	for _, c in ipairs(Controllers) do
		if c == controller then
			assert(c ~= controller, "Controller already exists")
		end
	end

	table.insert(Controllers, controller)
end

function controllers.removeController(controller)
	local controllerValidity, controllerValidityError = utils.validateArweaveId(controller)
	if controllerValidity == false then
		return utils.reply(controllerValidityError)
	end

	local controllerExists = false

	for i, v in ipairs(Controllers) do
		if v == controller then
			table.remove(Controllers, i)
			controllerExists = true
			break
		end
	end

	if not controllerExists then
		assert(controllerExists == true, "Controller does not exist")
	end
end

function controllers.getControllers(msg)
	utils.reply(json.encode(Controllers))
end

return controllers
