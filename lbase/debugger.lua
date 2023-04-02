---
--- Use debugger with the following steps.
--- 1、Add breakpoint.
--- 2、Start debugger.
--- 3、Into debugger mode.
--- 4、Debug(print or do something else).
---
--- Your can import those function into global to use conveniently in debug mode.
--- p = Debugger.printLocal
--- pa = Debugger.printAllLocal

local Extend = require("lbase/extend")

--- @module Debugger
local Debugger = { m_allBreakpoints = {} }

---
--- Adds line breakpoint and it can be trigger when run into special line.
function Debugger:addLineBreakpoint(filename, line)
	table.insert(self.m_allBreakpoints, { type = "line", filename = filename, line = line })
end

---
--- Adds call breakpoint and it can be trigger when call the function.
function Debugger:addCallBreakpoint(func)
	table.insert(self.m_allBreakpoints, { type = "call", func = func })
end

--- Removes line breakpoint.
function Debugger:removeLineBreakpoint(filename, line)
	for index, breakpoint in ipairs(self.m_allBreakpoints) do
		if breakpoint.type == "line" and breakpoint.filename == filename and breakpoint.line == line then
			table.remove(self.m_allBreakpoints, index)
		end
	end
end

---
--- Removes call breakpoint.
function Debugger:removeCallBreakpoint(func)
	for index, breakpoint in ipairs(self.m_allBreakpoints) do
		if breakpoint.type == "call" and breakpoint.func == func then
			table.remove(self.m_allBreakpoints, index)
		end
	end
end

--- Clears all breakpoint.
function Debugger:clearBreakpoint()
	self.m_allBreakpoints = {}
end

--- Start debugger.
function Debugger:start()
	local function hook(event, line)
		--[[ funcInfo table
			{
				["nups"] = 0,
				["what"] = "main",
				["func"] = <function: 0x1906540>,
				["lastlinedefined"] = 0,
				["source"] = "@./test.lua",
				["currentline"] = 208,
				["namewhat"] = "",
				["linedefined"] = 0,
				["short_src"] = "./test.lua",
			}
		]]
		local funcInfo = debug.getinfo(2)

		for _, breakpoint in pairs(self.m_allBreakpoints) do
			if breakpoint.type == event then
				local hit
				if event == "line" then
					if string.find(funcInfo.source, breakpoint.filename) and line == breakpoint.line then
						hit = true
						print(string.format("Hit line breakpoint at %s:%d", breakpoint.filename, breakpoint.line))
					end
				elseif event == "call" then
					hit = funcInfo.func == breakpoint.func
					if hit then
						print(string.format("Hit call breakpoint at %s:%d", funcInfo.short_src, funcInfo.currentline))
					end
				end

				if hit then
					debug.debug()
					break
				end
			end
		end
	end

	debug.sethook(hook, "cl")
end

-- Return structure: { Index = { Name = "", Value = Any } }
function Debugger.getAllLocal(level)
	local allLocal = {}
	local index = 1
	while true do
		local name, value = debug.getlocal(level + 1, index)
		if not name then
			break
		end
		allLocal[index] = { name = name, value = value } -- Replace same name variable.
		index = index + 1
	end
	return allLocal
end

---
--- Prints local variable.
function Debugger.printLocal(level, name)
	-- Call p to print variable in debug.
	-- Stack:
	-- 1. printLocal
	-- 2. input chunk
	-- 3. debug.debug
	-- 4. hook
	-- 5. hit breakpoint source
	for index, var in pairs(Debugger.getAllLocal(level + 4)) do
		if var.name == name then
			print(index, name)
			table.print(var)
		end
	end
end

---
--- Prints all local variable.
function Debugger.printAllLocal(level)
	Extend.printAny(Debugger.getAllLocal(level + 4))
end

return Debugger