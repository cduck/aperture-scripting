local _M = {}

local zero_omissions = {
	L = 'leading_zeros',
	T = 'trailing_zeros',
	D = 'no_omission',
}

local coordinate_modes = {
	A = 'absolute',
	I = 'incremental',
}

local unit_modes = {
	IN = 'inches',
	MM = 'millimeters',
}

local image_polarities = {
	POS = 'positive',
	NEG = 'negative',
}

local layer_polarities = {
	D = 'dark',
	C = 'clear',
}

local commands = {}

function commands.AS(data, block) -- axis select
	local a,b = block:match('^ASA(.)B(.)$')
	assert(a and b and a~=b)
	data.axis_select = { a = a, b = b }
end

function commands.FS(data, block) -- format statement
	assert(#block % 2 == 0)
	local omission,mode = block:match('^..(.)(.)')
	local format = {
		zero_omission = assert(zero_omissions[omission]),
		coordinate_modes = assert(coordinate_modes[mode]),
	}
	for option,value in block:sub(5):gmatch('([A-Z])(%d+)') do
		if option=='N' then
			format.sequence_number = tonumber(value)
		elseif option=='G' then
			format.preparatory_function_code = tonumber(value)
		elseif option=='X' then
			local i,d = value:match('(.)(.)')
			assert(i and d)
			i,d = tonumber(i),tonumber(d)
			format.x = {i=i, d=d}
		elseif option=='Y' then
			local i,d = value:match('(.)(.)')
			assert(i and d)
			i,d = tonumber(i),tonumber(d)
			format.y = {i=i, d=d}
		elseif option=='Z' then
			local i,d = value:match('(.)(.)')
			assert(i and d)
			i,d = tonumber(i),tonumber(d)
			format.z = {i=i, d=d}
		elseif option=='D' then
			format.draft_code = tonumber(value)
		elseif option=='M' then
			format.misc_code = tonumber(value)
		else
			error("unrecognized format statement option '"..option.."'")
		end
	end
	data.format = format
end

commands.MI = nil -- mirror image

function commands.MO(data, block) -- mode of units
	data.unit_mode = assert(unit_modes[block:sub(3)])
end

function commands.OF(data, block) -- offset
	assert(block=='OFA0B0')
end

commands.SF = nil -- scale factor

function commands.IJ(data, block) -- image justify
	assert(block=='IJALBL')
end

commands.IN = nil -- image name
commands.IO = nil -- image offset

function commands.IP(data, block) -- image polarity
	data.image_polarity = assert(image_polarities[block:sub(3)])
end

commands.IR = nil -- image rotation
commands.PF = nil -- plotter film

function commands.AD(data, block) -- aperture description
	-- :TODO:
end

function commands.AM(data, block) -- aperture macro
	-- :TODO:
end

function commands.LN(data, block) -- layer name
	-- discard anonymous layer if it's empty
	if #data.layers == 1 and
		not data.layers[1].name and
		#data.layers[1] == 0 then
		data.layers[1] = nil
	end
	local layer = {}
	layer.name = block:sub(3)
	table.insert(data.layers, layer)
	data.state.layer = layer
end

function commands.LP(data, block) -- layer polarity
	assert(data.state.layer, "LP before LN in "..data.state.filename)
	data.state.layer.polarity = assert(layer_polarities[block:sub(3)])
end

commands.KO = nil -- knockout

function commands.SR(data, block) -- step and repeat
	assert(block=='SRX1Y1I0J0')
end

commands.SM = nil -- symbol mirror
commands.IF = nil -- include file

function _M.parse(filename)
	local file = assert(io.open(filename, 'rb'))
	local content = assert(file:read('*all'))
	assert(file:close())
	content = content:gsub('[%s%%]', '')
	
	local data = { layers = { }, state = { filename = filename } }
	
	-- set a global anonymous layer
	data.layers[1] = {}
	data.state.layer = data.layers[1]
	
	local layer
	
	for block in content:gmatch('([^*]*)%*') do
		local command = block:match('^[A-Z][A-Z]')
		command = commands[command]
		if command then
			command(data, block)
		elseif block:match('^[XYIJ]%d') then
		elseif block:match('^D0[1-3]') then
		elseif block:match('^D%d') then
			local dcode = block:match('^D(%d+)')
			assert(dcode)
			dcode = tonumber(dcode)
			assert(dcode >= 10 and dcode <= 999 and math.floor(dcode)==dcode)
			data.state.aperture = block
		elseif block:match('^G%d') then
			local gcode,param = block:match('^G(%d+)(.*)$')
			assert(gcode)
			gcode = tonumber(gcode)
		--	error("unsupported G-code "..gcode)
		elseif block:match('^M%d') then
		elseif block:match('^%d') then
		else
			error("block "..block.." not supported")
		end
	end
	
	-- discard the parsing state
	data.state = nil
	
	return data
end

return _M
