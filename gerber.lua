local _M = {}

local math = require 'math'
local table = require 'table'
local dump = require 'dump'
_M.blocks = require 'gerber.blocks'

------------------------------------------------------------------------------

local scales = {
	IN = 25.4,
	MM = 1,
}

local circle_steps = 64
--local circle_steps = 360

------------------------------------------------------------------------------

local macro_primitives = {}

function macro_primitives.polygon(exposure, vertices, x, y, diameter, rotation)
	assert(exposure==1, "unexposed polygon primitives are not supported")
	assert(type(vertices)=='number')
	assert(type(x)=='number')
	assert(type(y)=='number')
	assert(type(diameter)=='number')
	assert(type(rotation)=='number')
	assert(x==0 and y==0 or rotation==0, "rotation is only allowed if the center point is on the origin")
	local r = diameter / 2
	rotation = math.rad(rotation)
	local path = {}
	for i=0,vertices do
		local a
		-- :KLUDGE: we force last vertex on the first, since sin(x) is not always equal to sin(x+2*pi)
		if i==vertices then i = 0 end
		local a = rotation + math.pi * 2 * (i / vertices)
		table.insert(path, {
			x = x + r * math.cos(a),
			y = y + r * math.sin(a),
		})
	end
	return path
end

function macro_primitives.moire(x, y, outer_diameter, ring_thickness, ring_gap, max_rings, cross_hair_thickness, cross_hair_length, rotation)
	assert(type(x)=='number')
	assert(type(y)=='number')
	assert(type(outer_diameter)=='number')
	assert(type(ring_thickness)=='number')
	assert(type(ring_gap)=='number')
	assert(type(max_rings)=='number')
	assert(type(cross_hair_length)=='number')
	assert(type(cross_hair_thickness)=='number')
	assert(type(rotation)=='number')
	assert(x==0 and y==0 or rotation==0, "rotation is only allowed if the center point is on the origin")
	print("moiré primitive not yet supported, drawing a circle instead")
	local r = outer_diameter / 2
	rotation = math.rad(rotation)
	local path = {}
	for i=0,circle_steps do
		local a
		-- :KLUDGE: we force last vertex on the first, since sin(x) is not always equal to sin(x+2*pi)
		if i==circle_steps then i = 0 end
		local a = rotation + math.pi * 2 * (i / circle_steps)
		table.insert(path, {
			x = x + r * math.cos(a),
			y = y + r * math.sin(a),
		})
	end
	return path
end

function macro_primitives.thermal(x, y, outer_diameter, inner_diameter, gap_thickness, rotation)
	assert(type(x)=='number')
	assert(type(y)=='number')
	assert(type(outer_diameter)=='number')
	assert(type(inner_diameter)=='number')
	assert(type(gap_thickness)=='number')
	assert(type(rotation)=='number')
	assert(x==0 and y==0 or rotation==0, "rotation is only allowed if the center point is on the origin")
	print("thermal primitive not yet supported, drawing a circle instead")
	local r = outer_diameter / 2
	rotation = math.rad(rotation)
	local path = {}
	for i=0,circle_steps do
		local a
		-- :KLUDGE: we force last vertex on the first, since sin(x) is not always equal to sin(x+2*pi)
		if i==circle_steps then i = 0 end
		local a = rotation + math.pi * 2 * (i / circle_steps)
		table.insert(path, {
			x = x + r * math.cos(a),
			y = y + r * math.sin(a),
		})
	end
	return path
end

function macro_primitives.outline(exposure, points, ...)
	assert(exposure==1, "unexposed polygon primitives are not supported")
	assert(type(points)=='number')
	local path = {}
	for i=0,points do
		local x,y = select(i*2+1, ...)
		assert(type(x)=='number')
		assert(type(y)=='number')
		table.insert(path, {x=x, y=y})
	end
	assert(#path >= 3)
	assert(path[1].x == path[#path].x)
	assert(path[1].y == path[#path].y)
	local rotation = select((points+1)*2+1, ...)
	assert(type(rotation)=='number')
	assert(rotation==0, "non-zero rotation of outline macro primitive is not yet supported")
	return path
end

--[[
function macro_primitives.circle(exposure, diameter, x, y)
	assert(exposure, "unexposed circle primitives are not supported")
	assert(type(diameter)=='number')
	assert(type(x)=='number')
	assert(type(y)=='number')
	return macro_primitives.polygon(exposure, circle_steps, x, y, diameter, 0)
end
--]]

local function compile_expression(expression)
	if type(expression)=='number' then
		return expression
	else
		return expression
			:gsub('%$(%d+)', function(n) return "_VARS["..n.."]" end)
			:gsub('%$(%a%w+)', function(k) return "_VARS['"..k.."']" end)
			:gsub('[xX]', '*')
	end
end
assert(compile_expression("1.08239X$1")=="1.08239*_VARS[1]")

local function load_macro(data, unit)
	local name = data.name
	local script = data.script
	assert(#script==1 and script[1].type=='primitive', "only macros with 1 primitive are supported")
	local source = "local _VARS = {...}\n"
	for _,instruction in ipairs(script) do
		if instruction.type=='comment' then
			-- ignore
		elseif instruction.type=='variable' then
			source = source.."_VARS['"..instruction.name.."'] = "..compile_expression(instruction.expression).."\n"
		elseif instruction.type=='primitive' then
			source = source..instruction.shape.."("
			for i,expression in ipairs(instruction.parameters) do
				if i > 1 then source = source..", " end
				source = source..compile_expression(expression)
			end
			source = source..")\n"
		else
			error("unsupported macro instruction type "..tostring(instruction.type))
		end
	end
--	print("========================================")
--	print(source)
--	print("========================================")
	local paths
	local env = setmetatable({}, {
		__index=function(_, k)
			return function(...)
--				print("primitive", k, ...)
				local path = assert(macro_primitives[k], "no generator function for primitive "..tostring(k))(...)
				table.insert(paths, path)
			end
		end,
		__newindex=function(_, k, v)
			error("macro script is trying to write a global")
		end,
	})
	local rawchunk
	if _VERSION == 'Lua 5.2' then
		rawchunk = assert(load(source, nil, 't', env))
	elseif _VERSION == 'Lua 5.1' then
		rawchunk = assert(loadstring(source))
		setfenv(rawchunk, env)
	end
	local chunk = function(...)
		paths = {}
		rawchunk(...)
		assert(#paths==1, "macro scripts must generate a single path")
		return paths[1]
	end
	return {
		name = name,
		unit = unit,
		script = script,
		chunk = chunk,
	}
end

local function save_macro(macro)
	local name = assert(macro.save_name)
	local script = assert(macro.script)
	assert(#script==1 and script[1].type=='primitive', "only macros with 1 primitive are supported")
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
	local parameters = data.parameters
	
	local shape,macro = gerber_shapes[gerber_shape]
	if not shape then
		macro = assert(macros[gerber_shape], "no macro with name "..tostring(gerber_shape))
		assert(macro.unit == unit, "aperture and macro units don't match")
	end
	
	return {
		name = dcode,
		unit = unit,
		shape = shape,
		macro = macro,
		parameters = parameters,
	}
end

local function save_aperture(aperture)
	local name = assert(aperture.save_name)
	local shape
	if aperture.macro then
		shape = aperture.macro.name
	else
		shape = assert(reverse_gerber_shapes[aperture.shape])
	end
	return _M.blocks.aperture(name, shape, aperture.parameters)
end

------------------------------------------------------------------------------

local function interpolate(path, point)
	local interpolation = point.interpolation
	local quadrant = point.quadrant
	if interpolation == 'linear' then
		-- no intermediates
	elseif interpolation == 'clockwise' or interpolation == 'counterclockwise' then
		local point0 = path[#path]
		local x0,y0 = point0.x, point0.y
		local cx,cy
		if quadrant == 'single' then
			local centers = {
				{ x = point0.x - point.i, y = point0.y - point.j },
				{ x = point0.x + point.i, y = point0.y - point.j },
				{ x = point0.x + point.i, y = point0.y + point.j },
				{ x = point0.x - point.i, y = point0.y + point.j },
			}
			local best = math.huge
			for _,c in ipairs(centers) do
				local dxa,dya = point0.x - c.x, point0.y - c.y
				local dxb,dyb = point.x - c.x, point.y - c.y
				local ra = math.sqrt(dxa*dxa + dya*dya)
				local rb = math.sqrt(dxb*dxb + dyb*dyb)
				local ta = math.deg(math.atan2(dya, dxa))
				local tb = math.deg(math.atan2(dyb, dxb))
				local dt
				if interpolation == 'clockwise' then
					while ta <= tb do ta = ta + 360 end
					dt = ta - tb
				else
					while tb <= ta do tb = tb + 360 end
					dt = tb - ta
				end
				if dt <= 90 then
					local ratio = math.max(ra, rb) / math.min(ra, rb)
					if ratio < best then
						best = ratio
						cx,cy = c.x,c.y
					end
				end
			end
			assert(cx and cy)
		elseif quadrant == 'multi' then
			cx,cy = point0.x + point.i, point0.y + point.j
		else
			error("unsupported quadrant mode "..tostring(quadrant))
		end
		
		local dxa,dya = point0.x - cx, point0.y - cy
		local dxb,dyb = point.x - cx, point.y - cy
		local ra = math.sqrt(dxa*dxa + dya*dya)
		local rb = math.sqrt(dxb*dxb + dyb*dyb)
		local ta = math.deg(math.atan2(dya, dxa))
		while ta < 0 do ta = ta + 360 end
		local tb = math.deg(math.atan2(dyb, dxb))
		while tb < 0 do tb = tb + 360 end
		local step,ta2,tb2 = 6
		if interpolation == 'clockwise' then
			while ta < tb do ta = ta + 360 end
			if quadrant == 'multi' and ta == tb then ta = ta + 360 end
			ta2 = (math.ceil(ta / step) - 1) * step
			tb2 = (math.floor(tb / step) + 1) * step
			step = -step
		else
			while tb <= ta do tb = tb + 360 end
			if quadrant == 'multi' and tb == ta then tb = tb + 360 end
			ta2 = (math.floor(ta / step) + 1) * step
			tb2 = (math.ceil(tb / step) - 1) * step
		end
		for t = ta2, tb2, step do
			local r = (t - ta) / (tb - ta) * (rb - ra) + ra
			local x = cx + r * math.cos(math.rad(t))
			local y = cy + r * math.sin(math.rad(t))
			table.insert(path, {x=x, y=y, interpolated=true})
			x0,y0 = x,y
		end
	else
		error("unsupported interpolation mode "..tostring(interpolation))
	end
	
	table.insert(path, point)
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
	local unit,quadrant,aperture,path
	local format
	for _,block in ipairs(data) do
		local tb = block.type
		if tb=='format' then
			assert(not format)
			format = block
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
			if tp=='OF' then
				-- :TODO: implement
			elseif tp=='IP' then
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
				layer.polarity = block.value
				layer.name = layer_name
				layer_name = nil
				table.insert(layers, layer)
			elseif tp=='MO' then
				assert(not unit or unit==block.value, "gerber files with mixtures of units not supported")
				assert(scales[block.value], "unsupported unit "..tostring(block.value))
				unit = block.value
			elseif tp=='IJ' then
				-- image justify
				assert(block.value == 'ALBL')
			elseif tp=='SR' then
				-- step & repeat
				assert(block.value == 'X1Y1I0J0')
			elseif tp=='IN' then
				-- image name
				image_name = block.value
			else
				error("unsupported parameter "..tp)
			end
		elseif tb=='directive' then
			if block.D and block.D >= 10 then
				assert(not block.X and not block.Y and not block.I and not block.J and (not block.G or block.G==54) and not block.M)
				-- terminate current path if any
				path = nil
				-- select new aperture
				aperture = assert(apertures[block.D])
			elseif block.D or block.X or block.Y then
				local scale = assert(scales[unit], "unsupported directive unit "..tostring(unit))
				if block.G then
					if block.G==1 then
						interpolation = 'linear'
					elseif block.G==2 then
						interpolation = 'clockwise'
					elseif block.G==3 then
						interpolation = 'counterclockwise'
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
						path = {aperture=not region and aperture or nil, unit=unit, {x=x, y=y}}
						if not layer then
							layer = { polarity = 'D' }
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
					elseif interpolation=='clockwise' or interpolation=='counterclockwise' then
						assert(quadrant, "circular interpolation before a quadrant mode is specified")
						local i = (block.I or 0) * scale
						local j = (block.J or 0) * scale
						interpolate(path, {x=x, y=y, i=i, j=j, interpolation=interpolation, quadrant=quadrant})
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
						layer = { polarity = 'D' }
						table.insert(layers, layer)
					end
					table.insert(layer, {aperture=aperture, unit=unit, {x=x, y=y}})
				elseif block.D then
					error("unsupported drawing block D"..block.D)
				else
					error("no D block and no previous movement defined")
				end
			elseif block.G==1 then
				interpolation = 'linear'
			elseif block.G==2 then
				interpolation = 'clockwise'
			elseif block.G==3 then
				interpolation = 'counterclockwise'
			elseif block.G==70 then
				assert(not unit or unit=='IN', "gerber files with mixtures of units not supported")
				unit = 'IN'
			elseif block.G==71 then
				assert(not unit or unit=='MM', "gerber files with mixtures of units not supported")
				unit = 'MM'
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
	local interpolations = { linear=1, clockwise=2, counterclockwise=3 }
	local quadrants = { single=74, multi=75 }
	local region = false
	local interpolation,quadrant,aperture,path
	local unit = assert(image.unit, "image has no unit")
	assert(scales[unit], "unsupported image unit")
	
	if image_name then
		table.insert(data, _M.blocks.parameter('IN', image_name))
	end
--	table.insert(data, _M.blocks.directive{G=75})
--	table.insert(data, _M.blocks.directive{G=70})
	table.insert(data, _M.blocks.format(image.format.zeroes, image.format.integer, image.format.decimal))
	table.insert(data, _M.blocks.parameter('MO', unit))
--	for _,block in pairs(image.parameters) do
--		table.insert(data, block)
--	end
--	for _,block in pairs(image.image) do
--		table.insert(data, block)
--	end
	
	for _,macro in ipairs(macro_order) do
		table.insert(data, save_macro(macro))
	end
	for _,aperture in ipairs(aperture_order) do
		table.insert(data, save_aperture(aperture))
	end
	
	for _,layer in ipairs(image.layers) do
		assert(layer.polarity, "layer has no polarity")
		table.insert(data, _M.blocks.parameter('LP', layer.polarity))
		if layer.name then
			table.insert(data, _M.blocks.parameter('LN', layer.name))
		end
		for _,path in ipairs(layer) do
			if path.aperture then
				if path.aperture ~= aperture then
					aperture = path.aperture
					table.insert(data, _M.blocks.directive{D=aperture.save_name})
				end
			else
				-- start region
				table.insert(data, _M.blocks.directive{G=36})
			end
			local scale = 1 / scales[path.unit]
			if #path == 1 then
				local flash = path[1]
				local px,py = flash.x * scale,flash.y * scale
				table.insert(data, _M.blocks.directive({
					D = 3,
					X = (verbose or px ~= x) and px or nil,
					Y = (verbose or py ~= y) and py or nil,
				}, image.format))
				x,y = px,py
			else
				assert(#path >= 2)
				for i,point in ipairs(path) do
					if not point.interpolated then
						if point.quadrant and point.quadrant ~= quadrant then
							quadrant = point.quadrant
							table.insert(data, _M.blocks.directive{G=quadrants[quadrant]})
						end
						local D = i == 1 and 2 or 1
						local interpolation_changed = false
						if D==1 and point.interpolation ~= interpolation then
							interpolation = point.interpolation
							interpolation_changed = true
						end
						local G
						if verbose then
							-- in verbose mode specify G for each stroke command
							if D == 1 then
								G = interpolations[interpolation]
							end
						else
							-- in compact mode specifies interpolation on its own when it changes
							if interpolation_changed then
								table.insert(data, _M.blocks.directive{G=interpolations[interpolation]})
							end
						end
						local px,py = point.x * scale,point.y * scale
						if D ~= 2 or x ~= px or y ~= py then -- don't move to the current pos
							table.insert(data, _M.blocks.directive({
								G = G,
								D = D,
								X = (verbose or px ~= x) and px or nil,
								Y = (verbose or py ~= y) and py or nil,
								I = point.i and (verbose or point.i ~= 0) and point.i * scale or nil,
								J = point.j and (verbose or point.j ~= 0) and point.j * scale or nil,
							}, image.format))
						end
						x,y = px,py
					end
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
