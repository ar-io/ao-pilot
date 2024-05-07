-- main.lua
local balances = require("contract.src.balances")
local arns = require("contract.src.arns")
local gar = require("contract.src.gar")
local utils = require("contract.src.utils")

local ActionMap = {
	Transfer = "Transfer",
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
	balances.transfer(msg)
end)

Handlers.add(ActionMap.Vault, utils.hasMatchingTag("Action", ActionMap.Vault), function(msg)
	balances.vault(msg)
end)

Handlers.add(ActionMap.BuyRecord, utils.hasMatchingTag("Action", ActionMap.BuyRecord), function(msg)
	-- TODO: parse out name, processId, type, qty, from, type, timestamp from message
	arns.buyRecord(msg)
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
