-- Adjust package.path to include the current directory
-- utils
local json = require(".json")
local utils = require(".utils")

-- core modules
local balances = require(".balances")
local initialize = require(".initialize")
local records = require(".records")
local controllers = require(".controllers")

Name = Name or "Arweave Name Token"
Ticker = Ticker or "ANT"
Logo = Logo or "LOGO"
Denomination = Denomination or 1

local ActionMap = {
	-- write
	SetController = "Set-Controller",
	RemoveController = "Remove-Controller",
	SetRecord = "Set-Record",
	RemoveRecord = "Remove-Record",
	SetName = "Se-Name",
	SetTicker = "Set-Ticker",
	--- initialization method for bootstrapping the contract from other platforms ---
	InitializeState = "Initialize-State",
	-- read
	GetControllers = "Get-Controllers",
	GetRecord = "Get-Record",
	GetRecords = "Get-Records",
}

local TokenSpecActionMap = {
	Info = "Info",
	Balances = "Balances",
	Balance = "Balance",
	Mint = "Mint",
	Transfer = "Transfer",
	CreditNotice = "Credit-Notice",
}

-- Handlers for contract functions
-- TokenSpecActionMap
Handlers.add(TokenSpecActionMap.Transfer, utils.hasMatchingTag("Action", TokenSpecActionMap.Transfer), function(msg)
	local recipient = msg.Tags.Recipient
	local function checkAssertions()
		assert(recipient, "Recipient is required")
		assert(utils.validateArweaveId(recipient), "Invalid recipient")
		assert(Balances[msg.From], "Sender is not the owner")
	end

	local inputStatus, inputResult = pcall(checkAssertions)

	if not inputStatus then
		ao.send({
			Target = msg.From,
			Tags = { Error = "Input-Error" },
			Data = tostring(inputResult),
		})
		return
	end
	local transferStatus, transferResult = pcall(balances.transfer, recipient)

	if not transferStatus then
		ao.send({
			Target = msg.From,
			Tags = { Error = "Transfer-Error" },
			Data = tostring(transferResult),
		})
		return
	else
		ao.send({
			Target = recipient,
			Tags = { Action = TokenSpecActionMap.CreditNotice },
			Data = "Transfer successful",
		})
	end
end)

Handlers.add(TokenSpecActionMap.Balance, utils.hasMatchingTag("Action", TokenSpecActionMap.Balance), function(msg)
	balances.balance(msg.Tags.Address or msg.From)
end)

Handlers.add(TokenSpecActionMap.Balances, utils.hasMatchingTag("Action", TokenSpecActionMap.Balances), function(msg)
	balances.balances()
end)

Handlers.add(TokenSpecActionMap.Mint, utils.hasMatchingTag("Action", TokenSpecActionMap.Mint), function(msg)
	balances.mint()
end)

Handlers.add(TokenSpecActionMap.Info, utils.hasMatchingTag("Action", TokenSpecActionMap.Info), function(msg)
	balances.info()
end)

-- ActionMap (ANT Spec)

Handlers.add(ActionMap.SetController, utils.hasMatchingTag("Action", ActionMap.SetController), function(msg)
	local hasPermission, permissionErr = pcall(utils.hasPermission, msg.From)
	if hasPermission == false then
		print("Permission Error", permissionErr)
		return utils.reply(permissionErr)
	end
	controllers.setController(msg.Tags.Controller)
end)

Handlers.add(ActionMap.RemoveController, utils.hasMatchingTag("Action", ActionMap.RemoveController), function(msg)
	local hasPermission, permissionErr = pcall(utils.hasPermission, msg.From)
	if hasPermission == false then
		return utils.reply(permissionErr)
	end
	local removeControllerValidity, removeControllerStatus = pcall(controllers.removeController, msg.Tags.Controller)

	if not removeControllerValidity then
		return utils.reply(removeControllerStatus)
	end
end)

Handlers.add(ActionMap.GetControllers, utils.hasMatchingTag("Action", ActionMap.GetControllers), function(msg)
	controllers.getControllers()
end)

Handlers.add(ActionMap.SetRecord, utils.hasMatchingTag("Action", ActionMap.SetRecord), function(msg)
	local hasPermission, permissionErr = pcall(utils.hasPermission, msg.From)
	if hasPermission == false then
		return utils.reply(permissionErr)
	end
	local tags = msg.Tags
	local name, transactionId, ttlSeconds = tags.Name, tags["Transaction-Id"], tags["TTL-Seconds"]
	local setRecordStatus, setRecordResult = pcall(records.setRecord, name, transactionId, ttlSeconds)
	if not setRecordStatus then
		return utils.reply(setRecordResult)
	end
end)

Handlers.add(ActionMap.RemoveRecord, utils.hasMatchingTag("Action", ActionMap.RemoveRecord), function(msg)
	local hasPermission, permissionErr = pcall(utils.hasPermission, msg.From)
	if hasPermission == false then
		return utils.reply(permissionErr)
	end
	records.removeRecord(msg.Tags.Name)
end)

Handlers.add(ActionMap.GetRecord, utils.hasMatchingTag("Action", ActionMap.GetRecord), function(msg)
	local nameValidity, nameValidityError = pcall(records.getRecord, msg.Tags.Name)
	if nameValidity == false then
		return utils.reply(nameValidityError)
	end
end)

Handlers.add(ActionMap.GetRecords, utils.hasMatchingTag("Action", ActionMap.GetRecords), function(msg)
	records.getRecords()
end)

Handlers.add(ActionMap.SetName, utils.hasMatchingTag("Action", ActionMap.SetName), function(msg)
	local nameValidity, nameStatus = pcall(balances.setName, msg.Tags.Name)
	if not nameValidity then
		return utils.reply(nameStatus)
	end
end)

Handlers.add(ActionMap.SetTicker, utils.hasMatchingTag("Action", ActionMap.SetTicker), function(msg)
	local tickerValidity, tickerStatus = pcall(balances.setTicker, msg.Tags.Ticker)
	if not tickerValidity then
		return utils.reply(tickerStatus)
	end
end)

Handlers.add(ActionMap.InitializeState, utils.hasMatchingTag("Action", ActionMap.InitializeState), function(msg)
	local status, state = pcall(json.decode(msg.Data))
	assert(status, "Invalid state provided")
	initialize.initializeState(state.Data)
end)
