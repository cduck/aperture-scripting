local _M = {}

local io = require 'io'
local math = require 'math'
local table = require 'table'
local string = require 'string'

------------------------------------------------------------------------------

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

------------------------------------------------------------------------------

local parameter_scopes = {
	AS = 'directive',
	FS = 'directive',
	MI = 'directive',
	MO = 'directive',
	OF = 'directive',
	SF = 'directive',
	IN = 'image',
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
	return self.name..self.value
end

function _M.parameter(name, value)
	local parameter = setmetatable({type='parameter'}, parameter_mt)
	parameter.scope = assert(parameter_scopes[name], "unknown parameter "..name)
	parameter.name = name
	parameter.value = value
	return parameter
end

local function load_parameter(block)
	local name,value = block:match('^(%u%u)(.*)$')
	assert(name and value)
	return _M.parameter(name, value)
end

------------------------------------------------------------------------------

local format_mt = {}

function format_mt:__tostring()
	return 'FS'..self.zeroes..'AX'..self.integer..self.decimal..'Y'..self.integer..self.decimal
end

function _M.format(zeroes, integer, decimal)
	local format = setmetatable({type='format'}, format_mt)
	format.zeroes = zeroes
	format.integer = integer
	format.decimal = decimal
	return format
end

local function load_format(block)
	local zeroes,mode,xi,xd,yi,yd = block:match('^FS(.)(.)X(%d)(%d)Y(%d)(%d)$')
	assert(zeroes and (zeroes=='L' or zeroes=='T' or zeroes=='D'))
	assert(mode=='A', "only files with absolute coordinates are supported")
	assert(xi and xd and yi and yd)
	assert(xi==yi and xd==yd)
	return _M.format(zeroes, tonumber(xi), tonumber(xd))
end

------------------------------------------------------------------------------

local macro_comment_mt = {}

function macro_comment_mt:__tostring()
	return '0'..self.text
end

function _M.macro_comment(text)
	local macro_comment = setmetatable({type='comment'}, macro_comment_mt)
	macro_comment.text = text
	return macro_comment
end

local function load_macro_comment(block)
	local text = block:match('^0(.*)$')
	return _M.macro_comment(text)
end

------------------------------------------------------------------------------

local shapes = {}
for name,code in pairs{
	circle = 1,
	line = 2,
	outline = 4,
	polygon = 5,
	moire = 6,
	thermal = 7,
	rectangle_ends = 20,
	rectangle_center = 21,
	rectangle_corner = 22,
} do
	shapes[name] = code
	shapes[code] = name
end

local macro_primitive_mt = {}

function macro_primitive_mt:__tostring()
	return assert(shapes[self.shape])..','..table.concat(self.parameters, ',')
end

function _M.macro_primitive(shape, parameters)
	local macro_primitive = setmetatable({type='primitive'}, macro_primitive_mt)
	macro_primitive.shape = shape
	macro_primitive.parameters = parameters
	return macro_primitive
end

local function load_macro_primitive(block)
	local sshape,sparameters = block:match('^(%d+)(.*)$')
	assert(sshape and sparameters)
	local shape = assert(shapes[tonumber(sshape)], "invalid shape "..sshape)
	local parameters = {}
	for expression in sparameters:gmatch(',([^,]*)') do
		if expression:match('^([%d.]+)$') then
			expression = assert(tonumber(expression), "expression '"..expression.."' doesn't parse as a number")
		end
		table.insert(parameters, expression)
	end
--	assert(','..table.concat(parameters, ',')==sparameters)
	return _M.macro_primitive(shape, parameters)
end

------------------------------------------------------------------------------

local macro_variable_mt = {}

function macro_variable_mt:__tostring()
	return '$'..self.name..'='..self.expression
end

function _M.macro_variable(name, expression)
	local macro_variable = setmetatable({type='variable'}, macro_variable_mt)
	macro_variable.name = name
	macro_variable.expression = expression
	return macro_variable
end

local function load_macro_variable(block)
	local name,expression = block:match('^%$([^=]+)=(.*)$')
	assert(name and expression)
	return _M.macro_variable(name, expression)
end

------------------------------------------------------------------------------

local function load_macro_instruction(block)
	local char = block:sub(1,1)
	if char=='0' then
		return load_macro_comment(block)
	elseif char=='$' then
		return load_macro_variable(block)
	else
		return load_macro_primitive(block)
	end
end

------------------------------------------------------------------------------

local macro_mt = {}

function macro_mt:__tostring()
	local name = self.save_name or self.name
	local script = {}
	for i,instruction in ipairs(self.script) do script[i] = tostring(instruction) end
	return 'AM'..name..'*\n'..table.concat(script, '*\n')
end

function _M.macro(name, script)
	local macro = setmetatable({type='macro'}, macro_mt)
	macro.name = name
	macro.script = script
	return macro
end

local function load_macro(block, script)
	local name = block:match('^AM(.*)$')
	assert(name and name:match('^[A-Z]'))
	local instructions = {}
	for _,block in ipairs(script) do
		local instruction = load_macro_instruction(block)
		table.insert(instructions, instruction)
	end
	return _M.macro(name, instructions)
end

------------------------------------------------------------------------------

local aperture_mt = {}
local aperture_getters = {}

function aperture_mt:__index(k)
	local getter = aperture_getters[k]
	if getter then
		return getter(self)
	end
	return nil
end

function aperture_getters:definition()
	local shape
	if self.macro then
		shape = self.macro.save_name or self.macro.name
	else
		shape = self.shape
	end
	local parameters = self.parameters and ","..table.concat(self.parameters, "X") or ""
	return shape..parameters
end

function aperture_mt:__tostring()
	return string.format('ADD%02d%s', self.dcode, self.definition)
end

function _M.aperture(dcode, shape, parameters)
	assert(not shape:match(','))
	local aperture = setmetatable({type='aperture'}, aperture_mt)
	aperture.dcode = dcode
	aperture.shape = shape
	aperture.parameters = parameters
	return aperture
end

local function load_aperture(block)
	local dcode,shape,parameters = block:match('^ADD(%d+)([^,]*)(.*)$')
	assert(dcode and shape and parameters)
	dcode = tonumber(dcode)
	assert(dcode and dcode >= 10 and dcode <= 999)
	if parameters == "" then
		parameters = nil
	else
		assert(parameters:sub(1,1) == ",")
		parameters = parameters:sub(2)
		assert(parameters ~= "")
		local t = {}
		for parameter in parameters:gmatch('[^X]+') do
			parameter = assert(tonumber(parameter))
			table.insert(t, parameter)
		end
		parameters = t
	end
	return _M.aperture(dcode, shape, parameters)
end

------------------------------------------------------------------------------

function _M.load_number(s, format)
	local sign,base = s:match('^([+-]?)(%d+)$')
	assert(sign and base)
	local size = format.integer + format.decimal
	if #base < size then
		if format.zeroes == 'L' then
			base = string.rep('0', size - #s) .. base
		elseif format.zeroes == 'T' then
			base = base .. string.rep('0', size - #s)
		elseif format.zeroes == 'D' then
			error("unexpected number "..s.." in format "..tostring(format))
		end
	end
	return (sign=='-' and -1 or 1) * tonumber(base) / 10 ^ format.decimal
end

function _M.save_number(n, format, long)
	local sign
	if n < 0 then
		sign = '-'
		n = -n
	else
		sign = ''
	end
	n = n * 10 ^ format.decimal
	local i = math.floor(n + 0.5)
--	assert(math.abs(n - i) < 1e-8, "rounding error")
	n = i
	local size = format.integer + format.decimal
	n = string.format('%0'..size..'d', n)
	assert(#n == size)
	if not long then
		if format.zeroes == 'L' then
			n = n:match('^0*(.*.)$')
		elseif format.zeroes=='T' then
			n = n:match('^(..-)0*$')
		end
	end
	return sign..n
end

------------------------------------------------------------------------------

local function save_directive(self, long)
	local G = self.G and string.format('G%02d', self.G) or ''
	local X = self.X and 'X'.._M.save_number(self.X, self.format, long) or ''
	local Y = self.Y and 'Y'.._M.save_number(self.Y, self.format, long) or ''
	local I = self.I and 'I'.._M.save_number(self.I, self.format, long) or ''
	local J = self.J and 'J'.._M.save_number(self.J, self.format, long) or ''
	local D = self.D and string.format('D%02d', self.D) or ''
	local M = self.M and string.format('M%02d', self.M) or ''
	local comment = self.comment or ''
	return G..X..Y..I..J..D..M..comment
end

local directive_mt = {}

function directive_mt:__tostring()
	return save_directive(self)
end

function _M.directive(data, format)
	local directive = setmetatable({type='directive'}, directive_mt)
	if data.X or data.Y or data.I or data.J then
		directive.format = assert(format)
	end
	for k,v in pairs(data) do
		directive[k] = v
	end
	return directive
end

local function load_directive(block, format)
	local directive
	if block:match('^G04') then
		directive = _M.directive{ G = 4, comment = block:sub(4) }
	else
		local data = {}
		for letter,number in block:gmatch('(%a)([0-9+-]+)') do
			if letter:match('[XYIJ]') then
				data[letter] = _M.load_number(number, assert(format))
			else
				assert(number:match('^%d%d%d?$'))
				data[letter] = tonumber(number)
			end
		end
		directive = _M.directive(data, format)
	end
--	assert(block == tostring(directive) or block == save_directive(directive, true), "block '"..block.."' has been converted to '"..tostring(directive).."'")
	return directive
end

------------------------------------------------------------------------------

function _M.comment(comment)
	return _M.directive{ G = 4, comment = comment:gsub('%*', '') }
end

------------------------------------------------------------------------------

function _M.eof()
	return _M.directive{ M = 2 }
end

------------------------------------------------------------------------------

function _M.load(filename)
	local file = assert(io.open(filename, 'rb'))
	local content = assert(file:read('*all'))
	assert(file:close())
	content = content:gsub('([%%*])%s*', '%1')
	
	local data = { parameters = {}, image = {}, macros = {}, apertures = {} }
	
	-- directives may appear before the first parameter
	local directives = content:match('^([^%%]*)%%')
	if directives then
		for block in directives:gmatch('([^*]*)%*') do
			local directive = load_directive(block, data.format)
			table.insert(data, directive)
		end
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
				local script = {}
				while i < #pdata and pdata[i+1]:match('^[%d$]') do
					table.insert(script, pdata[i+1])
					i = i + 1
				end
				local macro = load_macro(block, script)
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

------------------------------------------------------------------------------

return _M
