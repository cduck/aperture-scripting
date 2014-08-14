local _M = {}
local _NAME = ... or 'test'

local io = require 'io'
local math = require 'math'
local table = require 'table'
local string = require 'string'

if _NAME=='test' then
	require 'test'
end

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

local parameter_mt = {}

function parameter_mt:__tostring()
	return self.name..self.value
end

function _M.parameter(name, value)
	local parameter = setmetatable({type='parameter'}, parameter_mt)
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

-- see http://www.artwork.com/gerber/274x/rs274x.htm
-- 
-- FS[LTD][AI](Nn)(Gn)(Xa)(Yb)(Zc)(Dn)(Mn)
-- 
-- where:
-- 
-- L  = leading zeros omitted
-- T  = trailing zeros omitted
-- D  = explicit decimal point (i.e. no zeros omitted)
-- 
-- A  = absolute coordinate mode
-- I  = incremental coordinate mode
-- 
-- Nn = sequence number, where n is number of digits (rarely used)
-- Gn = prepartory function code (rarely used)
-- 
-- Xa = format of input data (5.5 is max)
-- Yb = format of input data
-- Zb = format of input data (Z is rarely if ever seen)
-- 
-- Dn = draft code (rarely used)
-- Mn = misc code (rarely used)

local format_mt = {}

function format_mt:__tostring()
	local format = { 'FS', self.zeroes or 'D', 'A' }
	local function append(...) for _,s in ipairs{...} do table.insert(format, s) end end
	if self.sequence_number then
		append('N', self.sequence_number)
	end
	if self.preparatory_function_code then
		append('G', self.preparatory_function_code)
	end
	append('X', self.integer, self.decimal)
	append('Y', self.integer, self.decimal)
	if self.has_z then
		append('Z', self.integer, self.decimal)
	end
	if self.draft_code then
		append('D', self.draft_code)
	end
	if self.misc_code then
		append('M', self.misc_code)
	end
	return table.concat(format)
end

function _M.format(zeroes, integer, decimal, seq, prep, draft, misc, has_z)
	local format = setmetatable({type='format'}, format_mt)
	format.zeroes = zeroes
	format.integer = integer
	format.decimal = decimal
	format.sequence_number = seq
	format.preparatory_function_code = prep
	format.draft_code = draft
	format.misc_code = misc
	format.has_z = has_z
	return format
end

local function load_format(block)
	local zeroes,mode,xi,xd,yi,yd = block:match('^FS([LTD])([AI])X(%d)(%d)Y(%d)(%d)$')
	local seq,prep,draft,misc,zi,zd
	local warn
	if not zeroes then
		warn = true
		local data = block:match('^FS(.*)$')
		-- try to extract some information
		for param in data:gmatch('%a%d*') do
			if param=='L' or param=='T' or param=='D' then
				zeroes = param
			elseif param=='A' or param=='I' then
				mode = param
			elseif param:match('^N%d+$') then
				seq = param:match('^N(%d+)$')
			elseif param:match('^G%d+$') then
				prep = param:match('^G(%d+)$')
			elseif param:match('^X%d%d$') then
				xi,xd = param:match('^X(%d)(%d)$')
			elseif param:match('^Y%d%d$') then
				yi,yd = param:match('^Y(%d)(%d)$')
			elseif param:match('^Z%d%d$') then
				zi,zd = param:match('^Z(%d)(%d)$')
			elseif param:match('^D%d+$') then
				draft = param:match('^D(%d+)$')
			elseif param:match('^M%d+$') then
				misc = param:match('^M(%d+)$')
			else
				error("unrecognized format '"..block.."'")
			end
		end
	end
	-- if unspecified default to missing leading zeroes
	if not zeroes then zeroes = 'L' end
--	assert(zeroes=='L' or zeroes=='T' or zeroes=='D', "unsupported zeroes mode "..zeroes.." in format '"..block.."'")
	-- if no missing zeroes, set field to nil
	if zeroes=='D' then zeroes = nil end
	assert(mode=='A', "only files with absolute coordinates are supported")
	assert(xi==yi and xd==yd, "files with different precisions on X and Y axis are not yet supported")
	if zi then
		assert(zi==yi and zd==yd, "files with different precisions on Y and Z axis are not yet supported")
	end
	local format = _M.format(
		zeroes,
		tonumber(xi),
		tonumber(xd),
		seq and tonumber(seq),
		prep and tonumber(prep),
		draft and tonumber(draft),
		misc and tonumber(misc),
		zi and true or nil)
	if warn then
		local str = tostring(format)
		if str~=block then
			print("warning: invalid Gerber format "..block..", treating as "..str)
		else
			print("warning: obsolete Gerber format "..block)
		end
	end
	return format
end

if _NAME=='test' then
	local _print = print
	local msg
	function print(str) msg = str end
	expect({type='format', zeroes='L', integer=2, decimal=4}, load_format("FSLAX24Y24"))
	expect({type='format', zeroes='L', integer=4, decimal=4}, load_format("FSAX44Y44"))
	expect("warning: invalid Gerber format FSAX44Y44, treating as FSLAX44Y44", msg)
	expect({
		type = 'format',
		zeroes = nil,
		integer = 2,
		decimal = 4,
		has_z = true,
		sequence_number = 2,
		preparatory_function_code = 3,
		draft_code = 7,
		misc_code = 8,
	}, load_format("FSDAN2G3X24Y24Z24D7M8"))
	expect("warning: obsolete Gerber format FSDAN2G3X24Y24Z24D7M8", msg)
	print = _print
end

------------------------------------------------------------------------------

-- numbers are scaled by a factor of 10^8 to keep as many digits as possible in the integer part of lua numbers
-- also 1e-8 inches and 1e-8 millimeters are both an integer number of picometers
local decimal_shift = 8
_M.decimal_shift = decimal_shift

local function load_number(s, format)
	local sign,base = s:match('^([+-]?)(%d+)$')
	assert(sign and base)
	local size = format.integer + format.decimal
	if #base < size then
		if format.zeroes == 'L' then
			base = string.rep('0', size - #base) .. base
		elseif format.zeroes == 'T' then
			base = base .. string.rep('0', size - #base)
		elseif format.zeroes == 'D' then
			error("unexpected number "..s.." in format "..tostring(format))
		end
	end
	return (sign=='-' and -1 or 1) * tonumber(base) * 10 ^ (decimal_shift - format.decimal)
end
_M.load_number = load_number

local function save_number(n, format, long)
	local sign
	if n < 0 then
		sign = '-'
		n = -n
	else
		sign = ''
	end
	n = n / 10 ^ (decimal_shift - format.decimal)
	local ni = math.floor(n + 0.5)
--	assert(math.abs(n - ni) < 1e-8, "rounding error")
	local d = ni % 10 ^ format.decimal
	local i = (ni - d) / 10 ^ format.decimal
	assert(i < 10 ^ format.integer, "number is too big for format")
	n = string.format('%0'..format.integer..'d%0'..format.decimal..'d', i, d)
	assert(#n == format.integer + format.decimal)
	if not long then
		if format.zeroes == 'L' then
			n = n:match('^0*(.*.)$')
		elseif format.zeroes=='T' then
			n = n:match('^(..-)0*$')
		end
	end
	return sign..n
end
_M.save_number = save_number

------------------------------------------------------------------------------

local function load_aperture_parameter(s)
	local sign,base = s:match('^([+-]?)([%d.]+)$')
	assert(sign and base, "invalid aperture parameter '"..tostring(s).."'")
	local integer,decimal
	if base:match('%.') then
		integer,decimal = base:match('^(.*)%.(.*)$')
	else
		integer,decimal = base,""
	end
	assert(integer:match('^%d*$'))
	assert(decimal:match('^%d*$'))
--	assert(#decimal <= decimal_shift, "aperture parameter has too many decimal digits")
	return (sign=='-' and -1 or 1) * tonumber(integer..decimal) * 10 ^ (decimal_shift - #decimal)
end
_M.load_aperture_parameter = load_aperture_parameter

local function save_aperture_parameter(n)
	local sign
	if n < 0 then
		sign = '-'
		n = -n
	else
		sign = ''
	end
	local d = n % 10 ^ decimal_shift
	local i = (n - d) / 10 ^ decimal_shift
	n = tostring(i)
	if d~=0 then
		d = string.format('%f', d)
		local di,dd = d:match('^(%d*)%.(%d*)$')
		if not di then
			di,dd = d,''
		end
		di = string.rep('0', decimal_shift - #di)..di
		n = (n..'.'..di..dd):gsub('0*$', '')
	end
	return sign..n
end
_M.save_aperture_parameter = save_aperture_parameter

if _NAME=='test' then
	expect(8, decimal_shift)
	
	expect(0, load_aperture_parameter("0"))
	expect(50000000, load_aperture_parameter("0.5"))
	expect(10000000, load_aperture_parameter("0.1"))
	expect(1000000, load_aperture_parameter("0.01"))
	expect(100000, load_aperture_parameter("0.001"))
	expect(10000, load_aperture_parameter("0.0001"))
	expect(1000, load_aperture_parameter("0.00001"))
	expect(6250000, load_aperture_parameter("0.0625"))
	expect(1000000000, load_aperture_parameter("10"))
	expect(1, load_aperture_parameter("0.00000001"))
	expect(1.01, load_aperture_parameter("0.0000000101"))
	expect(1001*10^-3, load_aperture_parameter("0.00000001001"))
	expect(1.0001, load_aperture_parameter("0.000000010001"))
	expect(0.5, load_aperture_parameter("0.000000005"))
	
	expect("0", save_aperture_parameter(0))
	expect("0.5", save_aperture_parameter(50000000))
	expect("0.1", save_aperture_parameter(10000000))
	expect("0.01", save_aperture_parameter(1000000))
	expect("0.001", save_aperture_parameter(100000))
	expect("0.0001", save_aperture_parameter(10000))
	expect("0.00001", save_aperture_parameter(1000))
	expect("0.0625", save_aperture_parameter(6250000))
	expect("10", save_aperture_parameter(1000000000))
	expect("0.00000001", save_aperture_parameter(1))
	expect("0.0000000101", save_aperture_parameter(1.01))
	expect("0.00000001001", save_aperture_parameter(1.001))
	expect("0.000000010001", save_aperture_parameter(1.0001))
	expect("0.000000005", save_aperture_parameter(0.5))
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

local ops = {
	addition = '+',
	subtraction = '-',
	multiplication = 'x',
	division = '/',
}

local function save_expression(value)
	local t = type(value)
	if t=='number' then
		assert(value >= 0, "negative number in macro expression")
		return save_aperture_parameter(value)
	elseif t=='string' then
		return '$'..value
	elseif t=='table' then
		assert(value.type)
		local a,b = value[1],value[2]
		local ta,tb = type(a),type(b)
		ta = ta=='table' and a.type or ta
		tb = tb=='table' and b.type or tb
		a = save_expression(a)
		b = save_expression(b)
		if value.type=='multiplication' then
			if ta=='addition' or ta=='subtraction' then
				a = '('..a..')'
			end
			if tb=='addition' or tb=='subtraction' then
				b = '('..b..')'
			end
		elseif value.type=='division' then
			if ta=='addition' or ta=='subtraction' then
				a = '('..a..')'
			end
			if tb~='number' and tb~='string' then
				b = '('..b..')'
			end
		elseif value.type=='subtraction' then
			if tb~='number' and tb~='string' then
				b = '('..b..')'
			end
		end
		return a..assert(ops[value.type])..b
	else
		error("unsupported expression type "..tostring(t))
	end
end

if _NAME=='test' then
	expect("1-2", save_expression({type='subtraction', 1e8, 2e8}))
	expect("1-2+3", save_expression({type='addition', {type='subtraction', 1e8, 2e8}, 3e8}))
	expect("1x(2+3)", save_expression({type='multiplication', 1e8, {type='addition', 2e8, 3e8}}))
	expect("1-(2+3)", save_expression({type='subtraction', 1e8, {type='addition', 2e8, 3e8}}))
	expect("1/(2x3)", save_expression({type='division', 1e8, {type='multiplication', 2e8, 3e8}}))
	expect("1/(2/3)", save_expression({type='division', 1e8, {type='division', 2e8, 3e8}}))
	expect("1-2-3", save_expression({type='subtraction', {type='subtraction', 1e8, 2e8}, 3e8}))
	expect("1/2/3", save_expression({type='division', {type='division', 1e8, 2e8}, 3e8}))
	expect("(1+2)/3", save_expression({type='division', {type='addition', 1e8, 2e8}, 3e8}))
end

local ops = {
	['+'] = 'addition',
	['-'] = 'subtraction',
	['x'] = 'multiplication',
	['X'] = 'multiplication',
	['/'] = 'division',
}

local function tokenize(str)
	local tokens = {}
	for val,op in (str..'\0'):gmatch('([^%z()xX/+-]*)([%z()xX/+-])') do
		if val~="" then
			table.insert(tokens, val)
		end
		table.insert(tokens, op)
	end
	assert(tokens[#tokens]=='\0')
	tokens[#tokens] = nil
	
	-- special handling for (invalid) negative numbers
	local i = 1
	while i < #tokens do
		local a,b = tokens[i-1],tokens[i]
		if b=='-' and (i==1 or ops[a] or a=='(') then
			assert(not ops[tokens[i+1]], "an operator directly follows a minus sign in a macro expression")
			table.insert(tokens, i, '(')
			table.insert(tokens, i+1, '0')
			table.insert(tokens, i+4, ')')
			i = i + 5
		else
			i = i + 1
		end
	end
	
	return tokens
end

if _NAME=='test' then
	expect({'1'}, tokenize("1"))
	expect({'$1'}, tokenize("$1"))
	expect({'$A'}, tokenize("$A"))
	expect({'1','+','2'}, tokenize("1+2"))
	expect({'$A','-','1'}, tokenize("$A-1"))
	expect({'$A','x','$B'}, tokenize("$Ax$B"))
	expect({'1','/','2'}, tokenize("1/2"))
	expect({'(','$A',')'}, tokenize("($A)"))
	expect({'(','$A','+','2',')'}, tokenize("($A+2)"))
	expect({'(','1','+','2',')','x','3'}, tokenize("(1+2)x3"))
	expect({'1','+','2','+','3'}, tokenize("1+2+3"))
	expect({'1','+','2','x','3'}, tokenize("1+2x3"))
	expect({'2','x','3','x','$4'}, tokenize("2x3x$4"))
	expect({'(','0','-','1',')'}, tokenize("-1"))
	expect({'(','0','-','$1',')'}, tokenize("-$1"))
	expect({'(','0','-','1',')','x','2'}, tokenize("-1x2"))
	expect({'(','0','-','$1',')','x','2'}, tokenize("-$1x2"))
	expect({'1','x','(','0','-','2',')'}, tokenize("1x-2"))
	expect({'$1','x','(','0','-','2',')'}, tokenize("$1x-2"))
	expect({'(','0','-','1',')','-','(','0','-','2',')','-','(','0','-','3',')','-','(','0','-','4',')'}, tokenize("-1--2--3--4"))
end

local function maketree(tokens)
	local node = {}
	while #tokens >= 1 do
		local token = table.remove(tokens, 1)
		if token=='(' then
			table.insert(node, maketree(tokens))
		elseif token==')' then
			break
		else
			table.insert(node, token)
		end
	end
	if #node==1 then
		node = node[1]
	end
	return node
end

if _NAME=='test' then
	expect('1', maketree(tokenize("1")))
	expect('$1', maketree(tokenize("$1")))
	expect('$A', maketree(tokenize("$A")))
	expect({'1','+','2'}, maketree(tokenize("1+2")))
	expect({'$A','-','1'}, maketree(tokenize("$A-1")))
	expect({'$A','x','$B'}, maketree(tokenize("$Ax$B")))
	expect({'1','/','2'}, maketree(tokenize("1/2")))
	expect('$A', maketree(tokenize("($A)")))
	expect({'$A','+','2'}, maketree(tokenize("($A+2)")))
	expect({{'1','+','2'},'x','3'}, maketree(tokenize("(1+2)x3")))
	expect({'1','+','2','+','3'}, maketree(tokenize("1+2+3")))
	expect({'1','+','2','x','3'}, maketree(tokenize("1+2x3")))
	expect({'2','x','3','x','$4'}, maketree(tokenize("2x3x$4")))
end

local function prioritize(node)
	if type(node)~='table' then return node end
	local terms = {}
	local term = {prioritize(node[1])}
	local i = 2
	while i <= #node+1 do
		local token = node[i]
		if token=='+' or token=='-' or token==nil then
			if #term==1 then term = term[1] end
			table.insert(terms, term)
			if token==nil then break end
			table.insert(terms, token)
			term = {prioritize(node[i+1])}
		else
			table.insert(term, token)
			table.insert(term, prioritize(node[i+1]))
		end
		i = i + 2
	end
	if #terms==1 then terms = terms[1] end
	return terms
end

if _NAME=='test' then
	expect('1', prioritize(maketree(tokenize("1"))))
	expect('$1', prioritize(maketree(tokenize("$1"))))
	expect('$A', prioritize(maketree(tokenize("$A"))))
	expect({'1','+','2'}, prioritize(maketree(tokenize("1+2"))))
	expect({'$A','-','1'}, prioritize(maketree(tokenize("$A-1"))))
	expect({'$A','x','$B'}, prioritize(maketree(tokenize("$Ax$B"))))
	expect({'1','/','2'}, prioritize(maketree(tokenize("1/2"))))
	expect('$A', prioritize(maketree(tokenize("($A)"))))
	expect({'$A','+','2'}, prioritize(maketree(tokenize("($A+2)"))))
	expect({{'1','+','2'},'x','3'}, prioritize(maketree(tokenize("(1+2)x3"))))
	expect({'1','+','2','+','3'}, prioritize(maketree(tokenize("1+2+3"))))
	expect({'1','+',{'2','x','3'}}, prioritize(maketree(tokenize("1+2x3"))))
	expect({'2','x','3','x','$4'}, prioritize(maketree(tokenize("2x3x$4"))))
	expect({{{'1','+',{'2','x','3'}},'x','4'},'+',{'5','x','6'}}, prioritize(maketree(tokenize("(1+2x3)x4+5x6"))))
end

local function chain(exp)
	if not (#exp % 2 == 1) then
		print(">", table.unpack(exp))
	end
	assert(#exp % 2 == 1)
	local tree = exp[1]
	for i=2,#exp,2 do
		tree = {
			type = assert(ops[exp[i]]),
			tree,
			exp[i+1],
		}
	end
	return tree
end

local function convert(node)
	if type(node)=='table' then
		for i,child in ipairs(node) do
			node[i] = convert(child)
		end
		return chain(node)
	elseif node:sub(1,1)=='$' then
		return node:sub(2)
	elseif ops[node] then
		return node
	else
		return load_aperture_parameter(node)
	end
end

local function load_expression(str)
	local tokens = tokenize(str)
	local tree = prioritize(maketree(tokens))
	return convert(tree)
end

if _NAME=='test' then
	expect(100000000, load_expression("1"))
	expect("1", load_expression("$1"))
	expect("A", load_expression("$A"))
	expect({
		type = 'addition',
		100000000,
		200000000,
	}, load_expression("1+2"))
	expect({
		type = 'subtraction',
		"A",
		100000000,
	}, load_expression("$A-1"))
	expect({
		type = 'multiplication',
		"A",
		"B",
	}, load_expression("$Ax$B"))
	expect({
		type = 'division',
		100000000,
		200000000,
	}, load_expression("1/2"))
	expect("A", load_expression("($A)"))
	expect({
		type = 'addition',
		"A",
		200000000,
	}, load_expression("($A+2)"))
	expect({
		type = 'multiplication',
		{
			type = 'addition',
			100000000,
			200000000,
		},
		300000000,
	}, load_expression("(1+2)x3"))
	expect({
		type = 'addition',
		{
			type = 'addition',
			100000000,
			200000000,
		},
		300000000,
	}, load_expression("1+2+3"))
	expect({
		type = 'addition',
		100000000,
		{
			type = 'multiplication',
			200000000,
			300000000,
		},
	}, load_expression("1+2x3"))
	expect({
		type = 'multiplication',
		{
			type = 'multiplication',
			200000000,
			300000000,
		},
		"4",
	}, load_expression("2x3x$4"))
	
	expect("1", save_expression(load_expression("1")))
	expect("$1", save_expression(load_expression("$1")))
	expect("$A", save_expression(load_expression("$A")))
	expect("1+2", save_expression(load_expression("1+2")))
	expect("$A-1", save_expression(load_expression("$A-1")))
	expect("$Ax$B", save_expression(load_expression("$Ax$B")))
	expect("1/2", save_expression(load_expression("1/2")))
	expect("$A", save_expression(load_expression("($A)")))
	expect("$A+2", save_expression(load_expression("($A+2)")))
	expect("(1+2)x3", save_expression(load_expression("(1+2)x3")))
	expect("1+2+3", save_expression(load_expression("1+2+3")))
	expect("1+2x3", save_expression(load_expression("1+2x3")))
	expect("2x3x$4", save_expression(load_expression("2x3x$4")))
	expect("1-(2-3)", save_expression(load_expression("1-(2-3)")))
	expect("0-1-(0-2)-(0-3)-(0-4)", save_expression(load_expression("-1--2--3--4")))
	expect("(0-1)x(0-2)x(0-3)x(0-4)", save_expression(load_expression("-1x-2x-3x-4")))
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
	local parameters = {}
	for i,expression in ipairs(self.parameters) do
		parameters[i] = save_expression(expression)
	end
	return assert(shapes[self.shape])..','..table.concat(parameters, ',')
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
		table.insert(parameters, (load_expression(expression)))
	end
	assert(select(2, sparameters:gsub(',', ''))==#parameters)
	return _M.macro_primitive(shape, parameters)
end

------------------------------------------------------------------------------

local macro_variable_mt = {}

function macro_variable_mt:__tostring()
	return '$'..self.name..'='..save_expression(self.value)
end

function _M.macro_variable(name, value)
	if type(name)=='string' and name:match('^%d+$') then
		name = tonumber(name)
	end
	local macro_variable = setmetatable({type='variable'}, macro_variable_mt)
	macro_variable.name = name
	macro_variable.value = value
	return macro_variable
end

local function load_macro_variable(block)
	local name,value = block:match('^%$([^=]+)=(.*)$')
	assert(name and value)
	return _M.macro_variable(name, load_expression(value))
end

------------------------------------------------------------------------------

function _M.macro_instruction(data)
	local t = data.type
	if t=='comment' then
		return _M.macro_comment(data.text)
	elseif t=='primitive' then
		return _M.macro_primitive(data.shape, data.parameters)
	elseif t=='variable' then
		return _M.macro_variable(data.name, data.value)
	else
		error("unsupported macro instruction type "..tostring(t))
	end
end

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
	macro.script = {}
	for i,instruction in ipairs(script) do
		macro.script[i] = _M.macro_instruction(instruction)
	end
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
	local parameters
	if self.parameters then
		parameters = {}
		for i,parameter in ipairs(self.parameters) do
			parameters[i] = save_aperture_parameter(parameter)
		end
		parameters = ","..table.concat(parameters, "X")
	else
		parameters = ""
	end
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
	assert(dcode and dcode >= 10 and dcode <= 2^31)
	if parameters == "" then
		parameters = nil
	else
		assert(parameters:sub(1,1) == ",")
		parameters = parameters:sub(2)
		assert(parameters ~= "")
		local t = {}
		for parameter in parameters:gmatch('[^X]+') do
			parameter = load_aperture_parameter(parameter)
			table.insert(t, parameter)
		end
		parameters = t
	end
	return _M.aperture(dcode, shape, parameters)
end

------------------------------------------------------------------------------

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
				data[letter] = load_number(number, assert(format))
			elseif number:match('^%d+$') then
				data[letter] = tonumber(number)
			else
				error("unexpected number '"..number.."' for field '"..letter.."'")
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
	
	local data = { macros = {}, apertures = {} }
	
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
				assert(data.apertures[aperture.dcode] == nil, "two different apertures share the same D-code")
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
