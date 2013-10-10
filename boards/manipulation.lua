local _M = {}

local table = require 'table'
local region = require 'boards.region'

------------------------------------------------------------------------------

function _M.offset_extents(extents, dx, dy)
	local copy = {}
	copy.left = extents.left + dx
	copy.right = extents.right + dx
	copy.bottom = extents.bottom + dy
	copy.top = extents.top + dy
	return region(copy)
end

function _M.offset_point(point, dx, dy)
	local copy = {}
	for k,v in pairs(point) do
		copy[k] = v
	end
	if copy.x then copy.x = copy.x + dx end
	if copy.y then copy.y = copy.y + dy end
	return copy
end

function _M.offset_path(path, dx, dy)
	local copy = {
		unit = path.unit,
	}
	if path.extents then
		copy.extents = _M.offset_extents(path.extents, dx, dy)
	end
	copy.aperture = path.aperture
	for i,point in ipairs(path) do
		copy[i] = _M.offset_point(point, dx, dy)
	end
	return copy
end

function _M.offset_layer(layer, dx, dy)
	local copy = {
		polarity = layer.polarity,
	}
	for i,path in ipairs(layer) do
		copy[i] = _M.offset_path(path, dx, dy)
	end
	return copy
end

function _M.offset_image(image, dx, dy)
	local copy = {
		file_path = nil,
		name = image.name,
		format = {},
		unit = image.unit,
		layers = {},
	}
	
	-- copy format
	for k,v in pairs(image.format) do
		copy.format[k] = v
	end
	
	-- move extents
	copy.extents = _M.offset_extents(image.extents, dx, dy)
	copy.center_extents = _M.offset_extents(image.center_extents, dx, dy)
	
	-- move layers
	for i,layer in ipairs(image.layers) do
		copy.layers[i] = _M.offset_layer(layer, dx, dy)
	end
	
	return copy
end

function _M.offset_board(board, dx, dy)
	local copy = {
		unit = board.unit,
		template = board.template,
		extensions = {},
		images = {},
	}
	
	-- copy extensions
	for type,extension in pairs(board.extensions) do
		copy.extensions[type] = extension
	end
	
	-- move extents
	copy.extents = _M.offset_extents(board.extents, dx, dy)
	
	-- move images
	for type,image in pairs(board.images) do
		copy.images[type] = _M.offset_image(image, dx, dy)
	end
	
	return copy
end

------------------------------------------------------------------------------

function _M.rotate180_extents(extents)
	local copy = {}
	copy.left = -extents.right
	copy.right = -extents.left
	copy.bottom = -extents.top
	copy.top = -extents.bottom
	return region(copy)
end

function _M.rotate180_macro(macro)
	local copy = {
		name = macro.name,
		unit = macro.unit,
		script = macro.script,
		chunk = macro.chunk,
	}
	print("warning: macro rotation not yet implemented, assumed symmetrical")
	return copy
end

local symmetrical180_shapes = {
	circle = true,
	rectangle = true,
	obround = true,
}

function _M.rotate180_aperture(aperture, macros)
	local copy = {
		name = aperture.name,
		unit = aperture.unit,
		shape = aperture.shape,
		macro = nil,
		parameters = {},
	}
	-- copy parameters
	for k,v in pairs(aperture.parameters) do
		copy.parameters[k] = v
	end
	-- adjust parameters
	assert(not (aperture.shape and aperture.macro), "aperture has a shape and a macro")
	if aperture.macro then
		copy.macro = macros[aperture.macro]
		if not copy.macro then
			copy.macro = _M.rotate180_macro(aperture.macro)
			macros[aperture.macro] = copy.macro
		end
	elseif symmetrical180_shapes[aperture.shape] then
		-- keep it that way
	elseif aperture.shape=='polygon' then
		local angle = copy.parameters[3] or 0
		angle = angle + 180
		if #copy.parameters==3 and angle==0 then
			copy.parameters[3] = nil
		else
			copy.parameters[3] = angle
		end
	elseif aperture.device then
		-- parts rotation is in the layer data
		copy.device = true
	else
		error("unsupported aperture shape")
	end
	return copy
end

function _M.rotate180_point(point)
	local copy = {}
	for k,v in pairs(point) do
		copy[k] = v
	end
	if copy.x then copy.x = -copy.x end
	if copy.y then copy.y = -copy.y end
	if copy.i then copy.i = -copy.i end
	if copy.j then copy.j = -copy.j end
	if copy.angle then copy.angle = (copy.angle + 180) % 360 end
	return copy
end

function _M.rotate180_path(path, apertures, macros)
	local copy = {
		unit = path.unit,
	}
	if path.extents then
		copy.extents = _M.rotate180_extents(path.extents)
	end
	if path.aperture then
		copy.aperture = apertures[path.aperture]
		if not copy.aperture then
			copy.aperture = _M.rotate180_aperture(path.aperture, macros)
			apertures[path.aperture] = copy.aperture
		end
	end
	for i,point in ipairs(path) do
		copy[i] = _M.rotate180_point(point)
	end
	return copy
end

function _M.rotate180_layer(layer, apertures, macros)
	local copy = {
		polarity = layer.polarity,
	}
	for i,path in ipairs(layer) do
		copy[i] = _M.rotate180_path(path, apertures, macros)
	end
	return copy
end

function _M.rotate180_image(image)
	local copy = {
		file_path = nil,
		name = image.name,
		format = {},
		unit = image.unit,
		layers = {},
	}
	
	-- copy format
	for k,v in pairs(image.format) do
		copy.format[k] = v
	end
	
	-- move extents
	copy.extents = _M.rotate180_extents(image.extents)
	copy.center_extents = _M.rotate180_extents(image.center_extents)
	
	-- apertures and macros are shared by layers and paths, so create an index to avoid duplicating them in the copy
	local apertures = {}
	local macros = {}
	
	-- move layers
	for i,layer in ipairs(image.layers) do
		copy.layers[i] = _M.rotate180_layer(layer, apertures, macros)
	end
	
	return copy
end

function _M.rotate180_board(board)
	local copy = {
		unit = board.unit,
		template = board.template,
		extensions = {},
		images = {},
	}
	
	-- copy extensions
	for type,extension in pairs(board.extensions) do
		copy.extensions[type] = extension
	end
	
	-- rotate extents
	copy.extents = _M.rotate180_extents(board.extents)
	
	-- rotate images
	for type,image in pairs(board.images) do
		copy.images[type] = _M.rotate180_image(image)
	end
	
	return copy
end

------------------------------------------------------------------------------

function _M.copy_path(path)
	return _M.offset_path(path, 0, 0)
end

function _M.copy_layer(layer)
	return _M.offset_layer(layer, 0, 0)
end

function _M.copy_image(image)
	return _M.offset_image(image, 0, 0)
end

function _M.copy_board(board)
	return _M.offset_board(board, 0, 0)
end

function _M.copy_side(side)
	return _M.offset_side(side, 0)
end

------------------------------------------------------------------------------

function _M.merge_layers(layer_a, layer_b)
	assert(layer_a.polarity == layer_b.polarity, "layer polarity mismatch ("..tostring(layer_a.polarity).." vs. "..tostring(layer_b.polarity)..")")
	local merged = {
		polarity = layer_a.polarity,
	}
	for i,path in ipairs(layer_a) do
		table.insert(merged, _M.copy_path(path))
	end
	for i,path in ipairs(layer_b) do
		table.insert(merged, _M.copy_path(path))
	end
	return merged
end

function _M.merge_images(image_a, image_b)
	assert(image_a.unit == image_b.unit, "image unit mismatch")
	local merged = {
		file_path = nil,
		name = nil,
		format = {},
		unit = image_a.unit,
		layers = {},
	}
	
	-- merge names
	if image_a.name or image_b.name then
		merged.name = (image_a.name or '<unknown>')..' merged with '..(image_b.name or '<unknown>')
	end
	
	-- copy format (and check that they are identical
	for k,v in pairs(image_a.format) do
		assert(image_b.format[k] == v, "image format mismatch (field "..tostring(k)..": "..tostring(v)..' vs. '..tostring(image_b.format[k])..")")
		merged.format[k] = v
	end
	for k,v in pairs(image_b.format) do
		assert(image_a.format[k] == v, "image format mismatch")
	end
	
	-- merge extents
	merged.extents = image_a.extents + image_b.extents
	merged.center_extents = image_a.center_extents + image_b.center_extents
	
	-- merge layers
	for i=1,#image_a.layers do
		local layer_a = image_a.layers[i]
		local layer_b = image_b.layers[i]
		if layer_b then
			merged.layers[i] = _M.merge_layers(layer_a, layer_b)
		else
			merged.layers[i] = _M.copy_layer(layer_a)
		end
	end
	for i=#image_a.layers+1,#image_b.layers do
		merged.layers[i] = _M.copy_layer(#image_b.layers[i])
	end
	
	return merged
end

function _M.merge_boards(board_a, board_b)
	assert(board_a.unit == board_b.unit, "board unit mismatch")
	assert(board_a.template == board_b.template, "board template mismatch")
	local merged = {
		unit = board_a.unit,
		template = board_a.template,
		extensions = {},
		images = {},
	}
	
	-- merge extensions
	for type,extension in pairs(board_a.extensions) do
		merged.extensions[type] = extension
	end
	for type,extension in pairs(board_b.extensions) do
		-- prefer extensions from A in case of conflict
		if not merged.extensions[type] then
			merged.extensions[type] = extension
		end
	end
	
	-- merge extents
	merged.extents = board_a.extents + board_b.extents
	
	-- merge images
	for type,image_a in pairs(board_a.images) do
		local image_b = board_b.images[type]
		if image_b then
			merged.images[type] = _M.merge_images(image_a, image_b)
		else
			merged.images[type] = _M.copy_image(image_a)
		end
	end
	for type,image_b in pairs(board_b.images) do
		local image_a = board_a.images[type]
		if not image_a then
			merged.images[type] = _M.copy_image(image_b)
		end
	end
	
	return merged
end

------------------------------------------------------------------------------

return _M
