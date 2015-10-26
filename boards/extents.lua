--- This module contain several functions to compute the extents of a board or its components. All extents are of type `region`, which is a table with fields `left`, `right`, `bottom` and `top`, virtual fields `width`, `height` `area` and `empty` and several operator overloads.
local _M = {}
local _NAME = ... or 'test'

local region = require 'boards.region'
if _NAME=='test' then
	require 'test'
end

local atan2 = math.atan2 or math.atan

------------------------------------------------------------------------------

function _M.compute_arc_extents(x0, y0, x1, y1, cx, cy, direction, quadrant)
	local extents = region()
	extents = extents + {x=x0, y=y0}
	extents = extents + {x=x1, y=y1}
	local a0 = atan2(y0 - cy, x0 - cx)
	local a1 = atan2(y1 - cy, x1 - cx)
	if direction=='clockwise' then a0,a1 = a1,a0 end
	while a1 < a0 do a1 = a1 + math.pi * 2 end
	if a1==a0 and quadrant=='multi' then a1 = a1 + math.pi * 2 end
	local q = math.pi / 2
	for a=math.ceil(a0 / q) * q, a1, q do
		extents = extents + {x=cx + math.cos(a), y=cy + math.sin(a)}
	end
	return extents
end

------------------------------------------------------------------------------

function _M.compute_path_extents(path)
	local extents = region()
	for i,point in ipairs(path) do
		if point.interpolation==nil or point.interpolation=='linear' then
			extents = extents + point
		elseif point.interpolation=='circular' then
			extents = extents + point
			assert(i >= 2)
			assert(point.direction=='clockwise' or point.direction=='counterclockwise')
			assert(point.quadrant=='single' or point.quadrant=='multi')
			extents = extents + _M.compute_arc_extents(path[i-1].x, path[i-1].y, point.x, point.y, point.cx, point.cy, point.direction, point.quadrant)
		else
			error("unsupported interpolation")
		end
	end
	return extents
end

--- Compute the extents of an aperture. This requires that the aperture paths have been previously generated (see [boards.generate\_aperture\_paths](#boards.generate_aperture_paths)).
function _M.compute_aperture_extents(aperture)
	local extents = region()
	for _,path in ipairs(aperture.paths) do
		extents = extents + _M.compute_path_extents(path)
	end
	return extents
end

if _NAME=='test' then
	local p1 = {
		{x=1, y=0},
		{x=0, y=-1, interpolation='circular', cx=0, cy=0, direction='counterclockwise', quadrant='single'},
	}
	local e1 = {
		left = -1,
		right = 1,
		top = 1,
		bottom = -1,
	}
	local p2 = {
		{x=1, y=0},
		{x=0, y=-1, interpolation='circular', cx=0, cy=0, direction='clockwise', quadrant='multi'},
	}
	local e2 = {
		left = 0,
		right = 1,
		top = 0,
		bottom = -1,
	}
	local p3 = {
		{x=0, y=-1},
		{x=1, y=0, interpolation='circular', cx=0, cy=0, direction='counterclockwise', quadrant='multi'},
	}
	local e3 = {
		left = 0,
		right = 1,
		top = 0,
		bottom = -1,
	}
	local p4 = {
		{x=0, y=-1},
		{x=1, y=0, interpolation='circular', cx=0, cy=0, direction='clockwise', quadrant='single'},
	}
	local e4 = {
		left = -1,
		right = 1,
		top = 1,
		bottom = -1,
	}
	expect(e1, _M.compute_path_extents(p1))
	expect(e2, _M.compute_path_extents(p2))
	expect(e3, _M.compute_path_extents(p3))
	expect(e4, _M.compute_path_extents(p4))
	expect(e1, _M.compute_aperture_extents({paths={p1}}))
	expect(e2, _M.compute_aperture_extents({paths={p2}}))
	expect(e3, _M.compute_aperture_extents({paths={p3}}))
	expect(e4, _M.compute_aperture_extents({paths={p4}}))
end

function _M.compute_outline_extents(outline)
	return _M.compute_path_extents(outline.path)
end

--- Compute the extents of an image. This does not include the aperture extents, if any.
function _M.compute_image_extents(image)
	local extents = region()
	for _,layer in ipairs(image.layers) do
		for _,path in ipairs(layer) do
			local path_extents = _M.compute_path_extents(path)
			extents = extents + path_extents
		end
	end
	return extents
end

--- Compute the extents of a board. This does not include the aperture extents, if any.
function _M.compute_board_extents(board)
	if board.outline then
		return _M.compute_outline_extents(board.outline)
	else
		local extents = region()
		for _,image in pairs(board.images) do
			extents = extents + _M.compute_image_extents(image)
		end
		return extents
	end
end

------------------------------------------------------------------------------

return _M
