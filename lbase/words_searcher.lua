--- WordsSearcher can use to optimize search title and name like short text.
--- If use to search long text will increase memory using.
---
--- N: All words number
--- M: Word number of words.
--- Time: O(N^2) -> O(M^2)
--- Memory: O(NM) -> (NM^2)

local Class = require("lbase/class")

local Utf8Words = {}

function Utf8Words.len(s)
	local _, length = string.gsub(s, "[^\128-\193]", "")
	return length
end

function Utf8Words.wordsNum(byte)
	local headers = {
		{ 0, 0xc0, 1 },
		{ 0xc0, 0xe0, 2 },
		{ 0xe0, 0xf0, 3 },
		{ 0xf0, 0xf8, 4 },
		{ 0xf8, 0xfc, 5 },
		{ 0xfc, 0xff, 6 },
	}

	for _, header in ipairs(headers) do
		if byte >= header[1] and byte < header[2] then
			return header[3]
		end
	end
end

function Utf8Words.sub(s, i, j)
	local result = ""
	local utf8Index = 1
	local byteIndex = 1
	local len = string.len(s)
	while byteIndex <= len do
		local byte = string.byte(s, byteIndex, byteIndex + 1)
		local wordsNum = Utf8Words.wordsNum(byte)
		if utf8Index >= i then
			result = result .. string.sub(s, byteIndex, byteIndex + wordsNum - 1)
		end

		byteIndex = byteIndex + wordsNum
		utf8Index = utf8Index + 1
		if utf8Index > j then
			break
		end
	end
	return result
end

---
--- @class WordsSearcher : Object
local WordsSearcher = Class.Object:inherit("WordsSearcher")

function WordsSearcher:constructor()
	self.m_wordsProcessor = Utf8Words -- Must provide len(s) and sub(s, i, j), if use string will only support ASCII.
	self.m_keyRoot = {
		son = {},
		matchList = {},
	}
	self.m_allWords = {}
end

function WordsSearcher:addKey(key, words)
	key = string.lower(key)
	local tree = self.m_keyRoot

	for i = 1, self.m_wordsProcessor.len(key) do
		local word = self.m_wordsProcessor.sub(key, i, i)
		tree.son[word] = tree.son[word] or {
			son = {},
			matchList = {},
		}

		tree = tree.son[word]
	end

	tree.matchList[words] = true
end

---
--- Adds words to internal cache.
--- @param words string
function WordsSearcher:addWords(words)
	if self.m_allWords[words] then
		return false
	end

	self.m_allWords[words] = true
	local wordsLen = self.m_wordsProcessor.len(words)
	for i = 1, wordsLen do
		for j = i, wordsLen do
			local key = self.m_wordsProcessor.sub(words, i, j)
			self:addKey(key, words)
		end
	end
end

function WordsSearcher:removeKey(key, words)
	key = string.lower(key)
	local tree = self.m_keyRoot
	if not tree then
		return
	end

	for i = 1, self.m_wordsProcessor.len(key) do
		local word = self.m_wordsProcessor.sub(key, i, i)
		if not tree.son[word] then
			return
		end

		tree = tree.son[word]
	end

	tree.matchList[words] = nil
end

---
--- Removes words of internal cache.
--- @param words string
function WordsSearcher:removeWords(words)
	if not self.m_allWords[words] then
		return false
	end

	local wordsLen = self.m_wordsProcessor.len(words)
	for i = 1, wordsLen do
		for j = i, wordsLen do
			local key = self.m_wordsProcessor.sub(words, i, j)
			self:removeKey(key, words)
		end
	end
end

---
--- Finds all words by key.
--- @param key string
--- @return table That map words to true.
function WordsSearcher:findKey(key)
	key = string.lower(key)
	local tree = self.m_keyRoot
	if not tree then
		return
	end

	for i = 1, self.m_wordsProcessor.len(key) do
		local word = self.m_wordsProcessor.sub(key, i, i)
		if not tree.son[word] then
			return
		end
		tree = tree.son[word]
	end

	return tree.matchList
end

local function test()
	local searcher = WordsSearcher:new()
	searcher:addWords("Mary")
	searcher:addWords("Ryan")
	searcher:addWords("Tom")

	local matchList = searcher:findKey("ry")
	local matchCount = 0
	for words, _ in pairs(matchList) do
		if words == "Ryan" or words == "Mary" then
			matchCount = matchCount + 1
		end
	end
	assert(matchCount == 2)

	searcher:removeWords("Mary")
	matchList = searcher:findKey("ry")
	assert(table.size(matchList) == 1)

	searcher:addWords("1大师2")
	searcher:addWords("1大师傅2")
	matchList = searcher:findKey("师")
	matchCount = 0
	for words, _ in pairs(matchList) do
		if words == "1大师2" or words == "1大师傅2" then
			matchCount = matchCount + 1
		end
	end
	assert(matchCount == 2)
end

test()

return WordsSearcher

