local _M = {}

local io = require 'io'
local table = require 'table'
local string = require 'string'
local gerber = require 'gerber.blocks'

_M.decimal_shift = gerber.decimal_shift

------------------------------------------------------------------------------

local tool_mt = {}

function tool_mt:__tostring()
	local parameters = {}
	for _,name in ipairs(self.parameters) do
		table.insert(parameters, name..gerber.save_aperture_parameter(self.parameters[name]))
	end
	return string.format('T%02d%s', self.tcode, table.concat(parameters))
end

function _M.tool(tcode, parameters)
	local data = {
		type = 'tool',
		tcode = tcode,
		parameters = parameters,
	}
	return setmetatable(data, tool_mt)
end

local function load_tool(block)
	-- may be a tool definition (in header) or a tool selection (in program)
	local tcode,sparameters = block:match('^T(%d+)(.*)$')
	assert(tcode and sparameters)
	tcode = tonumber(tcode)
	local parameters = {}
	for name,value in string.gmatch(sparameters, '(%a)([%d%.-]+)') do
		parameters[name] = gerber.load_aperture_parameter(value)
		table.insert(parameters, name) -- for order
	end
	return _M.tool(tcode, parameters)
end

------------------------------------------------------------------------------

local comment_mt = {}

function comment_mt:__tostring()
	return string.format(';%s', self.comment)
end

function _M.comment(text)
	local data = {
		type = 'comment',
		text = text,
	}
	return setmetatable(data, comment_mt)
end

local function load_comment(block)
	local text = block:match('^%s*;%s*(.-)%s*$')
	assert(text, "could not parse comment")
	return _M.comment(text)
end

------------------------------------------------------------------------------

local header_mt = {}

function header_mt:__tostring()
	local words = {self.name}
	for _,parameter in ipairs(self.parameters) do
		table.insert(words, parameter)
	end
	return table.concat(parameters, ",")
end

function _M.header(name, parameters)
	local data = {
		type = 'header',
		name = name,
		parameters = parameters,
	}
	return setmetatable(data, header_mt)
end

local function load_header(block)
	-- may be a tool definition (in header) or a tool selection (in program)
	local words = {}
	for word in block:gmatch('[^,]+') do
		table.insert(words, word)
	end
	assert(block == table.concat(words, ","))
	local name = table.remove(words, 1)
	local parameters = words
	return _M.header(name, parameters)
end

------------------------------------------------------------------------------

local function save_directive(self, long)
	local G = self.G and string.format('G%02d', self.G) or ''
	local X = self.X and 'X'..gerber.save_number(self.X, self.format, long) or ''
	local Y = self.Y and 'Y'..gerber.save_number(self.Y, self.format, long) or ''
	local T = self.T and string.format('T%02d', self.T) or ''
	local M = self.M and string.format('M%02d', self.M) or ''
	return G..X..Y..T..M
end

local directive_mt = {}

function directive_mt:__tostring()
	return save_directive(self)
end

function _M.directive(data, format)
	local directive = setmetatable({type='directive'}, directive_mt)
	if data.X or data.Y then
		directive.format = assert(format)
	end
	for k,v in pairs(data) do
		directive[k] = v
	end
	return directive
end

local function load_directive(block, format)
	local data = {}
	for letter,number in block:gmatch('(%a)([0-9+-]+)') do
		if letter:match('[XY]') then
			local i = 1
			local k = letter
			while data[k] do
				i = i + 1
				k = letter..i
			end
			data[k] = gerber.load_number(number, assert(format))
		elseif number:match('^%d+$') then
			data[letter] = tonumber(number)
		else
			error("unexpected number '"..number.."' for field '"..letter.."'")
		end
	end
	local directive = _M.directive(data, format)
--	local short,long = tostring(directive),save_directive(directive, true)
--	assert(block == short or block == long, "block '"..block.."' has been converted to '"..short.."' or '"..long.."'")
	return directive
end

------------------------------------------------------------------------------

function _M.load(filename)
	local file = assert(io.open(filename, 'rb'))
	local content = assert(file:read('*all'))
	assert(file:close())
	
	content = content:gsub('\r', '')

	local data = { headers = {}, tools = {} }
	-- :FIXME: find out how excellon files declare their format
	data.format = { integer = nil, decimal = nil, zeroes = 'T' } -- default is leading zeroes present (LZ), so 'T' missing
	local header = nil
	for block in content:gmatch('[^\n]+') do
		if header then
			if block=='M95' or block=='%' then
				header = false
			else
				if block:match('^T%d') then
					local tool = load_tool(block)
					data.tools[tool.tcode] = tool
					table.insert(data.headers, tool)
				elseif block:match('^;FILE_FORMAT=') then
					local i,d = block:match('^;FILE_FORMAT=(%d+):(%d+)$')
					data.format.integer = tonumber(i)
					data.format.decimal = tonumber(d)
					table.insert(data.headers, load_comment(block))
				elseif block:match('^;') then
					table.insert(data.headers, load_comment(block))
				elseif block=='M71' then
					table.insert(data.headers, load_header(block))
					if data.format.integer==nil and data.format.decimal==nil then
						data.format.integer,data.format.decimal = 3,3
					end
				elseif block=='M72' then
					table.insert(data.headers, load_header(block))
					if data.format.integer==nil and data.format.decimal==nil then
						data.format.integer,data.format.decimal = 2,4
					end
				elseif block:match('INCH') or block:match('METRIC') or block:match('LZ') or block:match('TZ') then
					for word in block:gmatch('[^,]+') do
						if word=='LZ' then -- header is what is present
							data.format.zeroes = 'T' -- format is what we omit
						elseif word=='TZ' then
							data.format.zeroes = 'L'
						elseif word=='INCH' then
							if data.format.integer==nil and data.format.decimal==nil then
								data.format.integer,data.format.decimal = 2,4
							end
							table.insert(data.headers, load_header(word))
						elseif word=='METRIC' then
							if data.format.integer==nil and data.format.decimal==nil then
								data.format.integer,data.format.decimal = 3,3
							end
							table.insert(data.headers, load_header(word))
						elseif word:match('^0+%.0+$') then
							local integer,decimal = word:match('^(0+)%.(0+)$')
							data.format.integer = #integer
							data.format.decimal = #decimal
						else
							error("unsupported keyword '"..word.."' in format header")
						end
					end
				else
					-- this is a very basic parameter parsing
					table.insert(data.headers, load_header(block))
				end
			end
		else
			if block=='%' then
				-- ignore
			elseif block=='M48' then
				header = true
			elseif block:match('^T') then
				if data.format.integer==nil and data.format.decimal==nil then
					data.format.integer,data.format.decimal = 2,4
				end
				table.insert(data, load_tool(block, data.format))
			elseif block:match('^[MXYG]') then
				if data.format.integer==nil and data.format.decimal==nil then
					data.format.integer,data.format.decimal = 2,4
				end
				table.insert(data, load_directive(block, data.format))
			elseif block:match('^;') then
				table.insert(data, load_comment(block))
			else
				table.insert(data, block)
			end
		end
	end
	
	return data
end

function _M.save(data, filename)
	local file = assert(io.open(filename, 'wb'))
	if data.headers then
		file:write('%\r\nM48\r\n')
		for _,header in ipairs(data.headers) do
			file:write(tostring(header)..'\r\n')
		end
		file:write('%\r\n')
	end
	for _,block in ipairs(data) do
		file:write(tostring(block)..'\r\n')
	end
	assert(file:close())
	return true
end

return _M
