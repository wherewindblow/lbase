require("global")

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
