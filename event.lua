
local Event = {
	m_listenList = {},
}

---
--- Register event for object. Only after this operation can use `listen` and `dispatch`.
--- @param obj table Object or module that will dispatch event.
--- @param eventName string Name of event.
function Event:register(obj, eventName)
	local listenList = self.m_listenList[obj]
	if not listenList then
		listenList = {}
		self.m_listenList[obj] = listenList
	end

	local observerList = listenList[eventName]
	assert(not observerList, "Already register for this event.")
	listenList[eventName] = {}
end

---
--- Removes event for object.
--- @param obj table Object or module that will dispatch event.
--- @param eventName string Name of event. Default is nil to remove all event of object.
function Event:remove(obj, eventName)
	local listenList = self.m_listenList[obj]
	if not listenList then
		return
	end

	if eventName then
		listenList[eventName] = nil
	else
		self.m_listenList[obj] = nil
	end
end

---
--- Listens for event, when target object dispatch will call object callback.
--- NOTE: Must call `register` to register event before listen it.
--- @param obj table  Object or module that listen event.
--- @param targetObj table Object or module that dispatch event.
--- @param eventName string Name of event.
--- @param callbackName string Name of callback function that in `obj`. Like fun(targetObj, eventName, eventArgs).
function Event:listen(obj, targetObj, eventName, callbackName)
	local listenList = self.m_listenList[targetObj]
	assert(listenList, "Listen for unknown event.")
	local observerList = listenList[eventName]
	assert(observerList, "Listen for unknown event.")
	assert(not observerList[obj], "Already listen for this event.")
	observerList[obj] = callbackName
end

---
--- Dispatches event to all object that listen for this event.
--- NOTE: Must call `register` to register event before dispatch it.
--- @param obj table  Object or module that dispatch event.
--- @param eventName string Name of event.
--- @param eventArgs table Arguments about event.
function Event:dispatch(obj, eventName, eventArgs)
	local listenList = self.m_listenList[obj]
	assert(listenList, "Dispatch for unknown event.")
	local observerList = listenList[eventName]
	assert(observerList, "Dispatch for unknown event.")

	for targetObj, callbackName in pairs(observerList) do
		xpcall(function () targetObj[callbackName](targetObj, obj, eventName, eventArgs) end, debug.errorhook)
	end
end

local function test()
	local Src = {}
	Event:register(Src, "work")

	function Src:work(...)
		Event:dispatch(Src, "work", {...})
	end

	local Dest = {}
	Event:listen(Dest, Src, "work", "onWork")

	local finishEvent
	function Dest:onWork(obj, name, args)
		finishEvent = true
		assert(obj == Src)
		assert(name == "work")
		assert(args[1] == 1)
		assert(args[2] == 2)
		assert(args[3] == "s")
	end

	Src:work(1, 2, "s")
	assert(finishEvent)

	Event:remove(Src)
	assert(table.empty(Event.m_listenList))
end

test()

return Event
