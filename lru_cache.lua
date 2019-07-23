local LinkedList = require("linked_list")

--- @class LruCache : Object
local LruCache = Object:inherit("LruCache")

---
--- Constructs lru cache object.
function LruCache:constructor(capacity)
	self.m_recentList = LinkedList:new()
	self.m_cacheList = {}
	self.m_capacity = capacity
end

---
--- Adds cache data.
--- NOTE: If over capacity will remove cache data that have not use recently.
--- @param key any
--- @param data any
function LruCache:addCache(key, data)
	local cache = self.m_cacheList[key]
	if cache then
		self.m_recentList:moveToBack(cache.node)
		cache.data = data
		return
	end

	if self.m_recentList:size() + 1 > self.m_capacity then
		local uselessKey = self.m_recentList:front()
		self.m_recentList:removeFront()
		self.m_cacheList[uselessKey] = nil
	end

	local node = self.m_recentList:pushBack(key)
	self.m_cacheList[key] = { data = data, node = node }
end

--- Gets cache data.
--- @param key any
--- @return any Cache data.
function LruCache:getCache(key)
	local cache = self.m_cacheList[key]
	if cache then
		self.m_recentList:moveToBack(cache.node)
		return cache.data
	end
end

---
--- Returns the value that use like standard `pairs`.
function LruCache:pairs()
	local gnext = _G.next
	local function next(cacheList, key)
		local nextKey, nextCache = gnext(cacheList, key)
		if nextKey then
			return nextKey, nextCache.data
		end
	end
	return next, self.m_cacheList, nil
end

---
--- Gets capacity.
function LruCache:getCapacity()
	return self.m_capacity
end

--- Sets capacity. If size is over capacity will shrink cache.
function LruCache:setCapacity(capacity)
	self.m_capacity = capacity
end

---
--- Returns size of list.
function LruCache:size()
	return self.m_recentList:size()
end

local function test()
	local valueArray = { "a", "b", "c", "d", "e" }
	local lru = LruCache:new(table.size(valueArray))
	for i, value in ipairs(valueArray) do
		lru:addCache(i, value)
	end

	for i, value in ipairs(valueArray) do
		local cacheValue = lru:getCache(i)
		assert(cacheValue == value)
	end

	local newKey = 100
	local newValue = "f"
	local beforeSize = lru:size()
	lru:addCache(newKey, newValue)
	assert(not lru:getCache(1))
	assert(lru:size() == lru:getCapacity())
	assert(lru:size() == beforeSize)
end

test()

return LruCache
