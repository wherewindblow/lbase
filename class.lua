---
--- Class support c++ like syntax.
--- 1. Distinguish class, object and general table.
--- 2. Support new function to create object of class. And it'll call constructor of class.
--- 3. Support delete function to destroy object. And it'll call destructor of class.
--- 4. Inherit from base class to object oriented.
--- 5. Expect call function to ensure base class constructor to be call by drived class constructor when necessary.
--- 6. Delete function will auto call base class destructor after call drived class destructor.
--- 7. Avoid cover general function with virtual function list. All virtual function must to add virtual attribute.
--- 8. Avoid derived class member cover base class member. NOTE: Only have effect when use in function. In out side of function have not effect.
---    When in class function to use self, all member create in self is private.
---    When out of class function to use object, all member create in object is public.
--- TODO: Support private function.

--- Table type to distinguish general table and special table.
TABLE_TYPE = {
	Class = "Class",
	Object = "Object",
}

--- @class Object
--- Base class to provide class relative function.
Object = {
	__className = "Object",
	__type = TABLE_TYPE.Class,
	__expectCall = {},
	__virtualFuncList = {},
}

--- All class set that map class name to class info.
AllClass = {
	[Object.__className] = { Class = Object, source = debug.getinfo(1).source }
}

---
--- Returns base class.
--- @param Class table
--- @return table
function super(Class)
	return Class:getBaseClass()
end

-- Optimize.
local pairs = pairs
local type = type
local next = next
local rawget = rawget
local rawset = rawset
local getmetatable = getmetatable
local setmetatable = setmetatable
local TABLE_TYPE = TABLE_TYPE
local assertFmt = assertFmt
local errorFmt = errorFmt
local super = super

---
--- New object and will call `constructor`.
--- NOTE: 1. This function must call by class.
---       2. Cannot override this function. Override `constructor` to customize.
--- @return table Object of specific class.
function Object:new(...)
	assertFmt(self.__type == TABLE_TYPE.Class, "This function must call by class.")
	local obj = {
		__type = TABLE_TYPE.Object,
		__expectCall = {},
		__members = {},
	}

	-- Enable to use object to call class function.
	setmetatable(obj, { __index = self })

	-- Collect all expect call function of object.
	local Class = self
	while Class do
		for funcName, _ in pairs(Class.__expectCall) do
			local func = rawget(Class, funcName)
			assertFmt(func, "Not exist expect call function %s:%s", Class.__className, funcName)

			obj.__expectCall[func] = {
				className = Class.__className,
				funcName = funcName,
				callTimes = 0,
			}
		end
		Class = super(Class)
	end

	-- Call constructor of object. Must call all expect call function in constructor.
	if obj.constructor then
		obj:constructor(...)
	end

	-- Check expect call function have be called.
	for func, callInfo in pairs(obj.__expectCall) do
		assertFmt(callInfo.callTimes ~= 0, "%s:%s expect to be call by %s:constructor, but not (May have called but not call finishCall).",
				callInfo.className, callInfo.funcName, self.__className)
	end
	obj.__expectCall = nil -- Don't need after finish check.

	return obj
end

---
--- This function can be override by derived class.
--- NOTE: Must call all expect call function in it.
function Object:constructor(...)

end

---
--- Deletes object and will call all `destructor`.
--- NOTE: 1. This function must call by object.
---       2. Cannot override this function. Override `destructor` to customize.
function Object:delete()
	assertFmt(self.__type == TABLE_TYPE.Object, "This function must call by object.")
	-- Call all destructor.
	local Class = self:getClass()
	while Class do
		local destructor = rawget(Class, "destructor")
		if destructor then
			destructor(self)
		end
		Class = super(Class)
	end
end

---
--- This function can be override by derived class.
function Object:destructor()

end

---
--- Inherits from this class.
--- NOTE: This function must call by class.
--- @param className string Derived class name.
--- @return table Derived class
function Object:inherit(className)
	assertFmt(self.__type == TABLE_TYPE.Class, "This function must call by class.")
	assertFmt(type(className) == "string", "className must be string.")

	local callerInfo = debug.getinfo(2)
	local classInfo = AllClass[className]
	if classInfo then
		-- Avoid register class repeatedly in difference source. But must check by manual when in same source.
		assertFmt(callerInfo.source == classInfo.source, "Already register class %s in %s", className, classInfo.source)
	end

	local Class = {
		__className = className,
		__type = TABLE_TYPE.Class,
		__expectCall = {},
		__virtualFuncList = {},
	}

	local metatable = {
		-- Enable to call base class function.
		__index = self,
		__newindex = function(t, k, v)
			-- Creates new function.
			if type(v) == "function" then
				local funcName = k
				-- Checks function can be override.
				if t[funcName] then
					-- Checks is virtual function.
					local isVirtualFunc
					local CurClass = Class
					while CurClass do
						local virtualFuncList = CurClass.__virtualFuncList
						if virtualFuncList[funcName] then
							isVirtualFunc = true
							break
						end
						CurClass = super(CurClass)
					end

					if not isVirtualFunc then
						-- Get class name of function.
						local funcClassName
						CurClass = Class
						while CurClass do
							local baseFunc = rawget(CurClass, funcName)
							if baseFunc then
								funcClassName = CurClass.__className
								break
							end
							CurClass = super(CurClass)
						end

						errorFmt("Override not virtual function %s:%s, must call setToVirtual to set function to virutal.", funcClassName, funcName)
					end
				end

				v = Class:createFunction(v)
			end

			rawset(t, k, v)
		end
	}
	setmetatable(Class, metatable)

	if not classInfo then
		AllClass[className] = { Class = Class, source = callerInfo.source }
	end
	return Class
end

---
--- Creates function that separate class member space to avoid derived class member cover base class member.
--- If want to override function that already create must call this function to create function to ensure behavior is correct.
--- NOTE: This function must call by class.
--- @param originFunc function
--- @return function That can be assign to class.
function Object:createFunction(originFunc)
	assertFmt(self.__type == TABLE_TYPE.Class, "This function must call by class.")
	local className = self.__className
	local function funcWrapper(self, ...)
		if self.__type == TABLE_TYPE.Object then
			local classMembers = self.__members[className]
			if not classMembers then
				classMembers = {
					__type = TABLE_TYPE.Object, -- Optimize get type operation.
				}

				-- Don't need weak table. It metatable is already is weak table?
				--local memberMetable = { __index = self }
				--setmetatable(memberMetable, {__mod = "v"})
				--setmetatable(classMembers, memberMetable)

				-- Enable call class function or get object field.
				setmetatable(classMembers, { __index = self })
				self.__members[className] = classMembers
			end
			self = classMembers
		end

		-- The following will be optimize by tail call. And trackback will not show original function name.
		--return originFunc(self, ...)

		-- To make trackback have original function name, but not efficient.
		--local ret = {originFunc(self, ...)}
		--return unpack(ret)

		-- To make trackback have original function name, but will return additional nil.
		return originFunc(self, ...), nil
	end
	return funcWrapper
end

---
--- Gets class.
--- @return table
function Object:getClass()
	local rawType = rawget(self, "__type")
	if rawType == TABLE_TYPE.Class then
		return self
	elseif rawType == TABLE_TYPE.Object then
		local Class = getmetatable(self).__index
		if Class.__type == TABLE_TYPE.Class then
			return Class
		end
	elseif self.__type == TABLE_TYPE.Object then -- Get type from metatable.
		local obj = getmetatable(self).__index
		local Class = getmetatable(obj).__index
		if Class.__type == TABLE_TYPE.Class then
			return Class
		end
	else
		errorFmt("Unknown type %s.", self.__type or "")
	end
end

---
--- Gets class name.
--- @return string
function Object:getClassName()
	local Class = self:getClass()
	return Class.__className
end

---
--- Gets base class.
--- NOTE: This function must call by class.
--- In fact, this function can be call by object, but will make some mistake when use to call base class constructor.
--- @return table Base class or nil.
function Object:getBaseClass()
	assertFmt(self.__type == TABLE_TYPE.Class, "This function must call by class.")
	local metatable = getmetatable(self)
	if metatable then
		local BaseClass = metatable.__index
		if BaseClass.__type == TABLE_TYPE.Class then
			return BaseClass
		end
	end
	--local BaseClass = getmetatable(self)
	--if BaseClass and BaseClass.__type == TABLE_TYPE.Class then
	--	return BaseClass
	--end
end

---
--- Gets type of class or object.
--- @return string
function Object:getType()
	return self.__type
end

---
--- Expects function to be call in `constructor`.
--- NOTE: This function must call by class.
--- @param funcName string
function Object:expectCall(funcName)
	assertFmt(self.__type == TABLE_TYPE.Class, "This function must call by class.")
	local func = rawget(self, funcName)
	assertFmt(func, "Not exist function %s:%s", self.__className, funcName)
	self.__expectCall[funcName] = true
end

---
--- Finish call function.
--- NOTE: 1. This function must call by object.
---       2. `func` must get from class, because use self will not return current class function when at base class.
--- @param func function
function Object:finishCall(func)
	assertFmt(self.__type == TABLE_TYPE.Object, "This function must call by object.")
	if self.__expectCall and self.__expectCall[func] then
		-- Object __expectCall is difference from Class.
		local callInfo = self.__expectCall[func]
		callInfo.callTimes = callInfo.callTimes + 1
	end
end

---
--- Sets function to virtual.
--- NOTE: This function must call by class.
--- @param funcName string
function Object:setToVirtual(funcName)
	assertFmt(self.__type == TABLE_TYPE.Class, "This function must call by class.")
	local func = rawget(self, funcName)
	assertFmt(func, "Not exist function %s:%s", self.__className, funcName)
	self.__virtualFuncList[funcName] = true
end

---
--- Returns table that need to serialize.
--- @return table
function Object:serialize()
	local t = {
		__className = self:getClassName(),
		__members = {}
	}

	local Class = self:getClass()
	while Class do
		local serializableMembers = rawget(Class, "__serializableMembers")
		local className = Class.__className
		local classMembers = self.__members[className]

		if serializableMembers and next(serializableMembers) and
				classMembers and next(classMembers) then
			t.__members[className] = t.__members[className] or {}
			local tMembers = t.__members[className]
			for _, varName in pairs(serializableMembers) do
				local varValue = Class.serializeMember(classMembers, varName)
				if varValue then
					if varValue.__type == TABLE_TYPE.Object then
						tMembers[varName] = varValue:serialize()
					else
						tMembers[varName] = varValue
					end
				end
			end
		end

		Class = super(Class)
	end

	return t
end

---
--- Unserializes from table that have same structure with `serialize` return value.
--- NOTE: 1. This function must call by class.
---       2. Must allow call all class constructor without arguments.
--- @param t table
--- @return table Object of specific class.
function Object:unserialize(t)
	assertFmt(self.__type == TABLE_TYPE.Class, "This function must call by class.")

	local Class = AllClass[t.__className].Class
	local obj = Class:new() -- Must allow call `constructor` without arguments.

	while Class do
		local className = Class.__className
		local tMembers = t.__members[className]
		if tMembers then
			local classMembers = obj.__members[className]
			if not classMembers then
				classMembers = { __className = className }
				setmetatable(classMembers, { __index = obj })
				obj.__members[className] = classMembers
			end

			for varName, varValue in pairs(tMembers) do
				if type(varValue) == "table" and varValue.__className then
					varValue = Object:unserialize(varValue)
				end
				-- Cannot use obj pass as self, because it may be Object function and not create by `createFunction`.
				-- So must pass classMembers by manual.
				Class.unserializeMember(classMembers, varName, varValue)
			end
		end

		Class = super(Class)
	end

	return obj
end

---
--- Gets serializable members.
--- @return table
function Object:getSerializableMembers()
	return self.__serializableMembers
end

---
--- Sets serializable members. Member name can be real name or virtual name.
--- NOTE: 1. This function must call by class.
---       2. Needs process in `serializeMember` and `unserializeMember` when have virtual name.
---       3. Needs re-generate members when `members` not include all members.
--- @param members table List of member name.
function Object:setSerializableMembers(members)
	assertFmt(self.__type == TABLE_TYPE.Class, "This function must call by class.")
	self.__serializableMembers = members
end

---
--- Returns serializable value of memeber name.
--- @param name string
function Object:serializeMember(name)
	return self[name]
end

---
--- Unserializes member.
--- @param name string
--- @param value any
function Object:unserializeMember(name, value)
	self[name] = value
end

---
--- Gets snapshot info that uses in error handler.
--- @return string
function Object:getSnapshot()
	return string.format("type=%s, className=%s", self.__type, self:getClassName())
end

--Object:expectCall("constructor") -- An example.
Object:setToVirtual("constructor")
Object:setToVirtual("destructor")
Object:setToVirtual("serializeMember")
Object:setToVirtual("unserializeMember")
Object:setToVirtual("getSnapshot")
