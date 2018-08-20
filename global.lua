
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

local printSetting = { maxDeep = 100, index = "    " }

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
		print(format("%s {", outIndex))

		local inIndex = outIndex .. index
		for k, v in pairs(any) do
			if true or k ~= "_G" then --
				if type(v) ~= "table" then
					print(format("%s[ %s ]%s = [ %s ]%s", inIndex, valueString(k), typeTag(k), valueString(v), typeTag(v)))
				else
					if not printed[v] then
						--print("not printed ", v)
						--table.print(printed)
						local v_name = format("%s.%s",name, tostring(k))
						printed[v] = v_name
						print(format("%s[ %s ]%s = %s", inIndex, valueString(k), typeTag(k), valueString(v)))
						innerPrint(v, deep + 1, v_name)
					else
						print(format("%s[ %s ]%s = [ %s ]r", inIndex, valueString(k), typeTag(k), printed[v]))
					end
				end
			end
		end
		print(format("%s }", outIndex))
	end

	for _, v in ipairs({...}) do
		printed[v] = "root"
		innerPrint(v, 1, printed[v])
	end
end

function errorFmt(fmt, ...)
	error(format(fmt, ...))
end

function assertFmt(v, fmt, ...)
	if not v then
		errorFmt(fmt, ...)
	end
end
