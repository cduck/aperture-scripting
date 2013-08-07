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

------------------------------------------------------------------------------

local scales = {
	IN = 25.4,
	MM = 1,
}

local function load_macro2(data, unit)
	local macro = data
--	macro.name = data.name
	macro.unit = unit
	return macro
end

local built_in_shapes = {
	C = true,
	R = true,
	O = true,
	P = true,
}

local function load_aperture2(data, macros, unit)
	local aperture = data
--	aperture.dcode = data.dcode
	aperture.dcode = nil
	aperture.unit = unit
	if not built_in_shapes[aperture.shape] then
		aperture.macro = assert(macros[aperture.shape], "no macro with name "..tostring(aperture.shape))
		assert(aperture.macro.unit == aperture.unit, "aperture and macro units don't match")
		aperture.shape = nil
	end
	return aperture
end

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

function _M.load(filename)
	local data,err = _M.blocks.load(filename)
	if not data then return nil,err end
	
	-- parse the data blocks
	local image = {}
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
			local macro = load_macro2(block, unit)
			macros[name] = macro
		elseif tb=='aperture' then
			-- :NOTE: defining an aperture makes it current
			local name = block.dcode
			aperture = load_aperture2(block, macros, unit)
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
				table.insert(image, layer)
			elseif tp=='MO' then
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
							table.insert(image, layer)
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
						table.insert(image, layer)
					end
					table.insert(layer, {aperture=aperture, unit=unit, {x=x, y=y}})
				elseif block.D then
					error("unsupported drawing block D"..block.D)
				else
					error("no D block and no previous movement defined")
				end
			elseif block.G==70 then
				unit = 'IN'
			elseif block.G==71 then
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
	
	image.format = format
	
	return image
end

function _M.decouple_apertures(image)
	-- decouple the apertures and macros
	for _,layer in ipairs(image) do
		for _,path in ipairs(layer) do
			path.aperture = copy(path.aperture)
		end
	end
end

function _M.merge_apertures(image)
	-- list apertures
	local apertures = {}
	local aperture_order = {}
	for _,layer in ipairs(image) do
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

function _M.save(image, filename)
	-- list apertures
	local apertures = {}
	local aperture_order = {}
	for _,layer in ipairs(image) do
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
	local unit,quadrant,aperture,path
	
	for _,layer in ipairs(image) do
		for _,path in ipairs(layer) do
			if not unit then
				unit = path.unit
			end
			assert(path.unit == unit)
			if path.aperture then
				assert(path.aperture.unit == unit)
				if path.aperture.macro then
					assert(path.aperture.macro.unit == unit)
				end
			end
		end
	end
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
	
	for _,layer in ipairs(image) do
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
	
	local success,err = _M.blocks.save(data, filename)
	
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
