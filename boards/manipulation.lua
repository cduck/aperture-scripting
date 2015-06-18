--- This module contains many function to manipulate image data and whole boards. Most are self-explanatory. All these function create copies of the input data and won't reference it in the output, so the input can be later modified without the output to be affected.
--- 
--- The *apertures* and *macros* arguments of some of these functions are mapping tables used to preserve sharing of apertures and macros respectively. You can initialize these as empty tables and then pass them to all subsequent calls of the same category of manipulation function (ie. offset, rotate, scale, copy or merge).
local _M = {}
local _NAME = ... or 'test'

local math = require 'math'
local table = require 'table'
local region = require 'boards.region'

------------------------------------------------------------------------------

--- 
function _M.offset_point(point, dx, dy)
	assert(point.x and point.y, "only points with x and y can be offset")
	local copy = {}
	for k,v in pairs(point) do
		copy[k] = v
	end
	-- fix x,y
	copy.x = copy.x + dx
	copy.y = copy.y + dy
	-- fix optional data
	if copy.cx or copy.cy then
		copy.cx = copy.cx + dx
		copy.cy = copy.cy + dy
	end
	if copy.x1 or copy.y1 then
		copy.x1 = copy.x1 + dx
		copy.y1 = copy.y1 + dy
	end
	if copy.x2 or copy.y2 then
		copy.x2 = copy.x2 + dx
		copy.y2 = copy.y2 + dy
	end
	return copy
end

--- 
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

--- 
function _M.offset_layer(layer, dx, dy)
	local copy = {
		polarity = layer.polarity,
	}
	for i,path in ipairs(layer) do
		copy[i] = _M.offset_path(path, dx, dy)
	end
	return copy
end

--- 
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

--- 
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

--- 
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
		local x = px*c - py*s
		local y = px*s + py*c
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
		local rx --= -py
		if py.type=='constant' and py.value==0 then
			rx = py
		elseif py.type=='subtraction' and py[1].type=='constant' and py[1].value==0 then
			rx = py[2]
		else
			rx = {type='subtraction', {type='constant', value=0, dimension={length=1}}, py}
		end
		local ry = px
		return rx,ry
	elseif angle==180 then
		local rx,ry --= -px,-py
		if px.type=='constant' and px.value==0 then
			rx = px
		elseif px.type=='subtraction' and px[1].type=='constant' and px[1].value==0 then
			rx = px[2]
		else
			rx = {type='subtraction', {type='constant', value=0, dimension={length=1}}, px}
		end
		if py.type=='constant' and py.value==0 then
			ry = py
		elseif py.type=='subtraction' and py[1].type=='constant' and py[1].value==0 then
			ry = py[2]
		else
			ry = {type='subtraction', {type='constant', value=0, dimension={length=1}}, py}
		end
		return rx,ry
	elseif angle==270 then
		local rx = py
		local ry --= -px
		if px.type=='constant' and px.value==0 then
			ry = px
		elseif px.type=='subtraction' and px[1].type=='constant' and px[1].value==0 then
			ry = px[2]
		else
			ry = {type='subtraction', {type='constant', value=0, dimension={length=1}}, px}
		end
		return rx,ry
	else
		if px.type=='constant' then
			px = px.value
		elseif px.type=='subtraction' and px[1].type=='constant' and px[1].value==0 and px[2].type=='constant' then
			px = -px[2].value
		end
		if py.type=='constant' then
			py = py.value
		elseif py.type=='subtraction' and py[1].type=='constant' and py[1].value==0 and py[2].type=='constant' then
			py = -py[2].value
		end
		if px and py then
			local a = math.rad(angle)
			local c,s = math.cos(a),math.sin(a)
			local x = px * c - py * s
			local y = px * s + py * c
			if x < 0 then
				x = {type='subtraction', {type='constant', value=0, dimension={length=1}}, {type='constant', value=-x, dimension={length=1}}}
			else
				x = {type='constant', value=x, dimension={length=1}}
			end
			if y < 0 then
				y = {type='subtraction', {type='constant', value=0, dimension={length=1}}, {type='constant', value=-y, dimension={length=1}}}
			else
				y = {type='constant', value=y, dimension={length=1}}
			end
			return x,y
		else
			error("arbitrary macro rotation not yet supported")
		end
	end
end

local function rotate_xy_parameters(x, y, angle)
	return rotate_xy_expressions(x, y, angle)
end

local function rotate_angle_parameter(value, angle)
	local t = assert(type(value)=='table' and value.type)
	if t=='constant' then
		return {type='constant', value=(value.value + angle) % 360, dimension={angle=1}}
	elseif t=='variable' then
		if angle==0 then
			return value
		elseif angle < 0 then
			return {type='subtraction', value, {type='constant', value=-angle, dimension={angle=1}}}
		else
			return {type='addition', value, {type='constant', value=angle, dimension={angle=1}}}
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
	copy[3],copy[4] = rotate_xy_parameters(parameters[3], parameters[4], angle)
	return copy
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
	if parameters[3].type=='constant' and parameters[3].value==0 and parameters[4].type=='constant' and parameters[4].value==0 then
		copy[6] = rotate_angle_parameter(parameters[6], angle)
	elseif parameters[2].type=='constant' and (angle * parameters[2].value) % 360 == 0 then
		copy[3],copy[4] = rotate_xy_parameters(parameters[3], parameters[4], angle)
	else
		error("arbitrary rotation of an offset polygon primitive is not yet supported")
		-- :TODO: convert to an outline
	end
	return copy
end

function macro_primitives.moire(parameters, angle)
	local copy = {}
	for i,param in ipairs(parameters) do
		copy[i] = param
	end
	if parameters[1].type=='constant' and parameters[1].value==0 and parameters[2].type=='constant' and parameters[2].value==0 then
		copy[9] = rotate_angle_parameter(parameters[9], angle)
	elseif angle % 90 == 0 then
		copy[1],copy[2] = rotate_xy_parameters(parameters[1], parameters[2], angle)
	else
		error("arbitrary rotation of an offset moiré primitive is not yet supported")
		-- :TODO: find some way to rotate these
	end
	return copy
end

function macro_primitives.thermal(parameters, angle)
	local copy = {}
	for i,param in ipairs(parameters) do
		copy[i] = param
	end
	if parameters[1].type=='constant' and parameters[1].value==0 and parameters[2].type=='constant' and parameters[2].value==0 then
		copy[6] = rotate_angle_parameter(parameters[6], angle)
	elseif angle % 90 == 0 then
		copy[1],copy[2] = rotate_xy_parameters(parameters[1], parameters[2], angle)
	else
		error("arbitrary rotation of an offset thermal primitive is not yet supported")
		-- :TODO: find some way to rotate these
	end
	return copy
end

local function rotate_macro_primitive(instruction, angle)
	local shape = instruction.shape
	local parameters = instruction.parameters
	if shape=='polygon'
		and parameters[1].type=='constant'
		and parameters[2].type=='constant'
		and parameters[3].type=='constant'
		and parameters[4].type=='constant'
		and parameters[5].type=='constant'
		and parameters[6].type=='constant'
		and (parameters[3].value~=0 or parameters[4].value~=0)
		and (angle * parameters[2].value) % 360 ~= 0
	then
		-- convert polygon to outline
		local exposure = parameters[1]
		local vertices = parameters[2]
		local x = parameters[3].value
		local y = parameters[4].value
		local d = parameters[5].value
		local rotation = parameters[6].value
		local outline = {
			type = instruction.type,
			shape = 'outline',
			parameters = {
				exposure,
				vertices, -- outline has an extra point, but it's not counted here
			},
		}
		vertices = vertices.value
		local r = d / 2
		for i=0,vertices do
			-- :KLUDGE: we force last vertex on the first, since sin(x) is not always equal to sin(x+2*pi)
			if i==vertices then i = 0 end
			local a = math.pi * 2 * (i / vertices)
			local px = x + r * math.cos(a)
			local py = y + r * math.sin(a)
			if px < 0 then
				table.insert(outline.parameters, {type='subtraction',
					{type='constant', value=0, dimension={length=1}},
					{type='constant', value=-px, dimension={length=1}},
				})
			else
				table.insert(outline.parameters, {type='constant', value=px, dimension={length=1}})
			end
			if py < 0 then
				table.insert(outline.parameters, {type='subtraction',
					{type='constant', value=0, dimension={length=1}},
					{type='constant', value=-py, dimension={length=1}},
				})
			else
				table.insert(outline.parameters, {type='constant', value=py, dimension={length=1}})
			end
		end
		table.insert(outline.parameters, {type='constant', value=(rotation + angle) % 360, dimension={angle=1}})
		return outline
	else
		local copy = {
			type = instruction.type,
			shape = shape,
		}
		local rotate = assert(macro_primitives[shape], "unsupported aperture macro primitive shape "..tostring(shape))
		copy.parameters = rotate(parameters, angle)
		return copy
	end
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
				value = instruction.value,
			})
		elseif instruction.type=='primitive' then
			table.insert(copy.script, rotate_macro_primitive(instruction, angle))
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

--- 
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
	-- adjust parameters (and some shapes need to be converted to macros)
	assert(not (aperture.shape and aperture.macro), "aperture has a shape and a macro")
	if aperture.macro then
		copy.macro = macros[aperture.macro]
		if not copy.macro then
			copy.macro = _M.rotate_macro(aperture.macro, angle)
			macros[aperture.macro] = copy.macro
		end
	elseif aperture.shape=='circle' then
		if angle % 90 ~= 0 and aperture.hole_height then
			copy.shape = nil
			copy.macro = {
				name = 'M'..aperture.name,
				unit = aperture.unit,
				script = {},
			}
			table.insert(copy.macro.script, {
				type = 'primitive',
				shape = 'circle',
				parameters = {
					{type='constant', value=1, dimension={boolean=1}},
					{type='constant', value=aperture.diameter, dimension={length=1}},
					{type='constant', value=0, dimension={length=1}},
					{type='constant', value=0, dimension={length=1}},
				},
			})
			assert(aperture.hole_width)
			table.insert(copy.macro.script, {
				type = 'primitive',
				shape = 'rectangle_center',
				parameters = {
					{type='constant', value=0, dimension={boolean=1}},
					{type='constant', value=aperture.hole_width, dimension={length=1}},
					{type='constant', value=aperture.hole_height, dimension={length=1}},
					{type='constant', value=0, dimension={length=1}},
					{type='constant', value=0, dimension={length=1}},
					{type='constant', value=angle, dimension={angle=1}},
				},
			})
		else
			copy.diameter = aperture.diameter
			copy.hole_width,copy.hole_height = rotate_aperture_hole(aperture.hole_width, aperture.hole_height, angle)
		end
	elseif aperture.shape=='rectangle' then
		if angle % 90 ~= 0 then
			copy.shape = nil
			copy.macro = {
				name = 'M'..aperture.name,
				unit = aperture.unit,
				script = {},
			}
			table.insert(copy.macro.script, {
				type = 'primitive',
				shape = 'rectangle_center',
				parameters = {
					{type='constant', value=1, dimension={boolean=1}},
					{type='constant', value=aperture.width, dimension={length=1}},
					{type='constant', value=aperture.height, dimension={length=1}},
					{type='constant', value=0, dimension={length=1}},
					{type='constant', value=0, dimension={length=1}},
					{type='constant', value=angle, dimension={angle=1}},
				},
			})
			if aperture.hole_height then
				assert(aperture.hole_width)
				table.insert(copy.macro.script, {
					type = 'primitive',
					shape = 'rectangle_center',
					parameters = {
						{type='constant', value=0, dimension={boolean=1}},
						{type='constant', value=aperture.hole_width, dimension={length=1}},
						{type='constant', value=aperture.hole_height, dimension={length=1}},
						{type='constant', value=0, dimension={length=1}},
						{type='constant', value=0, dimension={length=1}},
						{type='constant', value=angle, dimension={angle=1}},
					},
				})
			elseif aperture.hole_width then
				table.insert(copy.macro.script, {
					type = 'primitive',
					shape = 'circle',
					parameters = {
						{type='constant', value=0, dimension={boolean=1}},
						{type='constant', value=aperture.hole_width, dimension={length=1}},
						{type='constant', value=0, dimension={length=1}},
						{type='constant', value=0, dimension={length=1}},
					},
				})
			end
		else
			copy.width,copy.height = rotate_aperture_hole(aperture.width, aperture.height, angle)
			copy.hole_width,copy.hole_height = rotate_aperture_hole(aperture.hole_width, aperture.hole_height, angle)
		end
	elseif aperture.shape=='obround' then
		if angle % 90 ~= 0 and aperture.width == aperture.height and not aperture.hole_height then
			-- special case, convert to circle
			copy.shape = 'circle'
			copy.diameter = aperture.width
			copy.hole_width = aperture.hole_width
		elseif angle % 90 ~= 0 then
			copy.shape = nil
			copy.macro = {
				name = 'M'..aperture.name,
				unit = aperture.unit,
				script = {},
			}
			if aperture.width == aperture.height then
				table.insert(copy.macro.script, {
					type = 'primitive',
					shape = 'circle',
					parameters = {
						{type='constant', value=1, dimension={boolean=1}},
						{type='constant', value=aperture.width, dimension={length=1}},
						{type='constant', value=0, dimension={length=1}},
						{type='constant', value=0, dimension={length=1}},
					},
				})
			elseif aperture.width < aperture.height then
				local flat = aperture.height - aperture.width
				table.insert(copy.macro.script, {
					type = 'primitive',
					shape = 'rectangle_center',
					parameters = {
						{type='constant', value=1, dimension={boolean=1}},
						{type='constant', value=aperture.width, dimension={length=1}},
						{type='constant', value=flat, dimension={length=1}},
						{type='constant', value=0, dimension={length=1}},
						{type='constant', value=0, dimension={length=1}},
						{type='constant', value=angle, dimension={angle=1}},
					},
				})
				local dx,dy = 0,flat / 2
				dx,dy = rotate_xy(dx, dy, angle)
				dx = {type='constant', value=-dx, dimension={length=1}}
				dy = {type='constant', value=-dy, dimension={length=1}}
				local mdx = {type='subtraction', {type='constant', value=0, dimension={length=1}}, dx}
				local mdy = {type='subtraction', {type='constant', value=0, dimension={length=1}}, dy}
				if dx.value < 0 then
					dx.value = -dx.value
					dx,mdx = mdx,dx
				end
				if dy.value < 0 then
					dy.value = -dy.value
					dy,mdy = mdy,dy
				end
				table.insert(copy.macro.script, {
					type = 'primitive',
					shape = 'circle',
					parameters = {
						{type='constant', value=1, dimension={boolean=1}},
						{type='constant', value=aperture.width, dimension={length=1}},
						mdx,
						mdy,
					},
				})
				table.insert(copy.macro.script, {
					type = 'primitive',
					shape = 'circle',
					parameters = {
						{type='constant', value=1, dimension={boolean=1}},
						{type='constant', value=aperture.width, dimension={length=1}},
						dx,
						dy,
					},
				})
			else
				local flat = aperture.width - aperture.height
				table.insert(copy.macro.script, {
					type = 'primitive',
					shape = 'rectangle_center',
					parameters = {
						{type='constant', value=1, dimension={boolean=1}},
						{type='constant', value=flat, dimension={length=1}},
						{type='constant', value=aperture.height, dimension={length=1}},
						{type='constant', value=0, dimension={length=1}},
						{type='constant', value=0, dimension={length=1}},
						{type='constant', value=angle, dimension={angle=1}},
					},
				})
				local dx,dy = flat / 2,0
				dx,dy = rotate_xy(dx, dy, angle)
				dx = {type='constant', value=-dx, dimension={length=1}}
				dy = {type='constant', value=-dy, dimension={length=1}}
				local mdx = {type='subtraction', {type='constant', value=0, dimension={length=1}}, dx}
				local mdy = {type='subtraction', {type='constant', value=0, dimension={length=1}}, dy}
				if dx.value < 0 then
					dx.value = -dx.value
					dx,mdx = mdx,dx
				end
				if dy.value < 0 then
					dy.value = -dy.value
					dy,mdy = mdy,dy
				end
				table.insert(copy.macro.script, {
					type = 'primitive',
					shape = 'circle',
					parameters = {
						{type='constant', value=1, dimension={boolean=1}},
						{type='constant', value=aperture.height, dimension={length=1}},
						mdx,
						mdy,
					},
				})
				table.insert(copy.macro.script, {
					type = 'primitive',
					shape = 'circle',
					parameters = {
						{type='constant', value=1, dimension={boolean=1}},
						{type='constant', value=aperture.height, dimension={length=1}},
						dx,
						dy,
					},
				})
			end
			if aperture.hole_height then
				assert(aperture.hole_width)
				table.insert(copy.macro.script, {
					type = 'primitive',
					shape = 'rectangle_center',
					parameters = {
						{type='constant', value=0, dimension={boolean=1}},
						{type='constant', value=aperture.hole_width, dimension={length=1}},
						{type='constant', value=aperture.hole_height, dimension={length=1}},
						{type='constant', value=0, dimension={length=1}},
						{type='constant', value=0, dimension={length=1}},
						{type='constant', value=angle, dimension={angle=1}},
					},
				})
			elseif aperture.hole_width then
				table.insert(copy.macro.script, {
					type = 'primitive',
					shape = 'circle',
					parameters = {
						{type='constant', value=0, dimension={boolean=1}},
						{type='constant', value=aperture.hole_width, dimension={length=1}},
						{type='constant', value=0, dimension={length=1}},
						{type='constant', value=0, dimension={length=1}},
					},
				})
			end
		else
			copy.width,copy.height = rotate_aperture_hole(aperture.width, aperture.height, angle)
			copy.hole_width,copy.hole_height = rotate_aperture_hole(aperture.hole_width, aperture.hole_height, angle)
		end
	elseif aperture.shape=='polygon' then
		if angle % 90 ~= 0 and aperture.hole_height then
			copy.shape = nil
			copy.macro = {
				name = 'M'..aperture.name,
				unit = aperture.unit,
				script = {},
			}
			table.insert(copy.macro.script, {
				type = 'primitive',
				shape = 'polygon',
				parameters = {
					{type='constant', value=1, dimension={boolean=1}},
					{type='constant', value=aperture.steps, dimension={}},
					{type='constant', value=0, dimension={length=1}},
					{type='constant', value=0, dimension={length=1}},
					{type='constant', value=aperture.diameter, dimension={length=1}},
					{type='constant', value=(aperture.angle or 0) + angle, dimension={angle=1}},
				},
			})
			assert(aperture.hole_width)
			table.insert(copy.macro.script, {
				type = 'primitive',
				shape = 'rectangle_center',
				parameters = {
					{type='constant', value=0, dimension={boolean=1}},
					{type='constant', value=aperture.hole_width, dimension={length=1}},
					{type='constant', value=aperture.hole_height, dimension={length=1}},
					{type='constant', value=0, dimension={length=1}},
					{type='constant', value=0, dimension={length=1}},
					{type='constant', value=angle, dimension={angle=1}},
				},
			})
		else
			copy.diameter = aperture.diameter
			copy.steps = aperture.steps
			local copy_angle = ((aperture.angle or 0) + angle) % 360
			if copy_angle==0 and not aperture.hole_width and not aperture.hole_height then
				copy.angle = nil
			else
				copy.angle = copy_angle
			end
			copy.hole_width,copy.hole_height = rotate_aperture_hole(aperture.hole_width, aperture.hole_height, angle)
		end
	elseif aperture.device then
		-- parts rotation is in the layer data
		copy.device = true
	else
		error("unsupported aperture shape")
	end
	return copy
end

--- 
function _M.rotate_point(point, angle)
	assert(point.x and point.y, "only points with x and y can be rotated")
	angle = angle % 360
	local copy = {}
	for k,v in pairs(point) do
		copy[k] = v
	end
	-- fix x,y
	copy.x,copy.y = rotate_xy(point.x, point.y, angle)
	-- fix optional data
	if point.cx or point.cy then
		copy.cx,copy.cy = rotate_xy(point.cx, point.cy, angle)
	end
	if point.x1 or point.y1 then
		copy.x1,copy.y1 = rotate_xy(point.x1, point.y1, angle)
	end
	if point.x2 or point.y2 then
		copy.x2,copy.y2 = rotate_xy(point.x2, point.y2, angle)
	end
	-- fix angle
	if copy.angle then copy.angle = (copy.angle + angle) % 360 end
	return copy
end

--- 
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

--- 
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

--- 
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
	local rpath = _M.rotate_path(path, angle)
	-- find bottom-left point
	local min = 1
	for i=2,#rpath do
		if rpath[i].y < rpath[min].y or rpath[i].y == rpath[min].y and rpath[i].x < rpath[min].x then
			min = i
		end
	end
	-- re-order rotated points
	table.insert(copy, {x=rpath[min].x, y=rpath[min].y})
	for i=min+1,#path do
		table.insert(copy, _M.copy_point(rpath[i]))
	end
	for i=2,min do
		table.insert(copy, _M.copy_point(rpath[i]))
	end
	for i=2,#copy-1 do
		assert(copy[i].y > copy[1].y or copy[i].y == copy[1].y and copy[i].x > copy[1].x)
	end
	return copy
end

--- 
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

--- 
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

--- 
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
		copy.diameter = aperture.diameter * scale
		copy.hole_width,copy.hole_height = scale_aperture_hole(aperture.hole_width, aperture.hole_height, scale)
	elseif aperture.shape=='rectangle' or aperture.shape=='obround' then
		copy.width,copy.height = scale_aperture_hole(aperture.width, aperture.height, scale)
		copy.hole_width,copy.hole_height = scale_aperture_hole(aperture.hole_width, aperture.hole_height, scale)
	elseif aperture.shape=='polygon' then
		copy.diameter = aperture.diameter * scale
		copy.steps = aperture.steps
		copy.hole_width,copy.hole_height = scale_aperture_hole(aperture.hole_width, aperture.hole_height, scale)
	elseif aperture.device then
		-- parts rotation is in the layer data
		copy.device = true
	else
		error("unsupported aperture shape")
	end
	return copy
end

--- 
function _M.scale_point(point, scale)
	assert(point.x and point.y, "only points with x and y can be scaled")
	local copy = {}
	for k,v in pairs(point) do
		copy[k] = v
	end
	-- fix x,y
	copy.x = point.x * scale
	copy.y = point.y * scale
	-- fix optional data
	if point.cx or point.cy then
		copy.cx = point.cx * scale
		copy.cy = point.cy * scale
	end
	if point.x1 or point.y1 then
		copy.x1 = point.x1 * scale
		copy.y1 = point.y1 * scale
	end
	if point.x2 or point.y2 then
		copy.x2 = point.x2 * scale
		copy.y2 = point.y2 * scale
	end
	return copy
end

--- 
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

--- 
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

--- 
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

--- 
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

--- 
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

--- 
function _M.copy_point(point)
	return _M.rotate_point(point, 0)
end

--- 
function _M.copy_path(path, apertures, macros)
	return _M.rotate_path(path, 0, apertures, macros)
end

--- 
function _M.copy_layer(layer, apertures, macros)
	return _M.rotate_layer(layer, 0, apertures, macros)
end

--- 
function _M.copy_image(image, apertures, macros)
	return _M.rotate_image(image, 0, apertures, macros)
end

--- 
function _M.copy_board(board)
	return _M.rotate_board(board, 0)
end

------------------------------------------------------------------------------

--- 
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

--- 
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

--- 
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
