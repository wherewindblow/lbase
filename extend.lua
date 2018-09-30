function table.size(t)
	local count = 0
	for k, v in pairs(t) do
		count = count + 1
	end
	return count
end

function table.clone(src, dest)
	dest = dest or {}
	for k, v in pairs(src) do
		dest[k] = v
	end
	return dest
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