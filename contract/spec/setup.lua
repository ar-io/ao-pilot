package.path = "./contract/src/?.lua;" .. package.path
require("luacov")
require("state")
require('token')
require('demand')
require('constants')

_G.ao = {
	send = function()
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
