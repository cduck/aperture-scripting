--- This module contain several functions to compute the extents of a board or its components. All extents are of type `region`, which is a table with fields `left`, `right`, `bottom` and `top`, virtual fields `width`, `height` `area` and `empty` and several operator overloads.
local _M = {}

local region = require 'boards.region'

------------------------------------------------------------------------------

--- Compute the extents of an aperture. This requires that the aperture paths have been previously generated (see [boards.generate\_aperture\_paths](#boards.generate_aperture_paths)).
function _M.compute_aperture_extents(aperture)
	local extents = region()
	for _,path in ipairs(aperture.paths) do
		for _,point in ipairs(path) do
			extents = extents + point
		end
	end
	return extents
end

function _M.compute_path_extents(path)
	local extents = region()
	for _,point in ipairs(path) do
		extents = extents + point
	end
	return extents
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
