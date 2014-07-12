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

function _M.compute_path_extents(path, apertures_extents)
	if not apertures_extents then apertures_extents = {} end
	local center_extents = region()
	for _,point in ipairs(path) do
		center_extents = center_extents + point
	end
	local extents = region(center_extents)
	local aperture = path.aperture
	if aperture then
		local aperture_extents = apertures_extents[aperture] or _M.compute_aperture_extents(aperture)
		if not aperture_extents.empty then
			extents = extents * aperture_extents
		end
	end
	return extents,center_extents
end

function _M.compute_outline_extents(outline)
	return _M.compute_path_extents(outline.path)
end

function _M.compute_image_extents(image)
	-- cache apertures extents for speedup
	local apertures_extents = {}
	local apertures = {}
	for _,layer in ipairs(image.layers) do
		for _,path in ipairs(layer) do
			local aperture = path.aperture
			if aperture and not apertures_extents[aperture] then
				apertures_extents[aperture] = _M.compute_aperture_extents(aperture)
			end
		end
	end
	
	-- compute extents
	local center_extents = region()
	local extents = region()
	for _,layer in ipairs(image.layers) do
		for _,path in ipairs(layer) do
			local path_extents,path_center_extents = _M.compute_path_extents(path, apertures_extents)
			center_extents = center_extents + path_center_extents
			extents = extents + path_extents
		end
	end
	return extents,center_extents
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
