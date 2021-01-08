local Class = require("lbase/class")

--- @module Log
local Log = {}

---
--- Log message separater.
local LOG_SEPARATER = "\n"

Log.LOG_SEPARATER = LOG_SEPARATER

--- Log level.
local LOG_LEVEL = {
	OFF = 1,
	DEBUG = 2,
	INFO = 3,
	WARN = 4,
	ERROR = 5,
}

Log.LOG_LEVEL = LOG_LEVEL

local LOG_LEVLE_2_STR = {
	[LOG_LEVEL.DEBUG] = "debug",
	[LOG_LEVEL.INFO] = "info",
	[LOG_LEVEL.WARN] = "warn",
	[LOG_LEVEL.ERROR] = "error",
}

--- @class Logger : Object
local Logger = Class.Object:inherit("Logger")

---
--- Constructs logger object.
--- @param filePath string
--- @param isPrint2Screen boolean
function Logger:constructor(filePath, isPrint2Screen)
	self.m_filePath = filePath
	self.m_file = io.open(filePath, "a")
	self.m_level = LOG_LEVEL.INFO
	self.m_isPrint2Screen = isPrint2Screen
end

local dateStr
local dateTime

---
--- Log routine that record message.
function Logger:log(level, fmt, arg1, ...)
	local msg
	if arg1 then
		msg = string.format(fmt, arg1, ...)
	else
		msg = fmt
	end

	local now = os.time()
	if not dateTime or now ~= dateTime then
		dateStr = os.date("%Y-%m-%d %H:%M:%S")
		dateTime = now
	end

	local header = string.format("[%s] [%s] ", dateStr, LOG_LEVLE_2_STR[level])
	self.m_file:write(header)
	self.m_file:write(msg)
	self.m_file:write(LOG_SEPARATER)

	if self.m_isPrint2Screen then
		print(string.format("%s%s", header, msg))
	end
end

---
--- Add debug log message.
--- @param fmt string
function Logger:debug(fmt, ...)
	if LOG_LEVEL.DEBUG >= self.m_level then
		self:log(LOG_LEVEL.DEBUG, fmt, ...)
	end
end

---
--- Add info log message.
--- @param fmt string
function Logger:info(fmt, ...)
	if LOG_LEVEL.INFO >= self.m_level then
		self:log(LOG_LEVEL.INFO, fmt, ...)
	end
end

---
--- Add warn log message.
--- @param fmt string
function Logger:warn(fmt, ...)
	if LOG_LEVEL.WARN >= self.m_level then
		self:log(LOG_LEVEL.WARN, fmt, ...)
	end
end

---
--- Add error log message.
--- @param fmt string
function Logger:error(fmt, ...)
	if LOG_LEVEL.ERROR >= self.m_level then
		self:log(LOG_LEVEL.ERROR, fmt, ...)
	end
end

---
--- Gets log level.
--- @return number
function Logger:getLevel()
	return self.m_level
end

---
--- Sets log level.
--- @param level number Member of LOG_LEVEL.
function Logger:setLevel(level)
	self.m_level = level
end

---
--- Returns is print mseesage to screen.
function Logger:isPrint2Screen()
	return self.m_isPrint2Screen
end

---
--- Sets is print mseesage to screen.
--- @param isPrint2Screen boolean
function Logger:setIsPrint2Screen(isPrint2Screen)
	self.m_isPrint2Screen = isPrint2Screen
end

Log.Logger = Logger

return Log
