require 'test'
local fs = require 'lfs'
local gerber = require 'gerber'
local excellon = require 'excellon'
local dump = require 'dump'


local function exc(letter)
--	local data = assert(excellon.load("test/excellon/"..letter..".exc"))
--	assert(gerber.save(data, "test/excellon/"..letter..".ger"))
	local data = excellon.load("test/excellon/"..letter..".exc")
	data.file_path = nil
	return data
end

local function ger(letter)
	local data = gerber.load("test/excellon/"..letter..".ger")
	data.file_path = nil
	return data
end

expect(ger'd', exc'd')
expect(ger'e', exc'e')
expect(ger'f', exc'f')
expect(ger'g', exc'g')
expect(ger'h', exc'h')
expect(ger'i', exc'i')
expect(ger'j', exc'j')
expect(ger'k', exc'k')
expect(ger'l', exc'l')
expect(ger'm', exc'm')
expect(ger'n', exc'n')
expect(ger'o', exc'o')
expect(ger'p', exc'p')
expect(ger'q', exc'q')
expect(ger'r', exc'r')
expect(ger's', exc's')

local data = assert(excellon.load("test/excellon/p.exc"))
assert(excellon.save(data, "test/excellon/p.out.exc"))
expect(ger'p', exc'p.out')

local data = assert(excellon.load("test/excellon/q.exc"))
assert(excellon.save(data, "test/excellon/q.out.exc"))
expect(ger'q', exc'q.out')

