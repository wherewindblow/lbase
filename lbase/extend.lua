-- Optimize.
local type = type
local pairs = pairs
local next = next
local tostring = tostring
local assert = assert
local format = string.format
local stringlen = string.len
local stringsub = string.sub
local tableinsert = table.insert
local mathfloor = math.floor

---
--- Returns size of table.
--- @param t table
--- @return number
function table.size(t)
	local count = 0
	for k, v in pairs(t) do
		count = count + 1
	end
	return count
end

---
--- Checks table is empty.
--- @param t table
--- @return boolean
function table.empty(t)
	return next(t) == nil
end

---
--- Clones from `src` to `dest`.
--- @param src table
--- @param dest table Default is empty table.
--- @return table Destination table.
function table.clone(src, dest)
	dest = dest or {}
	for k, v in pairs(src) do
		dest[k] = v
	end
	return dest
end

---
--- Clones from `src` to `dest`.
--- @param src table
--- @param dest table Default is empty table.
--- @return table Destination table.
function table.deepclone(src, dest)
	local function clone(src, dest, deep)
		assert(deep < 15, "Clone too deep.")
		dest = dest or {}
		for k, v in pairs(src) do
			if type(v) == "table" then
				dest[k] = clone(v, nil, deep + 1)
			else
				dest[k] = v
			end
		end
		return dest
	end
	return clone(src, dest, 0)
end

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

local typeTagList = {
	["boolean"] = "b",
	["number"] = "n",
	["string"] = "s",
	["function"] = "f",
	["thread"] = "th"
}

local function typeTag(any)
	return typeTagList[type(any)] or type(any)
end

local printSetting = {
	maxDeep = 100,
	index = "    ",
	defaultRootName = "root"
}

---
--- Prints table.
--- @param t table
function table.print(t)
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

	printed[t] = printSetting.defaultRootName
	innerPrint(t, 1, printed[t])
end

---
--- Differentiate two table.
--- @param t1 table
--- @param t2 table
--- @return string|any|any Path and variable in two table.
function table.diff(t1, t2)
	if t1 == t2 then
		return
	end

	local t1Type = type(t1)
	local t2Type = type(t2)
	if t1Type ~= t2Type then
		return nil, t1, t2
	end

	if t1Type ~= "table" then
		if t1 ~= t2 then
			return nil, t1, t2
		end
		return
	end

	for k1, v1 in pairs(t1) do
		local v2 = t2[k1]
		if v2 == nil then
			return tostring(k1), v1, v2
		end
		local path, diffVar1, diffVar2 = table.diff(v1, v2)
		if diffVar1 then
			if path then
				return format("%s.%s", k1, path), diffVar1, diffVar2
			else
				return k1, diffVar1, diffVar2
			end
		end
	end

	for k2, v2 in pairs(t2) do
		local v1 = t1[k2]
		if v1 == nil then
			local k2Str
			if type(k2) == "number" and mathfloor(k2) == k2 then
				k2Str = format("%d", k2)
			else
				k2Str = tostring(k2)
			end
			return k2Str, v1, v2
		end
	end
end

---
--- Splits string into table.
--- @param s string
--- @param pattern string
--- @return table
function string.split(s, pattern)
	local result = {}
	string.gsub(s, '[^' .. pattern .. ']+', function(w)
		tableinsert(result, w)
	end)
	return result
end

---
--- String to table.
--- @param s string Table in string mode.
--- @return table
function string.totable(s)
	return loadstring("return ".. s)()
end

---
--- Checks is starts with pattern.
--- @param s string
--- @param pattern string
--- @return boolean
function string.startswith(s, pattern)
	local startPos, endPos = string.find(s, pattern)
	return startPos == 1
end

---
--- Checks is ends with pattern.
--- @param s string
--- @param pattern string
--- @return boolean
function string.endswith(s, pattern)
	local startPos, endPos = string.find(s, pattern)
	return endPos == string.len(s)
end

function string.safeformat(fmt, ...)
	local argsNum = select("#", ...)
	if argsNum == 0 then
		return fmt
	end
	local args = {...}
	local ok, msg = pcall(function ()
		return format(fmt, unpack(args, 1, argsNum))
	end)
	if not ok then
		msg = msg .. " > " .. debug.fulltraceback(2)
	end
	return msg
end

local VAR_TYPE = {
	LOCAL = 1,
	UPVALUE = 2,
}

local function variablesStr(varType, arg)
	local getVarFunc
	if varType == VAR_TYPE.LOCAL then
		getVarFunc = debug.getlocal
	else
		getVarFunc = debug.getupvalue
	end
	local localNum = 1
	local str

	while true do
		local name, value = getVarFunc(arg, localNum)
		if not name then
			break
		end

		-- Add variable name.
		if not str then
			str = format("\n\t\t'%s'", name)
		else
			str = format("%s\n\t\t'%s'", str, name)
		end

		-- Add variable value.
		local valueType = type(value)
		if valueType == "number" then
			if mathfloor(value) == value then
				str = format("%s: %d", str, value)
			else
				str = format("%s: %s", str, tostring(value))
			end
		elseif valueType == "string" then
			str = format("%s: '%s'", str, tostring(value))
		elseif valueType == "table" and type(value.getSnapshot) == "function" then
			str = format("%s: %s: %s", str, tostring(value), value:getSnapshot() or "unknown")
		else
			str = format("%s: %s", str, tostring(value))
		end

		localNum = localNum + 1
	end
	return str
end

local Class

local function fulltraceback(level)
    level = level or 1
	-- Outside level must add some level.
	-- 1. fulltraceback
	-- 2. pcall
	-- 3. debug.fulltraceback
    level = level + 3

    local traceList = { "stack traceback:" }
    local showLevel = 1

    while true do
        local funcInfo = debug.getinfo(level)
        if not funcInfo then
            break
        end

        -- Add source file.
        local traceInfo = format("\n\t(%d) %s:", showLevel, funcInfo.short_src)

        -- Add source line.
        if funcInfo.currentline > 0 then
            traceInfo = format("%s%d:", traceInfo, funcInfo.currentline)
        end

        -- Add function name.
        if stringlen(funcInfo.namewhat) ~= 0 then
            traceInfo = format("%s in function '%s'", traceInfo, funcInfo.name or "?")
        else
            if funcInfo.what == "main" then
                traceInfo = format("%s in main chunk", traceInfo)
            elseif funcInfo.what == "C" or funcInfo.what == "tail" then
                -- C function or tail call.
                traceInfo = format("%s ?", traceInfo)
            else
				if not Class then
					pcall(function() Class = require("lbase/class") end)
				end

				local originName = Class and Class.allOriginFunc[funcInfo.func]
				if originName then
					traceInfo = format("%s in function '%s'", traceInfo, originName)
				else
					traceInfo = format("%s in function <%s:%d>", traceInfo, funcInfo.short_src, funcInfo.linedefined)
				end
            end
        end

		-- Add general trace info.
		tableinsert(traceList, traceInfo)

		-- Add all local variables.
		local varLevel = level + 1 -- Outside level.
		local localVarStr = variablesStr(VAR_TYPE.LOCAL, varLevel)
		tableinsert(traceList, localVarStr)

		-- Add all upvalue.
		local upvalueStr = variablesStr(VAR_TYPE.UPVALUE, funcInfo.func)
		tableinsert(traceList, upvalueStr)

		showLevel = showLevel + 1
        level = level + 1
    end

    return table.concat(traceList)
end

---
--- Returns full traceback message that include all local variables.
--- @param level number Default is 1.
--- @return string
function debug.fulltraceback(level)
	local ok, msg = pcall(fulltraceback, level)
    if ok then
        return msg
    end

	local traceback = debug.traceback(level)
    return string.format("debug.fulltraceback internal error: %s\n%s", msg, traceback)
end

---
--- Hook for error.
function debug.errorhook(errMsg)
	print(errMsg)
	print(debug.fulltraceback(2))
end
