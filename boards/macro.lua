local _M = {}
local _NAME = ... or 'test'

local math = require 'math'
local table = require 'table'
local path = require 'boards.path'

if _NAME=='test' then
	require 'test'
end

local exterior = path.exterior

------------------------------------------------------------------------------

local config = {}
local macro_primitives = {}

local function argcheck(f, i, t, ...)
	local v = select(i, ...)
	local tv = select('#', ...) < i and 'none' or type(v)
	if tv==t then
		return v
	else
		error("invalid argument #"..i.." to '"..f.."' ("..t.." expected, got "..tv..")")
	end
end

-- Circle, primitive code 1
function macro_primitives.circle(...)
	local exposure = argcheck('circle', 1, 'number', ...)
	local diameter = argcheck('circle', 2, 'number', ...)
	local x = argcheck('circle', 3, 'number', ...)
	local y = argcheck('circle', 4, 'number', ...)
	return macro_primitives.polygon(exposure, config.circle_steps, x, y, diameter, 0)
end

local function rotate(point, rotation)
	local a = math.rad(rotation)
	local c = math.cos(a)
	local s = math.sin(a)
	return {
		x = point.x * c - point.y * s,
		y = point.x * s + point.y * c,
	}
end

-- Vector Line, primitive code 2 or 20
function macro_primitives.line(...)
	local exposure = argcheck('vector line', 1, 'number', ...)
	local line_width = argcheck('vector line', 2, 'number', ...)
	local x0 = argcheck('vector line', 3, 'number', ...)
	local y0 = argcheck('vector line', 4, 'number', ...)
	local x1 = argcheck('vector line', 5, 'number', ...)
	local y1 = argcheck('vector line', 6, 'number', ...)
	local rotation = argcheck('vector line', 7, 'number', ...)
	local dx = x1 - x0
	local dy = y1 - y0
	local n = math.sqrt(dx*dx + dy*dy)
	if n == 0 then
		return nil -- empty primitive
	end
	local lx = line_width / 2 * dx / n
	local ly = line_width / 2 * dy / n
	local path = {}
	table.insert(path, rotate({x=x0-ly, y=y0+lx}, rotation))
	table.insert(path, rotate({x=x0+ly, y=y0-lx}, rotation))
	table.insert(path, rotate({x=x1+ly, y=y1-lx}, rotation))
	table.insert(path, rotate({x=x1-ly, y=y1+lx}, rotation))
	table.insert(path, rotate({x=x0-ly, y=y0+lx}, rotation))
	local hole
	if exposure==0 then
		hole = true
	end
	return { hole=hole, path }
end
macro_primitives.rectangle_ends = macro_primitives.line

-- Center Line, primitive code 21
function macro_primitives.rectangle_center(...)
	local exposure = argcheck('center line', 1, 'number', ...)
	local width = argcheck('center line', 2, 'number', ...)
	local height = argcheck('center line', 3, 'number', ...)
	local x = argcheck('center line', 4, 'number', ...)
	local y = argcheck('center line', 5, 'number', ...)
	local rotation = argcheck('center line', 6, 'number', ...)
	local dx = width / 2
	local dy = height / 2
	local path = {}
	table.insert(path, rotate({x=x-dx, y=y-dy}, rotation))
	table.insert(path, rotate({x=x+dx, y=y-dy}, rotation))
	table.insert(path, rotate({x=x+dx, y=y+dy}, rotation))
	table.insert(path, rotate({x=x-dx, y=y+dy}, rotation))
	table.insert(path, rotate({x=x-dx, y=y-dy}, rotation))
	local hole
	if exposure==0 then
		hole = true
	end
	return { hole=hole, path }
end

-- Lower Left Line, primitive code 22
function macro_primitives.rectangle_corner(...)
	local exposure = argcheck('lower left line', 1, 'number', ...)
	local width = argcheck('lower left line', 2, 'number', ...)
	local height = argcheck('lower left line', 3, 'number', ...)
	local x = argcheck('lower left line', 4, 'number', ...)
	local y = argcheck('lower left line', 5, 'number', ...)
	local rotation = argcheck('lower left line', 6, 'number', ...)
	local dx = width
	local dy = height
	local path = {}
	table.insert(path, rotate({x=x   , y=y   }, rotation))
	table.insert(path, rotate({x=x+dx, y=y   }, rotation))
	table.insert(path, rotate({x=x+dx, y=y+dy}, rotation))
	table.insert(path, rotate({x=x   , y=y+dy}, rotation))
	table.insert(path, rotate({x=x   , y=y   }, rotation))
	local hole
	if exposure==0 then
		hole = true
	end
	return { hole=hole, path }
end

-- Outline, primitive code 4
function macro_primitives.outline(...)
	local exposure = argcheck('outline', 1, 'number', ...)
	local points = argcheck('outline', 2, 'number', ...)
	local path = {}
	for i=0,points do
		local x,y = select(i*2+3, ...)
		assert(type(x)=='number')
		assert(type(y)=='number')
		table.insert(path, {x=x, y=y})
	end
	assert(#path >= 3)
	assert(path[1].x == path[#path].x)
	assert(path[1].y == path[#path].y)
	local rotation = select((points+1)*2+3, ...)
	assert(type(rotation)=='number')
	for i=1,#path do
		path[i] = rotate(path[i], rotation)
	end
	if not exterior(path) then
		local t = {}
		for i=1,#path do
			t[i] = path[#path+1-i]
		end
		path = t
	end
	local hole
	if exposure==0 then
		hole = true
	end
	return { hole=hole, path }
end

-- Polygon, primitive code 5
function macro_primitives.polygon(...)
	local exposure = argcheck('polygon', 1, 'number', ...)
	local vertices = argcheck('polygon', 2, 'number', ...)
	local x = argcheck('polygon', 3, 'number', ...)
	local y = argcheck('polygon', 4, 'number', ...)
	local diameter = argcheck('polygon', 5, 'number', ...)
	local rotation = argcheck('polygon', 6, 'number', ...)
	assert(x==0 and y==0 or rotation==0, "rotation is only allowed if the center point is on the origin")
	if diameter < 0 then
		print("warning: negative polygon diameter in macro")
		diameter = -diameter
	end
	if diameter == 0 then
		return {}
	end
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
	local hole
	if exposure==0 then
		hole = true
	end
	return { hole=hole, path }
end

-- helper function for moiré
local function quadrant_point(path, quadrant, x, y, offset)
	if quadrant==0 then
		table.insert(path, { x = x + offset.x, y = y + offset.y })
	elseif quadrant==1 then
		table.insert(path, { x = x - offset.y, y = y + offset.x })
	elseif quadrant==2 then
		table.insert(path, { x = x - offset.x, y = y - offset.y })
	elseif quadrant==3 then
		table.insert(path, { x = x + offset.y, y = y - offset.x })
	end
end

-- Moiré, primitive code 6
function macro_primitives.moire(...)
	local x = argcheck('outline', 1, 'number', ...)
	local y = argcheck('outline', 2, 'number', ...)
	local outer_diameter = argcheck('outline', 3, 'number', ...)
	local ring_thickness = argcheck('outline', 4, 'number', ...)
	local ring_gap = argcheck('outline', 5, 'number', ...)
	local max_rings = argcheck('outline', 6, 'number', ...)
	local cross_hair_thickness = argcheck('outline', 7, 'number', ...)
	local cross_hair_length = argcheck('outline', 8, 'number', ...)
	local rotation = argcheck('outline', 9, 'number', ...)
	assert(x==0 and y==0 or rotation==0, "rotation is only allowed if the center point is on the origin")
	assert(cross_hair_length >= outer_diameter, "unsupported moiré configuration") -- :TODO: this is a hard beast to tackle
	assert(cross_hair_thickness > 0, "unsupported moiré configuration") -- :FIXME: this is just concentric rings
	if outer_diameter < 0 then
		print("warning: negative moiré diameter in macro")
		outer_diameter = -outer_diameter
	end
	assert(outer_diameter > 0, "unsupported moiré configuration") -- :FIXME: this is just a cross
	local r = outer_diameter / 2
	rotation = math.rad(rotation)
	local circle_steps = config.circle_steps
	local quadrant_steps = math.ceil(circle_steps / 4)
	
	local paths = {}
	
	-- draw exterior
	local path = {}
	-- start with right cross hair
	do
		local i = cross_hair_length / 2
		local j = -cross_hair_thickness / 2
		local c = math.cos(rotation)
		local s = math.sin(rotation)
		quadrant_point(path, 0, x, y, {
			x = c * i - s * j,
			y = c * j + s * i,
		})
	end
	for q=0,3 do
		local c = math.cos(rotation)
		local s = math.sin(rotation)
		-- cross hair end
		local i = cross_hair_length / 2
		local j = cross_hair_thickness / 2
		quadrant_point(path, q, x, y, {
			x = c * i - s * j,
			y = c * j + s * i,
		})
		-- intersection with outer circle
		local a0 = math.asin(cross_hair_thickness / 2 / r)
		local a1 = math.pi/2 - a0
		-- draw a quadrant
		for i=0,quadrant_steps do
			local a = rotation + a0 + (a1 - a0) * i / quadrant_steps
			quadrant_point(path, q, x, y, {
				x = r * math.cos(a),
				y = r * math.sin(a),
			})
		end
		-- straight segment to cross hair end
		local i = cross_hair_thickness / 2
		local j = cross_hair_length / 2
		quadrant_point(path, q, x, y, {
			x = c * i - s * j,
			y = c * j + s * i,
		})
	end
	table.insert(paths, path)
	
	-- cut out internal rings
	for q=0,3 do
		local minr = math.sqrt(2) * cross_hair_thickness / 2
		local rings = 0
		local r0 = r - ring_thickness
		while r0 > minr do
			rings = rings + 1
			local path = {}
			-- outer edge
			do
				local a0 = math.asin(cross_hair_thickness / 2 / r0)
				local a1 = math.pi/2 - a0
				for i=0,quadrant_steps do
					local a = rotation + a1 + (a0 - a1) * i / quadrant_steps
					quadrant_point(path, q, x, y, {
						x = r0 * math.cos(a),
						y = r0 * math.sin(a),
					})
				end
			end
			-- inner edge
			local r1
			if rings >= max_rings then
				r1 = minr
			else
				r1 = r0 - ring_gap
			end
			if r1 <= minr then
				-- corner case
				local a = rotation + math.pi / 4
				local r = math.sqrt(2) * cross_hair_thickness / 2
				quadrant_point(path, q, x, y, {
					x = r * math.cos(a),
					y = r * math.sin(a),
				})
			else
				local a0 = math.asin(cross_hair_thickness / 2 / r1)
				local a1 = math.pi/2 - a0
				for i=0,quadrant_steps do
					local a = rotation + a0 + (a1 - a0) * i / quadrant_steps
					quadrant_point(path, q, x, y, {
						x = r1 * math.cos(a),
						y = r1 * math.sin(a),
					})
				end
			end
			-- close the path
			table.insert(path, {x=path[1].x, y=path[1].y})
			table.insert(paths, path)
			
			r0 = r1 - ring_thickness
		end
	end
	
	return paths
end

-- Thermal, primitive code 7
function macro_primitives.thermal(x, y, outer_diameter, inner_diameter, gap_thickness, rotation)
	assert(type(x)=='number')
	assert(type(y)=='number')
	assert(type(outer_diameter)=='number')
	assert(type(inner_diameter)=='number')
	assert(type(gap_thickness)=='number')
	assert(type(rotation)=='number')
	assert(x==0 and y==0 or rotation==0, "rotation is only allowed if the center point is on the origin")
	assert(gap_thickness > 0, "unsupported thermal configuration") -- :FIXME: this is just a ring
	if outer_diameter < inner_diameter then
		print("warning: thermal outer diameter is smaller than inner diameter")
		outer_diameter,inner_diameter = inner_diameter,outer_diameter
	end
	if outer_diameter == inner_diameter then
		return {}
	end
	if gap_thickness > outer_diameter then
		return {}
	end
	local circle_steps = config.circle_steps
	local quadrant_steps = math.ceil(circle_steps / 4)
	local r0 = outer_diameter / 2
	local r1 = inner_diameter / 2
	local minr = math.sqrt(2) * gap_thickness / 2
	rotation = math.rad(rotation)
	
	local paths = {}
	
	-- the whole thermal is like one moiré ring
	for q=0,3 do
		local path = {}
		-- outer edge
		do
			local a0 = math.asin(gap_thickness / 2 / r0)
			local a1 = math.pi/2 - a0
			for i=0,quadrant_steps do
				local a = rotation + a0 + (a1 - a0) * i / quadrant_steps
				quadrant_point(path, q, x, y, {
					x = r0 * math.cos(a),
					y = r0 * math.sin(a),
				})
			end
		end
		-- inner edge
		if r1 <= minr then
			-- corner case
			local a = rotation + math.pi/4
			local r = math.sqrt(2) * gap_thickness / 2
			quadrant_point(path, q, x, y, {
				x = r * math.cos(a),
				y = r * math.sin(a),
			})
		else
			local a0 = math.asin(gap_thickness / 2 / r1)
			local a1 = math.pi/2 - a0
			for i=0,quadrant_steps do
				local a = rotation + a1 + (a0 - a1) * i / quadrant_steps
				quadrant_point(path, q, x, y, {
					x = r1 * math.cos(a),
					y = r1 * math.sin(a),
				})
			end
		end
		-- close the path
		table.insert(path, {x=path[1].x, y=path[1].y})
		
		table.insert(paths, path)
	end
	
	return paths
end

local ops = {
	addition = '+',
	subtraction = '-',
	multiplication = '*',
	division = '/',
}

local function compile_expression(expression)
	local t = assert(type(expression)=='table' and expression.type)
	if t=='constant' then
		return expression.value
	elseif t=='variable' then
		local name = expression.name
		if type(name)=='string' then
			assert(not name:match('^%d+$'))
			name = "'"..name.."'"
		end
		return "_VARS["..name.."]"
	else--if t=='table' then
		local a,b = expression[1],expression[2]
		local ta,tb = type(a),type(b)
		ta = ta=='table' and a.type or ta
		tb = tb=='table' and b.type or tb
		a = compile_expression(a)
		b = compile_expression(b)
		if t=='multiplication' or t=='division' then
			if ta=='addition' or ta=='subtraction' then
				a = '('..a..')'
			end
			if tb=='addition' or tb=='subtraction' then
				b = '('..b..')'
			end
		end
		return a..assert(ops[t])..b
	end
end
_M.compile_expression = compile_expression

if _NAME=='test' then
	expect("1.08239*_VARS[1]", compile_expression({
		type = 'multiplication',
		{type='constant', value=1.08239},
		{type='variable', name=1},
	}))
	expect("_VARS['Y']*2", compile_expression({
		type = 'multiplication',
		{type='variable', name="Y"},
		{type='constant', value=2},
	}))
end

------------------------------------------------------------------------------

function _M.compile(macro, circle_steps)
	local script = macro.script
	local source = {}
	local function write(s) table.insert(source, s) end
	write("local _VARS = {...}\n")
	for _,instruction in ipairs(script) do
		if instruction.type=='comment' then
			-- ignore
		elseif instruction.type=='variable' then
			if type(instruction.name)=='number' then
				write("_VARS["..instruction.name.."]")
			else
				write("_VARS['"..instruction.name.."']")
			end
			write(" = "..compile_expression(instruction.value).."\n")
		elseif instruction.type=='primitive' then
			write(instruction.shape.."(")
			for i,expression in ipairs(instruction.parameters) do
				if i > 1 then write(", ") end
				write(compile_expression(expression))
			end
			write(")\n")
		else
			error("unsupported macro instruction type "..tostring(instruction.type))
		end
	end
	source = table.concat(source)
	local buffer
	local env = setmetatable({}, {
		__index=function(_, k)
			return function(...)
				local gpc = require 'gpc'
				local primitive = assert(macro_primitives[k], "no generator function for primitive "..tostring(k))(...)
				-- build up a primitive polygon
				local primpoly = gpc.new()
				for _,path in ipairs(primitive) do
					local c = {}
					for i=1,#path-1 do
						table.insert(c, path[i].x)
						table.insert(c, path[i].y)
					end
					if exterior(path) then
						primpoly = primpoly + gpc.new():add(c)
					else
						primpoly = primpoly - gpc.new():add(c)
					end
				end
				-- add it to the aperture
				if primitive.hole then
					buffer = buffer - primpoly
				else
					buffer = buffer + primpoly
				end
			end
		end,
		__newindex=function(_, k, v)
			error("macro script is trying to write a global")
		end,
	})
	local rawchunk
	if _VERSION == 'Lua 5.2' or _VERSION == 'Lua 5.3' then
		rawchunk = assert(load(source, nil, 't', env))
	elseif _VERSION == 'Lua 5.1' then
		rawchunk = assert(loadstring(source))
		setfenv(rawchunk, env)
	else
		error("unsupported Lua version")
	end
	local chunk = function(...)
		local gpc = require 'gpc'
		-- setup
		buffer = gpc.new()
		config.circle_steps = circle_steps
		-- run macro
		rawchunk(...)
		-- cleanup
		config.circle_steps = nil
		local paths = {}
		for c=1,buffer:get() do
			local path = {}
			local n,h = buffer:get(c)
			for i=1,n do
				local x,y = buffer:get(c, i)
				path[i] = {x=x, y=y}
			end
			path[n+1] = {x=path[1].x, y=path[1].y}
			if h == exterior(path) then
				local t = {}
				for i=1,#path do
					t[i] = path[#path+1-i]
				end
				path = t
			end
			table.insert(paths, path)
		end
		buffer = nil
		-- return data
		return paths
	end
	return chunk
end

------------------------------------------------------------------------------

local function analyze_expression(expression, variables)
	local t = type(expression)
	if t=='number' then
		return {type='constant', value=expression}
	elseif t=='string' then
		if expression:match('^%d+') then
			local index = tonumber(expression)
			local variable = variables[index]
			if not variable then
				variable = {type='variable', name=index}
				variables[index] = variable
			end
			return variable
		else
			return assert(variables[expression], "variable "..tostring(expression).." is used before being defined")
		end
	elseif t=='table' then
		local type = assert(expression.type)
		assert(#expression==2, "expression of type "..tostring(type).." has "..#expression.." operands")
		return {type=type, analyze_expression(expression[1], variables), analyze_expression(expression[2], variables)}
	else
		error("unexpected expression type "..t)
	end
end

local function expand_script(script)
	local script2 = {}
	local variables = {}
	for _,instruction in ipairs(script) do
		if instruction.type=='comment' then
			table.insert(script2, instruction)
		elseif instruction.type=='variable' then
			local name = instruction.name
			if name:match('^%d+$') then
				name = tonumber(name)
			end
			local variable = {
				type = 'variable',
				name = name,
				value = analyze_expression(instruction.value, variables),
			}
			table.insert(script2, variable)
			variables[name] = variable
		elseif instruction.type=='primitive' then
			local instruction2 = {
				type = 'primitive',
				shape = instruction.shape,
				parameters = {},
			}
			for i,expression in ipairs(instruction.parameters) do
				instruction2.parameters[i] = analyze_expression(expression, variables)
			end
			table.insert(script2, instruction2)
		else
			error("unsupported macro instruction type "..tostring(instruction.type))
		end
	end
	return script2
end

local primitive_dimensions = {}

primitive_dimensions.circle = {{boolean=1}, {length=1}, {length=1}, {length=1}}
primitive_dimensions.line = {{boolean=1}, {length=1}, {length=1}, {length=1}, {length=1}, {length=1}, {angle=1}}
primitive_dimensions.rectangle_ends = primitive_dimensions.line
primitive_dimensions.rectangle_center = {{boolean=1}, {length=1}, {length=1}, {length=1}, {length=1}, {angle=1}}
primitive_dimensions.rectangle_corner = {{boolean=1}, {length=1}, {length=1}, {length=1}, {length=1}, {angle=1}}
primitive_dimensions.polygon = {{boolean=1}, {}, {length=1}, {length=1}, {length=1}, {angle=1}}
primitive_dimensions.moire = {{length=1}, {length=1}, {length=1}, {length=1}, {length=1}, {}, {length=1}, {length=1}, {angle=1}}
primitive_dimensions.thermal = {{length=1}, {length=1}, {length=1}, {length=1}, {length=1}, {angle=1}}

-- special case
function primitive_dimensions.outline(exposure, npoints, x, y, ...)
	local dimensions = {{boolean=1}, {}, {length=1}, {length=1}}
	for i=1,select('#', ...)-1 do
		table.insert(dimensions, {length=1})
	end
	table.insert(dimensions, {angle=1})
	return dimensions
end

local function apply_constraint(expression, dimension)
	local t = expression.type
	if t=='constant' then
		expression.dimension = dimension
	elseif t=='variable' then
		expression.dimension = dimension
	elseif t=='addition' or t=='subtraction' then
		-- to add things, both must be of the same dimension
		apply_constraint(expression[1], dimension, open)
		apply_constraint(expression[2], dimension, open)
	elseif t=='multiplication' or t=='division' then
		-- :TODO: use partial/relative dimensions
	else
		error("unsupported expression type "..tostring(t))
	end
end

local function collect_values(expression, variables, constants)
	local t = expression.type
	if t=='constant' then
		constants[expression] = true
	elseif t=='variable' then
		variables[expression] = true
	elseif t=='addition' or t=='subtraction' or t=='multiplication' or t=='division' then
		assert(#expression==2)
		collect_values(expression[1], variables, constants)
		collect_values(expression[2], variables, constants)
	else
		error("unsupported expression type "..tostring(t))
	end
end

function _M.analyze_script(script)
	script = expand_script(script)
	-- apply known dimensions
	for i=#script,1,-1 do
		local instruction = script[i]
		if instruction.type=='comment' then
			-- ignore
		elseif instruction.type=='variable' then
			if instruction.dimension then
				apply_constraint(instruction.value, instruction.dimension)
			end
		elseif instruction.type=='primitive' then
			local instruction2 = {
				type = 'primitive',
				shape = instruction.shape,
				parameters = {},
			}
			local dimensions = assert(primitive_dimensions[instruction.shape], "no dimension for primitive shape "..tostring(instruction.shape))
			if type(dimensions)=='function' then
				dimensions = dimensions(table.unpack(instruction.parameters))
			end
			for i,expression in ipairs(instruction.parameters) do
				apply_constraint(expression, dimensions[i])
			end
		end
	end
	-- collect variables and constants
	local variables = {}
	local constants = {}
	for _,instruction in ipairs(script) do
		if instruction.type=='comment' then
			-- ignore
		elseif instruction.type=='variable' then
			variables[instruction] = true
			collect_values(instruction.value, variables, constants)
		elseif instruction.type=='primitive' then
			for _,expression in ipairs(instruction.parameters) do
				collect_values(expression, variables, constants)
			end
		end
	end
	return script,variables,constants
end

local function copy_expression(expression, value_map)
	local t = expression.type
	if t=='constant' or t=='variable' then
		local copy = value_map[expression]
		if not copy then
			copy = {
				type = t,
				name = expression.name,
				value = expression.value,
				dimension = expression.dimension,
				unit = expression.unit,
			}
			value_map[expression] = copy
		end
		return copy
	else
		return {
			type = t,
			copy_expression(expression[1], value_map),
			copy_expression(expression[2], value_map),
		}
	end
end

function _M.copy_script(script)
	local value_map = {}
	local copy = {}
	local script2 = {}
	local variables = {}
	for _,instruction in ipairs(script) do
		if instruction.type=='comment' then
			table.insert(copy, {
				type = 'comment',
				text = instruction.text,
			})
		elseif instruction.type=='variable' then
			local name = instruction.name
			if name:match('^%d+$') then
				name = tonumber(name)
			end
			local variable = {
				type = 'variable',
				name = instruction.name,
				value = copy_expression(instruction.value, value_map),
			}
			table.insert(copy, variable)
			value_map[instruction] = variable
		elseif instruction.type=='primitive' then
			local primitive = {
				type = 'primitive',
				shape = instruction.shape,
				parameters = {},
			}
			for i,expression in ipairs(instruction.parameters) do
				primitive.parameters[i] = copy_expression(expression, value_map)
			end
			table.insert(copy, primitive)
		else
			error("unsupported macro instruction type "..tostring(instruction.type))
		end
	end
	local variables,constants = {},{}
	for _,value in pairs(value_map) do
		if value.type=='constant' then
			constants[value] = true
		elseif value.type=='variable' then
			variables[value] = true
		end
	end
	return copy,variables,constants
end

local function simplify_expression(expression, variables)
	local t = assert(type(expression)=='table' and expression.type)
	if t=='constant' then
		return expression.value
	elseif t=='variable' then
		return tostring(expression.name)
	else
		assert(#expression==2, "expression of type "..tostring(t).." has "..#expression.." operands")
		return {type=t, simplify_expression(expression[1]), simplify_expression(expression[2])}
	end
end

function _M.simplify_script(script)
	local script2 = {}
	for _,instruction in ipairs(script) do
		if instruction.type=='comment' then
			table.insert(script2, instruction)
		elseif instruction.type=='variable' then
			local name = instruction.name
			if name:match('^%d+$') then
				name = tonumber(name)
			end
			local variable = {
				type = 'variable',
				name = name,
				value = simplify_expression(instruction.value),
			}
			table.insert(script2, variable)
		elseif instruction.type=='primitive' then
			local instruction2 = {
				type = 'primitive',
				shape = instruction.shape,
				parameters = {},
			}
			for i,expression in ipairs(instruction.parameters) do
				instruction2.parameters[i] = simplify_expression(expression)
			end
			table.insert(script2, instruction2)
		else
			error("unsupported macro instruction type "..tostring(instruction.type))
		end
	end
	return script2
end

------------------------------------------------------------------------------

return _M
