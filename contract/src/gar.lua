-- arns.lua
local utils = require("utils")
local constants = require("constants")

local gar = {}

local initialStats = {
	prescribedEpochCount = 0,
	observeredEpochCount = 0,
	totalEpochParticipationCount = 0,
	passedEpochCount = 0,
	failedEpochCount = 0,
	failedConsecutiveEpochs = 0,
	passedConsecutiveEpochs = 0,
}

if not Gateways then
	Gateways = {}
end

if not Observations then
	Observations = {}
end

if not Epochs then
	Epochs = {}
end

function gar.joinNetwork(caller, stake, settings, observerWallet)
	if caller == nil or settings == nil or stake == nil then
		utils.reply("caller, settings and stake are required")
	end

	if Gateways[caller] ~= nil then
		utils.reply("Gateway already exists in the network")
	end

	-- TODO: check if the caller has enough balance

	-- TODO: check the params meet the requirements

	local newGateway = {
		operatorStake = stake,
		vaults = {},
		delegates = {},
		startTimestamp = os.clock(),
		stats = initialStats,
		settings = settings,
		status = "joined",
		observerWallet = observerWallet,
	}

	Gateways[caller] = newGateway
	return newGateway
end

function gar.leaveNetwork(caller)
	if caller == nil then
		utils.reply("caller is required")
	end

	if Gateways[caller] == nil then
		utils.reply("Gateway does not exist in the network")
	end

	local gateway = Gateways[caller]

	if gateway.status ~= "joined" then
		utils.reply("gateway cannot leave the network. current status: " .. gateway.status)
	end

	gateway.vaults = {
		-- TODO: append the vaults
		[caller] = {
			startTimestamp = os.clock(),
			endTimestamp = os.clock() + (constants.thirtyDaysSeconds * 1000),
			amount = gateway.operatorStake,
		},
	}
	gateway.status = "leaving"
	gateway.endTimestamp = os.clock() + (constants.thirtyDaysSeconds * 1000)
	gateway.operatorStake = 0

	-- update global state
	Gateways[caller] = gateway
	return gateway
end

function gar.increaseOperatorStake()
	-- TODO: implement
	utils.reply("increaseOperatorStake is not implemented yet")
end

function gar.decreaseOperatorStake()
	-- TODO: implement
	utils.reply("decreaseOperatorStake is not implemented yet")
end

function gar.updateGatewaySettings()
	-- TODO: implement
	utils.reply("updateGatewaySettings is not implemented yet")
end

function gar.saveObservations()
	-- TODO: implement
	utils.reply("saveObservations is not implemented yet")
end

function gar.getGateway(processId)
	local gateway = Gateways[processId]
	if gateway == nil then
		return nil, "Gateway does not exist in the network"
	end
	return gateway
end

function gar.getPrescribedObservers()
	-- TODO: implement
	utils.reply("getPrescribedObservers is not implemented yet")
end

function gar.getEpoch()
	-- TODO: implement
	utils.reply("getEpoch is not implemented yet")
end

function gar.getObservations()
	-- TODO: implement
	utils.reply("getObservations is not implemented yet")
end

return gar
