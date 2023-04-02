local Extend = require("lbase/extend")
local Class = require("lbase/class")

-- Optimize.
local assertFmt = Extend.assertFmt

--- @class Event : Object
local Event = Class.Object:inherit("Event")

---
--- Constructs event object.
function Event:constructor()
	self.m_eventMap = {}
end

---
--- Register event for object. Only after this operation can use `listen` and `dispatch`.
--- @param eventName string Name of event.
function Event:register(eventName)
	assertFmt(not self.m_eventMap[eventName], "Already register for this event.")
	local listenerMap = {}
	setmetatable(listenerMap, { __mode = "k" })
	self.m_eventMap[eventName] = listenerMap
end

---
--- Removes event for object.
--- @param eventName string Name of event. Default is nil to remove all event of object.
function Event:remove(eventName)
	self.m_eventMap[eventName] = nil
end

---
--- Listens for event, when dispatch will call object callback.
--- NOTE: Must call `register` to register event before listen it.
--- @param eventName string Name of event.
--- @param obj table  Object or module that listen event.
--- @param callbackName string Name of callback function that in `obj`. Like fun(eventName, ...).
---                     This king of usage is use to support update function.
function Event:listen(eventName, obj, callbackName)
	local listenerMap = self.m_eventMap[eventName]
	assertFmt(listenerMap, "Listen for unknown event.")
	assertFmt(not listenerMap[obj], "Already listen for this event.")
	listenerMap[obj] = callbackName
end

---
--- Dispatches event to all object that listen for this event.
--- NOTE: Must call `register` to register event before dispatch it.
--- @param eventName string Name of event.
--- @param eventArgs table Arguments about event.
function Event:dispatch(eventName, eventArgs)
	local listenerMap = self.m_eventMap[eventName]
	assertFmt(listenerMap, "Dispatch for unknown event.")
	for targetObj, callbackName in pairs(listenerMap) do
		xpcall(function()
			if eventArgs then
				targetObj[callbackName](targetObj, eventName, unpack(eventArgs))
			else
				targetObj[callbackName](targetObj, eventName)
			end
		end, debug.errorhook)
	end
end

local function test()
	local event = Event:new()
	event:register("work")

	local src = {}
	function src:work(...)
		event:dispatch("work", { src, ... })
	end

	local dest = {}
	event:listen("work", dest,"onWork")

	local eventArgs = { 1, 2, "s" }

	local finishEvent
	function dest:onWork(eventName, eventSrc, ...)
		finishEvent = true
		assert(eventName == "work")
		assert(eventSrc == src)
		local args = { ... }
		for i, value in ipairs(args) do
			assert(value == eventArgs[i])
		end
	end

	src:work(unpack(eventArgs))
	assert(finishEvent)

	event:remove("work")
	local ok, msg = pcall(function () event:listen("work", dest,"onWork") end)
	assert(not ok)
end

test()

return Event
