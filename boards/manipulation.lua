local _M = {}
local _NAME = ... or 'test'

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
	assert(path.extents, "path has no extents")
	copy.extents = _M.offset_extents(path.extents, dx, dy)
	assert(path.center_extents)
	copy.center_extents = _M.offset_extents(path.center_extents, dx, dy)
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
		file_path = image.file_path,
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

function _M.offset_outline(outline, dx, dy)
	local copy = {
		apertures = {},
	}
	
	-- move the extents
	copy.extents = _M.offset_extents(outline.extents, dx, dy)
	
	-- move the path
	copy.path = _M.offset_path(outline.path, dx, dy)
	
	-- copy the aperture references
	for type,aperture in pairs(outline.apertures) do
		copy.apertures[type] = aperture
	end
	
	return copy
end

function _M.offset_board(board, dx, dy)
	local copy = {
		unit = board.unit,
		template = board.template,
		extensions = {},
		formats = {},
		images = {},
	}
	
	-- copy extensions
	for type,extension in pairs(board.extensions) do
		copy.extensions[type] = extension
	end
	
	-- copy formats
	for type,format in pairs(board.formats) do
		copy.formats[type] = format
	end
	
	-- move extents
	copy.extents = _M.offset_extents(board.extents, dx, dy)
	
	-- move images
	for type,image in pairs(board.images) do
		copy.images[type] = _M.offset_image(image, dx, dy)
	end
	
	-- move outline
	if board.outline then
		copy.outline = _M.offset_outline(board.outline, dx, dy)
	end
	
	return copy
end

------------------------------------------------------------------------------

function _M.rotate_extents(extents, angle)
	angle = angle % 360
	local copy = {}
	if angle==0 then
		copy.left = extents.left
		copy.right = extents.right
		copy.bottom = extents.bottom
		copy.top = extents.top
	elseif angle==90 then
		copy.left = -extents.top
		copy.right = -extents.bottom
		copy.bottom = extents.left
		copy.top = extents.right
	elseif angle==180 then
		copy.left = -extents.right
		copy.right = -extents.left
		copy.bottom = -extents.top
		copy.top = -extents.bottom
	elseif angle==270 then
		copy.left = extents.bottom
		copy.right = extents.top
		copy.bottom = -extents.right
		copy.top = -extents.left
	else
		error("unsupported rotation angle")
	end
	return region(copy)
end

function _M.rotate_macro(macro)
	local copy = {
		name = macro.name,
		unit = macro.unit,
		script = macro.script,
		chunk = macro.chunk,
	}
	print("warning: macro rotation not yet implemented, assumed symmetrical")
	return copy
end

local function rotate_aperture_hole(a, b, angle)
	if b then
		assert(a)
		if angle==0 or angle==180 then
			-- symmetrical
		elseif angle==90 or angle==270 then
			a,b = b,a
		else
			error("unsupported rotation angle")
		end
	end
	return a,b
end

function _M.rotate_aperture(aperture, angle, macros)
	angle = angle % 360
	local copy = {
		name = aperture.name,
		unit = aperture.unit,
		shape = aperture.shape,
		macro = nil,
		parameters = nil,
	}
	-- copy parameters
	if aperture.parameters then
		copy.parameters = {}
		for k,v in pairs(aperture.parameters) do
			copy.parameters[k] = v
		end
	end
	-- adjust parameters
	assert(not (aperture.shape and aperture.macro), "aperture has a shape and a macro")
	if aperture.macro then
		copy.macro = macros[aperture.macro]
		if not copy.macro then
			copy.macro = _M.rotate_macro(aperture.macro, angle)
			macros[aperture.macro] = copy.macro
		end
	elseif aperture.shape=='circle' then
		copy.parameters[2],copy.parameters[3] = rotate_aperture_hole(copy.parameters[2], copy.parameters[3], angle)
	elseif aperture.shape=='rectangle' or aperture.shape=='obround' then
		assert(#copy.parameters >= 2)
		copy.parameters[1],copy.parameters[2] = rotate_aperture_hole(copy.parameters[1], copy.parameters[2], angle)
		copy.parameters[3],copy.parameters[4] = rotate_aperture_hole(copy.parameters[3], copy.parameters[4], angle)
	elseif aperture.shape=='polygon' then
		local shape_angle = copy.parameters[3] or 0
		shape_angle = (shape_angle + angle) % 360
		if #copy.parameters<=3 and shape_angle==0 then
			copy.parameters[3] = nil
		else
			copy.parameters[3] = shape_angle
		end
		copy.parameters[4],copy.parameters[5] = rotate_aperture_hole(copy.parameters[4], copy.parameters[5], angle)
	elseif aperture.device then
		-- parts rotation is in the layer data
		copy.device = true
	else
		error("unsupported aperture shape")
	end
	return copy
end

local function rotate_xy(px, py, angle)
	local a = math.rad(angle)
	local c,s = math.cos(a),math.sin(a)
	x = px*c - py*s
	y = px*s + py*c
	return x,y
end

if _NAME=='test' then
	require 'test'
	local function round(x, digits) return math.floor(x * 10^digits + 0.5) / 10^digits end
	expect( 1, round(select(1, rotate_xy(1, 0, 0)), 12))
	expect( 0, round(select(2, rotate_xy(1, 0, 0)), 12))
	expect( 0, round(select(1, rotate_xy(1, 0, 90)), 12))
	expect( 1, round(select(2, rotate_xy(1, 0, 90)), 12))
	expect(-1, round(select(1, rotate_xy(1, 0, 180)), 12))
	expect( 0, round(select(2, rotate_xy(1, 0, 180)), 12))
	expect( 0, round(select(1, rotate_xy(1, 0, 270)), 12))
	expect(-1, round(select(2, rotate_xy(1, 0, 270)), 12))
	expect( 0, round(select(1, rotate_xy(0, 1, 0)), 12))
	expect( 1, round(select(2, rotate_xy(0, 1, 0)), 12))
	expect(-1, round(select(1, rotate_xy(0, 1, 90)), 12))
	expect( 0, round(select(2, rotate_xy(0, 1, 90)), 12))
	expect( 0, round(select(1, rotate_xy(0, 1, 180)), 12))
	expect(-1, round(select(2, rotate_xy(0, 1, 180)), 12))
	expect( 1, round(select(1, rotate_xy(0, 1, 270)), 12))
	expect( 0, round(select(2, rotate_xy(0, 1, 270)), 12))
end

function _M.rotate_point(point, angle)
	angle = angle % 360
	local copy = {}
	for k,v in pairs(point) do
		copy[k] = v
	end
	-- fix x,y
	local x,y
	if angle==0 then
		x,y = point.x,point.y
	elseif angle==90 then
		local px,py = point.x,point.y
		if px then y = px end
		if py then x = -py end
	elseif angle==180 then
		local px,py = point.x,point.y
		if px then x = -px end
		if py then y = -py end
	elseif angle==270 then
		local px,py = point.x,point.y
		if px then y = -px end
		if py then x = py end
	else
		assert(point.x and point.y, "only points with x and y can be rotated an arbitrary angle")
		x,y = rotate_xy(point.x, point.y, angle)
	end
	copy.x,copy.y = x,y
	-- fix i,j
	local i,j
	if point.i or point.j then
		if angle==0 then
			i,j = point.i,point.j
		elseif angle==90 or angle==270 then
			assert(point.quadrant)
			if point.quadrant=='single' then
				assert((point.i or 0) >= 0)
				assert((point.j or 0) >= 0)
				i,j = point.j,point.i
			elseif point.quadrant=='multi' then
				if angle==90 then
					local pi,pj = point.i,point.j
					if pi then j = pi end
					if pj then i = -pj end
				else
					local pi,pj = point.i,point.j
					if pi then j = -pi end
					if pj then i = pj end
				end
			else
				error("unsupported quadrant mode")
			end
		elseif angle==180 then
			assert(point.quadrant)
			if point.quadrant=='single' then
				assert((point.i or 0) >= 0)
				assert((point.j or 0) >= 0)
				i,j = point.i,point.j
			elseif point.quadrant=='multi' then
				if point.i then i = -point.i end
				if point.j then j = -point.j end
			else
				error("unsupported quadrant mode")
			end
		else
			assert(point.quadrant)
			if point.quadrant=='single' then
				error("arcs in single quadrant mode cannot be rotated an arbitrary angle")
			elseif point.quadrant=='multi' then
				assert(point.i and point.j, "only arcs with i and j can be rotated an arbitrary angle")
				i,j = rotate_xy(point.i, point.j, angle)
			else
				error("unsupported quadrant mode")
			end
		end
	end
	copy.i,copy.j = i,j
	-- fix angle
	if copy.angle then copy.angle = (copy.angle + angle) % 360 end
	return copy
end

function _M.rotate_path(path, angle, apertures, macros)
	if not apertures then apertures = {} end
	if not macros then macros = {} end
	local copy = {
		unit = path.unit,
	}
	assert(path.extents)
	copy.extents = _M.rotate_extents(path.extents, angle)
	assert(path.center_extents)
	copy.center_extents = _M.rotate_extents(path.center_extents, angle)
	if path.aperture then
		copy.aperture = apertures[path.aperture]
		if not copy.aperture then
			copy.aperture = _M.rotate_aperture(path.aperture, angle, macros)
			apertures[path.aperture] = copy.aperture
		end
	end
	for i,point in ipairs(path) do
		copy[i] = _M.rotate_point(point, angle)
	end
	return copy
end

function _M.rotate_layer(layer, angle, apertures, macros)
	if not apertures then apertures = {} end
	if not macros then macros = {} end
	local copy = {
		polarity = layer.polarity,
	}
	for i,path in ipairs(layer) do
		copy[i] = _M.rotate_path(path, angle, apertures, macros)
	end
	return copy
end

function _M.rotate_image(image, angle, apertures, macros)
	if not apertures then apertures = {} end
	if not macros then macros = {} end
	local copy = {
		file_path = image.file_path,
		name = image.name,
		format = {},
		unit = image.unit,
		layers = {},
	}
	
	-- copy format
	for k,v in pairs(image.format) do
		copy.format[k] = v
	end
	
	-- rotate extents
	copy.extents = _M.rotate_extents(image.extents, angle)
	copy.center_extents = _M.rotate_extents(image.center_extents, angle)
	
	-- rotate layers
	for i,layer in ipairs(image.layers) do
		copy.layers[i] = _M.rotate_layer(layer, angle, apertures, macros)
	end
	
	return copy
end

function _M.rotate_outline_path(path, angle)
	local copy = {
		unit = path.unit,
	}
	assert(path.extents)
	copy.extents = _M.rotate_extents(path.extents, angle)
	assert(path.center_extents)
	copy.center_extents = _M.rotate_extents(path.center_extents, angle)
	assert(not path.aperture)
	-- rotate points
	local rpath = {}
	for i=1,#path-1 do
		assert(i==1 or path[i].interpolation=='linear')
		table.insert(rpath, _M.rotate_point(path[i], angle))
	end
	-- find bottom-left point
	local min = 1
	for i=2,#rpath do
		if rpath[i].y < rpath[min].y or rpath[i].y == rpath[min].y and rpath[i].x < rpath[min].x then
			min = i
		end
	end
	-- re-order rotated points
	assert(rpath[#rpath].interpolation=='linear')
	for i=min,#path-1 do
		table.insert(copy, _M.copy_point(rpath[i]))
	end
	for i=1,min do
		table.insert(copy, _M.copy_point(rpath[i]))
	end
	for i=2,#copy-1 do
		assert(copy[i].y > copy[1].y or copy[i].y == copy[1].y and copy[i].x > copy[1].x)
	end
	copy[1].interpolation = nil
	copy[#copy-min+1].interpolation = 'linear'
	return copy
end

function _M.rotate_outline(outline, angle, apertures, macros)
	if not apertures then apertures = {} end
	if not macros then macros = {} end
	local copy = {
		apertures = {},
	}
	
	-- rotate extents
	copy.extents = _M.rotate_extents(outline.extents, angle)
	
	-- rotate path (which should be a region)
	assert(not outline.path.aperture)
	copy.path = _M.rotate_outline_path(outline.path, angle)
	
	-- rotate apertures
	for type,aperture in pairs(outline.apertures) do
		copy.apertures[type] = apertures[aperture]
		if not copy.apertures[type] then
			copy.apertures[type] = _M.rotate_aperture(aperture, angle, macros)
			apertures[aperture] = copy.apertures[type]
		end
	end
	
	return copy
end

function _M.rotate_board(board, angle)
	local copy = {
		unit = board.unit,
		template = board.template,
		extensions = {},
		formats = {},
		images = {},
	}
	
	-- copy extensions
	for type,extension in pairs(board.extensions) do
		copy.extensions[type] = extension
	end
	
	-- copy formats
	for type,format in pairs(board.formats) do
		copy.formats[type] = format
	end
	
	-- rotate extents
	copy.extents = _M.rotate_extents(board.extents, angle)
	
	-- apertures and macros are shared by layers and paths, so create an index to avoid duplicating them in the copy
	-- do it at the board level in case some apertures are shared between images and the outline or other images
	local apertures = {}
	local macros = {}
	
	-- rotate images
	for type,image in pairs(board.images) do
		copy.images[type] = _M.rotate_image(image, angle, apertures, macros)
	end
	
	-- rotate outline
	if board.outline then
		copy.outline = _M.rotate_outline(board.outline, angle, apertures, macros)
	end
	
	return copy
end

------------------------------------------------------------------------------

function _M.scale_extents(extents, scale)
	local copy = {}
	copy.left = extents.left * scale
	copy.right = extents.right * scale
	copy.bottom = extents.bottom * scale
	copy.top = extents.top * scale
	return region(copy)
end

function _M.scale_macro(macro, s)
	local copy = {
		name = macro.name,
		unit = macro.unit,
		script = macro.script,
		chunk = macro.chunk,
	}
	error("macro scaling not yet implemented")
	return copy
end

local function scale_aperture_hole(a, b, scale)
	a = a * scale
	if b then
		b = b * scale
	end
	return a,b
end

function _M.scale_aperture(aperture, scale, macros)
	local copy = {
		name = aperture.name,
		unit = aperture.unit,
		shape = aperture.shape,
		macro = nil,
		parameters = nil,
	}
	-- copy parameters
	if aperture.parameters then
		copy.parameters = {}
		for k,v in pairs(aperture.parameters) do
			copy.parameters[k] = v
		end
	end
	-- adjust parameters
	assert(not (aperture.shape and aperture.macro), "aperture has a shape and a macro")
	if aperture.macro then
		copy.macro = macros[aperture.macro]
		if not copy.macro then
			copy.macro = _M.scale_macro(aperture.macro, scale)
			macros[aperture.macro] = copy.macro
		end
	elseif aperture.shape=='circle' then
		copy.parameters[1] = copy.parameters[1] * scale
		copy.parameters[2],copy.parameters[3] = scale_aperture_hole(copy.parameters[2], copy.parameters[3], scale)
	elseif aperture.shape=='rectangle' or aperture.shape=='obround' then
		assert(#copy.parameters >= 2)
		copy.parameters[1],copy.parameters[2] = scale_aperture_hole(copy.parameters[1], copy.parameters[2], scale)
		copy.parameters[3],copy.parameters[4] = scale_aperture_hole(copy.parameters[3], copy.parameters[4], scale)
	elseif aperture.shape=='polygon' then
		copy.parameters[1] = copy.parameters[1] * scale
		copy.parameters[4],copy.parameters[5] = scale_aperture_hole(copy.parameters[4], copy.parameters[5], scale)
	elseif aperture.device then
		-- parts rotation is in the layer data
		copy.device = true
	else
		error("unsupported aperture shape")
	end
	return copy
end

function _M.scale_point(point, scale)
	local copy = {}
	for k,v in pairs(point) do
		copy[k] = v
	end
	-- fix x,y
	copy.x = point.x * scale
	copy.y = point.y * scale
	-- fix i,j
	local i,j
	if point.i or point.j then
		i = point.i * scale
		j = point.j * scale
	end
	copy.i,copy.j = i,j
	return copy
end

function _M.scale_path(path, scale, apertures, macros)
	if not apertures then apertures = {} end
	if not macros then macros = {} end
	local copy = {
		unit = path.unit,
	}
	assert(path.extents)
	copy.extents = _M.scale_extents(path.extents, scale)
	assert(path.center_extents)
	copy.center_extents = _M.scale_extents(path.center_extents, scale)
	if path.aperture then
		copy.aperture = apertures[path.aperture]
		if not copy.aperture then
			copy.aperture = _M.scale_aperture(path.aperture, scale, macros)
			apertures[path.aperture] = copy.aperture
		end
	end
	for i,point in ipairs(path) do
		copy[i] = _M.scale_point(point, scale)
	end
	return copy
end

function _M.scale_layer(layer, scale, apertures, macros)
	if not apertures then apertures = {} end
	if not macros then macros = {} end
	local copy = {
		polarity = layer.polarity,
	}
	for i,path in ipairs(layer) do
		copy[i] = _M.scale_path(path, scale, apertures, macros)
	end
	return copy
end

function _M.scale_image(image, scale, apertures, macros)
	if not apertures then apertures = {} end
	if not macros then macros = {} end
	local copy = {
		file_path = image.file_path,
		name = image.name,
		format = {},
		unit = image.unit,
		layers = {},
	}
	
	-- copy format
	for k,v in pairs(image.format) do
		copy.format[k] = v
	end
	
	-- scale extents
	copy.extents = _M.scale_extents(image.extents, scale)
	copy.center_extents = _M.scale_extents(image.center_extents, scale)
	
	-- scale layers
	for i,layer in ipairs(image.layers) do
		copy.layers[i] = _M.scale_layer(layer, scale, apertures, macros)
	end
	
	return copy
end

function _M.scale_outline(outline, scale, apertures, macros)
	if not apertures then apertures = {} end
	if not macros then macros = {} end
	local copy = {
		apertures = {},
	}
	
	-- scale extents
	copy.extents = _M.scale_extents(outline.extents, scale)
	
	-- scale path (which should be a region)
	assert(not outline.path.aperture)
	copy.path = _M.scale_path(outline.path, scale)
	
	-- scale apertures
	for type,aperture in pairs(outline.apertures) do
		copy.apertures[type] = apertures[aperture]
		if not copy.apertures[type] then
			copy.apertures[type] = _M.scale_aperture(aperture, scale, macros)
			apertures[aperture] = copy.apertures[type]
		end
	end
	
	return copy
end

function _M.scale_board(board, scale)
	local copy = {
		unit = board.unit,
		template = board.template,
		extensions = {},
		formats = {},
		images = {},
	}
	
	-- copy extensions
	for type,extension in pairs(board.extensions) do
		copy.extensions[type] = extension
	end
	
	-- copy formats
	for type,format in pairs(board.formats) do
		copy.formats[type] = format
	end
	
	-- scale extents
	copy.extents = _M.scale_extents(board.extents, scale)
	
	-- apertures and macros are shared by layers and paths, so create an index to avoid duplicating them in the copy
	-- do it at the board level in case some apertures are shared between images and the outline or other images
	local apertures = {}
	local macros = {}
	
	-- scale images
	for type,image in pairs(board.images) do
		copy.images[type] = _M.scale_image(image, scale, apertures, macros)
	end
	
	-- scale outline
	if board.outline then
		copy.outline = _M.scale_outline(board.outline, scale, apertures, macros)
	end
	
	return copy
end

------------------------------------------------------------------------------

function _M.copy_point(point)
	return _M.rotate_point(point, 0)
end

function _M.copy_path(path, apertures, macros)
	return _M.rotate_path(path, 0, apertures, macros)
end

function _M.copy_layer(layer, apertures, macros)
	return _M.rotate_layer(layer, 0, apertures, macros)
end

function _M.copy_image(image, apertures, macros)
	return _M.rotate_image(image, 0, apertures, macros)
end

function _M.copy_board(board)
	return _M.rotate_board(board, 0)
end

------------------------------------------------------------------------------

function _M.merge_layers(layer_a, layer_b, apertures, macros)
	assert(layer_a.polarity == layer_b.polarity, "layer polarity mismatch ("..tostring(layer_a.polarity).." vs. "..tostring(layer_b.polarity)..")")
	if not apertures then apertures = {} end
	if not macros then macros = {} end
	local merged = {
		polarity = layer_a.polarity,
	}
	for i,path in ipairs(layer_a) do
		table.insert(merged, _M.copy_path(path, apertures, macros))
	end
	for i,path in ipairs(layer_b) do
		table.insert(merged, _M.copy_path(path, apertures, macros))
	end
	return merged
end

function _M.merge_images(image_a, image_b, apertures, macros)
	assert(image_a.unit == image_b.unit, "image unit mismatch ("..tostring(image_a.unit).." vs. "..tostring(image_b.unit)..")")
	if not apertures then apertures = {} end
	if not macros then macros = {} end
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
			merged.layers[i] = _M.merge_layers(layer_a, layer_b, apertures, macros)
		else
			merged.layers[i] = _M.copy_layer(layer_a, apertures, macros)
		end
	end
	for i=#image_a.layers+1,#image_b.layers do
		merged.layers[i] = _M.copy_layer(image_b.layers[i], apertures, macros)
	end
	
	return merged
end

function _M.merge_boards(board_a, board_b)
	assert(board_a.unit == board_b.unit, "board unit mismatch")
	assert(board_a.template == board_b.template, "board template mismatch ("..tostring(board_a.template).." vs. "..tostring(board_b.template)..")")
	local merged = {
		unit = board_a.unit,
		template = board_a.template,
		extensions = {},
		formats = {},
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
	
	-- merge formats
	for type,format in pairs(board_a.formats) do
		merged.formats[type] = format
	end
	for type,format in pairs(board_b.formats) do
		-- prefer formats from A in case of conflict
		if not merged.formats[type] then
			merged.formats[type] = format
		end
	end
	
	-- merge extents
	merged.extents = board_a.extents + board_b.extents
	
	-- merge images
	local apertures = {}
	local macros = {}
	for type,image_a in pairs(board_a.images) do
		local image_b = board_b.images[type]
		if image_b then
			merged.images[type] = _M.merge_images(image_a, image_b, apertures, macros)
		else
			merged.images[type] = _M.copy_image(image_a, apertures, macros)
		end
	end
	for type,image_b in pairs(board_b.images) do
		local image_a = board_a.images[type]
		if not image_a then
			merged.images[type] = _M.copy_image(image_b, apertures, macros)
		end
	end
	
	-- drop outlines, it's impossible to merge without multi-contour outlines
	-- instead assume a panelization upper layer will regenerate it
	
	return merged
end

------------------------------------------------------------------------------

return _M
