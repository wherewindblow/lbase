local Class = require("lbase/class")

--- @class LinkedList : Object
local LinkedList = Class.Object:inherit("LinkedList")

---
--- Constructs list object.
function LinkedList:constructor()
	self.m_head = {}
	self.m_tail = {}
	self.m_head.next = self.m_tail
	self.m_tail.previous = self.m_head
	self.m_size = 0
	self.m_nodeMap = {}
end

---
--- Adds value to tail.
--- @param value any
--- @return table Node that contain value.
function LinkedList:add(value)
	return self:pushBack(value)
end

---
--- Pushs value to head.
--- @param value any
--- @return table Node that contain value.
function LinkedList:pushFront(value)
	local node = { value = value, previous = self.m_head, next = self.m_head.next }
	self.m_head.next.previous = node
	self.m_head.next = node
	self.m_size = self.m_size + 1
	self.m_nodeMap[node] = true
	return node
end

---
--- Pushs value to tail.
--- @param value any
--- @return table Node that contain value.
function LinkedList:pushBack(value)
	local node = { value = value, previous = self.m_tail.previous, next = self.m_tail }
	self.m_tail.previous.next = node
	self.m_tail.previous = node
	self.m_size = self.m_size + 1
	self.m_nodeMap[node] = true
	return node
end

---
--- Removes value.
--- @param value any
--- @return table Node that contain value.
function LinkedList:remove(value)
	assert(value, "Value cannot be nil")
	local node = self.m_head
	while node do
		if node.value == value then
			node.previous.next = node.next
			node.next.previous = node.previous
			self.m_size = self.m_size - 1
			self.m_nodeMap[node] = nil
			return node
		end
		node = node.next
	end
end

---
--- Removes value from head.
--- @return table Node that contain value.
function LinkedList:removeFront()
	if self:empty() then
		return
	end

	local node = self.m_head.next
	self.m_head.next = node.next
	node.next.previous = self.m_head
	self.m_size = self.m_size - 1
	self.m_nodeMap[node] = nil
	return node
end

---
--- Removes value from tail.
--- @return table Node that contain value.
function LinkedList:removeBack()
	if self:empty() then
		return
	end

	local node = self.m_tail.previous
	self.m_tail.previous = node.previous
	node.previous.next = self.m_tail
	self.m_size = self.m_size - 1
	self.m_nodeMap[node] = nil
	return node
end

---
--- Removes value with target check.
--- @param isTarget function fun(value) To check value is target.
--- @return table Node list that contain value.
function LinkedList:removeIf(isTarget)
	local node = self.m_head
	local nodeList = {}
	while node do
		if node.value and isTarget(node.value) then
			node.previous.next = node.next
			node.next.previous = node.previous
			self.m_size = self.m_size - 1
			self.m_nodeMap[node] = nil
			table.insert(nodeList, node)
		end
		node = node.next
	end
	return nodeList
end

function LinkedList:removeNode(node)
	assert(self.m_nodeMap[node], "Invalid node in LinkedList.")
	node.previous.next = node.next
	node.next.previous = node.previous
	self.m_size = self.m_size - 1
	self.m_nodeMap[node] = nil
end

---
--- Returns head value.
function LinkedList:front()
	return self.m_head.next.value
end

---
--- Returns tail value.
function LinkedList:back()
	return self.m_tail.previous.value
end

---
--- Moves node to head.
function LinkedList:moveToFront(node)
	self:removeNode(node)
	local next = self.m_head.next
	self.m_head.next = node
	next.previous = node
	node.next = next
	node.previous = self.m_head
	self.m_nodeMap[node] = true
	self.m_size = self.m_size + 1
end

---
--- Moves node to tail.
function LinkedList:moveToBack(node)
	self:removeNode(node)
	local previous = self.m_tail.previous
	self.m_tail.previous = node
	previous.next = node
	node.next = self.m_tail
	node.previous = previous
	self.m_nodeMap[node] = true
	self.m_size = self.m_size + 1
end

---
--- Returns size of list.
function LinkedList:size()
	return self.m_size
end

---
--- Returns the value that use like standard `pairs`.
function LinkedList:pairs()
	local function next(self, node)
		node = node.next
		if node and node.value then
			return node, node.value
		end
	end
	return next, self, self.m_head
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
		local allValue = {}
		for k, v in self:pairs() do
			table.insert(allValue, v)
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

	local valueArray = { 1, 2, 3}
	for _, value in ipairs(valueArray) do
		list:pushBack(value)
	end

	assert(not list:empty() and list:size() == table.size(valueArray))

	local index = 1
	for k, v in list:pairs() do
		assert(v == valueArray[index])
		index = index + 1
	end

	local oldSize = list:size()
	list:removeFront()
	assert(list:size() == oldSize - 1 and list:front() == valueArray[2])

	local beforeSize = list:size()
	local newValue = 1
	list:pushFront(newValue)
	list:removeBack()
	assert(list:size() == beforeSize and list:front() == newValue)
end

test()

local function computeUseTime(type, funcList)
	local container
	local function proccess(type, funcName, func)
		collectgarbage("collect")
		local startMem = collectgarbage("count")
		local startTime = os.clock()
		container = func(container) or container
		local finishTime = os.clock()
		collectgarbage("collect")
		local finishMem = collectgarbage("count")
		print(string.format("%-15s %-10s use time  %0.4f,   mem %7d",
				type, funcName, finishTime - startTime, finishMem - startMem))
	end

	local funcNameList = {"init", "add", "remove"}
	for _, name in ipairs(funcNameList) do
		proccess(type, name, funcList[name])
	end
end

local function compareArrayAndList()
	local ITEM_NUM = 14000

	-- Hold integer.
	computeUseTime("array integer", {
		init = function()
			return {}
		end,
		add = function(t)
			for i = 1, ITEM_NUM do
				table.insert(t, i)
			end
			return t
		end,
		remove = function(t)
			for i = 1, ITEM_NUM do
				table.remove(t, 1)
			end
		end })

	computeUseTime("list integer", {
		init = function()
			return LinkedList:new()
		end,
		add = function(list)
			for i = 1, ITEM_NUM do
				list:pushBack(i)
			end
			return list
		end,
		remove = function(list)
			for i = 1, ITEM_NUM do
				list:removeFront()
			end
		end })

	-- Hold table.
	computeUseTime("array table", {
		init = function()
			return {}
		end,
		add = function(t)
			for i = 1, ITEM_NUM do
				table.insert(t, { i })
			end
			return t
		end,
		remove = function(t)
			for i = 1, ITEM_NUM do
				table.remove(t, 1)
			end
		end })

	computeUseTime("list table", {
		init = function()
			return LinkedList:new()
		end,
		add = function(list)
			for i = 1, ITEM_NUM do
				list:pushBack({ i })
			end
			return list
		end,
		remove = function(list)
			for i = 1, ITEM_NUM do
				list:removeFront()
			end
		end })
end

--compareArrayAndList()

-- Hold integer.
-- array integer   init       use time  0.0000,   mem       0
-- array integer   add        use time  0.0046,   mem     256
-- array integer   remove     use time  1.0748,   mem       0
-- list integer    init       use time  0.0000,   mem       1
-- list integer    add        use time  0.0105,   mem    3702
-- list integer    remove     use time  0.0070,   mem   -3062
--
-- Hold table.
-- array table     init       use time  0.0000,   mem       0
-- array table     add        use time  0.0043,   mem    1349
-- array table     remove     use time  1.1518,   mem   -1093
-- list table      init       use time  0.0000,   mem       1
-- list table      add        use time  0.0125,   mem    4796
-- list table      remove     use time  0.0071,   mem   -4156

return LinkedList