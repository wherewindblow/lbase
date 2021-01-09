local Class = require("lbase/class")
local floor = math.floor

--- @class clsMinHeap : Object
local MinHeap = Class.Object:inherit("MinHeap")

---
--- Constructs min heap object.
--- @param compareFunc fun(data:any, data:any):boolean @Use to compare which data is
---        greater when data cannot compare with "<" opearter.
function MinHeap:constructor(compareFunc)
    self.m_array = {}
    self.m_size = 0
    self.m_compareFunc = compareFunc
end

---
--- Pushes data into heap and ensure order.
function MinHeap:push(data)
    local pos = self.m_size + 1
    self.m_array[pos] = data
    self.m_size = self.m_size + 1
    self:_shiftUp(pos)
end

function MinHeap:_shiftUp(pos)
    local array = self.m_array
    local data = array[pos]
    local compareFunc = self.m_compareFunc

    while pos > 1 do
        local parentPos = floor(pos / 2)
        local parentData = array[parentPos]
        local isLess
        if compareFunc then
            isLess = compareFunc(data, parentData)
        else
            isLess = data < parentData
        end

        if isLess then
            array[pos] = parentData
            pos = parentPos
        else
            break
        end
    end

    array[pos] = data
end

---
--- Pop top data and ensure order.
function MinHeap:pop()
    if self.m_size <= 0 then
        return
    end

    local array = self.m_array
    local topData = array[1]
    local compareFunc = self.m_compareFunc
    local lastData = array[self.m_size]
    array[self.m_size] = nil
    self.m_size = self.m_size - 1

    local endPos = self.m_size
    local pos = 1
    local rightChildPos = pos * 2 + 1

    -- Shift down.
    while rightChildPos <= endPos do
        local leftChildPos = rightChildPos - 1
        local leftChildData = array[leftChildPos]
        local rightChildData = array[rightChildPos]

        local isLess
        if compareFunc then
            isLess = compareFunc(leftChildData, rightChildData)
        else
            isLess = leftChildData < rightChildData
        end

        if isLess then
            array[pos] = leftChildData
            pos = leftChildPos
        else
            array[pos] = rightChildData
            pos = rightChildPos
        end

        rightChildPos = pos * 2 + 1
    end

    -- Only remain left child.
    if rightChildPos == endPos + 1 then
        local leftChildPos = rightChildPos - 1
        local leftChildData = array[leftChildPos]
        array[pos] = leftChildData
        pos = leftChildPos
    end

    array[pos] = lastData
    self:_shiftUp(pos)
    return topData
end

---
--- Returns top data.
function MinHeap:top()
    return self.m_array[1]
end

---
--- Returns size.
function MinHeap:size()
    return self.m_size
end

---
--- Checks is empty.
function MinHeap:empty()
    return self.m_size == 0
end

---
--- Builds heap from array.
function MinHeap:heapify(array)
    if array then
        self.m_array = array
        self.m_size = #array
    end
    for i = 1, self.m_size do
        self:_shiftUp(i)
    end
end

local function test()
    -- Use min heap with number.
    local minHeap = MinHeap:new()
    local size = 10
    for i = size, 1, -1 do
        minHeap:push(i)
    end
    assert(minHeap:size() == size)

    for i = 1, size do
        assert(minHeap:top() == i)
        minHeap:pop()
    end
    assert(minHeap:empty())

    minHeap:heapify({5,4,3,2,1})
    assert(minHeap:top() == 1)

    -- Use min heap with table.
    minHeap = MinHeap:new(function (left, right) return left.val < right.val end)
    for i = size, 1, -1 do
        minHeap:push({ val = i })
    end
    assert(minHeap:size() == size)

    for i = 1, size do
        assert(minHeap:top().val == i)
        minHeap:pop()
    end
    assert(minHeap:empty())
end

test()

return MinHeap