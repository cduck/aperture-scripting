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

local parameter_scopes = {
	AS = 'directive',
	FS = 'directive',
	MI = 'directive',
	MO = 'directive',
	OF = 'directive',
	SF = 'directive',
	IP = 'image',
	IR = 'image',
	IJ = 'image',
	LN = 'layer',
	LP = 'layer',
	SR = 'layer',
	KO = 'layer',
}

local parameter_mt = {}

function parameter_mt:__tostring()
	return self.block
end

local function load_parameter(block)
	local name = block:match('^(%u%u)')
	assert(name)
	local parameter = setmetatable({type='parameter'}, parameter_mt)
	assert(type(block)=='string')
	parameter.block = block
	parameter.name = name
	parameter.scope = assert(parameter_scopes[name], "unknown parameter "..name)
	return parameter
end

local format_mt = {}

function format_mt:__tostring()
	return self.block
end

local function load_format(block)
	local zeroes,mode,xi,xd,yi,yd = block:match('^FS(.)(.)X(%d)(%d)Y(%d)(%d)$')
	assert(zeroes and (zeroes=='L' or zeroes=='T' or zeroes=='D'))
	assert(mode=='A', "only files with absolute coordinates are supported")
	assert(xi and xd and yi and yd)
	assert(xi==yi and xd==yd)
	local format = setmetatable({type='format'}, format_mt)
	format.block = block
	format.zeroes = zeroes
	format.integer = tonumber(xi)
	format.decimal = tonumber(xd)
	return format
end

local macro_mt = {}

function macro_mt:__tostring()
	return 'AM'..self.name..'*\n'..table.concat(self, '*\n')
end

local function load_macro(block, apertures)
	local name = block:match('^AM(.*)$')
	assert(name and name:match('^[A-Z]'))
	local macro = setmetatable({type='macro'}, macro_mt)
	macro.name = name
	for _,aperture in ipairs(apertures) do
		table.insert(macro, aperture)
	end
	return macro
end

local aperture_mt = {}

function aperture_mt:__tostring()
	return 'ADD'..string.format('%02d', self.dcode)..self.definition
end

local function load_aperture(block)
	local dcode,definition = block:match('^ADD(%d+)(.*)$')
	assert(dcode and definition)
	dcode = tonumber(dcode)
	assert(dcode and dcode >= 10 and dcode <= 999)
	local aperture = setmetatable({type='aperture'}, aperture_mt)
	aperture.dcode = dcode
	aperture.definition = definition
	return aperture
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
			error("unexpected number "..s.." in format "..format.block)
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

local function load_directive(block, format)
	local directive = setmetatable({type='directive'}, directive_mt)
	if block:match('^G04') then
		directive.G = 4
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
	return directive
end

function _M.comment(comment)
	local directive = setmetatable({type='directive'}, directive_mt)
	directive.G = 4
	directive.comment = " "..comment:gsub('%*', '')
	return directive
end

function _M.load(filename)
	local file = assert(io.open(filename, 'rb'))
	local content = assert(file:read('*all'))
	assert(file:close())
	content = content:gsub('([%%*])%s*', '%1')
	
	local data = { parameters = {}, image = {}, macros = {}, apertures = {} }
	
	-- directives may appear before the first parameter
	local directives = content:match('^([^%%]*)%%')
	for block in directives:gmatch('([^*]*)%*') do
		local directive = load_directive(block, data.format)
		table.insert(data, directive)
	end
	-- parse alternating parameter/directive blocks
	for parameters,directives in content:gmatch('%%([^%%]*)%%([^%%]*)') do
		local pdata = {}
		for block in parameters:gmatch('([^*]*)%*') do
			table.insert(pdata, block)
		end
		local i = 1
		while i <= #pdata do
			local block = pdata[i]
			if block:match('^FS') then
				data.format = load_format(block)
				table.insert(data, data.format)
			elseif block:match('^AD') then
				local aperture = load_aperture(block)
				assert(data.apertures[aperture.dcode] == nil)
				data.apertures[aperture.dcode] = aperture
				table.insert(data, aperture)
			elseif block:match('^AM') then
				local apertures = {}
				while i < #pdata and pdata[i+1]:match('^%d') do
					table.insert(apertures, pdata[i+1])
					i = i + 1
				end
				local macro = load_macro(block, apertures)
				assert(data.macros[macro.name] == nil)
				data.macros[macro.name] = macro
				table.insert(data, macro)
			else
				local parameter = load_parameter(block)
				if parameter.scope == 'directive' then
					assert(data.parameters[parameter.name] == nil)
					data.parameters[parameter.name] = parameter
				elseif parameter.scope == 'image' then
					assert(data.image[parameter.name] == nil)
					data.image[parameter.name] = parameter
				end
				table.insert(data, parameter)
			end
			i = i + 1
		end
		for block in directives:gmatch('([^*]*)%*') do
			table.insert(data, load_directive(block, data.format))
		end
	end
	
	return data
end

function _M.save(data, filename)
	local file = assert(io.open(filename, "wb"))
	for _,block in ipairs(data) do
		if block.type=='directive' then
			assert(file:write(tostring(block):gsub('\n', '\r\n')..'*\r\n'))
		else
			assert(file:write('%'..tostring(block):gsub('\n', '\r\n')..'*%\r\n'))
		end
	end
	assert(file:close())
	return true
end

return _M
