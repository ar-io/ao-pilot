local json = require('json')

if not Balances then
	Balances = {}

	-- ao.id is the protocol balance
	Balances[ao.id] = 200000000
	
	-- Assignments for complex keys
	Balances["iKryOeZQMONi2965nKz528htMMN_sBcjlhc-VncoRjA"] = 100000000
	Balances["QGWqtJdLLgm2ehFWiiPzMaoFLD50CnGuzZIPEdoDRGQ"] = 100000000
end

-- Setup the default record pointing to the ArNS landing page
if not Records then
	Records = {}
	Records['@'] = {
		transactionId = 'UyC5P5qKPZaltMmmZAWdakhlDXsBF6qmyrbWYFchRTk',
		ttlSeconds = 3600
	}
end

-- Set empty controllers
if not Controllers then
	Controllers = {}
	Controllers['ecJ9HQzdzIELyEC6JZKO2awNEz23VYgVP5jVcdmIyRI'] = true
	Controllers['QGWqtJdLLgm2ehFWiiPzMaoFLD50CnGuzZIPEdoDRGQ'] = true
end

Name = Name or 'Test AR.IO EXP'
Ticker = Ticker or 'tEXP'
Denomination = Denomination or 6
Logo = Logo or 'Sie_26dvgyok0PZD_-iQAFOhOd5YxDTkczOLoqTTL_A'
LastBalanceLoadTimestamp = LastBalanceLoadTimestamp or 0
TotalSupply = TotalSupply or 0
SourceCodeTxId = SourceCodeTxId or "__INSERT_SOURCE_CODE_ID__"

-- TEMPORARY SECURITY FIX
function Trusted(msg)
	local mu = "fcoN_xJeisVsPXA-trzVAuIiqO3ydLQxM-L4XbrQKzY"
	-- return false if trusted
	if msg.Owner == mu then
		return false
	end
	if msg.From == msg.Owner or Controllers[msg.From] ~= nil then
		return false
	end
	return true
end

Handlers.prepend("qualify message",
	Trusted,
	function(msg)
		print("This Msg is not trusted!")
	end
)

local function isInteger(number)
	return math.type(number) == "integer"
end

-- Merged token info and ANT info
Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
	local info = {
		name = Name,
		ticker = Ticker,
		logo = Logo,
		owner = Owner,
		denomination = tostring(Denomination),
		controllers = json.encode(Controllers),
		records = Records
	}
	if msg.reply then
		msg.reply({
			Tags = { Action = 'Info-Notice', Name = Name, Ticker = Ticker, Logo = Logo, Denomination = tostring(Denomination), Owner = Owner, Controllers = json.encode(Controllers) },
			Data = json.encode(info)
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Info-Notice', Name = Name, Ticker = Ticker, Logo = Logo, Denomination = tostring(Denomination), Owner = Owner, Controllers = json.encode(Controllers) },
			Data = json.encode(info)
		})
	end
end)

Handlers.add('balance', Handlers.utils.hasMatchingTag('Action', 'Balance'), function(msg)
	local bal = '0'

	-- If not Target is provided, then return the Senders balance
	if (msg.Tags.Target and Balances[msg.Tags.Target]) then
		bal = tostring(Balances[msg.Tags.Target])
	elseif Balances[msg.From] then
		bal = tostring(Balances[msg.From])
	end

	if msg.reply then
		msg.reply({
			Action = "Balance-Notice",
			Balance = bal,
			Ticker = Ticker,
			Account = msg.Tags.Recipient or msg.From,
			Data = bal,
		})
	else
		ao.send({
			Target = msg.From,
			Action = "Balance-Notice",
			Balance = bal,
			Ticker = Ticker,
			Account = msg.Tags.Recipient or msg.From,
			Data = bal,
		})
	end
end)

Handlers.add('balances', Handlers.utils.hasMatchingTag('Action', 'Balances'), function(msg) 
	if msg.reply then
		msg.reply({ Data = json.encode(Balances) })
	else 
		ao.send({ Target = msg.From, Denomination = tostring(Denomination), Data = json.encode(Balances) }) 
	end
end)

Handlers.add('transfer', Handlers.utils.hasMatchingTag('Action', 'Transfer'), function(msg)
	assert(type(msg.Tags.Recipient) == 'string', 'Recipient is required!')
	assert(type(msg.Tags.Quantity) == 'string', 'Quantity is required!')

	if not Balances[msg.From] then Balances[msg.From] = 0 end

	if not Balances[msg.Tags.Recipient] then Balances[msg.Tags.Recipient] = 0 end

	local qty = tonumber(msg.Tags.Quantity)
	assert(type(qty) == 'number', 'qty must be number')
	assert(isInteger(qty) == true, 'decimals not allowed in qty')
	assert(qty > 0, 'Quantity must be greater than 0')

	if Balances[msg.From] >= qty then
		Balances[msg.From] = Balances[msg.From] - qty
		Balances[msg.Tags.Recipient] = Balances[msg.Tags.Recipient] + qty

		--[[
        Only Send the notifications to the Sender and Recipient
        if the Cast tag is not set on the Transfer message
        ]]
		--
		if not msg.Cast then
			-- Debit-Notice message template, that is sent to the Sender of the transfer
			local debitNotice = {
				Target = msg.From,
				Action = 'Debit-Notice',
				Recipient = msg.Recipient,
				Quantity = msg.Quantity,
				Data = Colors.gray ..
					"You transferred " ..
					Colors.blue .. msg.Quantity .. Colors.gray .. " to " .. Colors.green .. msg.Recipient .. Colors
					.reset
			}

			-- Credit-Notice message template, that is sent to the Recipient of the transfer
			local creditNotice = {
				Target = msg.Recipient,
				Action = 'Credit-Notice',
				Sender = msg.From,
				Quantity = msg.Quantity,
				Data = Colors.gray ..
					"You received " ..
					Colors.blue .. msg.Quantity .. Colors.gray .. " from " .. Colors.green .. msg.From .. Colors.reset
			}

			-- Add forwarded tags to the credit and debit notice messages
			for tagName, tagValue in pairs(msg) do
				-- Tags beginning with "X-" are forwarded
				if string.sub(tagName, 1, 2) == "X-" then
					debitNotice[tagName] = tagValue
					creditNotice[tagName] = tagValue
				end
			end

			if msg.reply then
				msg.reply(debitNotice)
			else
				debitNotice.Target = msg.From
				ao.send(debitNotice)
			end
			ao.send(creditNotice)
		end
	else
		if msg.reply then
			msg.reply({
			  Action = 'Transfer-Error',
			  ['Message-Id'] = msg.Id,
			  Error = 'Insufficient Balance!'
			})
		else
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Transfer-Error',
			['Message-Id'] = msg.Id,
			Error = 'Insufficient Balance!' }
		})
		end
	end
end)

Handlers.add('mint', Handlers.utils.hasMatchingTag('Action', 'Mint'), function(msg)
	assert(type(msg.Tags.Quantity) == 'string', 'Quantity is required!')
	assert(type(msg.Tags.Recipient) == 'string', 'Recipient is required!')
	
	if msg.From == ao.id or msg.From == Owner or Controllers[msg.From] == true then
		-- Add tokens to the token pool, according to Quantity
		local qty = tonumber(msg.Tags.Quantity)
		assert(type(qty) == 'number', 'qty must be number')
		assert(qty > 0, 'Quantity must be greater than 0')
		assert(isInteger(qty) == true, 'decimals not allowed in qty')
		if not Balances[msg.Tags.Recipient] then Balances[msg.Tags.Recipient] = 0 end

		Balances[msg.Tags.Recipient] = Balances[msg.Tags.Recipient] + qty
		TotalSupply = TotalSupply + qty

		-- Send Mint-Notice to the Sender
		ao.send({
			Target = msg.From,
			Action = 'Mint-Notice',
			Recipient = msg.Tags.Recipient,
			Quantity = tostring(qty),
			Data = Colors.gray ..
				"You minted " ..
				Colors.blue ..
				msg.Tags.Quantity .. Colors.gray .. " to " .. Colors.green .. msg.Tags.Recipient .. Colors.reset
		})

		-- Send Credit-Notice to the Recipient
		ao.send({
			Target = msg.Tags.Recipient,
			Action = 'Credit-Notice',
			Sender = msg.From,
			Quantity = tostring(qty),
			Data = Colors.gray ..
				"You received " ..
				Colors.blue ..
				msg.Tags.Quantity ..
				Colors.gray .. " from " .. Colors.green .. msg.Tags.Recipient .. Colors.reset
		})
	else
		ao.send({
			Target = msg.From,
			Tags = {
				Action = 'Mint-Error',
				['Message-Id'] = msg.Id,
				Error = 'Only the Process Owner or Controller can mint new ' .. Ticker .. ' tokens!'
			}
		})
	end
end)

Handlers.add('totalSupply', Handlers.utils.hasMatchingTag('Action', 'Total-Supply'), function(msg)
	assert(msg.From ~= ao.id, 'Cannot call Total-Supply from the same process!')
	if msg.reply then
		msg.reply({
		  Action = 'Total-Supply',
		  Data = tostring(TotalSupply),
		  Ticker = Ticker
		})
	  else
		Send({
		  Target = msg.From,
		  Action = 'Total-Supply',
		  Data = tostring(TotalSupply),
		  Ticker = Ticker
		})
	  end
end)

function assertHasPermission(from)
	for _, c in ipairs(Controllers) do
		if c == from then
			-- if is controller, return true
			return
		end
	end
	if Owner == from then
		return
	end
	if ao.id == from then
		return
	end
	assert(false, "Only controllers and owners can set controllers, records, and change metadata.")
end

Handlers.add('loadBalances', Handlers.utils.hasMatchingTag('Action', 'Load-Balances'), function(msg)
	-- Validate if the message is from the process owner to ensure that only authorized updates are processed.
	local assertHasPermission, permissionErr = pcall(assertHasPermission, msg.From)

	if assertHasPermission == false then
		print("Unauthorized data update attempt detected from: " .. msg.From)
		-- Sending an error notice back to the sender might be a security concern in some contexts, consider this based on your application's requirements.
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Load-Balances-Error', Error = 'Unauthorized attempt detected' }
		})
		return
	end

	local data, err = json.decode(msg.Data)
	if not data or err then
		print("Error decoding JSON data: " .. err)
		-- Handle error (e.g., send an error response)
		return
	end

	-- Counter for added or updated records.
	local balancesAddedOrUpdated = 0

	-- Ensure 'data.records' is present and iterate through the decoded data to update the Records table accordingly.
	if type(data) == 'table' then
		print("Updating balances.")
		for key, value in pairs(data) do
			if not Balances[key] or Balances[key] == 0 then
				Balances[key] = tonumber(value)
			elseif Balances[key] > 0 then
				Balances[key] = Balances[key] + tonumber(value)
				TotalSupply = TotalSupply + tonumber(value)
			end
		end

		-- Update the global sync timestamp to mark the latest successful update.
		LastBalanceLoadTimestamp = msg.Timestamp

		-- Notify the process owner about the successful update.
		ao.send({
			Target = ao.id,
			Tags = { Action = 'Loaded-Balances', BalancesUpdated = tostring(balancesAddedOrUpdated) }
		})
	else
		-- Handle the case where 'data.records' is not in the expected format.
		print("The 'balances' field is missing or not in the expected format.")
		-- Notify the process owner about the issue.
		ao.send({
			Target = ao.id,
			Tags = { Action = 'Load-Balances-Failure', Error = "'balances' field missing or invalid" }
		})
	end
end)

-- ANT Functionality
Handlers.add('getRecord', Handlers.utils.hasMatchingTag('Action', 'Get-Record'), function(msg)
	if msg.Tags.SubDomain and Records[msg.Tags.SubDomain] then
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Record-Resolved', SubDomain = msg.Tags.SubDomain, TransactionId = Records[msg.Tags.SubDomain].transactionId, TtlSeconds = tostring(Records[msg.Tags.SubDomain].ttlSeconds) }
		})
	elseif Records['@'] then -- If no SubDomain is provided, then return the root subdomain
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Record-Resolved', SubDomain = '@', TransactionId = Records['@'].transactionId, TtlSeconds = tostring(Records['@'].ttlSeconds) }
		})
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = 'Get-Record-Error', ['Message-Id'] = msg.Id, Error = 'Requested non-existant record' }
		})
	end
end)

Handlers.add('getRecords', Handlers.utils.hasMatchingTag('Action', 'Get-Records'),
	function(msg) ao.send({ Action = 'Records-Resolved', Target = msg.From, Data = json.encode(Records) }) end)

Handlers.add('setRecord', Handlers.utils.hasMatchingTag('Action', 'Set-Record'), function(msg)
	local isValidRecord, responseMsg = validateSetRecord(msg)
	if isValidRecord then
		if msg.From == ao.id then
			Records[msg.Tags.SubDomain] = {
				transactionId = msg.Tags.TransactionId,
				ttlSeconds = msg.Tags.TtlSeconds
			}
			if not msg.Tags.Cast then
				-- Send SetRecord-Notice to the Sender if cast is not provided
				ao.send({
					Target = msg.From,
					Tags = { Action = 'SetRecord-Notice', SubDomain = msg.Tags.SubDomain, TransactionId = msg.Tags.TransactionId, TtlSeconds = msg.Tags.TtlSeconds }
				})
			end
		elseif Controllers[msg.From] then
			Records[msg.Tags.SubDomain] = {
				transactionId = msg.Tags.TransactionId,
				ttlSeconds = msg.Tags.TtlSeconds
			}
			if not msg.Tags.Cast then
				-- Send SetRecord-Notice to the Sender if cast is not provided
				ao.send({
					Target = msg.From,
					Tags = { Action = 'SetRecord-Notice', SubDomain = msg.Tags.SubDomain, TransactionId = msg.Tags.TransactionId, TtlSeconds = msg.Tags.TtlSeconds }
				})
				-- Send SetRecord-Notice to the Owner if cast is not provided
				ao.send({
					Target = ao.id,
					Tags = { Action = 'SetRecord-Notice', Controller = msg.From, SubDomain = msg.Tags.SubDomain, TransactionId = msg.Tags.TransactionId, TtlSeconds = msg.Tags.TtlSeconds }
				})
			end
		else
			ao.send({
				Target = msg.From,
				Tags = { Action = 'SetRecord-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
			})
		end
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = 'SetRecord-Error', ['Message-Id'] = msg.Id, Error = responseMsg }
		})
	end
end)

Handlers.add('removeRecord', Handlers.utils.hasMatchingTag('Action', 'Remove-Record'), function(msg)
	if msg.From == ao.id or Controllers[msg.From] then
		if Records[msg.Tags.SubDomain] then
			Records[msg.Tags.SubDomain] = nil
			if not msg.Tags.Cast then
				-- Send SetRecord-Notice to the Sender if cast is not provided
				ao.send({
					Target = msg.From,
					Tags = { Action = 'RemoveRecord-Notice', SubDomain = msg.Tags.SubDomain }
				})
			end
		else
			ao.send({
				Target = msg.From,
				Tags = { Action = 'RemoveRecord-Error', ['Message-Id'] = msg.Id, Error = 'Subdomain does not exist in this process' }
			})
		end
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = 'RemoveRecord-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
		})
	end
end)

Handlers.add('setController', Handlers.utils.hasMatchingTag('Action', 'Set-Controller'), function(msg)
	if msg.From == ao.id then
		Controllers[msg.Tags.Target] = true
		if not msg.Tags.Cast then
			-- Send SetController-Notice to the Sender if cast is not provided
			ao.send({
				Target = msg.From,
				Tags = { Action = 'SetController-Notice', Target = msg.Tags.Target }
			})
			-- Send SetController-Notice to the Target
			ao.send({
				Target = msg.Tags.Target,
				Tags = { Action = 'SetController-Notice', Sender = msg.From, Target = msg.Tags.Target }
			})
		end
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = 'SetController-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
		})
	end
end)

Handlers.add('removeController', Handlers.utils.hasMatchingTag('Action', 'Remove-Controller'), function(msg)
	if msg.From == ao.id then
		Controllers[msg.Tags.Target] = nil
		if not msg.Tags.Cast then
			-- Send RemoveController-Notice to the Sender if cast is not provided
			ao.send({
				Target = msg.From,
				Tags = { Action = 'RemoveController-Notice', Target = msg.Tags.Target }
			})
			-- Send RemoveController-Notice to the Target
			ao.send({
				Target = msg.Tags.Target,
				Tags = { Action = 'RemoveController-Notice', Sender = msg.From, Target = msg.Tags.Target }
			})
		end
	else
		ao.send({
			Target = msg.From,
			Tags = { Action = 'RemoveController-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
		})
	end
end)
