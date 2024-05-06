-- arns.lua

local utils = require '.utils'

local arns = {}





--[[ function arns.buyRecord(msg)
    local name = string.lower(msg.Tags.name)
    local validRecord, validRecordErr = utils.validateBuyRecord(msg.Tags)
    if msg.Tags.purchaseType == nil then
        msg.Tags.purchaseType = 'lease' -- set to lease by default
    end

    if msg.Tags.years == nil then
        msg.Tags.years = 1 -- set to 1 year by default
    end

    if validRecord == false then
        print("Error for name: " .. name)
        print(validRecordErr)
        ao.send({
            Target = msg.Tags.Sender,
            Tags = { Action = 'ArNS-Invalid-Record-Notice', Sender = msg.Tags.Sender, Name = tostring(msg.Tags.name), ProcessId = tostring(msg.Tags.processId) }
        })
        return
    end

    local totalRegistrationFee = calculateRegistrationFee(msg.Tags.purchaseType, name, msg.Tags.years)
    if totalRegistrationFee > msg.Tags.quantity then
        print('Not enough tokens for this name')
        ao.send({
            Target = msg.Tags.Sender,
            Tags = { Action = 'ArNS-Insufficient-Funds', Sender = msg.Tags.Sender, Name = tostring(msg.Tags.name), ProcessId = tostring(msg.Tags.processId) }
        })
        return
    end

    if isExistingActiveRecord(Records[name], msg.Timestamp) then
        -- Notify the original purchaser
        print('Name is already taken')
        ao.send({
            Target = msg.Tags.Sender,
            Tags = { Action = 'ArNS-Deny-Notice', Sender = msg.Tags.Sender, Name = tostring(msg.Tags.name), ProcessId = tostring(msg.Tags.processId) }
        })
    else
        print('This name is available for purchase!')
        if msg.Tags.purchaseType == 'lease' then
                        Records[name] = {
                            processId = msg.Tags.processId,
                            endTimestamp = msg.Timestamp + MS_IN_A_YEAR * msg.Tags.years,
                            startTimestamp = msg.Timestamp,
                            type = "lease",
                            undernames = DEFAULT_UNDERNAME_COUNT,
                            purchasePrice = totalRegistrationFee
                        }
        elseif msg.Tags.purchaseType == 'permabuy' then
                        Records[name] = {
                            processId = msg.Tags.processId,
                            startTimestamp = msg.Timestamp,
                            type = "permabuy",
                            undernames = DEFAULT_UNDERNAME_COUNT,
                            purchasePrice = totalRegistrationFee
                        }
                   end

                    print('Added record: ' .. name)

                    -- Check if any remaining balance to send back
                    local remainingQuantity = quantity - totalRegistrationFee
                    if remainingQuantity > 1 then
                        -- Send the tokens back
                        print('Sending back remaining tokens: ' .. remainingQuantity)
                        ao.send({
                            Target = TOKEN_PROCESS_ID,
                            Tags = { Action = 'Transfer', Recipient = msg.Tags.Sender, Quantity = tostring(remainingQuantity) }
                        })
                        ao.send({
                            Target = msg.Tags.Sender,
                            Tags = { Action = 'ArNS-Purchase-Notice-Remainder', Sender = msg.Tags.Sender, Name = tostring(msg.Tags.name), ProcessId = tostring(msg.Tags.processId), Quantity = tostring(remainingQuantity) }
                        })
                    else
                        ao.send({
                            Target = msg.Tags.Sender,
                            Tags = { Action = 'ArNS-Purchase-Notice', Sender = msg.Tags.Sender, Name = tostring(msg.Tags.name), ProcessId = tostring(msg.Tags.processId) }
                        })
                    end
                end
            elseif msg.Tags.Function == 'increaseUndernameCount' and msg.Tags.name and msg.Tags.qty then
                local name = string.lower(msg.Tags.name)
                -- validate record can increase undernames
                local validIncrease, err = validateIncreaseUndernames(Records[name], msg.Tags.qty, msg.Timestamp)
                if validIncrease == false then
                    print("Error for name: " .. name)
                    print(err)
                    ao.send({
                        Target = msg.Tags.Sender,
                        Tags = { Action = 'ArNS-Invalid-Undername-Increase-Notice', Sender = msg.Tags.Sender, Name = tostring(msg.Tags.name), ProcessId = tostring(msg.Tags.processId) }
                    })
                    -- Send the tokens back
                    ao.send({
                        Target = TOKEN_PROCESS_ID,
                        Tags = { Action = 'Transfer', Recipient = msg.Tags.Sender, Quantity = tostring(msg.Tags.Quantity) }
                    })
                    return
                end

                local record = Records[name]
                local endTimestamp
                if isLeaseRecord(record) then
                    endTimestamp = ensureMilliseconds(record.endTimestamp)
                else
                    endTimestamp = nil
                end

                local yearsRemaining
                if endTimestamp then
                    yearsRemaining = calculateYearsBetweenTimestamps(msg.Timestamp, endTimestamp)
                else
                    yearsRemaining = PERMABUY_LEASE_FEE_LENGTH -- Assuming PERMABUY_LEASE_FEE_LENGTH is defined somewhere
                end

                local existingUndernames = record.undernames

                local additionalUndernameCost = calculateUndernameCost(name, msg.Tags.qty, record.type,
                    yearsRemaining)

                if additionalUndernameCost > quantity then
                    print('Not enough tokens for adding undernames.')
                    ao.send({
                        Target = msg.Tags.Sender,
                        Tags = { Action = 'ArNS-Insufficient-Funds', Sender = msg.Tags.Sender, Name = tostring(msg.Tags.name), ProcessId = tostring(msg.Tags.processId) }
                    })
                    -- Send the tokens back
                    ao.send({
                        Target = TOKEN_PROCESS_ID,
                        Tags = { Action = 'Transfer', Recipient = msg.Tags.Sender, Quantity = tostring(msg.Tags.Quantity) }
                    })
                    return
                end

                local incrementedUndernames = existingUndernames + msg.Tags.qty
                Records[name].undernames = incrementedUndernames
                print('Increased undernames for: ' .. name .. " to " .. incrementedUndernames .. " undernames")

                -- Check if any remaining balance to send back
                local remainingQuantity = quantity - additionalUndernameCost
                if remainingQuantity > 1 then
                    -- Send the tokens back
                    print('Sending back remaining tokens: ' .. remainingQuantity)
                    ao.send({
                        Target = TOKEN_PROCESS_ID,
                        Tags = { Action = 'Transfer', Recipient = msg.Tags.Sender, Quantity = tostring(remainingQuantity) }
                    })
                    ao.send({
                        Target = msg.Tags.Sender,
                        Tags = { Action = 'ArNS-Increase-Undername-Notice-Remainder', Sender = msg.Tags.Sender, Name = tostring(msg.Tags.name), ProcessId = tostring(msg.Tags.processId), Quantity = tostring(remainingQuantity), IncrementedUndernames = tostring(incrementedUndernames) }
                    })
                else
                    ao.send({
                        Target = msg.Tags.Sender,
                        Tags = { Action = 'ArNS-Increase-Undername-Notice', Sender = msg.Tags.Sender, Name = tostring(msg.Tags.name), ProcessId = tostring(msg.Tags.processId), IncrementedUndernames = tostring(incrementedUndernames) }
                    })
                end
            end
        end
    else
        -- Optional: Handle or log unauthorized credit notice attempts.
        print("Unauthorized Credit-Notice attempt detected from: ", msg.From)
    end ]]
           --
function arns.buyRecord(msg)
    utils.reply("buyRecord is not implemented yet")
end

function arns.submitAuctionBid()
    utils.reply("submitAuctionBid is not implemented yet")
end

function arns.extendLease()
    -- TODO: implement
    utils.reply("extendLease is not implemented yet")
end

function arns.increaseUndernameCount()
    -- TODO: implement
    utils.reply("increaseUndernameCount is not implemented yet")
end

function arns.getRecord()
    -- TODO: implement
    utils.reply("getRecord is not implemented yet")
end

function arns.getAuction()
    -- TODO: implement
    utils.reply("getAuction is not implemented yet")
end

function arns.getReservedName()
    -- TODO: implement
    utils.reply("getReservedName is not implemented yet")
end

return arns
