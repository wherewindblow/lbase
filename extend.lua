function table.size(t)
	local count = 0
	for k, v in pairs(t) do
		count = count + 1
	end
	return count
end

function table.empty(t)
	return next(t) ~= nil
end

-- Clone from `src` to `dest`. `dest` can be nil.
function table.clone(src, dest)
	dest = dest or {}
	for k, v in pairs(src) do
		dest[k] = v
	end
	return dest
end

-- Clone from `src` to `dest`. `dest` can be nil.
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

function table.print(t)
	printAny(t)
end

function string.split(s, p)
	local rt = {}
	string.gsub(s, '[^' .. p .. ']+', function(w)
		table.insert(rt, w)
	end)
	return rt
end

function string.totable(s)
	return loadstring("return ".. s)()
end