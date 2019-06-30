-- Optimize.
local pairs = pairs
local type = type
local tostring = tostring
local format = string.format
local stringlen = string.len
local stringsub = string.sub
local stringgsub = string.gsub
local TABLE_TYPE = TABLE_TYPE
local assertFmt = assertFmt

local Utils = {}

---
--- Update module and ensure all old reference can be update.
--- 1. Use require to load module, so any module must return itself at file ending.
--- 2. Module can be class or module, module can include class, but cannot include module.
--- 3. Cannot change value type while update.
--- 4. Update only can add new value or replace old value, but cannot only remove old value.
--- 5. Only code(function or class) that inside module can be update, data will not change.
--- 6. All define in main chunk will be perform again while update, so they will be update.
--- @param module string
function Utils.update(module)
	local oldModule = require(module)
	package.loaded[module] = nil -- Ensure require can reload module again.
	local newModule = require(module)

	-- Copy all value into old module to ensure all old reference can be update.
	if oldModule.__type == TABLE_TYPE.Class then
		assertFmt(newModule.__type == oldModule.__type, "Cannot change type while update module, new type %s, old type %s.", newModule.__type or "nil", oldModule.__type or "nil")
		table.clone(newModule, oldModule)
	else
		-- Is module and module may include class.
		for k, v in pairs(newModule) do
			local oldV = oldModule[k]
			local vType = type(v)
			if oldV then
				assertFmt(vType == type(oldV), "Cannot change type while update module, new type %s, old type %s.", vType, type(oldV))
			end

			if vType == "table" then
				if v.__type == TABLE_TYPE.Class then
					if oldV then
						assertFmt(v.__type == oldV.__type, "Cannot change type while update module, new type %s, old type %s.", v.__type or "nil", oldV.__type or "nil")
						table.clone(v, oldV)
					else
						oldModule[k] = v
					end
				else -- Is data.
					if not oldV then
						oldModule[k] = v
					end
				end
			elseif vType == "function" then
				oldModule[k] = v
			else -- Is data.
				if not oldV then
					oldModule[k] = v
				end
			end
		end
	end

	-- Make sure require return old module reference.
	package.loaded[module] = oldModule
end

local function storeableString(str)
	local rawTag = "[[raw]]"
	local rawTagLen = stringlen(rawTag)

	local tag = stringsub(str, 1, rawTagLen)
	if tag == rawTag then
		return stringsub(str, rawTagLen + 1)
	else
		str = format("\"%s\"", str)
		return stringgsub(str, "\n", "\\\n")
	end
end

---
--- Serialize table or object to string.
--- NOTE: Cannot serialize circle reference table.
---       Cannot serialize thread and function.
---       Key cannot be table.
--- @param t table Serialization target.
--- @param optimize boolean Default is false. Uses to trim space character.
--- @return string
function Utils.serialize(t, optimize)
	local invalidType = {
		["thread"] = 1,
		["function"] = 2,
	}

	local index = "    "

	optimize = optimize or false

	local processedTable = {}
	local function process(t, name, deep)
		if t.__type == TABLE_TYPE.Object then
			t = t:serialize()
		end

		local outIndex = string.rep(index, deep)

		local str
		if optimize then
			str = "{"
		else
			if deep == 0 then
				str = format("%s{\n", outIndex)
			else
				str = "{\n"
			end
		end

		local inIndex = outIndex .. index
		for k, v in pairs(t) do
			local kType = type(k)
			local vType = type(v)
			assertFmt(kType ~= "table", "Key cannot be table.")
			assertFmt(not invalidType[kType], "Key is invalid type.")
			assertFmt(not invalidType[vType], "Value is invalid type.")

			local kStr
			if kType == "string" then
				kStr = storeableString(k)
			else
				kStr = tostring(k)
			end

			local vStr
			if vType == "table" then
				local vName = format("%s.%s", name, tostring(k))
				assertFmt(not processedTable[v], "Process %s repeat with %s, cannot serialize circle reference table.", vName, processedTable[v])
				processedTable[v] = vName
				vStr = process(v, vName, deep + 1)
			elseif vType == "string" then
				vStr = storeableString(v)
			else
				vStr = tostring(v)
			end

			if optimize then
				str = format("%s[%s]=%s,", str, kStr, vStr)
			else
				str = format("%s%s[%s] = %s,\n", str, inIndex, kStr, vStr)
			end
		end

		if optimize then
			str = str .. "}"
		else
			str = format("%s%s}", str, outIndex)
		end
		return str
	end

	local rootName = "root"
	processedTable[t] = rootName
	return process(t, rootName, 0)
end

---
--- Unserialize string to table or object.
--- NOTE: `str` is a table string and not include return.
--- @param str string
--- @return table or object
function Utils.unserialize(str)
	local chunk, err = loadstring("return " .. str)
	assert(chunk, err)
	local t = chunk()
	if t.__className then
		return Object:unserialize(t)
	end
	return t
end

local function testSerialize()
	local serialize = Utils.serialize
	local unserialize = Utils.unserialize

	local LinkedList = require("linked_list")
	local list1 = LinkedList:new()
	list1:add("a")
	list1:add("b")
	list1:add("a\
b")
	local list1Str = serialize(list1)
	local t = {
		"a",
		b = {
			"c",
			d = {
				"e"
			}
		}
	}
	local tStr = serialize(t)

	local list2 = unserialize(list1Str)
	local iterator = list2:iterator()
	assert(list2:size() == 3)
	assert(iterator() == "a")
	assert(iterator() == "b")
	assert(iterator() == "a\
b")
	assert(serialize(list2) == list1Str)

	local t2 = unserialize(tStr)
	assert(t2[1] == "a")
	assert(t2.b[1] == "c")
	assert(t2.b.d[1] == "e")
	assert(serialize(t2) == tStr)

	local Base = Object:inherit("TestSerializeBase")

	local Queue = require("queue")

	function Base:constructor()
		self.m_list = LinkedList:new()
		self.m_queue = Queue:new()
		self:finishCall(Base.constructor)
	end
	Base:expectCall("constructor")

	function Base:addDefaultValue()
		self.m_list:add(1)
		self.m_list:add(2)
		self.m_queue:push("a")
		self.m_queue:push("b")
	end

	Base:setSerializableMembers({"m_list", "m_queue"})

	local Derived = Base:inherit("TestSerializeDerived")
	function Derived:constructor(name)
		super(Derived).constructor(self)
		self.m_name = name
	end

	Derived:setSerializableMembers({"m_name"})

	local derived1 = Derived:new("Derived")
	derived1:addDefaultValue()
	local derived1Str = serialize(derived1)
	local derived2 = unserialize(derived1Str)
	assert(serialize(derived2) == derived1Str)

	AllClass["TestSerializeBase"] = nil
	AllClass["TestSerializeDerived"] = nil
end

testSerialize()

---
--- Monitor table get set operation.
--- @param setCallback function
--- @param getCallback function
--- @return table
function Utils.proxyTable(setCallback, getCallback)
	local container = {}
	local metatable = {
		__newindex = function (t, k, v)
			if container[k] ~= v then
				setCallback(t, k, v)
			end
			container[k] = v
		end,
		__index = function (t, k)
			getCallback(t, k)
			return container[k]
		end
	}
	local proxy = {}
	setmetatable(proxy, metatable)
	return proxy
end

return Utils