local _M = {}

local math = require 'math'
local table = require 'table'

------------------------------------------------------------------------------

local function interpolate_point(path, point, epsilon, allowed)
	local interpolation = point.interpolation
	if allowed[interpolation] then
		table.insert(path, point)
	elseif (interpolation == 'clockwise' or interpolation == 'counterclockwise') and allowed.linear then
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
		local step,ta2,tb2 = 6
		if interpolation == 'clockwise' then
			while ta < tb do ta = ta + 360 end
			if quadrant == 'multi' and ta == tb then ta = ta + 360 end
			ta2 = (math.ceil(ta / step) - 1) * step
			tb2 = (math.floor(tb / step) + 1) * step
			step = -step
		else
			while tb < ta do tb = tb + 360 end
			if quadrant == 'multi' and tb == ta then tb = tb + 360 end
			ta2 = (math.floor(ta / step) + 1) * step
			tb2 = (math.ceil(tb / step) - 1) * step
		end
		for t = ta2, tb2, step do
			local r = (t - ta) / (tb - ta) * (rb - ra) + ra
			local x = cx + r * math.cos(math.rad(t))
			local y = cy + r * math.sin(math.rad(t))
			table.insert(path, {x=x, y=y, interpolation='linear'})
		end
		table.insert(path, {x=point.x, y=point.y, interpolation='linear'})
	else
		error("unsupported interpolation mode "..tostring(interpolation))
	end
end

local function interpolate_path(path, epsilon, allowed)
	assert(epsilon==nil, "interpolation epsilon is not yet supported")
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
