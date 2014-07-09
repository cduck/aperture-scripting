local _M = {}

local math = require 'math'
local table = require 'table'
local dump = require 'dump'
_M.blocks = require 'gerber.blocks'

------------------------------------------------------------------------------

-- all positions in picometers (1e-12 meters)
local scales = {
	IN = 25400000000 / 10 ^ _M.blocks.decimal_shift,
	MM =  1000000000 / 10 ^ _M.blocks.decimal_shift,
}
for unit,scale in pairs(scales) do
	assert(math.floor(scale)==scale)
end

------------------------------------------------------------------------------

local function load_macro(data, unit)
	local name = data.name
	local script = data.script
	return {
		name = name,
		unit = unit,
		script = script,
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
				assert(not unit or unit==block.value, "gerber files with mixtures of units not supported")
				assert(scales[block.value], "unsupported unit "..tostring(block.value))
				unit = block.value
			elseif tp=='IJ' then
				-- image justify
				assert(block.value == 'ALBL', "unsupported image justify "..tostring(block.value).." (Gerber IJ parameter")
			elseif tp=='MI' then
				-- mirror image
				assert(block.value == 'A0B0', "unsupported non-trivial mirror image "..tostring(block.value).." (Gerber MI parameter")
			elseif tp=='OF' then
				-- offset
				local a,b = block.value:match('^A([%d.]+)B([%d.]+)$')
				assert(a and b, "unsupported offset "..tostring(block.value).." (Gerber OF parameter")
				a,b = tonumber(a),tonumber(b)
				assert(a == 0 and b == 0, "unsupported non-null offset "..tostring(block.value).." (Gerber OF parameter")
			elseif tp=='SF' then
				-- scale factor
				local a,b = block.value:match('^A([%d.]+)B([%d.]+)$')
				assert(a and b, "unsupported scale factor "..tostring(block.value).." (Gerber SF parameter")
				a,b = tonumber(a),tonumber(b)
				assert(a == 1 and b == 1, "unsupported non-identity scale factor "..tostring(block.value).." (Gerber SF parameter")
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
					elseif interpolation=='clockwise' or interpolation=='counterclockwise' then
						assert(quadrant, "circular interpolation before a quadrant mode is specified")
						local i = (block.I or 0) * scale
						local j = (block.J or 0) * scale
						table.insert(path, {x=x, y=y, i=i, j=j, interpolation=interpolation, quadrant=quadrant})
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
	assert(image.format.zeroes and image.format.integer and image.format.decimal)
	table.insert(data, _M.blocks.format(image.format.zeroes, image.format.integer, image.format.decimal))
	table.insert(data, _M.blocks.parameter('MO', unit))
	
	for _,macro in ipairs(macro_order) do
		table.insert(data, save_macro(macro))
	end
	for _,aperture in ipairs(aperture_order) do
		table.insert(data, save_aperture(aperture))
	end
	
	for _,layer in ipairs(image.layers) do
		assert(layer.polarity, "layer has no polarity")
		table.insert(data, _M.blocks.parameter('LP', layer_polarity_codes[layer.polarity]))
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
					if not point.interpolated then
						if point.quadrant and point.quadrant ~= quadrant then
							quadrant = point.quadrant
							table.insert(data, _M.blocks.directive{G=quadrants[quadrant]})
						end
						local D = i == 1 and 2 or 1
						local interpolation_changed = false
						if D==1 then
							assert(point.interpolation)
							if point.interpolation ~= interpolation then
								interpolation = point.interpolation
								interpolation_changed = true
							end
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
						local px,py = point.x / scale,point.y / scale
						if D ~= 2 or x ~= px or y ~= py then -- don't move to the current pos
							table.insert(data, _M.blocks.directive({
								G = G,
								D = D,
								X = (verbose or px ~= x) and px or nil,
								Y = (verbose or py ~= y) and py or nil,
								I = point.i and (verbose or point.i ~= 0) and point.i / scale or nil,
								J = point.j and (verbose or point.j ~= 0) and point.j / scale or nil,
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
