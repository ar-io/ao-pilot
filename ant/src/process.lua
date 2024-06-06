-- Adjust package.path to include the current directory
local json = require("ant.src.json")
local balances = require("ant.src.balances")
local utils = require("ant.src.utils")
local initialize = require("ant.src.initialize")
local records = require("ant.src.records")
local controllers = require("ant.src.controllers")

Name = Name or "Arweave Name Token"
Ticker = Ticker or "ANT"
Logo = Logo or "LOGO"
Denomination = Denomination or 1

local ActionMap = {
	-- write
	SetController = "SetController",
	RemoveController = "RemoveController",
	SetRecord = "SetRecord",
	RemoveRecord = "RemoveRecord",
	SetName = "SetName",
	SetTicker = "SetTicker",
	--- initialization method for bootstrapping the contract from other platforms ---
	InitializeState = "InitializeState",
	-- read
	GetControllers = "GetControllers",
	GetRecord = "GetRecord",
	GetRecords = "GetRecords",
}

local TokenSpecActionMap = {
	Info = "Info",
	Balances = "Balances",
	Balance = "Balance",
	Mint = "Mint",
	Transfer = "Transfer",
}

-- Handlers for contract functions
-- TokenSpecActionMap
Handlers.add(TokenSpecActionMap.Transfer, utils.hasMatchingTag("Action", TokenSpecActionMap.Transfer), function(msg)
	balances.transfer(msg)
end)

Handlers.add(TokenSpecActionMap.Balance, utils.hasMatchingTag("Action", TokenSpecActionMap.Balance), function(msg)
	balances.balance(msg)
end)

Handlers.add(TokenSpecActionMap.Balances, utils.hasMatchingTag("Action", TokenSpecActionMap.Balances), function(msg)
	balances.balances(msg)
end)

Handlers.add(TokenSpecActionMap.Mint, utils.hasMatchingTag("Action", TokenSpecActionMap.Mint), function(msg)
	balances.mint(msg)
end)

Handlers.add(TokenSpecActionMap.Info, utils.hasMatchingTag("Action", TokenSpecActionMap.Info), function(msg)
	balances.info(msg)
end)

-- ActionMap (ANT Spec)

Handlers.add(ActionMap.SetController, utils.hasMatchingTag("Action", ActionMap.SetControllers), function(msg)
	controllers.setControllers(msg)
end)

Handlers.add(ActionMap.GetControllers, utils.hasMatchingTag("Action", ActionMap.GetControllers), function(msg)
	controllers.getControllers(msg)
end)

Handlers.add(ActionMap.SetRecord, utils.hasMatchingTag("Action", ActionMap.SetRecord), function(msg)
	records.setRecord(msg)
end)

Handlers.add(ActionMap.RemoveRecord, utils.hasMatchingTag("Action", ActionMap.RemoveRecord), function(msg)
	records.removeRecord(msg)
end)

Handlers.add(ActionMap.GetRecord, utils.hasMatchingTag("Action", ActionMap.GetRecord), function(msg)
	records.getRecord(msg)
end)

Handlers.add(ActionMap.GetRecords, utils.hasMatchingTag("Action", ActionMap.GetRecords), function(msg)
	records.getRecords(msg)
end)

Handlers.add(ActionMap.SetName, utils.hasMatchingTag("Action", ActionMap.SetName), function(msg)
	balances.setName(msg)
end)

Handlers.add(ActionMap.SetTicker, utils.hasMatchingTag("Action", ActionMap.SetTicker), function(msg)
	balances.setTicker(msg)
end)

Handlers.add(ActionMap.InitializeState, utils.hasMatchingTag("Action", ActionMap.InitializeState), function(msg)
	local status, state = pcall(json.decode(msg.Data))
	assert(status, "Invalid state provided")
	initialize.initializeState(state.Data)
end)