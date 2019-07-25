-- Optimize.
local type = type
local tostring = tostring
local print = print
local error = error
local assert = assert
local format = string.format
local stringsub = string.sub

local function valueString(any)
	local str
	local vType = type(any)
	if vType == "string" then
		str = format("\"%s\"", any)
	elseif vType == "function" then
		str = stringsub(tostring(any), 11)
	elseif vType == "table" then
		str = stringsub(tostring(any), 8)
	else
		str = tostring(any)
	end
	return str
end

local function typeTag(any)
	local tags = {
		boolean = "b",
		number = "n",
		string = "s",
		["function"] = "f",
		thread = "th"
	}
	return tags[type(any)] or type(any)
end

local printSetting = {
	maxDeep = 100,
	index = "    ",
	defaultRootName = "root"
}

---
--- Prints any value.
function printAny(...)
	local printed = {}
	local function innerPrint(any, deep, name)
		if deep > printSetting.maxDeep then
			return
		end

		if type(any) ~= "table" then
			print(any)
			return
		end

		local index = printSetting.index
		local outIndex = string.rep(index, deep)
		if deep == 1 then
			print(format("%s %s", outIndex, valueString(any)))
		end
		print(format("%s {", outIndex))

		local inIndex = outIndex .. index
		for k, v in pairs(any) do
			if type(v) ~= "table" then
				print(format("%s[ %s ]%s = [ %s ]%s", inIndex, valueString(k), typeTag(k), valueString(v), typeTag(v)))
			else
				if not printed[v] then
					local vName = format("%s.%s", name, tostring(k))
					printed[v] = vName
					print(format("%s[ %s ]%s = %s", inIndex, valueString(k), typeTag(k), valueString(v)))
					innerPrint(v, deep + 1, vName)
				else
					print(format("%s[ %s ]%s = [ %s ]r", inIndex, valueString(k), typeTag(k), printed[v]))
				end
			end
		end
		print(format("%s }", outIndex))
	end

	for _, v in ipairs({...}) do
		printed = {}
		printed[v] = printSetting.defaultRootName
		innerPrint(v, 1, printed[v])
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
