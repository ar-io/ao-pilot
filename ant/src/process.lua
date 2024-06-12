-- lib
Handlers = require(".handlers")
local _ao = require("ao")

local process = { _version = "0.2.0" }
-- wrap ao.send and ao.spawn for magic table
local aosend = _ao.send
local aospawn = _ao.spawn
_ao.send = function(msg)
	if msg.Data and type(msg.Data) == "table" then
		msg["Content-Type"] = "application/json"
		msg.Data = require("json").encode(msg.Data)
	end
	return aosend(msg)
end
_ao.spawn = function(module, msg)
	if msg.Data and type(msg.Data) == "table" then
		msg["Content-Type"] = "application/json"
		msg.Data = require("json").encode(msg.Data)
	end
	return aospawn(module, msg)
end

function Send(msg)
	_ao.send(msg)
	return "message added to outbox"
end

function Spawn(module, msg)
	if not msg then
		msg = {}
	end

	_ao.spawn(module, msg)
	return "spawn process request"
end

function Assign(assignment)
	_ao.assign(assignment)
	return "assignment added to outbox"
end

Seeded = Seeded or false

-- utils
local json = require(".json")
local utils = require(".ant-utils")

-- core modules
local balances = require(".balances")
local initialize = require(".initialize")
local records = require(".records")
local controllers = require(".controllers")

local camel = utils.camelCase
function Tab(msg)
	local inputs = {}
	for _, o in ipairs(msg.Tags) do
		if not inputs[o.name] then
			inputs[o.name] = o.value
		end
	end
	return inputs
end

function process.handle(msg, ao)
	ao.id = ao.env.Process.Id
	initialize.initializeProcessState(msg, ao.env)

	-- tagify msg
	msg.TagArray = msg.Tags
	msg.Tags = Tab(msg)
	-- tagify Process
	ao.env.Process.TagArray = ao.env.Process.Tags
	ao.env.Process.Tags = Tab(ao.env.Process)
	-- magic table - if Content-Type == application/json - decode msg.Data to a Table
	if msg.Tags["Content-Type"] and msg.Tags["Content-Type"] == "application/json" then
		msg.Data = require("json").decode(msg.Data or "{}")
	end
	-- init Errors
	Errors = Errors or {}
	-- clear Outbox
	ao.clearOutbox()

	-- Only trust messages from a signed owner or an Authority
	if msg.From ~= msg.Owner and not ao.isTrusted(msg) then
		Send({ Target = msg.From, Data = "Message is not trusted by this process!" })
		print("Message is not trusted! From: " .. msg.From .. " - Owner: " .. msg.Owner)
		return ao.result({})
	end

	Owner = Owner or ao.env.Process.Owner

	Name = Name or "Arweave Name Token"
	Ticker = Ticker or "ANT"
	Logo = Logo or "LOGO"
	Denomination = Denomination or 1
	TotalSupply = TotalSupply or 1

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
		Transfer = "Transfer",
		TotalSupply = "Total-Supply",
		CreditNotice = "Credit-Notice",
		-- not implemented
		Mint = "Mint",
		Burn = "Burn",
	}

	-- Handlers for contract functions
	-- TokenSpecActionMap

	Handlers.add(
		camel(TokenSpecActionMap.Transfer),
		utils.hasMatchingTag("Action", TokenSpecActionMap.Transfer),
		function(msg)
			local recipient = msg.Tags.Recipient
			local function checkAssertions()
				utils.validateArweaveId(recipient)
				utils.validateOwner(msg.From)
			end

			local inputStatus, inputResult = pcall(checkAssertions)

			if not inputStatus then
				ao.send({
					Target = msg.From,
					Tags = { Error = "Transfer-Error" },
					Error = tostring(inputResult),
					["Message-Id"] = msg.Id,
				})
				return
			end
			local transferStatus, transferResult = pcall(balances.transfer, recipient)

			if not transferStatus then
				ao.send({
					Target = msg.From,
					Action = "Transfer-Error",
					["Message-Id"] = msg.Id,
					Error = tostring(transferResult),
				})
				return
			elseif not msg.Cast then
				local creditNotice = utils.notices.credit(msg)
				local debitNotice = utils.notices.debit(msg)

				utils.notices.sendNotices({ creditNotice, debitNotice })
			end
		end
	)

	Handlers.add(
		camel(TokenSpecActionMap.Balance),
		utils.hasMatchingTag("Action", TokenSpecActionMap.Balance),
		function(msg)
			local balStatus, balRes = pcall(balances.balance, msg.Tags.Recipient or msg.From)
			if not balStatus then
				utils.reply({
					Tags = { Error = "Balance-Error" },
					Error = tostring(balRes),
				})
			end
		end
	)

	Handlers.add(
		camel(TokenSpecActionMap.Balances),
		utils.hasMatchingTag("Action", TokenSpecActionMap.Balances),
		function(msg)
			balances.balances()
		end
	)

	Handlers.add(
		camel(TokenSpecActionMap.TotalSupply),
		utils.hasMatchingTag("Action", TokenSpecActionMap.TotalSupply),
		function(msg)
			assert(msg.From ~= ao.id, "Cannot call Total-Supply from the same process!")

			ao.send({
				Target = msg.From,
				Action = "Total-Supply",
				Data = TotalSupply,
				Ticker = Ticker,
			})
		end
	)

	Handlers.add(camel(TokenSpecActionMap.Info), utils.hasMatchingTag("Action", TokenSpecActionMap.Info), function(msg)
		balances.info()
	end)

	Handlers.add(camel(TokenSpecActionMap.Mint), utils.hasMatchingTag("Action", TokenSpecActionMap.Mint), function(msg)
		balances.mint()
	end)

	Handlers.add(camel(TokenSpecActionMap.Burn), utils.hasMatchingTag("Action", TokenSpecActionMap.Burn), function(msg)
		balances.burn()
	end)

	-- ActionMap (ANT Spec)

	Handlers.add(camel(ActionMap.SetController), utils.hasMatchingTag("Action", ActionMap.SetController), function(msg)
		local hasPermission, permissionErr = pcall(utils.hasPermission, msg.From)
		if hasPermission == false then
			print("Permission Error", permissionErr)
			return utils.reply(permissionErr)
		end
		controllers.setController(msg.Tags.Controller)
	end)

	Handlers.add(
		camel(ActionMap.RemoveController),
		utils.hasMatchingTag("Action", ActionMap.RemoveController),
		function(msg)
			local hasPermission, permissionErr = pcall(utils.hasPermission, msg.From)
			if hasPermission == false then
				return utils.reply(permissionErr)
			end
			local removeControllerValidity, removeControllerStatus =
				pcall(controllers.removeController, msg.Tags.Controller)

			if not removeControllerValidity then
				return utils.reply(removeControllerStatus)
			end
		end
	)

	Handlers.add(
		camel(ActionMap.GetControllers),
		utils.hasMatchingTag("Action", ActionMap.GetControllers),
		function(msg)
			controllers.getControllers()
		end
	)

	Handlers.add(camel(ActionMap.SetRecord), utils.hasMatchingTag("Action", ActionMap.SetRecord), function(msg)
		local hasPermission, permissionErr = pcall(utils.hasPermission, msg.From)
		if hasPermission == false then
			return utils.reply(permissionErr)
		end
		local tags = msg.Tags
		local name, transactionId, ttlSeconds = tags["Sub-Domain"], tags["Transaction-Id"], tags["TTL-Seconds"]
		local setRecordStatus, setRecordResult = pcall(records.setRecord, name, transactionId, ttlSeconds)
		if not setRecordStatus then
			return utils.reply(setRecordResult)
		end
	end)

	Handlers.add(camel(ActionMap.RemoveRecord), utils.hasMatchingTag("Action", ActionMap.RemoveRecord), function(msg)
		local hasPermission, permissionErr = pcall(utils.hasPermission, msg.From)
		if hasPermission == false then
			return utils.reply(permissionErr)
		end
		records.removeRecord(msg.Tags.Name)
	end)

	Handlers.add(camel(ActionMap.GetRecord), utils.hasMatchingTag("Action", ActionMap.GetRecord), function(msg)
		local nameValidity, nameValidityError = pcall(records.getRecord, msg.Tags.Name)
		if nameValidity == false then
			return utils.reply(nameValidityError)
		end
	end)

	Handlers.add(camel(ActionMap.GetRecords), utils.hasMatchingTag("Action", ActionMap.GetRecords), function(msg)
		records.getRecords()
	end)

	Handlers.add(camel(ActionMap.SetName), utils.hasMatchingTag("Action", ActionMap.SetName), function(msg)
		local nameValidity, nameStatus = pcall(balances.setName, msg.Tags.Name)
		if not nameValidity then
			return utils.reply(nameStatus)
		end
	end)

	Handlers.add(camel(ActionMap.SetTicker), utils.hasMatchingTag("Action", ActionMap.SetTicker), function(msg)
		local tickerValidity, tickerStatus = pcall(balances.setTicker, msg.Tags.Ticker)
		if not tickerValidity then
			return utils.reply(tickerStatus)
		end
	end)

	Handlers.add(
		camel(ActionMap.InitializeState),
		utils.hasMatchingTag("Action", ActionMap.InitializeState),
		function(msg)
			local status, state = pcall(json.decode(msg.Data))
			assert(status, "Invalid state provided")
			initialize.initializeANTState(state.Data)
		end
	)

	-- call evaluate from handlers passing env

	local status, result = pcall(Handlers.evaluate, msg, ao.env)

	if not status then
		table.insert(Errors, result)
		return { Error = result }
		-- return {
		--   Output = {
		--     data = {
		--       prompt = Prompt(),
		--       json = 'undefined',
		--       output = result
		--     }
		--   },
		--   Messages = {},
		--   Spawns = {}
		-- }
	end

	return ao.result({})
end

return process
