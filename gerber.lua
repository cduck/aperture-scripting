local _M = {}

local math = require 'math'
local table = require 'table'
local dump = require 'dump'
_M.blocks = require 'gerber.blocks'

local function copy(v)
	local t = type(v)
	if t=='nil' or t=='number' or t=='string' then
		return v
	elseif t=='table' then
		local v2 = {}
		for k,v in pairs(v) do
			v2[copy(k)] = copy(v)
		end
		return setmetatable(v2, getmetatable(v))
	else
		error("uncopyable type "..t)
	end
end

local unpack = unpack or table.unpack

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

------------------------------------------------------------------------------

local built_in_shapes = {
	C = true,
	R = true,
	O = true,
	P = true,
}

local function load_aperture(data, macros, unit)
	local dcode = data.dcode
	local shape,macro = data.shape,nil
	local parameters = data.parameters
	local scale = assert(scales[unit], "unsupported aperture unit "..tostring(unit))
	
	if not built_in_shapes[shape] then
		macro = assert(macros[shape], "no macro with name "..tostring(shape))
		assert(macro.unit == unit, "aperture and macro units don't match")
		shape = nil
	end
	
	local path
	if shape=='C' then
		local d,hx,hy = unpack(parameters)
		assert(d, "circle apertures require at least 1 parameter")
		assert(not hx and not hy, "circle apertures with holes are not yet supported")
		path = {concave=true}
		if d ~= 0 then
			local r = d / 2 * scale
			for i=0,circle_steps do
				if i==circle_steps then i = 0 end -- :KLUDGE: sin(2*pi) is not zero, but an epsilon, so we force it
				local a = math.pi * 2 * (i / circle_steps)
				table.insert(path, {x=r*math.cos(a), y=r*math.sin(a)})
			end
		end
	elseif shape=='R' then
		local x,y,hx,hy = unpack(parameters)
		assert(x and y, "rectangle apertures require at least 2 parameters")
		assert(not hx and not hy, "rectangle apertures with holes are not yet supported")
		path = {
			concave=true,
			{x=-x/2*scale, y=-y/2*scale},
			{x= x/2*scale, y=-y/2*scale},
			{x= x/2*scale, y= y/2*scale},
			{x=-x/2*scale, y= y/2*scale},
			{x=-x/2*scale, y=-y/2*scale},
		}
	elseif shape=='O' then
		assert(circle_steps % 2 == 0, "obround apertures are only supported when circle_steps is even")
		local x,y,hx,hy = unpack(parameters)
		assert(x and y, "obround apertures require at least 2 parameters")
		assert(not hx and not hy, "obround apertures with holes are not yet supported")
		path = {concave=true}
		if y > x then
			local straight = (y - x) * scale
			local r = x / 2 * scale
			for i=0,circle_steps/2 do
				local a = math.pi * 2 * (i / circle_steps)
				table.insert(path, {x=r*math.cos(a), y=r*math.sin(a)+straight/2})
			end
			for i=circle_steps/2,circle_steps do
				if i==circle_steps then i = 0 end -- :KLUDGE: sin(2*pi) is not zero, but an epsilon, so we force it
				local a = math.pi * 2 * (i / circle_steps)
				table.insert(path, {x=r*math.cos(a), y=r*math.sin(a)-straight/2})
			end
			table.insert(path, {x=r, y=straight/2})
		else
			local straight = (x - y) * scale
			local r = y / 2 * scale
			for i=0,circle_steps/2 do
				local a = math.pi * 2 * (i / circle_steps)
				table.insert(path, {x=r*math.sin(a)+straight/2, y=-r*math.cos(a)})
			end
			for i=circle_steps/2,circle_steps do
				if i==circle_steps then i = 0 end -- :KLUDGE: sin(2*pi) is not zero, but an epsilon, so we force it
				local a = math.pi * 2 * (i / circle_steps)
				table.insert(path, {x=r*math.sin(a)-straight/2, y=-r*math.cos(a)})
			end
			table.insert(path, {x=straight/2, y=-r})
		end
	elseif shape=='P' then
		local d,steps,angle,hx,hy = unpack(parameters)
		assert(d and steps, "polygon apertures require at least 2 parameter")
		angle = angle or 0
		assert(not hx and not hy, "polygon apertures with holes are not yet supported")
		path = {concave=true}
		if d ~= 0 then
			local r = d / 2 * scale
			for i=0,steps do
				if i==steps then i = 0 end -- :KLUDGE: sin(2*pi) is not zero, but an epsilon, so we force it
				local a = math.pi * 2 * (i / steps) + math.rad(angle)
				table.insert(path, {x=r*math.cos(a), y=r*math.sin(a)})
			end
		end
	elseif macro then
		path = macro.chunk(unpack(parameters or {}))
		for _,point in ipairs(path) do
			point.x = point.x * scale
			point.y = point.y * scale
		end
	else
		error("unsupported aperture shape "..tostring(shape))
	end
	
	return {
		name = dcode,
		unit = unit,
		shape = shape,
		macro = macro,
		parameters = parameters,
		path = path,
	}
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
				layer_name = block.value
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
				assert(not unit, "gerber files with mixtures of units not supported")
				assert(scales[block.value], "unsupported unit "..tostring(block.value))
				unit = block.value
			elseif tp=='IJ' then
				-- image justify
				assert(block.value == 'ALBL')
			elseif tp=='SR' then
				-- step & repeat
				assert(block.value == 'X1Y1I0J0')
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
				assert(not unit, "gerber files with mixtures of units not supported")
				unit = 'IN'
			elseif block.G==71 then
				assert(not unit, "gerber files with mixtures of units not supported")
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
			else
				error("unsupported directive ("..tostring(block)..")")
			end
		else
			error("unsupported block type "..tostring(block.type))
		end
	end
	
	local image = {
		file_path = file_path,
		format = format,
		unit = unit,
		layers = layers,
	}
	
	return image
end

function _M.decouple_apertures(image)
	-- decouple the apertures and macros
	for _,layer in ipairs(image.layers) do
		for _,path in ipairs(layer) do
			path.aperture = copy(path.aperture)
		end
	end
end

function _M.merge_apertures(image)
	-- list apertures
	local apertures = {}
	local aperture_order = {}
	for _,layer in ipairs(image.layers) do
		for _,path in ipairs(layer) do
			local aperture = path.aperture
			local s = dump.tostring(aperture)
			if apertures[s] then
				aperture = apertures[s]
				path.aperture = aperture
			else
				apertures[s] = aperture
				table.insert(aperture_order, aperture)
			end
			local path2 = {}
			path2.unit = path.unit
			path2.aperture = aperture
			for _,point in ipairs(path) do
				table.insert(path2, point)
			end
		end
	end
	
	-- list macros
	local macros = {}
	local macro_order = {}
	for _,aperture in ipairs(aperture_order) do
		local macro = aperture.macro
		if macro then
			local s = dump.tostring(macro)
			if macros[s] then
				aperture.macro = macros[s]
			else
				macros[s] = macro
				table.insert(macro_order, macro)
			end
		end
	end
end

function _M.save(image, file_path)
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
	
	-- generate aperture names and fix shape names
	for i,aperture in ipairs(aperture_order) do
		aperture.dcode = 10 + i - 1
	end
	
	-- assemble a block array
	local data = {}
	
	local x,y = 0,0
	local layer_name
	local interpolations = { linear=1, clockwise=2, counterclockwise=3 }
	local interpolation = 'linear' -- :KLUDGE: official RS274X spec says it's undefined
--	local movements = { 'stroke', 'move', 'flash' }
--	local movement = nil
	local quadrants = { single=74, multi=75 }
	local region = false
	local quadrant,aperture,path
	local unit = image.unit
	assert(scales[unit])
	
--	table.insert(data, _M.blocks.directive{G=75})
--	table.insert(data, _M.blocks.directive{G=70})
	table.insert(data, image.format)
	table.insert(data, _M.blocks.parameter('MO', unit))
--	for _,block in pairs(image.parameters) do
--		table.insert(data, block)
--	end
--	for _,block in pairs(image.image) do
--		table.insert(data, block)
--	end
	
	for _,macro in ipairs(macro_order) do
		table.insert(data, macro)
	end
	for _,aperture in ipairs(aperture_order) do
		table.insert(data, aperture)
	end
	
	for _,layer in ipairs(image.layers) do
		if layer.name then
			table.insert(data, _M.blocks.parameter('LN', layer.name))
		end
		table.insert(data, _M.blocks.parameter('LP', layer.polarity))
		for _,path in ipairs(layer) do
			if path.aperture then
				if path.aperture ~= aperture then
					aperture = path.aperture
					table.insert(data, _M.blocks.directive{D=aperture.dcode})
				end
			else
				-- start region
				table.insert(data, _M.blocks.directive{G=36})
			end
			local scale = 1 / scales[path.unit]
			if #path == 1 then
				local flash = path[1]
				table.insert(data, _M.blocks.directive({D=3, X=flash.x * scale, Y=flash.y * scale}, image.format))
			else
				assert(#path >= 2)
				for i,point in ipairs(path) do
					if not point.interpolated then
						local G
						if i==1 then
							if interpolation ~= 'linear' then
								interpolation = 'linear'
								G = 1
							end
						else
							if point.interpolation ~= interpolation then
								interpolation = point.interpolation
								G = interpolations[interpolation]
							end
						end
						if point.quadrant and point.quadrant ~= quadrant then
							quadrant = point.quadrant
							table.insert(data, _M.blocks.directive{G=quadrants[quadrant]})
						end
						local px,py = point.x * scale,point.y * scale
						table.insert(data, _M.blocks.directive({
							G = G,
							D = i==1 and 2 or 1,
							X = px ~= x and px or nil,
							Y = py ~= y and py or nil,
							I = point.i and point.i ~= 0 and point.i * scale or nil,
							J = point.j and point.j ~= 0 and point.j * scale or nil,
						}, image.format))
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
		aperture.dcode = nil
	end
	
	return success,err
end

------------------------------------------------------------------------------

return _M
