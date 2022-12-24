-- Optimize.
local print = print
local error = error
local assert = assert
local format = string.format

---
--- Prints any value.
function printAny(...)
	local argsNum = select("#", ...)
	local args = {...}
	for i = 1, argsNum do
		table.print(args[i])
	end
end

---
--- Error with format message.
--- @param fmt string Support default fmt.
function errorFmt(fmt, ...)
	local msg = fmt and format(fmt, ...)
	error(msg)
end

---
--- Assert with format message to optimize string format.
--- @param fmt string Support default fmt.
function assertFmt(v, fmt, ...)
	if not v then
		local msg = fmt and format(fmt, ...)
		assert(v, msg)
	end
end

local function compareAssertFormat()
	local exp
	local assertTimes = 1000000
	local function computeTimeUse(func)
		local startTime = os.clock()
		func()
		local finishTime = os.clock()
		print(finishTime - startTime)
	end

	computeTimeUse(function ()
		for i = 1, assertTimes do
			assert(not exp, string.format("failure when i is %d%s", i, "test"))
		end
	end)

	computeTimeUse(function ()
		for i = 1, assertTimes do
			assertFmt(not exp, "failure when i is %d%s", i, "test")
		end
	end)

	computeTimeUse(function ()
		for i = 1, assertTimes do
			if exp then
				error(string.format("failure when i is %d%s", i, "test"))
			end
		end
	end)
end

--compareAssertFormat()

--assert timeUse          0.53s
--assertFmt timeUse       0.05s
--if assert timeUse       0.01s
