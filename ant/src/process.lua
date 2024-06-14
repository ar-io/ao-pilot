-- lib
Handlers = Handlers or require(".common.handlers")
local json = require(".common.json")
local initialize = require(".common.initialize")
local _ao = require("ao")

local ant = require(".common.main")

local process = { _version = "0.0.1" }
-- wrap ao.send and ao.spawn for magic table
local aosend = _ao.send
local aospawn = _ao.spawn
_ao.send = function(msg)
	if msg.Data and type(msg.Data) == "table" then
		msg["Content-Type"] = "application/json"
		msg.Data = json.encode(msg.Data)
	end
	return aosend(msg)
end
_ao.spawn = function(module, msg)
	if msg.Data and type(msg.Data) == "table" then
		msg["Content-Type"] = "application/json"
		msg.Data = json.encode(msg.Data)
	end
	return aospawn(module, msg)
end

function Send(msg)
	_ao.send(msg)
	return "message added to outbox"
end

function Spawn(module, msg)
	if not msg then
		msg = {}
	end

	_ao.spawn(module, msg)
	return "spawn process request"
end

function Assign(assignment)
	_ao.assign(assignment)
	return "assignment added to outbox"
end

function Tab(msg)
	local inputs = {}
	for _, o in ipairs(msg.Tags) do
		if not inputs[o.name] then
			inputs[o.name] = o.value
		end
	end
	return inputs
end

function process.handle(msg, ao)
	ao.id = ao.env.Process.Id
	initialize.initializeProcessState(msg, ao.env)

	-- tagify msg
	msg.TagArray = msg.Tags
	msg.Tags = Tab(msg)
	-- tagify Process
	ao.env.Process.TagArray = ao.env.Process.Tags
	ao.env.Process.Tags = Tab(ao.env.Process)
	-- magic table - if Content-Type == application/json - decode msg.Data to a Table
	if msg.Tags["Content-Type"] and msg.Tags["Content-Type"] == "application/json" then
		msg.Data = json.decode(msg.Data or "{}")
	end
	-- init Errors
	Errors = Errors or {}
	-- clear Outbox
	ao.clearOutbox()

	-- Only trust messages from a signed owner or an Authority
	-- skip this check for test messages in dev
	if msg.From ~= msg.Owner and not ao.isTrusted(msg) then
		Send({ Target = msg.From, Data = "Message is not trusted by this process!" })
		print("Message is not trusted! From: " .. msg.From .. " - Owner: " .. msg.Owner)
		return ao.result({})
	end

	-- initialize the ANT handlers
	ant.init()

	local status, result = pcall(Handlers.evaluate, msg, ao.env)

	if not status then
		table.insert(Errors, result)
		return { Error = result }
		-- return {
		--   Output = {
		--     data = {
		--       prompt = Prompt(),
		--       json = 'undefined',
		--       output = result
		--     }
		--   },
		--   Messages = {},
		--   Spawns = {}
		-- }
	end

	return ao.result({})
end

return process
