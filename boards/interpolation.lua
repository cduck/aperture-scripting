local _M = {}

local math = require 'math'
local table = require 'table'

------------------------------------------------------------------------------

function _M.single_quadrant_center(x0, y0, i, j, x1, y1, interpolation)
	local centers = {
		{ x = x0 - i, y = y0 - j },
		{ x = x0 + i, y = y0 - j },
		{ x = x0 + i, y = y0 + j },
		{ x = x0 - i, y = y0 + j },
	}
	local cx,cy
	local best = math.huge
	for _,c in ipairs(centers) do
		local dxa,dya = x0 - c.x, y0 - c.y
		local dxb,dyb = x1 - c.x, y1 - c.y
		local ra = math.sqrt(dxa*dxa + dya*dya)
		local rb = math.sqrt(dxb*dxb + dyb*dyb)
		local ta = math.deg(math.atan2(dya, dxa))
		local tb = math.deg(math.atan2(dyb, dxb))
		local dt
		if interpolation == 'clockwise' then
			while ta <= tb do ta = ta + 360 end
			dt = ta - tb
		else
			while tb <= ta do tb = tb + 360 end
			dt = tb - ta
		end
		if dt < 180 then
			local ratio = math.max(ra, rb) / math.min(ra, rb)
			if ratio < best then
				best = ratio
				cx,cy = c.x,c.y
			end
		end
	end
	assert(cx and cy)
	return cx,cy
end

function _M.interpolate(path, point)
	local interpolation = point.interpolation
	local quadrant = point.quadrant
	if interpolation == 'linear' then
		-- no intermediates
	elseif interpolation == 'clockwise' or interpolation == 'counterclockwise' then
		local point0 = path[#path]
		local x0,y0 = point0.x, point0.y
		local cx,cy
		if quadrant == 'single' then
			cx,cy = _M.single_quadrant_center(point0.x, point0.y, point.i, point.j, point.x, point.y, interpolation)
		elseif quadrant == 'multi' then
			cx,cy = point0.x + point.i, point0.y + point.j
		else
			error("unsupported quadrant mode "..tostring(quadrant))
		end
		
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
			while tb <= ta do tb = tb + 360 end
			if quadrant == 'multi' and tb == ta then tb = tb + 360 end
			ta2 = (math.floor(ta / step) + 1) * step
			tb2 = (math.ceil(tb / step) - 1) * step
		end
		for t = ta2, tb2, step do
			local r = (t - ta) / (tb - ta) * (rb - ra) + ra
			local x = cx + r * math.cos(math.rad(t))
			local y = cy + r * math.sin(math.rad(t))
			table.insert(path, {x=x, y=y, interpolated=true})
			x0,y0 = x,y
		end
	else
		error("unsupported interpolation mode "..tostring(interpolation))
	end
	
	table.insert(path, point)
end

------------------------------------------------------------------------------

return _M
