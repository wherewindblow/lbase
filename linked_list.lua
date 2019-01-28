--- @class LinkedList
local LinkedList = Object:inherit("LinkedList")

function LinkedList:constructor()
	self.m_head = {}
	self.m_tail = {}
	self.m_head.next = self.m_tail
	self.m_tail.previous = self.m_head
	self.m_size = 0
end

---
--- Adds value to tail.
--- @param value any
function LinkedList:add(value)
	self:pushBack(value)
end

---
--- Pushs value to head.
--- @param value any
function LinkedList:pushFront(value)
	local newNode = { value = value, previous = self.m_head, next = self.m_head.next }
	self.m_head.next.previous = newNode
	self.m_head.next = newNode
	self.m_size = self.m_size + 1
end

---
--- Pushs value to tail.
--- @param value any
function LinkedList:pushBack(value)
	local newNode = { value = value, previous = self.m_tail.previous, next = self.m_tail }
	self.m_tail.previous.next = newNode
	self.m_tail.previous = newNode
	self.m_size = self.m_size + 1
end

---
--- Removes value.
--- @param value any
function LinkedList:remove(value)
	assert(value, "value cannot be nil")
	local node = self.m_head
	while node do
		if node.value == value then
			node.previous.next = node.next
			node.next.previous = node.previous
			self.m_size = self.m_size - 1
			return
		end
		node = node.next
	end
end

---
--- Removes value from head.
function LinkedList:removeFront()
	if self:empty() then
		return
	end

	local node = self.m_head.next
	self.m_head.next = node.next
	node.next.previous = self.m_head
	self.m_size = self.m_size - 1
end

---
--- Removes value from tail.
function LinkedList:removeBack()
	if self:empty() then
		return
	end

	local node = self.m_tail.previous
	self.m_tail.previous = node.previous
	node.previous.next = self.m_tail
	self.m_size = self.m_size - 1
end

---
--- Removes value with target check.
--- @param isTarget function fun(value) To check value is target.
function LinkedList:removeIf(isTarget)
	local node = self.m_head
	while node do
		if node.value and isTarget(node.value) then
			node.previous.next = node.next
			node.next.previous = node.previous
			self.m_size = self.m_size - 1
		end
		node = node.next
	end
end

---
--- Returns size of list.
function LinkedList:size()
	return self.m_size
end

---
--- Returns iterator that can for each value.
--- @return function
function LinkedList:iterator()
	local next = self.m_head.next
	local function nextValue()
		local value = next.value
		next = next.next
		return value
	end

	return nextValue
end

---
--- Checks list is empty.
function LinkedList:empty()
	return self.m_size == 0
end

---
--- Clears list.
function LinkedList:clear()
	self:constructor()
end

function LinkedList:debug()
	local node = self.m_head
	while node do
		print(node, node.value, node.previous, node.next)
		node = node.next
	end
end

LinkedList:setSerializableMembers({"allValue"})

function LinkedList:serializeMember(name)
	if name == "allValue" then
		local iterator = self:iterator()
		local allValue = {}
		while true do
			local value = iterator()
			if not value then
				break
			end

			table.insert(allValue, value)
		end

		return allValue
	end
end

function LinkedList:unserializeMember(name, allValue)
	if name == "allValue" then
		for i, v in ipairs(allValue) do
			self:add(v)
		end
	end
end

local function test()
	local list = LinkedList:new()
	assert(list:empty())

	list:pushBack(1)
	list:pushBack(2)
	assert(not list:empty() and list:size() == 2)

	local iterator = list:iterator()
	local currentValue = 1
	while true do
		local value = iterator()
		if not value then
			break
		end

		assert(currentValue == value)
		currentValue = currentValue + 1
	end

	list:removeFront()
	assert(list:size() == 1 and list:iterator()() == 2)

	list:pushFront(1)
	list:removeBack()
	assert(list:size() == 1 and list:iterator()() == 1)
end

test()

local function computeUseTime(addFunc, removeFunc)
	local container
	local function proccess(funcName, func)
		collectgarbage("collect")
		local startMem = collectgarbage("count")
		local startTime = os.clock()
		container = func(container) or container
		local finishTime = os.clock()
		collectgarbage("collect")
		local finishMem = collectgarbage("count")
		print(string.format("%10s use time  %0.4f,   mem %7d", funcName, finishTime - startTime, finishMem - startMem))
	end

	proccess("addFunc", addFunc)
	proccess("removeFunc", removeFunc)
end

local function compareArrayAndList()
	local ITEM_NUM = 14000

	-- Hold integer.
	computeUseTime(function()
		local t = {}
		for i = 1, ITEM_NUM do
			table.insert(t, i)
		end
		return t
	end, function(t)
		for i = 1, ITEM_NUM do
			table.remove(t, 1)
		end
	end)

	computeUseTime(function()
		local list = LinkedList:new()
		for i = 1, ITEM_NUM do
			list:pushBack(i)
		end
		return list
	end, function(list)
		for i = 1, ITEM_NUM do
			list:removeFront()
		end
	end)

	-- Hold table.
	computeUseTime(function()
		local t = {}
		for i = 1, ITEM_NUM do
			table.insert(t, { i })
		end
		return t
	end, function(t)
		for i = 1, ITEM_NUM do
			table.remove(t, 1)
		end
	end)

	computeUseTime(function()
		local list = LinkedList:new()
		for i = 1, ITEM_NUM do
			list:pushBack({ i })
		end
		return list
	end, function(list)
		for i = 1, ITEM_NUM do
			list:removeFront()
		end
	end)
end

--compareArrayAndList()

-- Hold integer.
--
-- use array.    addFunc use time  0.0000,   mem     256
-- use array. removeFunc use time  1.1000,   mem       0
--
-- use list.     addFunc use time  0.0100,   mem    3063
-- use list.  removeFunc use time  0.0000,   mem   -3062
--
-- Hold table.
--
-- use array.    addFunc use time  0.0000,   mem    1349
-- use array. removeFunc use time  1.1200,   mem   -1093
--
-- use list.     addFunc use time  0.0100,   mem    4157
-- use list.  removeFunc use time  0.0100,   mem   -4156

return LinkedList