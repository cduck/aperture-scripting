local _M = {}
local _NAME = ... or 'test'

local math = require 'math'
local table = require 'table'
local spline = require 'boards.spline'

if _NAME=='test' then
	require 'test'
end

------------------------------------------------------------------------------

local curve_steps = 16

local function interpolate_point(path, point, epsilon, allowed)
	local interpolation = point.interpolation
	if allowed[interpolation] then
		table.insert(path, point)
	elseif interpolation == 'circular' and allowed.linear then
		local direction = assert(point.direction, "circular interpolation has no direction")
		local quadrant = point.quadrant
		local point0 = path[#path]
		local cx,cy = point.cx,point.cy
		
		local dxa,dya = point0.x - cx, point0.y - cy
		local dxb,dyb = point.x - cx, point.y - cy
		local ra = math.sqrt(dxa*dxa + dya*dya)
		local rb = math.sqrt(dxb*dxb + dyb*dyb)
		local ta = math.deg(math.atan2(dya, dxa))
		while ta < 0 do ta = ta + 360 end
		local tb = math.deg(math.atan2(dyb, dxb))
		while tb < 0 do tb = tb + 360 end
		
		-- error is r * (1 - cos(step / 2))
		local r = math.max(ra, rb)
		local re = math.min(epsilon/r, 1)
		local step = math.deg(2 * math.acos(1 - re)) - 1e-11
		assert(r * (1 - math.cos(math.rad(step / 2))) <= epsilon)
		step = 90 / math.ceil(90 / step) -- improve precision so that we get points on both axis
		assert(r * (1 - math.cos(math.rad(step / 2))) <= epsilon)
		step = math.max(step, 0.1)
		
		local ta2,tb2
		if direction == 'clockwise' then
			while ta < tb do ta = ta + 360 end
			if quadrant == 'multi' and ta == tb then ta = ta + 360 end
			ta2 = (math.ceil(ta / step) - 1) * step
			tb2 = (math.floor(tb / step) + 1) * step
			step = -step
		elseif direction == 'counterclockwise' then
			while tb < ta do tb = tb + 360 end
			if quadrant == 'multi' and tb == ta then tb = tb + 360 end
			ta2 = (math.floor(ta / step) + 1) * step
			tb2 = (math.ceil(tb / step) - 1) * step
		else
			error("unsupported circular interpolation direction "..tostring(direction))
		end
		for t = ta2, tb2+0.5*step, step do
			local r = (t - ta) / (tb - ta) * (rb - ra) + ra
			local x = cx + r * math.cos(math.rad(t))
			local y = cy + r * math.sin(math.rad(t))
			table.insert(path, {x=x, y=y, interpolation='linear'})
		end
		if point.x~=path[#path].x or point.y~=path[#path].y then
			table.insert(path, {x=point.x, y=point.y, interpolation='linear'})
		end
	elseif (interpolation == 'quadratic' or interpolation == 'cubic') and allowed.circular and allowed.linear then
		local curve
		if interpolation == 'quadratic' then
			curve = spline.quadratic(path[#path].x, path[#path].y, point.x1, point.y1, point.x, point.y)
		elseif interpolation == 'cubic' then
			curve = spline.cubic(path[#path].x, path[#path].y, point.x1, point.y1, point.x2, point.y2, point.x, point.y)
		end
		local arcs = spline.convert_to_arcs(curve, epsilon)
		for _,arc in ipairs(arcs) do
			assert(arc.x0==path[#path].x)
			assert(arc.y0==path[#path].y)
			assert(arc.mode=='arc')
			if (arc.x1-arc.x0)^2 + (arc.y1-arc.y0)^2 < epsilon^2 then
				table.insert(path, {interpolation='linear', x=arc.x1, y=arc.y1})
			else
				table.insert(path, {interpolation='circular', quadrant='single', direction=arc.direction, cx=arc.cx, cy=arc.cy, x=arc.x1, y=arc.y1})
			end
		end
	elseif interpolation == 'quadratic' and allowed.linear then
		-- :TODO: use epsilon instead of curve_steps
		local P0 = path[#path]
		local P1 = {x=point.x1, y=point.y1}
		local P2 = point
		for t=1,curve_steps do
			t = t / curve_steps
			local k1 = (1 - t) ^ 2
			local k2 = 2 * (1 - t) * t
			local k3 = t ^ 2
			local px = k1 * P0.x + k2 * P1.x + k3 * P2.x
			local py = k1 * P0.y + k2 * P1.y + k3 * P2.y
			table.insert(path, {x=px, y=py, interpolation='linear'})
		end
		assert(path[#path].x==P2.x and path[#path].y==P2.y)
	elseif interpolation == 'cubic' and allowed.linear then
		-- :TODO: use epsilon instead of curve_steps
		local P0 = path[#path]
		local P1 = {x=point.x1, y=point.y1}
		local P2 = {x=point.x2, y=point.y2}
		local P3 = point
		for t=1,curve_steps do
			t = t / curve_steps
			local k1 = (1 - t) ^ 3
			local k2 = 3 * (1 - t) ^ 2 * t
			local k3 = 3 * (1 - t) * t ^ 2
			local k4 = t ^ 3
			local px = k1 * P0.x + k2 * P1.x + k3 * P2.x + k4 * P3.x
			local py = k1 * P0.y + k2 * P1.y + k3 * P2.y + k4 * P3.y
			table.insert(path, {x=px, y=py, interpolation='linear'})
		end
	else
		error("unsupported interpolation mode "..tostring(interpolation))
	end
end

if _NAME=='test' then
	local path = {{x=0, y=0}}
	local point = {interpolation='circular', cx=1, cy=0, x=1, y=1, direction='clockwise', quadrant='single'}
	interpolate_point(path, point, 0.001, {linear=true})
	expect(19, #path)
	local path = {{x=0, y=0}}
	local point = {interpolation='circular', cx=1, cy=0, x=0, y=0, direction='clockwise', quadrant='single'}
	interpolate_point(path, point, 0.001, {linear=true})
	expect(1, #path)
	local path = {{x=0, y=0}}
	local point = {interpolation='circular', cx=1, cy=0, x=0, y=0, direction='clockwise', quadrant='multi'}
	interpolate_point(path, point, 0.001, {linear=true})
	expect(73, #path)
	local path = {{x=0, y=0}}
	local point = {interpolation='circular', cx=2.54, cy=2.54, x=0, y=5.08, direction='clockwise', quadrant='single'}
	interpolate_point(path, point, 0.01, {linear=true})
	expect(13, #path)
end

local function interpolate_path(path, epsilon, allowed)
	assert(epsilon~=nil, "interpolation epsilon is required")
	if not allowed then allowed = { linear = true } end
	assert(allowed.linear, "interpolation require at least linear segment support")
	local path_allowed = true
	for i,point in ipairs(path) do
		if i >= 2 and not allowed[point.interpolation] then
			path_allowed = false
			break
		end
	end
	if path_allowed then return path end
	local interpolated = { aperture = path.aperture }
	for i,point in ipairs(path) do
		if i == 1 then
			assert(next(point)=='x' and next(point, 'x')=='y' and next(point, 'y')==nil or
				next(point)=='y' and next(point, 'y')=='x' and next(point, 'x')==nil)
			table.insert(interpolated, {x=point.x, y=point.y})
		else
			interpolate_point(interpolated, point, epsilon, allowed)
		end
	end
	return interpolated
end
_M.interpolate_path = interpolate_path

local function interpolate_image_paths(image, epsilon, allowed)
	for _,layer in ipairs(image.layers) do
		for ipath,path in ipairs(layer) do
			layer[ipath] = interpolate_path(path, epsilon, allowed)
		end
	end
end
_M.interpolate_image_paths = interpolate_image_paths

function _M.interpolate_board_paths(board, epsilon, allowed)
	for _,image in pairs(board.images) do
		interpolate_image_paths(image, epsilon, allowed)
	end
	if board.outline then
		board.outline.path = interpolate_path(board.outline.path, epsilon, allowed)
	end
end

------------------------------------------------------------------------------

return _M
