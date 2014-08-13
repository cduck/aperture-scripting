local _MT = {}
local _M = setmetatable({}, _MT)
local _NAME = ... or 'test'

local math = require 'math'

local default_region = {
	left = math.huge,
	right = -math.huge,
	bottom = math.huge,
	top = -math.huge,
}

local region_mt = {}
local region_getters = {}
local region_methods = {}

local function ctor(orig)
	if not orig then orig = default_region end
	return setmetatable({
		left = orig.left,
		right = orig.right,
		bottom = orig.bottom,
		top = orig.top,
	}, region_mt)
end

function region_mt.__index(self, k)
	local getter = region_getters[k]
	if getter then
		return getter(self)
	end
	return region_methods[k]
end

function region_getters:empty()
	return self.right <= self.left or self.top <= self.bottom
end

function region_getters:area()
	return (self.right - self.left) * (self.top - self.bottom)
end

function region_getters:width()
	return self.right - self.left
end

function region_getters:height()
	return self.top - self.bottom
end

function region_mt.__add(self, extension)
	if self and extension and extension.x and extension.y then
		return ctor{
			left = math.min(self.left, extension.x),
			right = math.max(self.right, extension.x),
			bottom = math.min(self.bottom, extension.y),
			top = math.max(self.top, extension.y),
		}
	elseif self and extension and extension.left and extension.right and extension.bottom and extension.top then
		return ctor{
			left = math.min(self.left, extension.left),
			right = math.max(self.right, extension.right),
			bottom = math.min(self.bottom, extension.bottom),
			top = math.max(self.top, extension.top),
		}
	else
		error("only points or other regions can be added to a region")
	end
end

function region_mt.__mul(a, b)
	if a and b and a.left and a.right and a.bottom and a.top and b.left and b.right and b.bottom and b.top then
		return ctor{
			left = a.left + b.left,
			right = a.right + b.right,
			bottom = a.bottom + b.bottom,
			top = a.top + b.top,
		}
	else
		error("regions can only be multiplied with other regions")
	end
end

function region_methods:contains(point)
	return self.left <= point.x and point.x <= self.right
		and self.bottom <= point.y and point.y <= self.top
end

_M.new = ctor

function _MT:__call(...)
	return ctor(...)
end

if _NAME=='test' then
	require 'test'
	assert(_M.new())
	assert(_M())
	expect(region_mt, getmetatable(_M.new()))
	expect(region_mt, getmetatable(_M()))
	expect(true, _M().empty)
	expect(nil, _M().foo)
	local r = _M{left=1, bottom=3, right=4, top=5}
	expect(3, r.width)
	expect(2, r.height)
	expect(6, r.area)
	local r1 = _M{left=1, bottom=1, right=3, top=3}
	local r2 = _M{left=2, bottom=2, right=4, top=4}
	local r = r1 + r2
	expect(1, r.left)
	expect(1, r.bottom)
	expect(4, r.right)
	expect(4, r.top)
	local p = {x=4, y=4}
	local r = r1 + p
	expect(1, r.left)
	expect(1, r.bottom)
	expect(4, r.right)
	expect(4, r.top)
	local r = r1 * r2
	expect(3, r.left)
	expect(3, r.bottom)
	expect(7, r.right)
	expect(7, r.top)
	expect(false, pcall(function() return r + {} end))
	expect(false, pcall(function() return r * {} end))
end

------------------------------------------------------------------------------

return _M
