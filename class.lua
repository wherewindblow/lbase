-- Class support c++ like syntax.
-- 1. Distinguish class, object and general table.
-- 2. Support new function to create object of class. And it'll call constructor of class.
-- 3. Support delete function to destroy object. And it'll call destructor of class.
-- 4. Inherit from base class to object oriented.
-- 5. Expect call function to ensure base class constructor to be call by drived class constructor when necessary.
-- 6. Delete function will auto call base class destructor after call drived class destructor.
-- 7. Avoid cover general function with virtual function list. All virtual function must to add virtual attribute.
-- 8. Avoid derived class member cover base class member. NOTE: Only have effect when use in function. In out side of function have not effect.
-- TODO: Allow in out side of function to operate class member.
-- TODO: Allow to replace function.
-- TODO: Support private function.

local TABLE_TYPE = {
	Class = "Class",
	Object = "Object",
}

Object = {
	__className = "Object",
	__type = TABLE_TYPE.Class,
	__expectCall = {},
	__virtualFuncList = {},
}

AllClass = { [Object.__className] = Object }

-- New object and will call create.
-- NOTE: Cannot override this function. Override create to custom.
function Object:new(...)
	assert(self.__type == TABLE_TYPE.Class, "Must call by class.")
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
			if not func then
				assert(false, string.format("Not exist expect call function %s:%s", Class:getClassName(), funcName))
			end

			obj.__expectCall[func] = {
				className = Class:getClassName(),
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
		if callInfo.callTimes == 0 then
			assert(false, string.format("%s:%s expect to be call by %s:create, but not (May have called but not call finishCall).", callInfo.className, callInfo.funcName, self:getClassName()))
		end
	end
	obj.__expectCall = nil -- Don't need after finish check.

	return obj
end

-- NOTE: Must call all expect call function in it.
-- Can be override by derived class.
function Object:constructor(...)

end

-- Delete object and will call all destroy.
-- NOTE: Cannot override this function. Override destroy to custom.
function Object:delete()
	assert(self.__type == TABLE_TYPE.Object, "Must call by object.")
	-- Call all destroy function.
	local Class = self:getClass()
	while Class do
		local destroy = rawget(Class, "destroy")
		if destroy then
			destroy(self)
		end
		Class = super(Class)
	end
end

-- Can be override by derived class.
function Object:destructor()

end

-- NOTE: This function must call by class.
function Object:inherit(className)
	assert(self.__type == TABLE_TYPE.Class, "Must call by class.")
	assert(type(className) == "string", "className must be string.")
	assert(not AllClass[className], "Aleady exist class " .. className)

	local Class = {
		__className = className,
		__type = TABLE_TYPE.Class,
		__baseClass = self,
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
					local curClass = Class
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
						curClass = Class
						while curClass do
							local baseFunc = rawget(curClass, funcName)
							if baseFunc then
								funcClassName = curClass:getClassName()
								break
							end
							curClass = super(curClass)
						end

						assert(false, string.format("Override not virtual function %s:%s, must call setToVirtual to set function to virutal.", funcClassName, funcName))
					end
				end

				-- Separate class memeber space to avoid derived class member cover base class member.
				-- NOTE: Only have effect when use in function. In out side of function have not effect.
				local originFunc = v
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
					return originFunc(self, ...)
				end
				v = funcWrapper
			end

			rawset(t, k, v)
		end
	}
	setmetatable(Class, metatable)

	AllClass[className] = Class
	return Class
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
		assert(false, "Unknow type.")
	end
end

function Object:getClassName()
	local Class = self:getClass()
	return Class.__className
end

-- NOTE: This function must call by class.
-- In fact, this function can be call by object, but will make some mistake when use to call base class constructor.
function Object:getBaseClass()
	assert(self.__type == TABLE_TYPE.Class, "Must call by class.")
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

function Object:getTableType()
	return self.__type
end

-- NOTE: This function must call by class.
function Object:expectCall(funcName)
	assert(self.__type == TABLE_TYPE.Class, "Must call by class.")
	local func = rawget(self, funcName)
	if not func then
		assert(false, string.format("Not exist function %s:%s", self:getClassName(), funcName))
	end
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
	assert(self.__type == TABLE_TYPE.Class, "Must call by class.")
	local func = rawget(self, funcName)
	if not func then
		assert(false, string.format("Not exist function %s:%s", self:getClassName(), funcName))
	end
	self.__virtualFuncList[funcName] = true
end

--Object:expectCall("constructor") -- An example.
Object:setToVirtual("constructor")
Object:setToVirtual("destructor")

function super(self)
	return self:getBaseClass()
end
