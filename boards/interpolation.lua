local _M = {}

local math = require 'math'
local table = require 'table'

------------------------------------------------------------------------------

local function interpolate_point(path, point)
	local interpolation = point.interpolation
	local quadrant = point.quadrant
	if interpolation == 'linear' then
		-- no intermediates
	elseif interpolation == 'clockwise' or interpolation == 'counterclockwise' then
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
			table.insert(path, {x=x, y=y, interpolated=true})
		end
	else
		error("unsupported interpolation mode "..tostring(interpolation))
	end
	
	table.insert(path, point)
end

local function interpolate_path(path)
	local interpolated = { aperture = path.aperture }
	for i,point in ipairs(path) do
		if i == 1 then
			table.insert(interpolated, point)
		else
			interpolate_point(interpolated, point)
		end
	end
	for i,point in ipairs(interpolated) do
		point.interpolated = nil
		point.cx = nil
		point.cy = nil
		point.quadrant = nil
		if i > 1 then point.interpolation = 'linear' end
	end
	return interpolated
end

local function interpolate_image_paths(image)
	for _,layer in ipairs(image.layers) do
		for ipath,path in ipairs(layer) do
			layer[ipath] = interpolate_path(path)
		end
	end
end
_M.interpolate_image_paths = interpolate_image_paths

function _M.interpolate_board_paths(board)
	for _,image in pairs(board.images) do
		interpolate_image_paths(image)
	end
	if board.outline then
		board.outline.path = interpolate_path(board.outline.path)
	end
end

------------------------------------------------------------------------------

return _M
