local _M = {}

local math = require 'math'
local table = require 'table'
local dump = require 'dump'
_M.blocks = require 'gerber.blocks'
local macros = require 'boards.macro'
local interpolationlib = require 'boards.interpolation'

------------------------------------------------------------------------------

-- all positions in picometers (1e-12 meters)
local scales = {
	['in'] = 25400000000 / 10 ^ _M.blocks.decimal_shift,
	mm     =  1000000000 / 10 ^ _M.blocks.decimal_shift,
}
for unit,scale in pairs(scales) do
	assert(math.floor(scale)==scale)
end

------------------------------------------------------------------------------

local scales2 = {
	in_pm = 25400000000,
	mm_pm =  1000000000,
}

local function load_macro(data, unit)
	local name = data.name
	local parameters
	
	local script,variables,constants = macros.analyze_script(data.script)
	local ambiguous = false
	for variable in pairs(variables) do
		if not variable.dimension then
			ambiguous = true
			break
		end
	end
	if not ambiguous then
		for constant in pairs(constants) do
			if not constant.dimension then
				ambiguous = true
				break
			end
		end
	end
	if ambiguous then
		for constant in pairs(constants) do
			constant.value = constant.value / 10 ^ _M.blocks.decimal_shift
		end
		print("warning: typing of macro "..name.." is ambiguous")
	else
		local length_scale = assert(scales2[unit..'_pm'])
		local scale = scales[unit]
		for constant in pairs(constants) do
			local dimension = constant.dimension
			local scale = length_scale ^ (dimension.length or 0) / 10 ^ _M.blocks.decimal_shift
			constant.value = constant.value * scale
		end
		unit = 'pm'
		parameters = {}
		for variable in pairs(variables) do
			if type(variable.name)=='number' then
				parameters[variable.name] = variable.dimension
			end
		end
	end
	
	return {
		name = name,
		unit = unit,
		script = script,
		parameters = parameters,
	}
end

local function save_macro(macro, unit)
	local name = assert(macro.save_name)
	
	local script,variables,constants = macros.copy_script(macro.script)
	local ambiguous = false
	for variable in pairs(variables) do
		if not variable.dimension then
			ambiguous = true
			break
		end
	end
	if not ambiguous then
		for constant in pairs(constants) do
			if not constant.dimension then
				ambiguous = true
				break
			end
		end
	end
	if ambiguous then
		assert(unit==macro.unit, "ambiguous macro cannot be converted from "..tostring(macro.unit).." to "..tostring(unit))
		for constant in pairs(constants) do
			constant.value = constant.value * 10 ^ _M.blocks.decimal_shift
		end
		print("warning: typing of macro "..name.." is ambiguous")
	else
		local length_scale = assert(scales2[unit..'_pm'])
		local scale = scales[unit]
		for constant in pairs(constants) do
			local dimension = constant.dimension
			local scale = 10 ^ _M.blocks.decimal_shift / length_scale ^ (dimension.length or 0)
			constant.value = constant.value * scale
		end
	end
	
	script = macros.simplify_script(script)
	
	return _M.blocks.macro(name, script)
end

------------------------------------------------------------------------------

local gerber_shapes = {
	C = 'circle',
	R = 'rectangle',
	O = 'obround',
	P = 'polygon',
}
local reverse_gerber_shapes = {}
for k,v in pairs(gerber_shapes) do reverse_gerber_shapes[v] = k end

local function load_aperture(data, macros, unit)
	local dcode = data.dcode
	local gerber_shape = data.shape
	local scale = scales[unit]
	
	local shape,macro = gerber_shapes[gerber_shape]
	local aperture = {
		name = dcode,
		shape = shape,
	}
	
	if shape=='circle' then
		local d,hx,hy = table.unpack(data.parameters)
		assert(d, "circle apertures require at least 1 parameter")
		aperture.unit = 'pm'
		aperture.diameter = d * scale
		aperture.hole_width = hx and hx * scale
		aperture.hole_height = hy and hy * scale
	elseif shape=='rectangle' then
		local x,y,hx,hy = table.unpack(data.parameters)
		assert(x and y, "rectangle apertures require at least 2 parameters")
		aperture.unit = 'pm'
		aperture.width = x * scale
		aperture.height = y * scale
		aperture.hole_width = hx and hx * scale
		aperture.hole_height = hy and hy * scale
	elseif shape=='obround' then
		local x,y,hx,hy = table.unpack(data.parameters)
		assert(x and y, "obround apertures require at least 2 parameters")
		aperture.unit = 'pm'
		aperture.width = x * scale
		aperture.height = y * scale
		aperture.hole_width = hx and hx * scale
		aperture.hole_height = hy and hy * scale
	elseif shape=='polygon' then
		local d,steps,angle,hx,hy = table.unpack(data.parameters)
		assert(d and steps, "polygon apertures require at least 2 parameter")
		aperture.unit = 'pm'
		aperture.diameter = d * scale
		aperture.steps = steps / 10 ^ _M.blocks.decimal_shift
		aperture.angle = angle and angle / 10 ^ _M.blocks.decimal_shift
		aperture.hole_width = hx and hx * scale
		aperture.hole_height = hy and hy * scale
	else
		aperture.unit = unit
		aperture.macro = assert(macros[gerber_shape], "no macro with name "..tostring(gerber_shape))
		if aperture.macro.unit == unit then
			local scale = 1 / 10 ^ _M.blocks.decimal_shift
			if data.parameters then
				local parameters = {}
				for i,value in ipairs(data.parameters) do
					parameters[i] = value * scale
				end
				aperture.parameters = parameters
			end
		else
			assert(aperture.macro.parameters)
			if data.parameters then
				local parameters = {}
				local length_scale = assert(scales2[unit..'_pm'])
				for i,value in ipairs(data.parameters) do
					local dimension = aperture.macro.parameters
					local scale = length_scale ^ (dimension.length or 0) / 10 ^ _M.blocks.decimal_shift
					parameters[i] = value * scale
				end
				aperture.parameters = parameters
			end
		end
	end
	
	return aperture
end

local function save_aperture(aperture, unit)
	local name = assert(aperture.save_name)
	local gerber_shape,parameters
	assert(aperture.macro or aperture.shape, "aperture has no shape and no macro")
	if aperture.macro then
		gerber_shape = aperture.macro.name
		if aperture.parameters then
			assert(aperture.unit == unit, "can't convert aperture macro with unit '"..aperture.unit.."' to '"..unit.."'")
			local scale = 10 ^ _M.blocks.decimal_shift
			parameters = {}
			for i,value in ipairs(aperture.parameters) do
				parameters[i] = value * scale
			end
		end
	else
		assert(aperture.unit=='pm', "basic apertures must be defined in picometers")
		local shape = aperture.shape
		gerber_shape = assert(reverse_gerber_shapes[shape], "unsupported aperture shape "..tostring(shape))
		local scale = scales[unit]
		if shape=='circle' then
			assert(aperture.diameter, "circle aperture has no diameter")
			parameters = {
				aperture.diameter / scale,
				aperture.hole_width and aperture.hole_width / scale,
				aperture.hole_height and aperture.hole_height / scale,
			}
		elseif shape=='rectangle' then
			assert(aperture.width, "rectangle aperture has no width")
			assert(aperture.height, "rectangle aperture has no height")
			parameters = {
				aperture.width / scale,
				aperture.height / scale,
				aperture.hole_width and aperture.hole_width / scale,
				aperture.hole_height and aperture.hole_height / scale,
			}
		elseif shape=='obround' then
			assert(aperture.width, "obround aperture has no width")
			assert(aperture.height, "obround aperture has no height")
			parameters = {
				aperture.width / scale,
				aperture.height / scale,
				aperture.hole_width and aperture.hole_width / scale,
				aperture.hole_height and aperture.hole_height / scale,
			}
		elseif shape=='polygon' then
			assert(aperture.diameter, "polygon aperture has no diameter")
			assert(aperture.steps, "polygon aperture has no number of vertices")
			parameters = {
				aperture.diameter / scale,
				aperture.steps * 1e8,
				aperture.angle and aperture.angle * 1e8,
				aperture.hole_width and aperture.hole_width / scale,
				aperture.hole_height and aperture.hole_height / scale,
			}
		else
			error("unsupported shape "..tostring(shape))
		end
	end
	return _M.blocks.aperture(name, gerber_shape, parameters)
end

------------------------------------------------------------------------------

local ignored_parameter = {
--	AA = true, -- Aperture Assignment
--	AF = true, -- Auto Focus
--	AP = true, -- Aperture Offset
--	AR = true, -- Aperture Record
	AS = true, -- Axis Select
--	AV = true, -- Aperture Velocity
--	BD = true, -- Block Delete
--	BG = true, -- Background Mode
--	DL = true, -- Dash Line Specification
	IC = true, -- Input Code
	ID = true, -- Input Display
--	IF = true, -- Include File
--	IO = true, -- Image Offset
--	IR = true, -- Image Rotation
--	KO = true, -- KnockOut
--	LS = true, -- Load Symbol
--	MI = true, -- Mirror Image
--	NF = true, -- Sequence Number
--	NS = true, -- Sequence Number
--	OP = true, -- Option Stop
--	PD = true, -- Plotter Destination
--	PE = true, -- Perspective
--	PF = true, -- Film Type
--	PK = true, -- Park
--	PO = true, -- Pen Offset
--	RC = true, -- Rotate Symbol
--	RO = true, -- Rotate Position Data
--	SC = true, -- Single Step Mode
--	SF = true, -- Scale Factor
--	SM = true, -- Symbol Mirroring
--	SS = true, -- Symbol Scaling
--	TR = true, -- Translation
--	VL = true, -- Velocity Limit
--	WI = true, -- Window Specification
}

local layer_polarity_names = {
	D = 'dark',
	C = 'clear',
}
local layer_polarity_codes = {
	dark = 'D',
	clear = 'C',
}

local function circle_center(x0, y0, i, j, x1, y1, direction, quadrant)
	assert(direction=='clockwise' or direction=='counterclockwise')
	if quadrant=='single' then
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
			if direction == 'clockwise' then
				while ta < tb do ta = ta + 360 end
				dt = ta - tb
			else
				while tb < ta do tb = tb + 360 end
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
		assert(cx and cy, "could not find circle center in single quadrant mode")
		return cx,cy
	elseif quadrant=='multi' then
		return x0+i,y0+j
	else
		error("unsupported quadrant mode "..tostring(quadrant))
	end
end

function _M.load(file_path)
	local data,err = _M.blocks.load(file_path)
	if not data then return nil,err end
	
	-- parse the data blocks
	local layers = {}
	local layer
	local layer_name
	local image_name
	local macros = {}
	local apertures = {}
	local x,y = 0,0
	local interpolation = 'linear' -- :KLUDGE: official RS274X spec says it's undefined
	local movements = { 'stroke', 'move', 'flash' }
	local movement = nil
	local region = false
	local unit,direction,quadrant,aperture,path
	local format
	for _,block in ipairs(data) do
		local tb = block.type
		if tb=='format' then
			assert(not format)
			format = {
				integer = block.integer,
				decimal = block.decimal,
				zeroes = block.zeroes,
			}
		elseif tb=='macro' then
			-- ignore
			local name = block.name
			local macro = load_macro(block, unit)
			macros[name] = macro
		elseif tb=='aperture' then
			-- :NOTE: defining an aperture makes it current
			local name = block.dcode
			aperture = load_aperture(block, macros, unit)
			apertures[name] = aperture
		elseif tb=='parameter' then
			local tp = block.name
			if tp=='IP' then
				-- image polarity
				assert(block.value=='POS', "unsupported image polarity")
			elseif tp=='LN' then
				-- layer name
				if layer and not layer.name then
					layer.name = block.value
				else
					layer_name = block.value
				end
			elseif tp=='LP' then
				-- layer polarity
				-- terminate current path if any
				path = nil
				-- reset coordinates
				x,y = 0,0
			--	assert(block.value == 'D', "layer polarity '"..tostring(block.value).."' not yet supported")
				layer = {}
				layer.polarity = layer_polarity_names[block.value]
				layer.name = layer_name
				layer_name = nil
				table.insert(layers, layer)
			elseif tp=='MO' then
				local value = block.value:lower()
				assert(not unit or unit==value, "gerber files with mixtures of units not supported")
				assert(scales[value], "unsupported unit "..tostring(block.value))
				unit = value
			elseif tp=='IJ' then
				-- image justify
				assert(block.value == 'ALBL', "unsupported image justify "..tostring(block.value).." (Gerber IJ parameter)")
			elseif tp=='MI' then
				-- mirror image
				assert(block.value == 'A0B0', "unsupported non-trivial mirror image "..tostring(block.value).." (Gerber MI parameter)")
			elseif tp=='OF' then
				-- offset
				local a,b = block.value:match('^A([%d.]+)B([%d.]+)$')
				assert(a and b, "unsupported offset "..tostring(block.value).." (Gerber OF parameter)")
				a,b = tonumber(a),tonumber(b)
				assert(a == 0 and b == 0, "unsupported non-null offset "..tostring(block.value).." (Gerber OF parameter)")
			elseif tp=='SF' then
				-- scale factor
				local a,b = block.value:match('^A([%d.]+)B([%d.]+)$')
				assert(a and b, "unsupported scale factor "..tostring(block.value).." (Gerber SF parameter=")
				a,b = tonumber(a),tonumber(b)
				assert(a == 1 and b == 1, "unsupported non-identity scale factor "..tostring(block.value).." (Gerber SF parameter)")
			elseif tp=='IR' then
				-- image rotation
				assert(tonumber(block.value) == 0, "unsupported non-identity image rotation "..tostring(block.value).." (Gerber IR parameter)")
			elseif tp=='SR' then
				-- step & repeat
				assert(block.value == 'X1Y1I0J0', "unsupported non-trivial step & repeat "..tostring(block.value).." (Gerber SR parameter)")
			elseif tp=='IN' then
				-- image name
				image_name = block.value
			elseif ignored_parameter[tp] then
				print("ignored Gerber parameter "..tp.." with value "..tostring(block.value))
			else
				error("unsupported parameter "..tp.." with value "..tostring(block.value))
			end
		elseif tb=='directive' then
			if block.D and block.D >= 10 then
				assert(not block.X and not block.Y and not block.I and not block.J and (not block.G or block.G==54) and not block.M)
				-- terminate current path if any
				path = nil
				-- select new aperture
				aperture = assert(apertures[block.D], "aperture "..tostring(block.D).." is used before being defined")
			elseif block.D or block.X or block.Y then
				local scale = assert(scales[unit], "unsupported directive unit "..tostring(unit))
				if block.G then
					if block.G==1 then
						interpolation = 'linear'
						direction = nil
					elseif block.G==2 then
						interpolation = 'circular'
						direction = 'clockwise'
					elseif block.G==3 then
						interpolation = 'circular'
						direction = 'counterclockwise'
					elseif block.G==55 then
						assert(block.D==3, "G55 precedes a D-code different than D03")
					else
						error("unsupported block with both G and D codes")
					end
				end
				if block.D then
					movement = movements[block.D]
				end
				if movement == 'stroke' then
					-- stroke
					-- start a path if necessary
					if not path then
						assert(region or aperture, "no aperture selected while stroking")
						path = {aperture=not region and aperture or nil, {x=x, y=y}}
						if not layer then
							layer = { polarity = 'dark' }
							table.insert(layers, layer)
						end
						table.insert(layer, path)
					end
					if block.X then
						x = block.X * scale
					end
					if block.Y then
						y = block.Y * scale
					end
					if interpolation=='linear' then
						table.insert(path, {x=x, y=y, interpolation=interpolation})
					elseif interpolation=='circular' then
						assert(quadrant, "circular interpolation before a quadrant mode is specified")
						local i = (block.I or 0) * scale
						local j = (block.J or 0) * scale
						local x0 = path[#path].x
						local y0 = path[#path].y
						local cx,cy = circle_center(x0, y0, i, j, x, y, direction, quadrant)
						table.insert(path, {x=x, y=y, cx=cx, cy=cy, interpolation=interpolation, direction=direction, quadrant=quadrant})
					elseif interpolation then
						error("unsupported interpolation mode "..interpolation)
					else
						error("no interpolation selected while stroking")
					end
				elseif movement == 'move' then
					-- move
					-- terminate current path if any
					path = nil
					if block.X then
						x = block.X * scale
					end
					if block.Y then
						y = block.Y * scale
					end
				elseif movement == 'flash' then
					-- flash
					assert(aperture, "no aperture selected while flashing")
					if block.X then
						x = block.X * scale
					end
					if block.Y then
						y = block.Y * scale
					end
					if not layer then
						layer = { polarity = 'dark' }
						table.insert(layers, layer)
					end
					table.insert(layer, {aperture=aperture, {x=x, y=y}})
				elseif block.D then
					error("unsupported drawing block D"..block.D)
				else
					error("no D block and no previous movement defined")
				end
			elseif block.G==1 then
				interpolation = 'linear'
				direction = nil
			elseif block.G==2 then
				interpolation = 'circular'
				direction = 'clockwise'
			elseif block.G==3 then
				interpolation = 'circular'
				direction = 'counterclockwise'
			elseif block.G==70 then
				assert(not unit or unit=='in', "gerber files with mixtures of units not supported")
				unit = 'in'
			elseif block.G==71 then
				assert(not unit or unit=='mm', "gerber files with mixtures of units not supported")
				unit = 'mm'
			elseif block.G==74 then
				quadrant = 'single'
			elseif block.G==75 then
				quadrant = 'multi'
			elseif block.G==36 then
				region = true
			elseif block.G==37 then
				region = false
				-- terminate current path if any
				path = nil
			elseif block.M==0 then
				-- program stop, deprecated, ignore
			elseif block.M==1 then
				-- optional stop, deprecated, ignore
			elseif block.M==2 then
				-- end of program, ignore
			elseif block.G==4 then
				-- comment, ignore
			elseif block.G==90 then
				-- set coordinates to absolute notation
				-- ignore
			elseif block.G==91 then
				-- set coordinates to incremental notation
				error("incremental notation for coordinates is not supported")
			elseif next(block)=='type' and next(block, 'type')==nil then
				-- empty block, ignore
			else
				error("unsupported directive ("..tostring(block)..")")
			end
		else
			error("unsupported block type "..tostring(block.type))
		end
	end
	
	local image = {
		file_path = file_path,
		name = image_name,
		format = format,
		unit = unit,
		layers = layers,
	}
	
	return image
end

local function compute_G(interpolation, direction)
	if interpolation=='linear' then
		return 1
	elseif interpolation=='circular' and direction=='clockwise' then
		return 2
	elseif interpolation=='circular' and direction=='counterclockwise' then
		return 3
	else
		error("unsupported interpolation")
	end
end

function _M.save(image, file_path, verbose)
	-- default to compact output, which makes use of the current state
	
	-- list apertures
	local apertures = {}
	local aperture_order = {}
	for _,layer in ipairs(image.layers) do
		for _,path in ipairs(layer) do
			local aperture = path.aperture
			if aperture and not apertures[aperture] then
				apertures[aperture] = true
				table.insert(aperture_order, aperture)
			end
		end
	end
	
	-- list macros
	local macros = {}
	local macro_order = {}
	for _,aperture in ipairs(aperture_order) do
		local macro = aperture.macro
		if macro and not macros[macro] then
			macros[macro] = true
			table.insert(macro_order, macro)
		end
	end
	
	-- make macro names unique
	local macro_names = {}
	for _,macro in ipairs(macro_order) do
		local base,i = macro.name,1
		local name = base
		while macro_names[name] do
			i = i + 1
			name = base..'_'..i
		end
		macro_names[name] = macro
		macro.save_name = name
	end
	
	-- generate unique aperture names
	local aperture_names = {}
	local aperture_conflicts = {}
	for i,aperture in ipairs(aperture_order) do
		local name = aperture.name
		if not name or aperture_names[name] then
			table.insert(aperture_conflicts, aperture)
		else
			aperture_names[name] = aperture
			aperture.save_name = name
		end
	end
	for _,aperture in ipairs(aperture_conflicts) do
		for name=10,2^31 do
			if not aperture_names[name] then
				aperture_names[name] = aperture
				aperture.save_name = name
				break
			end
		end
		assert(aperture.save_name, "could not assign a unique name to aperture")
	end
	
	-- assemble a block array
	local data = {}
	
	local image_name = image.name
	local x,y = 0,0
	local layer_name
	local quadrants = { single=74, multi=75 }
	local region = false
	local interpolation,direction,quadrant,aperture,path
	local unit = assert(image.unit, "image has no unit")
	assert(scales[unit], "unsupported image unit "..tostring(unit))
	local epsilon = 1e7 -- default to 0.01mm for bezier to arcs
	
	if image_name then
		table.insert(data, _M.blocks.parameter('IN', image_name))
	end
--	table.insert(data, _M.blocks.directive{G=75})
--	table.insert(data, _M.blocks.directive{G=70})
	assert(image.format.zeroes and image.format.integer and image.format.decimal)
	table.insert(data, _M.blocks.format(image.format.zeroes, image.format.integer, image.format.decimal))
	table.insert(data, _M.blocks.parameter('MO', unit:upper()))
	
	for _,macro in ipairs(macro_order) do
		table.insert(data, save_macro(macro, unit))
	end
	for _,aperture in ipairs(aperture_order) do
		table.insert(data, save_aperture(aperture, unit))
	end
	
	for _,layer in ipairs(image.layers) do
		assert(layer.polarity, "layer has no polarity")
		table.insert(data, _M.blocks.parameter('LP', layer_polarity_codes[layer.polarity]))
		if layer.name then
			table.insert(data, _M.blocks.parameter('LN', layer.name))
		end
		for _,path in ipairs(layer) do
			path = interpolationlib.interpolate_path(path, epsilon, {linear=true, circular=true})
			if path.aperture then
				if path.aperture ~= aperture then
					aperture = path.aperture
					table.insert(data, _M.blocks.directive{D=aperture.save_name})
				end
			else
				-- start region
				table.insert(data, _M.blocks.directive{G=36})
			end
			local scale = scales[unit]
			if #path == 1 then
				local flash = path[1]
				local px,py = flash.x / scale,flash.y / scale
				table.insert(data, _M.blocks.directive({
					D = 3,
					X = (verbose or px ~= x) and px or nil,
					Y = (verbose or py ~= y) and py or nil,
				}, image.format))
				x,y = px,py
			else
				assert(#path >= 2)
				for i,point in ipairs(path) do
					if point.quadrant and point.quadrant ~= quadrant then
						quadrant = point.quadrant
						table.insert(data, _M.blocks.directive{G=quadrants[quadrant]})
					end
					local D = i == 1 and 2 or 1
					local interpolation_changed = false
					if D==1 then
						assert(point.interpolation)
						if point.interpolation ~= interpolation or point.direction ~= direction then
							interpolation = point.interpolation
							direction = point.direction
							interpolation_changed = true
						end
					end
					local G
					if verbose then
						-- in verbose mode specify G for each stroke command
						if D == 1 then
							G = compute_G(interpolation, direction)
						end
					else
						-- in compact mode specifies interpolation on its own when it changes
						if interpolation_changed then
							table.insert(data, _M.blocks.directive{G=compute_G(interpolation, direction)})
						end
					end
					local px,py = point.x / scale,point.y / scale
					if D ~= 2 or x ~= px or y ~= py then -- don't move to the current pos
						local I,J
						if point.interpolation=='circular' then
							local cx = point.cx / scale
							local cy = point.cy / scale
							if verbose or cx ~= x then
								I = cx - x
								if point.quadrant=='single' then I = math.abs(I) end
							end
							if verbose or cy ~= y then
								J = cy - y
								if point.quadrant=='single' then J = math.abs(J) end
							end
						end
						table.insert(data, _M.blocks.directive({
							G = G,
							D = D,
							X = (verbose or px ~= x) and px or nil,
							Y = (verbose or py ~= y) and py or nil,
							I = I,
							J = J,
						}, image.format))
					end
					x,y = px,py
				end
			end
			if not path.aperture then
				-- end region
				table.insert(data, _M.blocks.directive{G=37})
			end
		end
	end
	table.insert(data, _M.blocks.eof())
	
	local success,err = _M.blocks.save(data, file_path)
	
	-- clear macro save names
	for _,macro in ipairs(macro_order) do
		macro.save_name = nil
	end
	-- clear aperture names
	for _,aperture in ipairs(aperture_order) do
		aperture.save_name = nil
	end
	
	return success,err
end

------------------------------------------------------------------------------

return _M
