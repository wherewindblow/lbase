
local Event = {
	m_eventList = {},
}

---
--- Register event for object. Only after this operation can use `listen` and `dispatch`.
--- @param eventName string Name of event.
function Event:register(eventName)
	assert(not self.m_eventList[eventName], "Already register for this event.")
	self.m_eventList[eventName] = {}
end

---
--- Removes event for object.
--- @param eventName string Name of event. Default is nil to remove all event of object.
function Event:remove(eventName)
	self.m_eventList[eventName] = nil
end

---
--- Listens for event, when dispatch will call object callback.
--- NOTE: Must call `register` to register event before listen it.
--- @param obj table  Object or module that listen event.
--- @param eventName string Name of event.
--- @param callbackName string Name of callback function that in `obj`. Like fun(eventName, ...).
---                     This king of usage is use to support update function.
function Event:listen(obj, eventName, callbackName)
	local listenerList = self.m_eventList[eventName]
	assert(listenerList, "Listen for unknown event.")
	assert(not listenerList[obj], "Already listen for this event.")
	listenerList[obj] = callbackName
end

---
--- Dispatches event to all object that listen for this event.
--- NOTE: Must call `register` to register event before dispatch it.
--- @param eventName string Name of event.
--- @param eventArgs table Arguments about event.
function Event:dispatch(eventName, eventArgs)
	local listenList = self.m_eventList[eventName]
	assert(listenList, "Dispatch for unknown event.")
	for targetObj, callbackName in pairs(listenList) do
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
	Event:register("work")

	local Src = {}
	function Src:work(...)
		Event:dispatch("work", { Src, ... })
	end

	local Dest = {}
	Event:listen(Dest, "work", "onWork")

	local eventArgs = { 1, 2, "s" }

	local finishEvent
	function Dest:onWork(eventName, eventSrc, ...)
		finishEvent = true
		assert(eventName == "work")
		assert(eventSrc == Src)
		local args = { ... }
		for i, value in ipairs(args) do
			assert(value == eventArgs[i])
		end
	end

	Src:work(unpack(eventArgs))
	assert(finishEvent)

	Event:remove("work")
	assert(table.empty(Event.m_eventList))
end

test()

return Event
