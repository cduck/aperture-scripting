local _M = {}

local region = require 'boards.region'

------------------------------------------------------------------------------

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
