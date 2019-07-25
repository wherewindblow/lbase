-- Optimize.
local type = type
local pairs = pairs
local next = next
local tostring = tostring
local assert = assert
local format = string.format
local stringlen = string.len
local tableinsert = table.insert

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

---
--- Prints table.
--- @param t table
function table.print(t)
	printAny(t)
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

local function localVariables(level)
	level = level + 1 -- Outside level.
	local localNum = 1
	local str

	while true do
		local name, value = debug.getlocal(level, localNum)
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
			str = format("%s: %s", str, tostring(value))
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
        local isClassFuncWrapper
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
					xpcall(function() Class = require("lbase/class") end)
				end

				local originName = Class and Class.allOriginFunc[funcInfo.func]
				if originName then
					traceInfo = format("%s in function '%s'", traceInfo, originName)
				else
					traceInfo = format("%s in function <%s:%d>", traceInfo, funcInfo.short_src, funcInfo.linedefined)
				end
            end
        end

        if not isClassFuncWrapper then
            -- Add general trace info.
            tableinsert(traceList, traceInfo)

            -- Add all local variables.
            tableinsert(traceList, localVariables(level))

            showLevel = showLevel + 1
        end

        isClassFuncWrapper = nil
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

    return "debug.fulltraceback internal error: " .. msg
end

---
--- Hook for error.
function debug.errorhook(errMsg)
	print(errMsg)
	print(debug.fulltraceback(2))
end
