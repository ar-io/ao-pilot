local utils = require(".ant-utils")
local json = require(".json")

Balances = Balances or {}

local balances = {}

function balances.walletHasSufficientBalance(wallet)
	return Balances[wallet] ~= nil and Balances[wallet] > 0
end

function balances.info()
	utils.reply({
		Name = Name,
		Ticker = Ticker,
		TotalSupply = tostring(TotalSupply),
		Logo = Logo,
		Denomination = tostring(Denomination),
		Owner = Owner,
	})
end

function balances.transfer(to)
	utils.validateArweaveId(to)
	Balances = { [to] = 1 }
	Owner = to
	Controllers = {}
end

function balances.balance(address)
	utils.validateArweaveId(address)
	local balance = Balances[address] or 0
	utils.reply({
		Target = address,
		Balance = balance,
		Ticker = Ticker,
		Account = address,
		Data = balance,
	})
end

function balances.balances()
	utils.reply(json.encode(Balances))
end

function balances.mint()
	utils.reply("Minting not supported")
end

function balances.burn()
	utils.reply("Burning not supported")
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
