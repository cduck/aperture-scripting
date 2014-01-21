local _MT = {}
local _M = setmetatable({}, _MT)

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

function region_mt.__add(self, extension)
	if extension.x and extension.y then
		return ctor{
			left = math.min(self.left, extension.x),
			right = math.max(self.right, extension.x),
			bottom = math.min(self.bottom, extension.y),
			top = math.max(self.top, extension.y),
		}
	elseif extension.left and extension.right and extension.bottom and extension.top then
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
	if a.left and a.right and a.bottom and a.top and b.left and b.right and b.bottom and b.top then
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

_M.new = ctor

function _MT:__call(...)
	return ctor(...)
end

------------------------------------------------------------------------------

function _M.recompute_path_extents(path)
	path.center_extents = ctor()
	for _,point in ipairs(path) do
		path.center_extents = path.center_extents + point
	end
	path.extents = ctor(path.center_extents)
	local aperture = path.aperture
	if aperture and not aperture.extents.empty then
		path.extents = path.extents * aperture.extents
	end
end

------------------------------------------------------------------------------

return _M
