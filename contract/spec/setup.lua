package.path = package.path .. ";../src/?.lua"

require("luacov")
package.loaded["ar-io-ao"] = nil

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

print("Global setup loaded successfully")
