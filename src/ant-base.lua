-- Load the JSON library for handling JSON data
local json = require('json')
-- Setup the default record pointing to the ArNS landing page if it doesn't exist
if not Records then
    Records = {}
    Records['@'] = {
        transactionId = 'UyC5P5qKPZaltMmmZAWdakhlDXsBF6qmyrbWYFchRTk',
        ttlSeconds = 3600
    }
end

-- Set empty controllers if they don't exist
if not Controllers then
    Controllers = {}
end

-- Handle 'info' messages with a matching 'Action' tag of 'Info'
Handlers.add('info', Handlers.utils.hasMatchingTag('Action', 'Info'), function(msg)
    -- Construct information to send back to the requester
    local info = {
        owner = Owner,
        records = Records
    }
    -- Send the information as a JSON-encoded data packet
    ao.send(
        {
            Target = msg.From,
            Tags = { Action = 'Info-Notice', ProcessOwner = Owner },
            Data = json.encode(info)
        })
end)

-- Handle 'getRecord' messages with a matching 'Action' tag of 'Get-Record'
Handlers.add('getRecord', Handlers.utils.hasMatchingTag('Action', 'Get-Record'), function(msg)
    -- Check if the requested subdomain exists in the Records
    if msg.Tags.SubDomain and Records[msg.Tags.SubDomain] then
        -- Send back the record information for the requested subdomain
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Record-Resolved', SubDomain = msg.Tags.SubDomain, TransactionId = Records[msg.Tags.SubDomain].transactionId, TtlSeconds = tostring(Records[msg.Tags.SubDomain].ttlSeconds) }
        })
    elseif Records['@'] then -- If no SubDomain is provided, then return the root subdomain record
        -- Send back the record information for the root subdomain
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Record-Resolved', SubDomain = '@', TransactionId = Records['@'].transactionId, TtlSeconds = tostring(Records['@'].ttlSeconds) }
        })
    else
        -- Send an error message if the requested record does not exist
        ao.send({
            Target = msg.From,
            Tags = { Action = 'Get-Record-Error', ['Message-Id'] = msg.Id, Error = 'Requested non-existant record' }
        })
    end
end)

-- Handler to get records based on specific action tag
Handlers.add('getRecords', Handlers.utils.hasMatchingTag('Action', 'Get-Records'),
    function(msg) ao.send({ Action = 'Records-Resolved', Target = msg.From, Data = json.encode(Records) }) end)

-- Handler to set a record based on specific action tag
Handlers.add('setRecord', Handlers.utils.hasMatchingTag('Action', 'Set-Record'), function(msg, env)
    -- Validate if the record is valid
    local isValidRecord, responseMsg = validateSetRecord(msg)
    if isValidRecord then
        -- Check if the sender is the owner process
        if msg.From == env.Process.Id then
            -- Update the record for the specified subdomain
            Records[msg.Tags.SubDomain] = {
                transactionId = msg.Tags.TransactionId,
                ttlSeconds = msg.Tags.TtlSeconds
            }
            -- Send SetRecord-Notice to the Sender if cast is not provided
            if not msg.Tags.Cast then
                ao.send({
                    Target = msg.From,
                    Tags = { Action = 'SetRecord-Notice', SubDomain = msg.Tags.SubDomain, TransactionId = msg.Tags.TransactionId, TtlSeconds = msg.Tags.TtlSeconds }
                })
            end
        -- Check if the sender is a valid controller
        elseif Controllers[msg.From] then
            -- Update the record for the specified subdomain
            Records[msg.Tags.SubDomain] = {
                transactionId = msg.Tags.TransactionId,
                ttlSeconds = msg.Tags.TtlSeconds
            }
            -- Send SetRecord-Notice to the Sender if cast is not provided
            if not msg.Tags.Cast then
                ao.send({
                    Target = msg.From,
                    Tags = { Action = 'SetRecord-Notice', SubDomain = msg.Tags.SubDomain, TransactionId = msg.Tags.TransactionId, TtlSeconds = msg.Tags.TtlSeconds }
                })
                -- Send SetRecord-Notice to the Owner if cast is not provided
                ao.send({
                    Target = env.Process.Id,
                    Tags = { Action = 'SetRecord-Notice', Controller = msg.From, SubDomain = msg.Tags.SubDomain, TransactionId = msg.Tags.TransactionId, TtlSeconds = msg.Tags.TtlSeconds }
                })
            end
        else
            -- Send error message if sender is not the owner or a valid controller
            ao.send({
                Target = msg.From,
                Tags = { Action = 'SetRecord-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
            })
        end
    else
        -- Send error message if the record is not valid
        ao.send({
            Target = msg.From,
            Tags = { Action = 'SetRecord-Error', ['Message-Id'] = msg.Id, Error = responseMsg }
        })
    end
end)

-- Handler to remove a record based on specific action tag
Handlers.add('removeRecord', Handlers.utils.hasMatchingTag('Action', 'Remove-Record'), function(msg, env)
    -- Check if the sender is the owner process or a valid controller
    if msg.From == env.Process.Id or Controllers[msg.From] then
        -- Check if the record for the specified subdomain exists
        if Records[msg.Tags.SubDomain] then
            -- Remove the record for the specified subdomain
            Records[msg.Tags.SubDomain] = nil
            -- Send RemoveRecord-Notice to the Sender if cast is not provided
            if not msg.Tags.Cast then
                ao.send({
                    Target = msg.From,
                    Tags = { Action = 'RemoveRecord-Notice', SubDomain = msg.Tags.SubDomain }
                })
            end
        else
            -- Send error message if the specified subdomain does not exist in this process
            ao.send({
                Target = msg.From,
                Tags = { Action = 'RemoveRecord-Error', ['Message-Id'] = msg.Id, Error = 'Subdomain does not exist in this process' }
            })
        end
    else
        -- Send error message if sender is not the owner or a valid controller
        ao.send({
            Target = msg.From,
            Tags = { Action = 'RemoveRecord-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
        })
    end
end)


-- This handler is triggered when a message with the tag 'Action' and value 'Set-Controller' is received.
Handlers.add('setController', Handlers.utils.hasMatchingTag('Action', 'Set-Controller'), function(msg, env)
    -- Check if the message sender is the process owner
    if msg.From == env.Process.Id then
        -- Set the controller status for the specified target
        Controllers[msg.Tags.Target] = true
        -- Check if the 'Cast' tag is not provided in the message
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
        -- Send an error message to the sender if they are not the process owner
        ao.send({
            Target = msg.From,
            Tags = { Action = 'SetController-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
        })
    end
end)

-- This handler is triggered when a message with the tag 'Action' and value 'Remove-Controller' is received.
Handlers.add('removeController', Handlers.utils.hasMatchingTag('Action', 'Remove-Controller'), function(msg, env)
    -- Check if the message sender is the process owner
    if msg.From == env.Process.Id then
        -- Remove the controller status for the specified target
        Controllers[msg.Tags.Target] = nil
        -- Check if the 'Cast' tag is not provided in the message
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
        -- Send an error message to the sender if they are not the process owner
        ao.send({
            Target = msg.From,
            Tags = { Action = 'RemoveController-Error', ['Message-Id'] = msg.Id, Error = NON_PROCESS_OWNER_CONTROLLER_MESSAGE }
        })
    end
end)
