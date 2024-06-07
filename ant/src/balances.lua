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

function balances.transfer(to, from, qty)
       assert(utils.validateArweaveId, to, "Receipent must be a valid arweave address")
       assert(utils.validateArweaveId, from, "Sender must be a valid arweave address")
       assert(type(qty) == "number and qty > 0 and qty % 0 == 0, "Quantity must be an integer greater than 0")
       
       local fromBalance = Balances[from] or 0
       local receipentBalance = Balances[recipient] or 0
       
       if fromBalance < qty then
           error("Insufficient balance")
       end
       
       Balances[from] = fromBalance - qty
       Balances[recipient] = repipentBalance + qty
       return
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
