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

local Class = {}

--- Table type to distinguish general table and special table.
Class.TABLE_TYPE = {
	Class = "Class",
	Object = "Object",
}

--- @class Object
--- Base class to provide class relative function.
--- NOTE: Must put it in a local variable and then put to Class table to enable Emmylua completion.
local Object = {
	__className = "Object",
	__type = Class.TABLE_TYPE.Class,
	__expectCall = {},
	__virtualFuncList = {},
}

Class.Object = Object

--- All class set that map class name to class info.
Class.allClass = {
	[Class.Object.__className] = { class = Class.Object, source = debug.getinfo(1).source }
}

--- All origin func info.
Class.allOriginFunc = {}

---
--- Returns base class.
--- @param Class table
--- @return table
function Class.super(Class)
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
local TABLE_TYPE = Class.TABLE_TYPE
local assertFmt = assertFmt
local errorFmt = errorFmt
local super = Class.super


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
	local class = self
	while class do
		for funcName, _ in pairs(class.__expectCall) do
			local func = rawget(class, funcName)
			assertFmt(func, "Not exist expect call function %s:%s", class.__className, funcName)

			obj.__expectCall[func] = {
				className = class.__className,
				funcName = funcName,
				callTimes = 0,
			}
		end
		class = super(class)
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
	local class = self:getClass()
	while class do
		local destructor = rawget(class, "destructor")
		if destructor then
			destructor(self)
		end
		class = super(class)
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
	local classInfo = Class.allClass[className]
	if classInfo then
		-- Avoid register class repeatedly in difference source. But must check by manual when in same source.
		assertFmt(callerInfo.source == classInfo.source, "Already register class %s in %s", className, classInfo.source)
	end

	local class = {
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
					local curClass = class
					while curClass do
						local virtualFuncList = curClass.__virtualFuncList
						if virtualFuncList[funcName] then
							isVirtualFunc = true
							break
						end
						curClass = super(curClass)
					end

					if not isVirtualFunc then
						-- Get class name of function.
						local funcClassName
						curClass = class
						while curClass do
							local baseFunc = rawget(curClass, funcName)
							if baseFunc then
								funcClassName = curClass.__className
								break
							end
							curClass = super(curClass)
						end

						errorFmt("Override not virtual function %s:%s, must call setToVirtual to set function to virutal.", funcClassName, funcName)
					end
				end

				v = class:createFunction(k, v)
			end

			rawset(t, k, v)
		end
	}
	setmetatable(class, metatable)

	if not classInfo then
		Class.allClass[className] = { class = class, source = callerInfo.source }
	end
	return class
end

---
--- Creates function that separate class member space to avoid derived class member cover base class member.
--- If want to override function that already create must call this function to create function to ensure behavior is correct.
--- NOTE: This function must call by class.
--- @param originFunc function
--- @return function That can be assign to class.
function Object:createFunction(funcName, originFunc)
	assertFmt(self.__type == TABLE_TYPE.Class, "This function must call by class.")
	local className = self.__className
	local function funcWrapper(self, ...)
		if self.__type == TABLE_TYPE.Object then
			local classMembers = self.__members[className]
			if not classMembers then
				classMembers = {
					__type = TABLE_TYPE.Object, -- Optimize get type operation.
					__isClassMembers = true,
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
		return originFunc(self, ...)
	end
	Class.allOriginFunc[originFunc] = funcName
	return funcWrapper
end

---
--- Gets class.
--- @return table
function Object:getClass()
	local rawType = rawget(self, "__type")
	if rawType == TABLE_TYPE.Class then -- Is class.
		return self
	elseif rawType == TABLE_TYPE.Object then
		if rawget(self, "__isClassMembers") then -- Is object class members.
			local obj = getmetatable(self).__index
			local class = getmetatable(obj).__index
			if class.__type == TABLE_TYPE.Class then
				return class
			end
		else -- Is object root.
			local class = getmetatable(self).__index
			if class.__type == TABLE_TYPE.Class then
				return class
			end
		end
	else
		errorFmt("Unknown type %s.", self.__type or "")
	end
end

---
--- Gets class name.
--- @return string
function Object:getClassName()
	local class = self:getClass()
	return class.__className
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
		local baseClass = metatable.__index
		if baseClass.__type == TABLE_TYPE.Class then
			return baseClass
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

	local class = self:getClass()
	while class do
		local serializableMembers = rawget(class, "__serializableMembers")
		local className = class.__className
		local classMembers = self.__members[className]

		if serializableMembers and next(serializableMembers) and
				classMembers and next(classMembers) then
			t.__members[className] = t.__members[className] or {}
			local tMembers = t.__members[className]
			for _, varName in pairs(serializableMembers) do
				local varValue = class.serializeMember(classMembers, varName)
				if varValue then
					if varValue.__type == TABLE_TYPE.Object then
						tMembers[varName] = varValue:serialize()
					else
						tMembers[varName] = varValue
					end
				end
			end
		end

		class = super(class)
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

	local class = Class.allClass[t.__className].class
	local obj = class:new() -- Must allow call `constructor` without arguments.

	while class do
		local className = class.__className
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
				class.unserializeMember(classMembers, varName, varValue)
			end
		end

		class = super(class)
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

local function test()
	local Base = Object:inherit("TestBase")

	function Base:constructor(name)
		self.m_name = name
	end

	function Base:getBaseName()
		return self.m_name
	end

	function Base:foo() end

	local base = Base:new()
	assert(base.foo)

	local Derived = Base:inherit("TestDerived")

	function Derived:constructor(name, baseName)
		Class.super(Derived).constructor(self, baseName)
		self.m_name = name
	end

	function Derived:getDerivedName()
		return self.m_name
	end

	local ret, msg = pcall(function ()
		function Derived:getBaseName()
		end
	end)

	assert(not ret)

	Base:setToVirtual("getBaseName")
	function Derived:getBaseName()
	end

	local derived = Derived:new("derived", "base")
	assert(derived:getDerivedName() ~= derived:getBaseName())

	derived:delete()

	Class.allClass["TestBase"] = nil
	Class.allClass["TestDerived"] = nil
end

test()

return Class
