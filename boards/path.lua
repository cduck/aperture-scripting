local _M = {}
local _NAME = ... or 'test'

local math = require 'math'
local table = require 'table'

if _NAME=='test' then
	require 'test'
end

------------------------------------------------------------------------------

local sqrt,min,max,asin = math.sqrt,math.min,math.max,math.asin
function _M.exterior(path)
	local total = 0
	for i=1,#path-1 do
		local p0 = path[i-1] or path[#path-1]
		local p1 = path[i]
		local p2 = path[i+1] or path[1]
		local dx1 = p1.x - p0.x
		local dy1 = p1.y - p0.y
		local dx2 = p2.x - p1.x
		local dy2 = p2.y - p1.y
		local l1 = sqrt(dx1*dx1+dy1*dy1)
		local l2 = sqrt(dx2*dx2+dy2*dy2)
		if l1 * l2 ~= 0 then
			local n = min(max((dx1*dy2-dy1*dx2)/(l1*l2), -1), 1) -- should only be marginally outside the range
			local angle = asin(n)
			total = total + angle
		end
	end
	return total >= 0
end

if _NAME=='test' then
	local path = {
		{
			x = -0.00223606797749979,
			y = -0.004472135954999579,
		},
		{
			x = 0.00223606797749979,
			y = 0.004472135954999579,
		},
		{
			x = -0.097763932022500222,
			y = 0.054472135954999591,
		},
		{
			x = -0.10223606797749979,
			y = 0.045527864045000428,
		},
		{
			x = -0.00223606797749979,
			y = -0.004472135954999579,
		},
	}
	assert(_M.exterior(path))
end

------------------------------------------------------------------------------

function _M.shift_path(path, i0)
	assert(path[#path].x==path[1].x and path[#path].y==path[1].y, "path is not closed")
	i0 = (i0 - 1) % #path + 1
	local shifted = {aperture=path.aperture}
	-- start with the end point
	shifted[1] = {} -- empty point, for now
	-- copy second half
	for i=i0+1,#path do
		table.insert(shifted, path[i])
	end
	for i=2,i0 do
		table.insert(shifted, path[i])
	end
	-- close the path
	shifted[1].x = shifted[#shifted].x
	shifted[1].y = shifted[#shifted].y
	return shifted
end

if _NAME=='test' then
	local a = {
		{x=-1, y= 0},
		{x= 0, y= 1, cx=0, cx=0, interpolation='circular', direction='clockwise', quadrant='single'},
		{x= 1, y= 0, cx=0, cx=0, interpolation='circular', direction='clockwise', quadrant='single'},
		{x= 0, y=-1, cx=0, cx=0, interpolation='circular', direction='clockwise', quadrant='single'},
		{x=-1, y= 0, cx=0, cx=0, interpolation='circular', direction='clockwise', quadrant='single'},
	}
	expect(a, _M.shift_path(a, 1))
	expect(a, _M.shift_path(a, 5))
	local b = {
		{x= 0, y= 1},
		{x= 1, y= 0, cx=0, cx=0, interpolation='circular', direction='clockwise', quadrant='single'},
		{x= 0, y=-1, cx=0, cx=0, interpolation='circular', direction='clockwise', quadrant='single'},
		{x=-1, y= 0, cx=0, cx=0, interpolation='circular', direction='clockwise', quadrant='single'},
		{x= 0, y= 1, cx=0, cx=0, interpolation='circular', direction='clockwise', quadrant='single'},
	}
	expect(b, _M.shift_path(a, 2))
	local b = {
		{x= 1, y= 0},
		{x= 0, y=-1, cx=0, cx=0, interpolation='circular', direction='clockwise', quadrant='single'},
		{x=-1, y= 0, cx=0, cx=0, interpolation='circular', direction='clockwise', quadrant='single'},
		{x= 0, y= 1, cx=0, cx=0, interpolation='circular', direction='clockwise', quadrant='single'},
		{x= 1, y= 0, cx=0, cx=0, interpolation='circular', direction='clockwise', quadrant='single'},
	}
	expect(b, _M.shift_path(a, 3))
	local b = {
		{x= 0, y=-1},
		{x=-1, y= 0, cx=0, cx=0, interpolation='circular', direction='clockwise', quadrant='single'},
		{x= 0, y= 1, cx=0, cx=0, interpolation='circular', direction='clockwise', quadrant='single'},
		{x= 1, y= 0, cx=0, cx=0, interpolation='circular', direction='clockwise', quadrant='single'},
		{x= 0, y=-1, cx=0, cx=0, interpolation='circular', direction='clockwise', quadrant='single'},
	}
	expect(b, _M.shift_path(a, 4))
end

------------------------------------------------------------------------------

local reverse_direction = {
	clockwise = 'counterclockwise',
	counterclockwise = 'clockwise',
}

function _M.reverse_path(path)
	local reverse = {aperture=path.aperture}
	-- start with the end point
	reverse[1] = {x=path[#path].x, y=path[#path].y}
	-- reverse each segment
	for i=#path-1,1,-1 do
		local point = path[i]
		local params = path[i+1] -- interpolation params are in the previous point
		local interpolation = params.interpolation
		if interpolation=='linear' then
			table.insert(reverse, {x=point.x, y=point.y, interpolation='linear'})
		elseif interpolation=='circular' then
			local direction = assert(reverse_direction[params.direction], "unsupported circular direction "..tostring(params.direction))
			table.insert(reverse, {x=point.x, y=point.y, cx=params.cx, cy=params.cy, interpolation='circular', direction=direction, quadrant=params.quadrant})
		elseif interpolation=='quadratic' then
			-- single control point stays the same
			table.insert(reverse, {x=point.x, y=point.y, x1=params.x1, y1=params.y1, interpolation='quadratic'})
		elseif interpolation=='cubic' then
			-- swap control points
			table.insert(reverse, {x=point.x, y=point.y, x1=params.x2, y1=params.y2, x2=params.x1, y2=params.y1, interpolation='cubic'})
		else
			error("unsupported interpolation "..tostring(interpolation))
		end
	end
	return reverse
end

if _NAME=='test' then
	local a = { {x=0, y=0}, {x=1, y=1, interpolation='linear'} }
	local b = { {x=1, y=1}, {x=0, y=0, interpolation='linear'} }
	expect(b, _M.reverse_path(a))
	local a = { {x=0, y=0}, {x=1, y=1, cx=1, cy=0, interpolation='circular', direction='clockwise', quadrant='single'} }
	local b = { {x=1, y=1}, {x=0, y=0, cx=1, cy=0, interpolation='circular', direction='counterclockwise', quadrant='single'} }
	expect(b, _M.reverse_path(a))
	local a = { {x=0, y=0}, {x=1, y=1, cx=1, cy=0, interpolation='circular', direction='counterclockwise', quadrant='multi'} }
	local b = { {x=1, y=1}, {x=0, y=0, cx=1, cy=0, interpolation='circular', direction='clockwise', quadrant='multi'} }
	expect(b, _M.reverse_path(a))
	local a = { {x=0, y=0}, {x1=1, y1=0, x=1, y=1, interpolation='quadratic'} }
	local b = { {x=1, y=1}, {x1=1, y1=0, x=0, y=0, interpolation='quadratic'} }
	expect(b, _M.reverse_path(a))
	local a = { {x=0, y=0}, {x1=0, y1=1, x2=1, y2=1, x=1, y=0, interpolation='cubic'} }
	local b = { {x=1, y=0}, {x1=1, y1=1, x2=0, y2=1, x=0, y=0, interpolation='cubic'} }
	expect(b, _M.reverse_path(a))
end

------------------------------------------------------------------------------

return _M
