local LinkedList = require("linked_list")
local Queue = Object:inherit("Queue")

function Queue:constructor()
	self.m_list = LinkedList:new()
end

function Queue:push(value)
	self.m_list:add(value)
end

function Queue:front()
	local iterator = self.m_list:iterator()
	return iterator()
end

function Queue:pop()
	self.m_list:removeFront()
end

function Queue:iterator()
	return self.m_list:iterator()
end

function Queue:debug()
	self.m_list:debug()
end

function Queue:size()
	return self.m_list:size()
end

function Queue:empty()
	return self.m_list:empty()
end

function Queue:serialize()
	return self.m_list:serialize()
end

function Queue:unserialize(allValue)
	return self.m_list:unserialize(allValue)
end

local function test()
	local queue = Queue:new()
	queue:push(1)
	queue:push(2)
	assert(not queue:empty() and queue:size() == 2)
	assert(queue:front() == 1)

	local iterator = queue:iterator()
	local currentValue = 1
	while true do
		local value = iterator()
		if not value then
			break
		end

		assert(currentValue == value)
		currentValue = currentValue + 1
	end

	queue:pop()
	assert(queue:size() == 1 and queue:iterator()() == 2)
end

test()

return Queue