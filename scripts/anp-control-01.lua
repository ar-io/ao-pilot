local json = require("json")
local ao = require('ao')

-- ANP-RESOLVE-01 Constants and Objects
local constants = {}

constants.UNDERNAME_DOES_NOT_EXIST_MESSAGE = "Record does not exist!"
constants.MAX_UNDERNAME_LENGTH = 61
constants.MIN_TTL_SECONDS = 900
constants.MAX_TTL_SECONDS = 3600
constants.INVALID_TTL_MESSAGE = "Invalid TTL. TLL must be an integer between "
	.. constants.MIN_TTL_SECONDS
	.. " and "
	.. constants.MAX_TTL_SECONDS
	.. " seconds"
constants.UNDERNAME_REGEXP = "^(?:@|[a-zA-Z0-9][a-zA-Z0-9-_]{0,"
	.. (constants.MAX_UNDERNAME_LENGTH - 2)
	.. "}[a-zA-Z0-9])$"

-- Setup the default record pointing to the ArNS landing page
if not Records then
	Records = {}
	Records["@"] = {
		transactionId = "UyC5P5qKPZaltMmmZAWdakhlDXsBF6qmyrbWYFchRTk",
		ttlSeconds = 3600,
	}
end

local ANPResolveSpecActionMap = {
	-- read actions
	Record = "Record",
	Records = "Records",
	State = "State",
}

local records = {}
function records.validateUndername(name)
	local valid = string.match(name, constants.UNDERNAME_REGEXP) == nil
	assert(valid ~= false, constants.UNDERNAME_DOES_NOT_EXIST_MESSAGE)
end

function records.validateTTLSeconds(ttl)
	local valid = type(ttl) == "number" and ttl >= constants.MIN_TTL_SECONDS and ttl <= constants.MAX_TTL_SECONDS
	return assert(valid ~= false, constants.INVALID_TTL_MESSAGE)
end

function records.getRecord(name)
	records.validateUndername(name)
	assert(Records[name] ~= nil, constants.UNDERNAME_DOES_NOT_EXIST_MESSAGE)

	return json.encode(Records[name])
end

function records.getRecords()
	return json.encode(Records)
end

-- ANP-CONTROL-01 Constants and Objects
constants.ARWEAVE_ID_REGEXP = "^[a-zA-Z0-9-_]{43}$"
constants.INVALID_ARWEAVE_ID_MESSAGE = "Invalid Arweave ID"

Controllers = Controllers or { Owner }

local ANPControlSpecActionMap = {
	-- read actions
	Controllers = "Controllers",
	-- write actions
	AddController = "Add-Controller",
	RemoveController = "Remove-Controller",
	SetRecord = "Set-Record",
	RemoveRecord = "Remove-Record",
}

function records.validateArweaveId(id)
	local valid = string.match(id, constants.ARWEAVE_ID_REGEXP) == nil

	assert(valid == true, constants.INVALID_ARWEAVE_ID_MESSAGE)
end

function records.setRecord(name, transactionId, ttlSeconds)
	local nameValidity, nameValidityError = pcall(records.validateUndername, name)
	assert(nameValidity ~= false, nameValidityError)
	local targetIdValidity, targetValidityError = pcall(records.validateArweaveId, transactionId)
	assert(targetIdValidity ~= false, targetValidityError)
	local ttlSecondsValidity, ttlValidityError = pcall(records.validateTTLSeconds, ttlSeconds)
	assert(ttlSecondsValidity ~= false, ttlValidityError)

	local recordsCount = #Records

	if recordsCount >= 10000 then
		error("Max records limit of 10,000 reached, please delete some records to make space")
	end

	Records[name] = {
		transactionId = transactionId,
		ttlSeconds = ttlSeconds,
	}

	return json.encode({
		transactionId = transactionId,
		ttlSeconds = ttlSeconds,
	})
end

function records.removeRecord(name)
	local nameValidity, nameValidityError = pcall(records.validateUndername, name)
	assert(nameValidity ~= false, nameValidityError)
	Records[name] = nil
	return json.encode(Records)
end

function assertHasPermission(from)
	for _, c in ipairs(Controllers) do
		if c == from then
			-- if is controller, return true
			return
		end
	end
	if Owner == from then
		return
	end
	if ao.env.Process.Id == from then
		return
	end
	assert(false, "Only controllers and owners can set controllers, records, and change metadata.")
end

local controllers = {}
function controllers.removeController(controller)
	local controllerExists = false

	for i, v in ipairs(Controllers) do
		if v == controller then
			table.remove(Controllers, i)
			controllerExists = true
			break
		end
	end

	assert(controllerExists ~= nil, "Controller does not exist")
	return json.encode(Controllers)
end

function controllers.setController(controller)
	for _, c in ipairs(Controllers) do
		assert(c ~= controller, "Controller already exists")
	end

	table.insert(Controllers, controller)
	return json.encode(Controllers)
end

function controllers.getControllers()
	return json.encode(Controllers)
end

-- ANP-RESOLVE-01 Handlers
Handlers.add(ANPResolveSpecActionMap.Record, Handlers.utils.hasMatchingTag("Action", ANPResolveSpecActionMap.Record),
	function(msg)
		local nameStatus, nameRes = pcall(records.getRecord, msg.Tags["Sub-Domain"])

		if not nameStatus then
			ao.send({
				Target = msg.From,
				Action = "Invalid-Record-Notice",
				Data = nameRes,
				Error = "Record-Error",
				["Message-Id"] = msg.Id,
			})
			return
		end

		local recordNotice = {
			Target = msg.From,
			Action = "Record-Notice",
			Name = msg.Tags["Sub-Domain"],
			Data = nameRes,
		}

		-- Add forwarded tags to the Record Notice messages
		for tagName, tagValue in pairs(msg) do
			-- Tags beginning with "X-" are forwarded
			if string.sub(tagName, 1, 2) == "X-" then
				recordNotice[tagName] = tagValue
			end
		end

		-- Send Record-Notice
		ao.send(recordNotice)
	end)

Handlers.add(ANPResolveSpecActionMap.Records, Handlers.utils.hasMatchingTag("Action", ANPResolveSpecActionMap.Records),
	function(msg)
		local records = records.getRecords()

		-- Credit-Notice message template, that is sent to the Recipient of the transfer
		local recordsNotice = {
			Target = msg.From,
			Action = "Records-Notice",
			Data = records,
		}

		-- Add forwarded tags to the Records Notice messages
		for tagName, tagValue in pairs(msg) do
			-- Tags beginning with "X-" are forwarded
			if string.sub(tagName, 1, 2) == "X-" then
				recordsNotice[tagName] = tagValue
			end
		end

		-- Send Records-Notice
		ao.send(recordsNotice)
	end)

Handlers.add(ANPResolveSpecActionMap.State, Handlers.utils.hasMatchingTag("Action", ANPResolveSpecActionMap.State),
	function(msg)
		local state = {
			Records = Records,
			Owner = Owner,
		}

		local stateNotice = {
			Target = msg.From,
			Action = "State-Notice",
			Data = json.encode(state),
		}

		-- Add forwarded tags to the State-Notice messages
		for tagName, tagValue in pairs(msg) do
			-- Tags beginning with "X-" are forwarded
			if string.sub(tagName, 1, 2) == "X-" then
				stateNotice[tagName] = tagValue
			end
		end

		-- Send State-Notice
		ao.send(stateNotice)
	end)

-- ANP-CONTROL-01 Handlers
Handlers.add(ANPControlSpecActionMap.Controllers,
	Handlers.utils.hasMatchingTag("Action", ANPControlSpecActionMap.Controllers),
	function(msg)
		local controllersNotice = {
			Target = msg.From,
			Action = "Controllers-Notice",
			Data = controllers.getControllers()
		}

		-- Add forwarded tags to the State-Notice messages
		for tagName, tagValue in pairs(msg) do
			-- Tags beginning with "X-" are forwarded
			if string.sub(tagName, 1, 2) == "X-" then
				controllersNotice[tagName] = tagValue
			end
		end

		-- Send Controllers-Notice
		ao.send(controllersNotice)
	end)

Handlers.add(ANPControlSpecActionMap.AddController,
	Handlers.utils.hasMatchingTag("Action", ANPControlSpecActionMap.AddController),
	function(msg)
		local assertHasPermission, permissionErr = pcall(assertHasPermission, msg.From)
		if assertHasPermission == false then
			return ao.send({
				Target = msg.From,
				Action = "Invalid-Add-Controller-Notice",
				Error = "Add-Controller-Error",
				["Message-Id"] = msg.Id,
				Data = permissionErr,
			})
		end
		local controllerStatus, controllerRes = pcall(controllers.setController, msg.Tags.Controller)
		if not controllerStatus then
			ao.send({
				Target = msg.From,
				Action = "Invalid-Add-Controller-Notice",
				Error = "Add-Controller-Error",
				["Message-Id"] = msg.Id,
				Data = controllerRes,
			})
			return
		end

		local addControllerNotice = {
			Target = msg.From,
			Action = "Add-Controller-Notice",
			Data = controllerRes,
		}

		-- Add forwarded tags to the Add-Controller-Notice messages
		for tagName, tagValue in pairs(msg) do
			-- Tags beginning with "X-" are forwarded
			if string.sub(tagName, 1, 2) == "X-" then
				addControllerNotice[tagName] = tagValue
			end
		end

		-- Send Add-Controller-Notice
		ao.send(addControllerNotice)
	end)

Handlers.add(ANPControlSpecActionMap.RemoveController,
	Handlers.utils.hasMatchingTag("Action", ANPControlSpecActionMap.RemoveController),
	function(msg)
		local assertHasPermission, permissionErr = pcall(assertHasPermission, msg.From)
		if assertHasPermission == false then
			return ao.send({
				Target = msg.From,
				Action = "Invalid-Remove-Controller-Notice",
				Data = permissionErr,
				Error = "Remove-Controller-Error",
				["Message-Id"] = msg.Id,
			})
		end
		local removeStatus, removeRes = pcall(controllers.removeController, msg.Tags.Controller)
		if not removeStatus then
			ao.send({
				Target = msg.From,
				Action = "Invalid-Remove-Controller-Notice",
				Data = removeRes,
				Error = "Remove-Controller-Error",
				["Message-Id"] = msg.Id,
			})
			return
		end

		local removeControllerNotice = {
			Target = msg.From,
			Action = "Remove-Controller-Notice",
			Data = removeRes
		}

		-- Add forwarded tags to the Remove-Controller-Notice messages
		for tagName, tagValue in pairs(msg) do
			-- Tags beginning with "X-" are forwarded
			if string.sub(tagName, 1, 2) == "X-" then
				removeControllerNotice[tagName] = tagValue
			end
		end

		-- Send Remove-Controller-Notice
		ao.send(removeControllerNotice)
	end)

Handlers.add(ANPControlSpecActionMap.SetRecord,
	Handlers.utils.hasMatchingTag("Action", ANPControlSpecActionMap.SetRecord),
	function(msg)
		local assertHasPermission, permissionErr = pcall(assertHasPermission, msg.From)
		if assertHasPermission == false then
			return ao.send({
				Target = msg.From,
				Action = "Invalid-Set-Record-Notice",
				Data = permissionErr,
				Error = "Set-Record-Error",
				["Message-Id"] = msg.Id,
			})
		end
		local tags = msg.Tags
		local name, transactionId, ttlSeconds =
			tags["Sub-Domain"], tags["Transaction-Id"], tonumber(tags["TTL-Seconds"])

		local setRecordStatus, setRecordResult = pcall(records.setRecord, name, transactionId, ttlSeconds)
		if not setRecordStatus then
			ao.send({
				Target = msg.From,
				Action = "Invalid-Set-Record-Notice",
				Data = setRecordResult,
				Error = "Set-Record-Error",
				["Message-Id"] = msg.Id,
			})
			return
		end

		local setRecordNotice = {
			Target = msg.From,
			Action = "Set-Record-Notice",
			Data = setRecordResult
		}

		-- Add forwarded tags to the Set-Record-Notice messages
		for tagName, tagValue in pairs(msg) do
			-- Tags beginning with "X-" are forwarded
			if string.sub(tagName, 1, 2) == "X-" then
				setRecordNotice[tagName] = tagValue
			end
		end

		-- Send Set-Record-Notice
		ao.send(setRecordNotice)
	end)

Handlers.add(ANPControlSpecActionMap.RemoveRecord,
	Handlers.utils.hasMatchingTag("Action", ANPControlSpecActionMap.RemoveRecord),
	function(msg)
		local assertHasPermission, permissionErr = pcall(assertHasPermission, msg.From)
		if assertHasPermission == false then
			return ao.send({ Target = msg.From, Action = "Invalid-Remove-Record-Notice", Data = permissionErr })
		end
		local removeRecordStatus, removeRecordResult = pcall(records.removeRecord, msg.Tags["Sub-Domain"])
		if not removeRecordStatus then
			ao.send({
				Target = msg.From,
				Action = "Invalid-Remove-Record-Notice",
				Data = removeRecordResult,
				Error = "Remove-Record-Error",
				["Message-Id"] = msg.Id,
			})
		else
			local removeRecordNotice = {
				Target = msg.From,
				Action = 'Remove-Record-Notice',
				Data = removeRecordResult
			}

			-- Add forwarded tags to the Remove-Record-Notice messages
			for tagName, tagValue in pairs(msg) do
				-- Tags beginning with "X-" are forwarded
				if string.sub(tagName, 1, 2) == "X-" then
					removeRecordNotice[tagName] = tagValue
				end
			end

			-- Send Remove-Record-Notice
			ao.send(removeRecordNotice)
		end
	end)
