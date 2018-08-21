require("class")

local Utils = {}

-- Update module and ensure all old reference can be update.
-- 1. Use require to load module, so any module must return itself at file ending.
-- 2. Module can be class or module, module can include class, but cannot include module.
-- 3. Cannot change value type while update.
-- 4. Update only can add new value or replace old value, but cannot only remove old value.
-- 5. All define in main chunk will be perform again while update, so they will be update.
function Utils.update(module)
	local oldModule = require(module)
	package.loaded[module] = nil -- Ensure require can reload module again.
	local newModule = require(module)

	-- Copy all value into old module to ensure all old reference can be update.
	if oldModule.__type == TABLE_TYPE.Class then
		assert(newModule.__type == oldModule.__type, "Cannot change type while update module")
		table.clone(newModule, oldModule)
	else
		-- Is module and module may include class.
		for k, v in pairs(newModule) do
			if oldModule[k] then
				assert(type(v) == type(oldModule[k]), "Cannot change type while update module")
			end

			if v.__type == TABLE_TYPE.Class then
				if oldModule[k] then
					assert(v.__type == oldModule[k].__type, "Cannot change type while update module")
				end
				table.clone(v, oldModule[k])
			else
				oldModule[k] = v
			end
		end
	end

	-- Make require return old module reference.
	package.loaded[module] = oldModule
end

return Utils