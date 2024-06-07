local json = require(".json")
local utils = require(".utils")

Controllers = Controllers or {}

local controllers = {}

function controllers.setController(msg)
	local controller = msg.Tags.Controller

	local hasPermission, permissionErr = utils.hasPermission(msg)
	if hasPermission == false then
		print("permissionErr", permissionErr)
		return utils.reply(permissionErr)
	end

	local controllerValidity, controllerValidityError = utils.validateArweaveId(controller)
	if controllerValidity == false then
		print("id length" .. #controller)
		print("controllerValidityError", controllerValidityError)
		return utils.reply(controllerValidityError)
	end

	table.insert(Controllers, controller)
end

function controllers.removeController(msg)
	local controller = msg.Tags.Controller

	local hasPermission, permissionErr = utils.hasPermission(msg)
	if not hasPermission then
		return utils.reply(permissionErr)
	end

	local controllerValidity, controllerValidityError = utils.validateArweaveId(controllers)
	if controllerValidity == false then
		return utils.reply(controllerValidityError)
	end

	for i, v in ipairs(Controllers) do
		if v == controller then
			table.remove(Controllers, i)
			break
		end
	end
end

function controllers.getControllers(msg)
	utils.reply(json.encode(Controllers))
end

return controllers
