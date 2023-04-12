local Class = require("lbase/class")
local Queue = require("lbase/queue")

--- @class ObjectPool : Object
local ObjectPool = Class.Object:inherit("ObjectPool")

---
--- Constructs object pool object.
--- @param poolSize number The size of pool.
--- @param isHardLimit boolean Settings that can create object more than pool size.
---     When set it to true and over the pool size, it'll wait for object release.
---     It also is a way to control concurrency.
--- @param createObjFunc function Uses to create object when not exist an object to use.
--- @param deleteObjFunc function Usse to delete object when it's unnecessary.
--- @param releaseObjFunc function Uses to release object when call `releaseObject`.
---     It's use to release some part that is not want to cache.
function ObjectPool:constructor(poolSize, isHardLimit, createObjFunc, deleteObjFunc, releaseObjFunc)
    self.m_poolSize = poolSize
    self.m_isHardLimit = isHardLimit
    self.m_createObjFunc = createObjFunc
    self.m_deleteObjFunc = deleteObjFunc
    self.m_releaseObjFunc = releaseObjFunc
    self.m_queue = Queue:new()
    self.m_objNum = 0
    self.m_waitObjCoList = {}
end

---
--- Gets object from pool. When is not exist object, will call `createObjFunc` to create it.
--- All arguments is forward to `createObjFunc`.
function ObjectPool:getObject(...)
    if not self.m_queue:empty() then
        local obj = self.m_queue:front()
        self.m_queue:pop()
        return obj
    end

    if self.m_isHardLimit and self.m_objNum >= self.m_poolSize then
        local co = coroutine.running()
        table.insert(self.m_waitObjCoList, co)
        local obj = coroutine.yield()
        return obj
    end

    -- createObjFunc way have yield operation, so must add number before it.
    self.m_objNum = self.m_objNum + 1
    local obj = self.m_createObjFunc(...)
    return obj
end

---
--- Release object that is get from the pool.
function ObjectPool:releaseObject(obj)
    if self.m_queue:size() < self.m_poolSize then
        if self.m_releaseObjFunc then
            self.m_releaseObjFunc(obj)
        end
        if #self.m_waitObjCoList > 0 then
            local co = table.remove(self.m_waitObjCoList, 1)
            coroutine.resume(co, obj)
            return
        end

        self.m_queue:push(obj)
        return
    end

    if self.m_deleteObjFunc then
        self.m_deleteObjFunc(obj)
    end
    -- deleteObjFunc way have yield operation, so must wait it finish.
    self.m_objNum = self.m_objNum - 1
end

return ObjectPool