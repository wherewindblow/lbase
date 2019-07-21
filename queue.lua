local LinkedList = require("linked_list")

--- @class Queue: Object
local Queue = Object:inherit("Queue")

---
--- Constructs queue object.
function Queue:constructor()
	self.m_list = LinkedList:new()
end

---
--- Pushs value into tail.
--- @param value any
function Queue:push(value)
	self.m_list:add(value)
end

---
--- Returns front value.
--- @return any
function Queue:front()
	local iterator = self.m_list:iterator()
	return iterator()
end

---
--- Pops value from head.
function Queue:pop()
	self.m_list:removeFront()
end

---
--- Returns iterator to for each value.
--- @return function
function Queue:iterator()
	return self.m_list:iterator()
end

function Queue:debug()
	self.m_list:debug()
end

---
--- Returns size of queue.
--- @return number
function Queue:size()
	return self.m_list:size()
end

---
--- Checks is empty.
--- @return boolean
function Queue:empty()
	return self.m_list:empty()
end

Queue:setSerializableMembers({"m_list"})

local function test()
	local queue = Queue:new()
	assert(queue:empty())

	local valueArray = { 1, 2, 3}
	for _, value in ipairs(valueArray) do
		queue:push(value)
	end
	assert(not queue:empty() and queue:size() == table.size(valueArray))
	assert(queue:front() == valueArray[1])

	local iterator = queue:iterator()
	local index = 1
	while true do
		local value = iterator()
		if not value then
			break
		end

		assert(value, valueArray[index])
		index = index + 1
	end

	local beforeSize = queue:size()
	queue:pop()
	assert(queue:size() == beforeSize - 1 and queue:iterator()() == 2)
end

test()

return Queue