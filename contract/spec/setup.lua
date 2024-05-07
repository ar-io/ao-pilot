require("luacov")

_G.ao = {
	send = function()
		return true
	end,
	id = "test",
}
os.clock = function()
	return 0
end

print("Global setup loaded successfully")
