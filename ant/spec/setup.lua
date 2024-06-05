package.path = "./ant/src/?.lua;" .. package.path

_G.ao = {
	send = function(obj)
		return true
	end,
	id = "test",
}

_G.Handlers = {
	utils = {
		reply = function()
			return true
		end,
	},
}

os.clock = function()
	return 0
end

print("Setup global ao mocks successfully...")
