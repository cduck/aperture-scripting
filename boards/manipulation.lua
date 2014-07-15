local _M = {}
local _NAME = ... or 'test'

local table = require 'table'
local region = require 'boards.region'

------------------------------------------------------------------------------

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

local function rotate_xy(px, py, angle)
	if angle==0 then
		return px,py
	elseif angle==90 then
		return -py,px
	elseif angle==180 then
		return -px,-py
	elseif angle==270 then
		return py,-px
	else
		local a = math.rad(angle)
		local c,s = math.cos(a),math.sin(a)
		x = px*c - py*s
		y = px*s + py*c
		return x,y
	end
end

if _NAME=='test' then
	require 'test'
	local function round(x, digits) return math.floor(x * 10^digits + 0.5) / 10^digits end
	expect( 1, select(1, rotate_xy(1, 0, 0)))
	expect( 0, select(2, rotate_xy(1, 0, 0)))
	expect( 0, select(1, rotate_xy(1, 0, 90)))
	expect( 1, select(2, rotate_xy(1, 0, 90)))
	expect(-1, select(1, rotate_xy(1, 0, 180)))
	expect( 0, select(2, rotate_xy(1, 0, 180)))
	expect( 0, select(1, rotate_xy(1, 0, 270)))
	expect(-1, select(2, rotate_xy(1, 0, 270)))
	expect( 0, select(1, rotate_xy(0, 1, 0)))
	expect( 1, select(2, rotate_xy(0, 1, 0)))
	expect(-1, select(1, rotate_xy(0, 1, 90)))
	expect( 0, select(2, rotate_xy(0, 1, 90)))
	expect( 0, select(1, rotate_xy(0, 1, 180)))
	expect(-1, select(2, rotate_xy(0, 1, 180)))
	expect( 1, select(1, rotate_xy(0, 1, 270)))
	expect( 0, select(2, rotate_xy(0, 1, 270)))
	expect( 0.707, round(select(1, rotate_xy(1, 0, 45)), 3))
	expect( 0.707, round(select(2, rotate_xy(1, 0, 45)), 3))
end

local function rotate_xy_expressions(px, py, angle)
	if angle==0 then
		return px,py
	elseif angle==90 then
		return '0-('..py..')',px
	elseif angle==180 then
		return '0-('..px..')','0-('..py..')'
	elseif angle==270 then
		return py,'0-('..px..')'
	else
		local a = math.rad(angle)
		local c,s = math.cos(a),math.sin(a)
		x = '('..px..')x'..c..'-('..py..')x'..s
		y = '('..px..')x'..s..'+('..py..')x'..c
		return x,y
	end
end

local function rotate_xy_parameters(x, y, angle)
	if type(x)=='number' and type(y)=='number' then
		return rotate_xy(x, y, angle)
	else
		-- :TODO: pass the macro down here to generate unique variable names
		local ix,iy
		if type(x)=='string' then
			ix = {
				type = 'variable',
				name = 'TMPX',
				expression = x,
			}
			x = '$TMPX'
		end
		if type(y)=='string' then
			iy = {
				type = 'variable',
				name = 'TMPY',
				expression = y,
			}
			y = '$TMPY'
		end
		x,y = rotate_xy_expressions(x, y, angle)
		return x,y,ix,iy
	end
end

local function rotate_angle_parameter(value, angle)
	local t = type(value)
	if t=='number' then
		return (value + angle) % 360
	elseif t=='string' then
		if angle==0 then
			return value
		elseif angle < 0 then
			return value..'-'..-angle
		else
			return value..'+'..angle
		end
	else
		error("unsupported parameter type "..t)
	end
end

local macro_primitives = {}

function macro_primitives.circle(parameters, angle)
	local copy = {}
	for i,param in ipairs(parameters) do
		copy[i] = param
	end
	local ix,iy
	copy[3],copy[4],ix,iy = rotate_xy_parameters(parameters[3], parameters[4], angle)
	return copy,ix,iy
end

function macro_primitives.line(parameters, angle)
	local copy = {}
	for i,param in ipairs(parameters) do
		copy[i] = param
	end
	copy[7] = rotate_angle_parameter(parameters[7], angle)
	return copy
end
macro_primitives.rectangle_ends = macro_primitives.line

function macro_primitives.rectangle_center(parameters, angle)
	local copy = {}
	for i,param in ipairs(parameters) do
		copy[i] = param
	end
	copy[6] = rotate_angle_parameter(parameters[6], angle)
	return copy
end

function macro_primitives.rectangle_corner(parameters, angle)
	local copy = {}
	for i,param in ipairs(parameters) do
		copy[i] = param
	end
	copy[6] = rotate_angle_parameter(parameters[6], angle)
	return copy
end

function macro_primitives.outline(parameters, angle)
	local copy = {}
	for i,param in ipairs(parameters) do
		copy[i] = param
	end
	copy[#copy] = rotate_angle_parameter(parameters[#parameters], angle)
	return copy
end

function macro_primitives.polygon(parameters, angle)
	local copy = {}
	for i,param in ipairs(parameters) do
		copy[i] = param
	end
	local ix,iy
	if parameters[3]==0 and parameters[4]==0 then
		copy[6] = rotate_angle_parameter(parameters[6], angle)
	elseif (angle * parameters[2]) % 360 == 0 then
		copy[3],copy[4],ix,iy = rotate_xy_parameters(parameters[3], parameters[4], angle)
	else
		error("arbitrary rotation of non-centered polygon is not supported")
		-- :TODO: convert to an outline
	end
	return copy,ix,iy
end

function macro_primitives.moire(parameters, angle)
	local copy = {}
	for i,param in ipairs(parameters) do
		copy[i] = param
	end
	local ix,iy
	if parameters[1]==0 and parameters[2]==0 then
		copy[9] = rotate_angle_parameter(parameters[9], angle)
	elseif angle % 90 == 0 then
		copy[1],copy[2],ix,iy = rotate_xy_parameters(parameters[1], parameters[2], angle)
	else
		error("arbitrary rotation of non-centered moiré is not supported")
		-- :TODO: find some way to rotate these
	end
	return copy,ix,iy
end

function macro_primitives.thermal(parameters, angle)
	local copy = {}
	for i,param in ipairs(parameters) do
		copy[i] = param
	end
	local ix,iy
	if parameters[1]==0 and parameters[2]==0 then
		copy[6] = rotate_angle_parameter(parameters[6], angle)
	elseif angle % 90 == 0 then
		copy[1],copy[2],ix,iy = rotate_xy_parameters(parameters[1], parameters[2], angle)
	else
		error("arbitrary rotation of non-centered thermal is not supported")
		-- :TODO: find some way to rotate these
	end
	return copy,ix,iy
end

local function rotate_macro_primitive(instruction, angle)
	local shape = instruction.shape
	local copy = {
		type = instruction.type,
		shape = shape,
	}
	local rotate = assert(macro_primitives[shape], "unsupported aperture macro primitive shape "..tostring(shape))
	local ix,iy
	copy.parameters,ix,iy = rotate(instruction.parameters, angle)
	return copy,ix,iy
end

function _M.rotate_macro(macro, angle)
	local copy = {
		name = macro.name,
		unit = macro.unit,
		script = {},
	}
	for _,instruction in ipairs(macro.script) do
		if instruction.type=='comment' then
			table.insert(copy.script, {
				type = instruction.type,
				text = instruction.text,
			})
		elseif instruction.type=='variable' then
			table.insert(copy.script, {
				type = instruction.type,
				name = instruction.name,
				expression = instruction.expression,
			})
		elseif instruction.type=='primitive' then
			local primitive,ix,iy = rotate_macro_primitive(instruction, angle)
			if ix then
				table.insert(copy.script, ix)
			end
			if iy then
				table.insert(copy.script, iy)
			end
			table.insert(copy.script, primitive)
		else
			error("unsupported macro instruction type "..tostring(instruction.type))
		end
	end
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
			error("rectangle aperture holes cannot be rotated an arbitrary angle")
			-- :TODO: convert to aperture macro
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
		assert(angle % 90 == 0, aperture.shape.." aperture can only be rotated multiples of 90 degrees")
		-- :TODO: convert to a macro if angle is arbitrary
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

function _M.rotate_point(point, angle)
	angle = angle % 360
	local copy = {}
	for k,v in pairs(point) do
		copy[k] = v
	end
	-- fix x,y
	assert(point.x and point.y, "only points with x and y can be rotated")
	local x,y = rotate_xy(point.x, point.y, angle)
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

function _M.scale_macro(macro, s)
	local copy = {
		name = macro.name,
		unit = macro.unit,
		script = macro.script,
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
