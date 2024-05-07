-- Adjust package.path to include the current directory
local token = require("token")
local arns = require("arns")
local gar = require("gar")
local utils = require("utils")
local json = require("json")

local ActionMap = {
	Transfer = "Transfer",
	GetBalance = "GetBalance",
	GetBalances = "GetBalances",
	Vault = "Vault",
	BuyRecord = "BuyRecord",
	SubmitAuctionBid = "SubmitAuctionBid",
	ExtendLease = "ExtendLease",
	IncreaseUndernameCount = "IncreaseUndernameCount",
	JoinNetwork = "JoinNetwork",
	LeaveNetwork = "LeaveNetwork",
	IncreaseOperatorStake = "IncreaseOperatorStake",
	DecreaseOperatorStake = "DecreaseOperatorStake",
	UpdateGatewaySettings = "UpdateGatewaySettings",
	SaveObservations = "SaveObservations",
}

-- Handlers for contract functions
Handlers.add(ActionMap.Transfer, utils.hasMatchingTag("Action", ActionMap.Transfer), function(msg)
	local result, err = token.transfer(msg.Tags.Recipient, msg.From, tonumber(msg.Tags.Quantity))
	if result and not msg.Cast then
		-- Send Debit-Notice to the Sender
		ao.send({
			Target = msg.From,
			Action = 'Debit-Notice',
			Recipient = msg.Tags.Recipient,
			Quantity = tostring(msg.Tags.Quantity),
			Data = "You transferred " .. msg.Tags.Quantity .. " to " .. msg.Tags.Recipient
		})
		if msg.Tags.Function and msg.Tags.Parameters then
			-- Send Credit-Notice to the Recipient and include the function and parameters tags
			ao.send({
				Target = msg.Tags.Recipient,
				Action = 'Credit-Notice',
				Sender = msg.From,
				Quantity = tostring(msg.Tags.Quantity),
				Function = tostring(msg.Tags.Function),
				Parameters = msg.Tags.Parameters,
				Data = "You received " ..
					msg.Tags.Quantity .. " from " .. msg.Tags.Recipient ..
					" with the instructions for function " .. msg.Tags.Function ..
					" with the parameters " .. msg.Tags.Parameters
			})
		else
			-- Send Credit-Notice to the Recipient
			ao.send({
				Target = msg.Tags.Recipient,
				Action = 'Credit-Notice',
				Sender = msg.From,
				Quantity = tostring(msg.Tags.Quantity),
				Data = "You received " ..
					msg.Tags.Quantity ..
					" from " .. msg.Tags.Recipient
			})
		end
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Transfer-Error', ['Message-Id'] = msg.Id, Error = tostring(err) },
			Data = tostring(err)
		})
	end
end)

Handlers.add(ActionMap.GetBalance, utils.hasMatchingTag('Action', ActionMap.GetBalance), function(msg)
	local result = token.getBalance(msg.Tags.Target, msg.From)
	ao.send({
		Target = msg.From,
		Balance = tostring(result),
		Data = json.encode(tonumber(result))
	})
end)

Handlers.add(ActionMap.GetBalances, utils.hasMatchingTag('Action', ActionMap.GetBalances), function(msg)
	local result = token.getBalances()
	ao.send({ Target = msg.From, Data = json.encode(result) })
end)

Handlers.add(ActionMap.Vault, utils.hasMatchingTag("Action", ActionMap.Vault), function(msg)
	token.vault(msg)
end)

Handlers.add(ActionMap.BuyRecord, utils.hasMatchingTag("Action", ActionMap.BuyRecord), function(msg)
	local result, err = arns.buyRecord(msg.Tags.Name, msg.Tags.PurchaseType, msg.Tags.Years, msg.From, msg.Tags.Auction,
		msg.Timestamp, msg.Tags.ProcessId)
	if err then
		ao.send({
			Target = msg.From,
			Tags = { Action = 'ArNS-Invalid-Buy-Record-Notice', Name = tostring(msg.Tags.Name), ProcessId = tostring(msg.Tags.ProcessId) },
			Data = tostring(err)
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = 'ArNS-Purchase-Notice', Sender = msg.From },
			Data = tostring(json.encode(result))
		})
	end
end)

Handlers.add(ActionMap.SubmitAuctionBid, utils.hasMatchingTag("Action", ActionMap.SubmitAuctionBid), function(msg)
	arns.submitAuctionBid(msg)
end)

Handlers.add(ActionMap.ExtendLease, utils.hasMatchingTag("Action", ActionMap.ExtendLease), function(msg)
	arns.extendLease(msg)
end)

Handlers.add(
	ActionMap.IncreaseUndernameCount,
	utils.hasMatchingTag("Action", ActionMap.IncreaseUndernameCount),
	function(msg)
		arns.increaseUndernameCount(msg)
	end
)

Handlers.add(ActionMap.JoinNetwork, utils.hasMatchingTag("Action", ActionMap.JoinNetwork), function(msg)
	gar.joinNetwork(msg)
end)

Handlers.add(ActionMap.LeaveNetwork, utils.hasMatchingTag("Action", ActionMap.JoinNetwork), function(msg)
	gar.leaveNetwork(msg)
end)

Handlers.add(
	ActionMap.IncreaseOperatorStake,
	utils.hasMatchingTag("Action", ActionMap.IncreaseOperatorStake),
	function(msg)
		gar.increaseOperatorStake(msg)
	end
)

Handlers.add(
	ActionMap.DecreaseOperatorStake,
	utils.hasMatchingTag("Action", ActionMap.DecreaseOperatorStake),
	function(msg)
		gar.decreaseOperatorStake(msg)
	end
)

Handlers.add(
	ActionMap.UpdateGatewaySettings,
	utils.hasMatchingTag("Action", ActionMap.UpdateGatewaySettings),
	function(msg)
		gar.updateGatewaySettings(msg)
	end
)

Handlers.add(ActionMap.SaveObservations, utils.hasMatchingTag("Action", ActionMap.SaveObservations), function(msg)
	gar.saveObservations(msg)
end)
