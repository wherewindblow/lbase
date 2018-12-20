
local format = string.format

local function valueString(any)
	local str
	local type = type(any)
	if type == "string" then
		str = format("\"%s\"", any)
	elseif type == "function" then
		str =  string.sub(tostring(any), 11)
	elseif type == "table" then
		str =  string.sub(tostring(any), 8)
	else
		str =  tostring(any)
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
					local v_name = format("%s.%s", name, tostring(k))
					printed[v] = v_name
					print(format("%s[ %s ]%s = %s", inIndex, valueString(k), typeTag(k), valueString(v)))
					innerPrint(v, deep + 1, v_name)
				else
					print(format("%s[ %s ]%s = [ %s ]r", inIndex, valueString(k), typeTag(k), printed[v]))
				end
			end
		end
		print(format("%s }", outIndex))
	end

	for _, v in ipairs({...}) do
		printed[v] = printSetting.defaultRootName
		innerPrint(v, 1, printed[v])
	end
end

function errorFmt(fmt, ...)
	error(format(fmt, ...))
end

-- Optimize assert expression.
function assertFmt(v, fmt, ...)
	if not v then
		errorFmt(fmt, ...)
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

require("class")
require("extend")

local function avoidAddGlobalVariable()
	local newGlobal = {}
	local metatable = getmetatable(_G) or {}

	metatable.__newindex = function(t, k, v)
		local info = debug.getinfo(2)
		printAny(info)
		print(string.format("WARNING: Add global variable \"%s\", type %s.", k, type(v)), debug.traceback())
		newGlobal[k] = v
	end

	metatable.__index = function(t, k)
		return newGlobal[k]
	end

	setmetatable(_G, metatable)
end

-- After this function, all variable in recommend to store in local.
-- To avoid add too many variable in global.
avoidAddGlobalVariable()