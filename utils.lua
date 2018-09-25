local Utils = {}

-- Optimize.
local type = type
local tostring = tostring
local format = string.format
local assertFmt = assertFmt

-- Update module and ensure all old reference can be update.
-- 1. Use require to load module, so any module must return itself at file ending.
-- 2. Module can be class or module, module can include class, but cannot include module.
-- 3. Cannot change value type while update.
-- 4. Update only can add new value or replace old value, but cannot only remove old value.
-- 5. All define in main chunk will be perform again while update, so they will be update.
function Utils.update(module)
	local oldModule = require(module)
	package.loaded[module] = nil -- Ensure require can reload module again.
	local newModule = require(module)

	-- Copy all value into old module to ensure all old reference can be update.
	if oldModule.__type == TABLE_TYPE.Class then
		assert(newModule.__type == oldModule.__type, "Cannot change type while update module")
		table.clone(newModule, oldModule)
	else
		-- Is module and module may include class.
		for k, v in pairs(newModule) do
			if oldModule[k] then
				assert(type(v) == type(oldModule[k]), "Cannot change type while update module")
			end

			if v.__type == TABLE_TYPE.Class then
				if oldModule[k] then
					assert(v.__type == oldModule[k].__type, "Cannot change type while update module")
				end
				table.clone(v, oldModule[k])
			else
				oldModule[k] = v
			end
		end
	end

	-- Make require return old module reference.
	package.loaded[module] = oldModule
end

function Utils.serialize(t)
	local invalidType = {
		"thread",
		"function"
	}

	local processTable = {}
	local function process(t)
		if t.serialize and type(t.serialize) == "function" then
			t = t:serialize()
		end

		local str = "{"
		for k, v in pairs(t) do
			local kType = type(k)
			local vType = type(v)
			assertFmt(kType ~= "table", "Key cannot be table.")
			assertFmt(not invalidType[kType], "Key is invalid type.")
			assertFmt(not invalidType[vType], "Value is invalid type.")

			local kStr
			if kType == "string" then
				kStr = format("\"%s\"", tostring(k))
			else
				kStr = tostring(k)
			end

			local vStr
			if vType == "table" then
				assertFmt(not processTable[v], "Process %s repeat, cannot serialize circle reference table.")
				processTable[v] = true
				vStr = process(v)
			elseif vType == "string" then
				vStr = format("\"%s\"", tostring(v))
			else
				vStr = tostring(v)
			end

			str = format("%s[%s]=%s,", str, kStr, vStr)
		end
		str = str .. "}"
		return str
	end

	processTable[t] = true
	return process(t)
end

function Utils.unserialize(str, obj)
	local chunk = loadstring("return " .. str)
	local t = chunk()
	if obj then
		obj:unserialize(t)
		return obj
	end
	return t
end

local function serializeTest()
	local serialize = Utils.serialize
	local unserialize = Utils.unserialize

	local LinkedList = require("linked_list")
	local list1 = LinkedList:new()
	list1:add("a")
	list1:add("b")
	local list1Str = serialize(list1)
	local t = {"a", b = {"c", d = {"e"}}}
	local tStr = serialize(t)

	local list2 = LinkedList:new()
	unserialize(list1Str, list2)
	local iterator = list2:iterator()
	assert(iterator() == "a")
	assert(iterator() == "b")
	assert(list2:size() == 2)
	assert(serialize(list2) == list1Str)

	local t2 = unserialize(serialize(t))
	assert(t2[1] == "a")
	assert(t2.b[1] == "c")
	assert(t2.b.d[1] == "e")
	assert(serialize(t2) == tStr)
end

serializeTest()

return Utils