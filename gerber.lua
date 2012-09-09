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

local function init_state(image)
	image.state.interpolation = 'linear'
	image.state.mode = 'draw'
	image.state.x = 0
	image.state.y = 0
	image.state.quadrant = 'single'
	image.state.unit = image.unit
end

local function image(filename, index)
	local image = { layers = { }, state = { filename = filename, index = index } }
	
	-- set a global anonymous layer
	image.layers[1] = {}
	image.state.layer = image.layers[1]
	
	-- initialize the drawing state
	init_state(image)
	
	return image
end

local parameters = {}

function parameters.AS(image, block) -- axis select
	local a,b = block:match('^ASA(.)B(.)$')
	assert(a and b and a~=b)
	image.axis_select = { a = a, b = b }
end

function parameters.FS(image, block) -- format statement
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
	image.format = format
end

parameters.MI = nil -- mirror image

function parameters.MO(image, block) -- mode of units
	image.unit = assert(unit_modes[block:sub(3)])
	image.state.unit = image.unit
end

function parameters.OF(image, block) -- offset
	assert(block=='OFA0B0')
end

parameters.SF = nil -- scale factor

function parameters.IJ(image, block) -- image justify
	assert(block=='IJALBL')
end

parameters.IN = nil -- image name
parameters.IO = nil -- image offset

function parameters.IP(image, block) -- image polarity
	image.image_polarity = assert(image_polarities[block:sub(3)])
end

parameters.IR = nil -- image rotation
parameters.PF = nil -- plotter film

function parameters.AD(image, block) -- aperture description
	-- :TODO:
end

function parameters.AM(image, block) -- aperture macro
	-- :TODO:
end

function parameters.LN(image, block) -- layer name
	-- discard anonymous layer if it's empty
	if #image.layers == 1 and
		not image.layers[1].name and
		#image.layers[1] == 0 then
		image.layers[1] = nil
	end
	local layer = {}
	layer.name = block:sub(3)
	table.insert(image.layers, layer)
	image.state.layer = layer
	init_state(image)
end

function parameters.LP(image, block) -- layer polarity
	assert(image.state.layer, "LP before LN in "..image.state.filename)
	image.state.layer.polarity = assert(layer_polarities[block:sub(3)])
end

parameters.KO = nil -- knockout

function parameters.SR(image, block) -- step and repeat
	assert(block=='SRX1Y1I0J0')
end

parameters.SM = nil -- symbol mirror
parameters.IF = nil -- include file

local function draw(image, data)
	if data.D == 1 then
		image.state.mode = 'draw'
	elseif data.D == 2 then
		image.state.mode = 'move'
	elseif data.D == 3 then
		image.state.mode = 'flash'
	elseif data.D then
		error("unsupported draw directive D"..data.D)
	end
	
	if image.state.outline then
		if image.state.mode == 'draw' then
			assert(#image.state.outline >= 1)
			table.insert(image.state.outline, {
				interpolation = image.state.interpolation,
				x = image.state.x,
				y = image.state.y,
				i = image.state.i,
				j = image.state.j,
				unit = image.state.unit,
			})
		elseif image.state.mode == 'move' then
			if #image.state.outline == 0 then
				table.insert(image.state.outline, {
					interpolation = image.state.interpolation,
					x = image.state.x,
					y = image.state.y,
					i = image.state.i,
					j = image.state.j,
					unit = image.state.unit,
				})
			else
				assert(image.state.outline[1].interpolation == image.state.interpolation)
				assert(image.state.outline[1].x == image.state.x)
				assert(image.state.outline[1].y == image.state.y)
				assert(image.state.outline[1].i == image.state.i)
				assert(image.state.outline[1].j == image.state.j)
				assert(image.state.outline[1].unit == image.state.unit)
			end
		else
			error("unsupported mode "..image.state.mode.." in outline fill")
		end
	else
		table.insert(image.state.layer, {
			mode = image.state.mode,
			x = image.state.x,
			y = image.state.y,
			i = image.state.i,
			j = image.state.j,
			unit = image.state.unit,
		})
	end
end

local function directive(image, block)
	local data = {}
	for letter,number in block:gmatch('([GXYIJD])([%d.-]+)') do
		data[letter] = tonumber(number)
	end
	if data.G == 4 then
		-- skip comment
	elseif data.G == 36 then
		assert(not (data.X or data.Y or data.I or data.J or data.D))
		image.state.outline = {mode='outline'}
	elseif data.G == 37 then
		assert(not (data.X or data.Y or data.I or data.J or data.D))
		table.insert(image.state.layer, image.state.outline)
		image.state.outline = nil
	elseif data.G == 70 then
		assert(not (data.X or data.Y or data.I or data.J or data.D))
		image.state.unit = 'inches'
	elseif data.G == 71 then
		assert(not (data.X or data.Y or data.I or data.J or data.D))
		image.state.unit = 'millimeters'
	elseif data.G == 74 then
		assert(not (data.X or data.Y or data.I or data.J or data.D))
		image.state.quadrant = 'single'
	elseif data.G == 75 then
		assert(not (data.X or data.Y or data.I or data.J or data.D))
		image.state.quadrant = 'multi'
	elseif data.G == 90 or data.G == 91 then
		error("unsupported parameter G"..data.G)
	elseif data.D and data.D >= 10 then
		assert(not (data.X or data.Y or data.I or data.J))
		assert(not data.G or data.G == 54)
		image.state.aperture = 'D'..data.D
	elseif data.G == 1 then
		image.state.interpolation = 'linear'
		draw(image, data)
	elseif data.G == 2 then
		image.state.interpolation = 'clockwise'
		draw(image, data)
	elseif data.G == 3 then
		image.state.interpolation = 'counterclockwise'
		draw(image, data)
	elseif data.G == 55 then
		-- optional flash directive
		draw(image, data)
	elseif data.G then
		error("unsupported parameter G"..data.G)
	else
		draw(image, data)
	end
end

local function parsefs(block)
	local zeroes,mode,xi,xd,yi,yd = block:match('^FS(.)(.)X(%d)(%d)Y(%d)(%d)$')
	assert(zeroes and (zeroes=='L' or zeroes=='T' or zeroes=='D'))
	assert(mode=='A', "only files with absolute coordinates are supported")
	assert(xi and xd and yi and yd)
	assert(xi==yi and xd==yd)
	return {
		name = block,
		zeroes = zeroes,
		integer = tonumber(xi),
		decimal = tonumber(xd),
	}
end

local function _tonumber(s, format)
	local sign,base = s:match('^([+-]?)(%d+)$')
	assert(sign and base)
	local size = format.integer + format.decimal
	if #base < size then
		if format.zeroes == 'L' then
			base = string.rep('0', size - #s) .. base
		elseif format.zeroes == 'T' then
			base = base .. string.rep('0', size - #s)
		elseif format.zeroes == 'D' then
			error("unexpected number "..s.." in format "..format.name)
		end
	end
	return (sign=='-' and -1 or 1) * tonumber(base) / 10 ^ format.decimal
end

local function save_number(n, format, long)
	local sign
	if n < 0 then
		sign = '-'
		n = -n
	else
		sign = ''
	end
	n = n * 10 ^ format.decimal
	local i = math.floor(n + 0.5)
	assert(n - i < 1e-8, "rounding error")
	n = i
	local size = format.integer + format.decimal
	n = string.format('%0'..size..'d', n)
	assert(#n == size)
	if not long then
		if format.zeroes == 'L' then
			n = n:match('^0*(.*.)$')
		elseif format=='T' then
			n = n:match('^(..-)0*$')
		end
	end
	return sign..n
end

local function save_directive(self, long)
	local G = self.G and string.format('G%02d', self.G) or ''
	local X = self.X and 'X'..save_number(self.X, self.format, long) or ''
	local Y = self.Y and 'Y'..save_number(self.Y, self.format, long) or ''
	local I = self.I and 'I'..save_number(self.I, self.format, long) or ''
	local J = self.J and 'J'..save_number(self.J, self.format, long) or ''
	local D = self.D and string.format('D%02d', self.D) or ''
	local M = self.M and string.format('M%02d', self.M) or ''
	local comment = self.comment or ''
	return G..X..Y..I..J..D..M..comment
end

local directive_mt = {}

function directive_mt:__tostring()
	return save_directive(self)
end

function _M.parse(filename)
	local file = assert(io.open(filename, 'rb'))
	local content = assert(file:read('*all'))
	assert(file:close())
	content = content:gsub('([%%*])%s*', '%1')
	
	local data = {}
	local format
	
	for parameters,directives in content:gmatch('%%([^%%]*)%%([^%%]*)') do
		local pdata = {type='parameters'}
		for block in parameters:gmatch('([^*]*)%*') do
			table.insert(pdata, block)
			if block:match('^FS') then
				format = parsefs(block)
			end
		end
		if #pdata >= 1 then
			table.insert(data, pdata)
		end
		for block in directives:gmatch('([^*]*)%*') do
			local directive = setmetatable({type='directive'}, directive_mt)
			if block:match('^G04') then
				directive.G = '04'
				directive.comment = block:sub(4)
			else
				for letter,number in block:gmatch('(%a)([0-9+-]+)') do
					if letter:match('[XYIJ]') then
						directive.format = assert(format)
						directive[letter] = _tonumber(number, format)
					else
						assert(number:match('^%d%d%d?$'))
						directive[letter] = tonumber(number)
					end
				end
			end
			assert(block == tostring(directive) or block == save_directive(directive, true), "block '"..block.."' has been converted to '"..tostring(directive).."'")
			table.insert(data, directive)
		end
	end
	
	return data
end

return _M
