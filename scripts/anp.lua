local json = require("json")
local bint = require('.bint')(256)
local ao = require('ao')

-- Update the below as needed
Name = Name or "ANT-Base-Spec"
Ticker = Ticker or "ANT-Base-Spec"
Denomination = Denomination or 0
TotalSupply = TotalSupply or 1
Logo = Logo or "Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A"

-- Setup balances as needed
Owner = Owner or ao.env.Process.Owner
Balances = Balances or { [Owner] = 1 }

-- Setup the default record pointing to the ArNS landing page
if not Records then
	Records = {}
	Records["@"] = {
		transactionId = "UyC5P5qKPZaltMmmZAWdakhlDXsBF6qmyrbWYFchRTk",
		ttlSeconds = 3600,
	}
end

-- Set empty controllers if needed
if not Controllers then
	Controllers = {}
end

local ANTSpecActionMap = {
	-- write
	AddController = "Add-Controller",
	RemoveController = "Remove-Controller",
	SetRecord = "Set-Record",
	RemoveRecord = "Remove-Record",
	SetName = "Set-Name",
	SetTicker = "Set-Ticker",
	--- initialization method for bootstrapping the contract from other platforms ---
	InitializeState = "Initialize-State",
	-- read
	Controllers = "Controllers",
	Record = "Record",
	Records = "Records",
	State = "State",
	Evolve = "Evolve",
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

-- Custom validateSetRecord function in Lua
function validateSetRecord(msg)
	-- Check for required fields
	local requiredFields = { "SubDomain", "TransactionId", "TtlSeconds" }
	for _, field in ipairs(requiredFields) do
		if not msg.Tags[field] then
			return false, field .. " is required!"
		end
	end

	-- Validate subDomain (Record)
	if not (msg.Tags.SubDomain == "@" or string.match(msg.Tags.SubDomain, "^[%w-_]+$")) then
		return false, "Record (subDomain) pattern is invalid."
	end

	if msg.Tags.SubDomain == "www" then
		return false, "Invalid ArNS Record Subdomain"
	end

	-- Validate transactionId
	-- if not validArweaveId(msg.Tags.TransactionId) then
	--    return false, "TransactionId pattern is invalid."
	-- end

	-- Validate ttlSeconds
	local ttlSeconds = tonumber(msg.Tags.TtlSeconds)
	if not ttlSeconds or ttlSeconds < 900 or ttlSeconds > 2592000 or ttlSeconds % 1 ~= 0 then
		return false, "TtlSeconds is invalid."
	end

	-- If all checks pass
	return true, "Valid"
end

-- Utility function to check if a string matches an arweave id
function validArweaveId(inputString)
	local pattern = "^[a-zA-Z0-9-_]{43}$"
	return string.match(inputString, pattern) ~= nil
end

-- Custom validateSetRecord function in Lua
function validateSetRecord(msg)
	-- Check for required fields
	local requiredFields = { "SubDomain", "TransactionId", "TtlSeconds" }
	for _, field in ipairs(requiredFields) do
		if not msg.Tags[field] then
			return false, field .. " is required!"
		end
	end

	-- Validate subDomain (Record)
	if not (msg.Tags.SubDomain == "@" or string.match(msg.Tags.SubDomain, "^[%w-_]+$")) then
		return false, "Record (subDomain) pattern is invalid."
	end

	if msg.Tags.SubDomain == "www" then
		return false, "Invalid ArNS Record Subdomain"
	end

	-- Validate transactionId
	-- if not validArweaveId(msg.Tags.TransactionId) then
	--    return false, "TransactionId pattern is invalid."
	-- end

	-- Validate ttlSeconds
	local ttlSeconds = tonumber(msg.Tags.TtlSeconds)
	if not ttlSeconds or ttlSeconds < 900 or ttlSeconds > 2592000 or ttlSeconds % 1 ~= 0 then
		return false, "TtlSeconds is invalid."
	end

	-- If all checks pass
	return true, "Valid"
end

-- Utility function to check if a string matches an arweave id
function validArweaveId(inputString)
	local pattern = "^[a-zA-Z0-9-_]{43}$"
	return string.match(inputString, pattern) ~= nil
end

-- caller must own the process or be the process itself
function validateOwner(caller)
	local isOwner = false
	if Owner == caller or ao.env.Process.Id == caller then
		isOwner = true
	end
	assert(isOwner, "Sender is not the owner.")
end

Handlers.add(
	TokenSpecActionMap.Transfer,
	Handlers.utils.hasMatchingTag("Action", TokenSpecActionMap.Transfer),
	function(msg)
		local recipient = msg.Tags.Recipient
		local function checkAssertions()
			validArweaveId(recipient)
			validateOwner(msg.From)
		end

		local inputStatus, inputResult = pcall(checkAssertions)

		if not inputStatus then
			ao.send({
				Target = msg.From,
				Tags = { Action = "Invalid-Transfer-Notice", Error = "Transfer-Error" },
				Data = tostring(inputResult),
				["Message-Id"] = msg.Id,
			})
			return
		end
		local transferStatus, transferResult = pcall(balances.transfer, recipient)

		if not transferStatus then
			ao.send({
				Target = msg.From,
				Tags = { Action = "Invalid-Transfer-Notice", Error = "Transfer-Error" },
				["Message-Id"] = msg.Id,
				Data = tostring(transferResult),
			})
			return
		elseif not msg.Cast then
			ao.send(utils.notices.debit(msg))
			ao.send(utils.notices.credit(msg))
			return
		end
		ao.send({
			Target = msg.From,
			Data = transferResult,
		})
	end
)













Handlers.add("info", Handlers.utils.hasMatchingTag("Action", "Info"), function(msg, env)
	local info = {
		name = Name,
		ticker = Ticker,
		logo = Logo,
		owner = Owner,
		denomination = tostring(Denomination),
		controllers = json.encode(Controllers),
		records = Records,
	}
	ao.send({
		Target = msg.From,
		Tags = {
			Action = "Info-Notice",
			Name = Name,
			Ticker = Ticker,
			Logo = Logo,
			ProcessOwner = Owner,
			Denomination = tostring(Denomination),
			Controllers = json.encode(Controllers),
		},
		Data = json.encode(info),
	})
end)

Handlers.add("getRecord", Handlers.utils.hasMatchingTag("Action", "Get-Record"), function(msg)
	if msg.Tags.SubDomain and Records[msg.Tags.SubDomain] then
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "Record-Resolved",
				SubDomain = msg.Tags.SubDomain,
				TransactionId = Records[msg.Tags.SubDomain].transactionId,
				TtlSeconds = tostring(Records[msg.Tags.SubDomain].ttlSeconds),
			},
		})
	elseif Records["@"] then -- If no SubDomain is provided, then return the root subdomain
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "Record-Resolved",
				SubDomain = "@",
				TransactionId = Records["@"].transactionId,
				TtlSeconds = tostring(Records["@"].ttlSeconds),
			},
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "Get-Record-Error", ["Message-Id"] = msg.Id, Error = "Requested non-existant record" },
		})
	end
end)

Handlers.add("getRecords", Handlers.utils.hasMatchingTag("Action", "Get-Records"), function(msg)
	ao.send({ Action = "Records-Resolved", Target = msg.From, Data = json.encode(Records) })
end)

Handlers.add("setRecord", Handlers.utils.hasMatchingTag("Action", "Set-Record"), function(msg, env)
	local isValidRecord, responseMsg = validateSetRecord(msg)
	if isValidRecord then
		if msg.From == env.Process.Id then
			Records[msg.Tags.SubDomain] = {
				transactionId = msg.Tags.TransactionId,
				ttlSeconds = msg.Tags.TtlSeconds,
			}
			if not msg.Tags.Cast then
				-- Send SetRecord-Notice to the Sender if cast is not provided
				ao.send({
					Target = msg.From,
					Tags = {
						Action = "SetRecord-Notice",
						SubDomain = msg.Tags.SubDomain,
						TransactionId = msg.Tags.TransactionId,
						TtlSeconds = msg.Tags.TtlSeconds,
					},
				})
			end
		elseif Controllers[msg.From] then
			Records[msg.Tags.SubDomain] = {
				transactionId = msg.Tags.TransactionId,
				ttlSeconds = msg.Tags.TtlSeconds,
			}
			if not msg.Tags.Cast then
				-- Send SetRecord-Notice to the Sender if cast is not provided
				ao.send({
					Target = msg.From,
					Tags = {
						Action = "SetRecord-Notice",
						SubDomain = msg.Tags.SubDomain,
						TransactionId = msg.Tags.TransactionId,
						TtlSeconds = msg.Tags.TtlSeconds,
					},
				})
				-- Send SetRecord-Notice to the Owner if cast is not provided
				ao.send({
					Target = env.Process.Id,
					Tags = {
						Action = "SetRecord-Notice",
						Controller = msg.From,
						SubDomain = msg.Tags.SubDomain,
						TransactionId = msg.Tags.TransactionId,
						TtlSeconds = msg.Tags.TtlSeconds,
					},
				})
			end
		else
			ao.send({
				Target = msg.From,
				Tags = {
					Action = "SetRecord-Error",
					["Message-Id"] = msg.Id,
					Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE,
				},
			})
		end
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = "SetRecord-Error", ["Message-Id"] = msg.Id, Error = responseMsg },
		})
	end
end)

Handlers.add("removeRecord", Handlers.utils.hasMatchingTag("Action", "Remove-Record"), function(msg, env)
	if msg.From == env.Process.Id or Controllers[msg.From] then
		if Records[msg.Tags.SubDomain] then
			Records[msg.Tags.SubDomain] = nil
			if not msg.Tags.Cast then
				-- Send SetRecord-Notice to the Sender if cast is not provided
				ao.send({
					Target = msg.From,
					Tags = { Action = "RemoveRecord-Notice", SubDomain = msg.Tags.SubDomain },
				})
			end
		else
			ao.send({
				Target = msg.From,
				Tags = {
					Action = "RemoveRecord-Error",
					["Message-Id"] = msg.Id,
					Error = "Subdomain does not exist in this process",
				},
			})
		end
	else
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "RemoveRecord-Error",
				["Message-Id"] = msg.Id,
				Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE,
			},
		})
	end
end)

Handlers.add("setController", Handlers.utils.hasMatchingTag("Action", "Set-Controller"), function(msg, env)
	if msg.From == env.Process.Id then
		Controllers[msg.Tags.Target] = true
		if not msg.Tags.Cast then
			-- Send SetController-Notice to the Sender if cast is not provided
			ao.send({
				Target = msg.From,
				Tags = { Action = "SetController-Notice", Target = msg.Tags.Target },
			})
			-- Send SetController-Notice to the Target
			ao.send({
				Target = msg.Tags.Target,
				Tags = { Action = "SetController-Notice", Sender = msg.From, Target = msg.Tags.Target },
			})
		end
	else
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "SetController-Error",
				["Message-Id"] = msg.Id,
				Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE,
			},
		})
	end
end)

Handlers.add("removeController", Handlers.utils.hasMatchingTag("Action", "Remove-Controller"), function(msg, env)
	if msg.From == env.Process.Id then
		Controllers[msg.Tags.Target] = nil
		if not msg.Tags.Cast then
			-- Send RemoveController-Notice to the Sender if cast is not provided
			ao.send({
				Target = msg.From,
				Tags = { Action = "RemoveController-Notice", Target = msg.Tags.Target },
			})
			-- Send RemoveController-Notice to the Target
			ao.send({
				Target = msg.Tags.Target,
				Tags = { Action = "RemoveController-Notice", Sender = msg.From, Target = msg.Tags.Target },
			})
		end
	else
		ao.send({
			Target = msg.From,
			Tags = {
				Action = "RemoveController-Error",
				["Message-Id"] = msg.Id,
				Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE,
			},
		})
	end
end)
