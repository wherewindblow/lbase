-- Class support c++ like syntax.
-- 1. Distinguish class, object and general table.
-- 2. Support new function to create object of class. And it'll call constructor of class.
-- 3. Support delete function to destroy object. And it'll call destructor of class.
-- 4. Inherit from base class to object oriented.
-- 5. Expect call function to ensure base class constructor to be call by drived class constructor when necessary.
-- 6. Delete function will auto call base class destructor after call drived class destructor.
-- 7. Avoid cover general function with virtual function list. All virtual function must to add virtual attribute.
-- 8. Avoid derived class member cover base class member. NOTE: Only have effect when use in function. In out side of function have not effect.
--    When in class function to use self, all member create in self is private.
--    When out of class function to use object, all member create in object is public.
-- TODO: Support private function.

require("global")

TABLE_TYPE = {
	Class = "Class",
	Object = "Object",
}

Object = {
	__className = "Object",
	__type = TABLE_TYPE.Class,
	__expectCall = {},
	__virtualFuncList = {},
}

AllClass = { [Object.__className] = { Class = Object, source = debug.getinfo(1).source } }

function super(self)
	return self:getBaseClass()
end

local TABLE_TYPE = TABLE_TYPE
local assertFmt = assertFmt
local errorFmt = errorFmt
local super = super

-- New object and will call constructor.
-- NOTE: Cannot override this function. Override constructor to custom.
function Object:new(...)
	assertFmt(self.__type == TABLE_TYPE.Class, "Must call by class.")
	local obj = {
		__type = TABLE_TYPE.Object,
		__expectCall = {},
		__members = {},
	}

	-- Enable use object to call class function.
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

-- Can be override by derived class.
-- NOTE: Must call all expect call function in it.
function Object:constructor(...)

end

-- Delete object and will call all destructor.
-- NOTE: Cannot override this function. Override destructor to custom.
function Object:delete()
	assertFmt(self.__type == TABLE_TYPE.Object, "Must call by object.")
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

-- Can be override by derived class.
function Object:destructor()

end

-- NOTE: This function must call by class.
function Object:inherit(className)
	assertFmt(self.__type == TABLE_TYPE.Class, "Must call by class.")
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
			if type(v) == "function" then
				local funcName = k
				-- Check function can be override.
				if t[funcName] then
					-- Check is virtual function.
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

-- Create function that separate class memeber space to avoid derived class member cover base class member.
-- If want to override function that already create must call this function to create function to ensure behavior is correct.
-- NOTE: This function must call by class.
-- NOTE: Only have effect when use in function. In out side of function have not effect.
--   When in class function to use self, all member create in self is private.
--   When out of class function to use object, all member create in object is public.
function Object:createFunction(originFunc)
	assertFmt(self.__type == TABLE_TYPE.Class, "Must call by class.")
	local className = self.__className
	local function funcWrapper(self, ...)
		if self.__type == TABLE_TYPE.Object then
			local classMembers = self.__members[className]
			if not classMembers then
				classMembers = {}
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

function Object:getClass()
	if self.__type == TABLE_TYPE.Class then
		return self
	elseif self.__type == TABLE_TYPE.Object then
		local Class = getmetatable(self).__index
		if Class.__type == TABLE_TYPE.Class then
			return Class
		end
	else
		errorFmt("Unknow type %s.", self.__type or "")
	end
end

function Object:getClassName()
	local Class = self:getClass()
	return Class.__className
end

-- NOTE: This function must call by class.
-- In fact, this function can be call by object, but will make some mistake when use to call base class constructor.
function Object:getBaseClass()
	assertFmt(self.__type == TABLE_TYPE.Class, "Must call by class.")
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

function Object:getType()
	return self.__type
end

-- NOTE: This function must call by class.
function Object:expectCall(funcName)
	assertFmt(self.__type == TABLE_TYPE.Class, "Must call by class.")
	local func = rawget(self, funcName)
	assertFmt(func, "Not exist function %s:%s", self.__className, funcName)
	self.__expectCall[funcName] = true
end

-- NOTE: This function must call by object.
function Object:finishCall(func)
	assert(self.__type == TABLE_TYPE.Object, "Must call by object.")
	if self.__expectCall and self.__expectCall[func] then
		-- Object __expectCall is difference from Class.
		local callInfo = self.__expectCall[func]
		callInfo.callTimes = callInfo.callTimes + 1
	end
end

-- NOTE: This function must call by class.
function Object:setToVirtual(funcName)
	assertFmt(self.__type == TABLE_TYPE.Class, "Must call by class.")
	local func = rawget(self, funcName)
	assertFmt(func, "Not exist function %s:%s", self.__className, funcName)
	self.__virtualFuncList[funcName] = true
end

--Object:expectCall("constructor") -- An example.
Object:setToVirtual("constructor")
Object:setToVirtual("destructor")
