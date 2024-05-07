local json = require("json")

if not Balances then
	Balances = { [ao.id] = 1 }
end

if Name ~= "Arweave Name Token" then
	Name = "Arweave Name Token"
end

if Ticker ~= "ANT" then
	Ticker = "ANT"
end

if Denomination ~= 1 then
	Denomination = 1
end

if not Records then
	Records = { ["@"] = { transactionId = "", ttlSeconds = 3600 } }
end

Handlers.add("info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg)
	ao.send({
		Target = msg.From,
		Tags = { Name = Name, Ticker = Ticker, Denomination = tostring(Denomination) },
		Records = json.encode(Records),
	})
end)

Handlers.add("balance", Handlers.utils.hasMatchingTag("Action", "Balance"), function(msg)
	local bal = "0"

	-- If not Target is provided, then return the Senders balance
	if msg.Tags.Target and Balances[msg.Tags.Target] then
		bal = tostring(Balances[msg.Tags.Target])
	elseif Balances[msg.From] then
		bal = tostring(Balances[msg.From])
	end

	ao.send({
		Target = msg.From,
		Tags = { Target = msg.From, Balance = bal, Ticker = Ticker, Data = json.encode(tonumber(bal)) },
	})
end)

Handlers.add("balances", Handlers.utils.hasMatchingTag("Action", "Balances"), function(msg)
	ao.send({ Target = msg.From, Data = json.encode(Balances) })
end)

Handlers.add("setRecord", Handlers.utils.hasMatchingTag("Action", "SetRecord"), function(msg)
	local Payload = json.decode(msg.Data)
	--  simple validation on if our name and target id are present
	if not Payload.name or not Payload.transactionId then
		ao.send({
			Target = msg.From,
			Tags = {
				Name = Name,
				Ticker = Ticker,
				Error = "Unable to set record. Missing transactionId or name from data payload.",
				Result = "error",
			},
		})
	end
	-- must be owner to modify records
	if msg.Owner ~= Owner then
		ao.send({
			Target = msg.From,
			Tags = {
				Name = Name,
				Ticker = Ticker,
				Error = "Unable to set record as caller is not process owner",
				Result = "error",
			},
		})
	end
	--  finally set the record
	Records[Payload.name] = { transactionId = Payload.transactionId, ttlSeconds = 3600 }
	ao.send({
		Target = msg.From,
		Tags = { Name = Name, Ticker = Ticker, Result = "ok" },
	})
end)
