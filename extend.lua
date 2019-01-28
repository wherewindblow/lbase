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
	return next(t) ~= nil
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