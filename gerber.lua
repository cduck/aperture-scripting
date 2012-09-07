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

function _M.parse(filename)
	local file = assert(io.open(filename, 'rb'))
	local content = assert(file:read('*all'))
	assert(file:close())
	content = content:gsub('[%s%%]', '')
	
	local data = { layers = {} }
	
	local layer
	
	for block in content:gmatch('([^*]*)%*') do
		if block:match('^ASA.B.$') then -- axis select
			local a,b = block:match('^ASA(.)B(.)$')
			assert(a and b and a~=b)
			data.axis_select = { a = a, b = b }
		elseif block:match('^FS') then -- format statement
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
	--	elseif block:match('^MI') then -- mirror image
		elseif block:match('^MO') then -- mode of units
			data.unit_mode = assert(unit_modes[block:sub(3)])
	--	elseif block:match('^OF') then -- offset
	--	elseif block:match('^SF') then -- scale factor
		elseif block:match('^IJ') then -- image justify
			assert(block=='IJALBL')
	--	elseif block:match('^IN') then -- image name
	--	elseif block:match('^IO') then -- image offset
		elseif block:match('^IP') then -- image polarity
			data.image_polarity = assert(image_polarities[block:sub(3)])
	--	elseif block:match('^IR') then -- image rotation
	--	elseif block:match('^PF') then -- plotter film
		elseif block:match('^AD') then -- aperture description
		elseif block:match('^AM') then -- aperture macro
		elseif block:match('^LN') then -- layer name
			layer = {}
			layer.name = block:sub(3)
			table.insert(data.layers, layer)
		elseif block:match('^LP') then -- layer polarity
			assert(layer)
			layer.polarity = assert(layer_polarities[block:sub(3)])
	--	elseif block:match('^KO') then -- knockout
		elseif block:match('^SR') then -- step and repeat
			assert(block=='SRX1Y1I0J0')
	--	elseif block:match('^SM') then -- symbol mirror
	--	elseif block:match('^IF') then -- include file
		elseif block:match('^X%d') then
		elseif block:match('^Y%d') then
		elseif block:match('^I%d') then
		elseif block:match('^J%d') then
		elseif block:match('^D%d') then
		elseif block:match('^G%d') then
		elseif block:match('^M%d') then
		elseif block:match('^%d') then
		else
			error("block "..block.." not supported")
		end
	end
	
	return data
end

return _M
