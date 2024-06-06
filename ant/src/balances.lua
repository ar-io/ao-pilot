local utils = require(".utils")
local json = require(".json")

	Balances = Balances or {}


local balances = {}

function balances.info(msg)
	utils.reply(json.encode({
		Name = Name,
		Ticker = Ticker,
		TotalSupply = 1,
		Logo = Logo,
		Denomination = tostring(Denomination),
	}))
end

function balances.transfer(msg)
	local from = msg.From
	local to = msg.Tags.Recipient

	local ownerStatus, ownerResult = pcall(utils.validateOwner, from)
	local recipientStatus, recipientResult = pcall(utils.validateArweaveId, to)

		if not ownerStatus then
			return utils.reply(ownerResult)
		else if not recipientStatus then
			return utils.reply(recipientResult)
		else
			Balances[from] = nil
			Balances[to] = 1
		end
	end
end

function balances.balance(msg)
	local address = msg.Tags.Address or msg.From
	local balance = Balances[address]
	if balance == nil then
		return utils.reply("0")
	end
	utils.reply("1")
end

function balances.balances(msg)
	utils.reply(json.encode(Balances))
end

function balances.mint(msg)
	utils.reply("Minting not supported")
end

function balances.setName(msg)
	local name = msg.Tags.Name
	Name = name
end

function balances.setTicker(msg)
	local ticker = msg.Tags.Ticker
	Ticker = ticker
end

return balances
