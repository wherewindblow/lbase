local IS_ALL_MODIFIED_KEY = "__isAllModify"
local NIL_VALUE = "__nil"

local ModificationCollector = {}

---
--- Adds monitor for container. And then all modification of container will be record.
--- @param tb table
function ModificationCollector:addMonitor(tb)
	local container = {}
	local proxy = {
		__hasModify = nil,
		__isAllModify = true,
		__isPathModify = false,
		__container = container,
		__parent = nil,
		__parentKey = nil,
	}

	local metatable = {
		__newindex = function (t, key, value)
			-- Set key has modify.
			if not proxy.__isAllModify then
				local hasModify = proxy.__hasModify
				if not hasModify then
					hasModify = {}
					rawset(proxy, "__hasModify", hasModify)
				end
				hasModify[key] = true
			end

			-- Set path has modify.
			if not proxy.__isPathModify then
				local curProxy = proxy
				while true do
					local parent = curProxy.__parent
					if not parent then
						break
					end
					if parent.__isPathModify then
						break
					end

					local parentHasModify = parent.__hasModify
					if not parentHasModify then
						parentHasModify = {}
						rawset(parent, "__hasModify", parentHasModify)
					end
					parentHasModify[curProxy.__parentKey] = true
					curProxy.__isPathModify = true
					curProxy = parent
				end
			end

			-- Add to container.
			if type(value) == "table" then
				value = self:addMonitor(value)
				rawset(value, "__parent", proxy)
				rawset(value, "__parentKey", key)
			end
			container[key] = value
		end,

		__index = container,
	}

	setmetatable(proxy, metatable)

	for k, v in pairs(tb) do
		proxy[k] = v
	end
	return proxy
end

local function innerCollect(proxy, notAllModified)
	local hasModify = proxy.__hasModify
	local isAllModify = proxy.__isAllModify
	if (not hasModify or table.empty(hasModify)) and (not isAllModify) then
		return
	end

	local container = proxy.__container
	if not container then
		return
	end

	local data = {}
	if isAllModify then
		if not notAllModified then
			data[IS_ALL_MODIFIED_KEY] = true
		end
		for key, value in pairs(container) do
			if type(value) ~= "table" then
				data[key] = value
			else
				value = innerCollect(value, true)
				data[key] = value
			end
		end
	else
		for key in pairs(hasModify) do
			local value = container[key]
			if not value then
				data[key] = NIL_VALUE
			elseif type(value) ~= "table" then
				data[key] = value
			else
				data[key] = innerCollect(value, notAllModified)
			end
		end
	end

	rawset(proxy, "__hasModify", nil)
	proxy.__isAllModify = false
	proxy.__isPathModify = false
	return data
end

---
--- Collects modified data of proxy.
--- NOTE: Proxy must be a table that generate by `addMonitor`, and it's root proxy not a sub proxy.
---       If pass a sub proxy will clear modification record and cannot collect in root proxy again.
--- @param proxy table
function ModificationCollector:collectModifiedData(proxy)
	return innerCollect(proxy)
end

local function test()
	-- Init table with number and table.
	local module = ModificationCollector:addMonitor({
		name = "testModule",
		t1 = { v = 1 }
	})

	-- Add number.
	module.num = 2
	assert(module.num == 2)
	-- Add table.
	module.t2 = { v = 3 }
	--table.print(module)
	local modifiedData1 = ModificationCollector:collectModifiedData(module)
	--table.print(modifiedData1)
	assert(modifiedData1.name == module.name)
	assert(modifiedData1.t1.v == module.t1.v)
	assert(modifiedData1.num == module.num)
	assert(modifiedData1.t2.v == module.t2.v)
	assert(modifiedData1[IS_ALL_MODIFIED_KEY])

	local t1 = module.t1
	-- Change internal table value.
	t1.v = 4
	t1.new = 5
	-- Remove number.
	module.num = nil
	--table.print(module)
	local modifiedData2 = ModificationCollector:collectModifiedData(module)
	--table.print(modifiedData2)
	assert(modifiedData2.t1.v == module.t1.v)
	assert(modifiedData2.t1.new == module.t1.new)
	assert(modifiedData2.num == NIL_VALUE)
	assert(not modifiedData2.name)

	-- Change new table to exist key.
	module.t1 = { newTable = true }
	-- Add new table and init with number and table.
	module.t3 = { v = 6, t4 = { v = 7 } }
	--table.print(module)
	local modifiedData3 = ModificationCollector:collectModifiedData(module)
	--table.print(modifiedData3)
	assert(modifiedData3.t1.newTable == module.t1.newTable)
	assert(modifiedData3.t1[IS_ALL_MODIFIED_KEY])
	assert(modifiedData3.t3.v == module.t3.v)
	assert(modifiedData3.t3.t4.v == module.t3.t4.v)
	assert(modifiedData3.t3[IS_ALL_MODIFIED_KEY])
	assert(not modifiedData3.name)
	assert(not modifiedData3.num)
end

test()

return ModificationCollector
