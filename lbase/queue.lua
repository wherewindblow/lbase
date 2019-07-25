local Class = require("lbase/class")
local LinkedList = require("lbase/linked_list")

--- @class Queue: Object
local Queue = Class.Object:inherit("Queue")

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
	return self.m_list:front()
end

---
--- Pops value from head.
function Queue:pop()
	self.m_list:removeFront()
end

---
--- Returns the value that use like standard `pairs`.
function Queue:pairs()
	return self.m_list:pairs()
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

	local index = 1
	for k, v in queue:pairs() do
		assert(v == valueArray[index])
		index = index + 1
	end

	local beforeSize = queue:size()
	queue:pop()
	assert(queue:size() == beforeSize - 1 and queue:front() == 2)
end

test()

return Queue