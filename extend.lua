-- Optimize.
local type = type
local pairs = pairs
local next = next
local tostring = tostring
local assert = assert
local format = string.format
local len = string.len

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
--- @param dest table Default is nil.
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
--- @param dest table Default is nil.
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
		table.insert(result, w)
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

local function addLocalVariable(str, level)
	level = level + 1 -- Outside level.
	local localNum = 1
	while true do
		local name, value = debug.getlocal(level, localNum)
		if not name then
			break
		end

		-- Add variable name.
		str = format("%s\n\t\t'%s'", str, name)

		-- Add variable value.
		local valueType = type(value)
		if valueType == "number" then
			str = format("%s: %s", str, tostring(value))
		elseif valueType == "string" then
			str = format("%s: '%s'", str, tostring(value))
		else
			str = format("%s: %s", str, tostring(value))
		end

		localNum = localNum + 1
	end
	return str
end

---
--- Returns full traceback message that include all local variables.
--- @param level number
--- @return string
function debug.fulltraceback(level)
	level = level or 2 -- Outside level is 2.
	local str = "stack traceback:"

	while true do
		local funcInfo = debug.getinfo(level)
		if not funcInfo then
			break
		end

		-- Add source file.
		str = format("%s\n\t(%d) %s:", str, level - 1, funcInfo.short_src)

		-- Add source line.
		if funcInfo.currentline > 0 then
			str = format("%s%d:", str, funcInfo.currentline)
		end

		-- Add function name.
		if len(funcInfo.namewhat) ~= 0 then
			str = format("%s in function '%s'", str, funcInfo.name or "?")
		else
			if funcInfo.what == "main" then
				str = format("%s in main chunk", str)
			elseif funcInfo.what == "C" or funcInfo.what == "tail" then -- C function or tail call.
				str = format("%s ?", str)
			else
				str = format("%s in function <%s:%d>", str, funcInfo.short_src, funcInfo.linedefined)
			end
		end

		-- Add all local variable.
		str = addLocalVariable(str, level)

		level = level + 1
	end
	return str
end
