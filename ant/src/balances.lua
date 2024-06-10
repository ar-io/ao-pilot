local utils = require(".utils")
local json = require(".json")

Balances = Balances or {}

local balances = {}

function balances.walletHasSufficientBalance(wallet)
	return Balances[wallet] ~= nil and Balances[wallet] > 0
end

function balances.info()
	utils.reply(json.encode({
		Name = Name,
		Ticker = Ticker,
		TotalSupply = 1,
		Logo = Logo,
		Denomination = Denomination,
	}))
end

function balances.transfer(to)
	Balances = { [to] = 1 }
end

function balances.balance(address)
	assert(utils.validateArweaveId(address), "Addreess must be valid Arweave ID")
	local balance = Balances[address] or 0
	utils.reply(tostring(balance))
end

function balances.balances()
	utils.reply(json.encode(Balances))
end

function balances.mint()
	utils.reply("Minting not supported")
end

function balances.setName(name)
	assert(type(name) == "string", "Name must be a string")
	Name = name
end

function balances.setTicker(ticker)
	assert(type(ticker) == "string", "Ticker must be a string")
	Ticker = ticker
end

return balances
