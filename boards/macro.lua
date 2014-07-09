local _M = {}

------------------------------------------------------------------------------

local config = {}
local macro_primitives = {}

-- Circle, primitive code 1
function macro_primitives.circle(exposure, diameter, x, y)
	assert(exposure, "unexposed circle primitives are not supported")
	assert(type(diameter)=='number')
	assert(type(x)=='number')
	assert(type(y)=='number')
	return macro_primitives.polygon(exposure, config.circle_steps, x, y, diameter, 0)
end

local function rotate(point, rotation)
	return {
		x = point.x * math.cos(math.rad(rotation)) - point.y * math.sin(math.rad(rotation)),
		y = point.x * math.sin(math.rad(rotation)) + point.y * math.cos(math.rad(rotation)),
	}
end

-- Vector Line, primitive code 2 or 20
function macro_primitives.line(exposure, line_width, x0, y0, x1, y1, rotation)
	assert(exposure==1, "unexposed line primitives are not supported")
	assert(type(line_width)=='number')
	assert(type(x0)=='number')
	assert(type(y0)=='number')
	assert(type(x1)=='number')
	assert(type(y1)=='number')
	assert(type(rotation)=='number')
	local dx = x1 - x0
	local dy = y1 - y0
	local n = math.sqrt(dx*dx + dy*dy)
	if n == 0 then
		return nil -- empty primitive
	end
	dx = dx * line_width / n
	dy = dy * line_width / n
	local path = {}
	table.insert(path, rotate({x=x0-dy, y=y0+dx}, rotation))
	table.insert(path, rotate({x=x0+dy, y=y0-dx}, rotation))
	table.insert(path, rotate({x=x1+dy, y=y1-dx}, rotation))
	table.insert(path, rotate({x=x1-dy, y=y1+dx}, rotation))
	table.insert(path, rotate({x=x0-dy, y=y0+dx}, rotation))
	return path
end
macro_primitives.rectangle_ends = macro_primitives.line

-- Center Line, primitive code 21
function macro_primitives.rectangle_center(exposure, width, height, x, y, rotation)
	assert(exposure==1, "unexposed line primitives are not supported")
	assert(type(width)=='number')
	assert(type(height)=='number')
	assert(type(x)=='number')
	assert(type(y)=='number')
	assert(type(rotation)=='number')
	local dx = width / 2
	local dy = height / 2
	local path = {}
	table.insert(path, rotate({x=x-dx, y=y-dy}, rotation))
	table.insert(path, rotate({x=x+dx, y=y-dy}, rotation))
	table.insert(path, rotate({x=x+dx, y=y+dy}, rotation))
	table.insert(path, rotate({x=x-dx, y=y+dy}, rotation))
	table.insert(path, rotate({x=x-dx, y=y-dy}, rotation))
	return path
end

-- Lower Left Line, primitive code 22
function macro_primitives.rectangle_corner(...)
	assert(exposure==1, "unexposed line primitives are not supported")
	assert(type(width)=='number')
	assert(type(height)=='number')
	assert(type(x)=='number')
	assert(type(y)=='number')
	assert(type(rotation)=='number')
	local dx = width
	local dy = height
	local path = {}
	table.insert(path, rotate({x=x   , y=y   }, rotation))
	table.insert(path, rotate({x=x+dx, y=y   }, rotation))
	table.insert(path, rotate({x=x+dx, y=y+dy}, rotation))
	table.insert(path, rotate({x=x   , y=y+dy}, rotation))
	table.insert(path, rotate({x=x   , y=y   }, rotation))
	return path
end

-- Outline, primitive code 4
function macro_primitives.outline(exposure, points, ...)
	assert(exposure==1, "unexposed polygon primitives are not supported")
	assert(type(points)=='number')
	local path = {}
	for i=0,points do
		local x,y = select(i*2+1, ...)
		assert(type(x)=='number')
		assert(type(y)=='number')
		table.insert(path, {x=x, y=y})
	end
	assert(#path >= 3)
	assert(path[1].x == path[#path].x)
	assert(path[1].y == path[#path].y)
	local rotation = select((points+1)*2+1, ...)
	assert(type(rotation)=='number')
	for i=1,#path do
		path[i] = rotate(path[i], rotation)
	end
	return path
end

-- Polygon, primitive code 5
function macro_primitives.polygon(exposure, vertices, x, y, diameter, rotation)
	assert(exposure==1, "unexposed polygon primitives are not supported")
	assert(type(vertices)=='number')
	assert(type(x)=='number')
	assert(type(y)=='number')
	assert(type(diameter)=='number')
	assert(type(rotation)=='number')
	assert(x==0 and y==0 or rotation==0, "rotation is only allowed if the center point is on the origin")
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
	return path
end

-- Moiré, primitive code 6
function macro_primitives.moire(x, y, outer_diameter, ring_thickness, ring_gap, max_rings, cross_hair_thickness, cross_hair_length, rotation)
	assert(type(x)=='number')
	assert(type(y)=='number')
	assert(type(outer_diameter)=='number')
	assert(type(ring_thickness)=='number')
	assert(type(ring_gap)=='number')
	assert(type(max_rings)=='number')
	assert(type(cross_hair_length)=='number')
	assert(type(cross_hair_thickness)=='number')
	assert(type(rotation)=='number')
	assert(x==0 and y==0 or rotation==0, "rotation is only allowed if the center point is on the origin")
	print("warning: moiré primitive not yet supported, drawing a circle instead")
	local r = outer_diameter / 2
	rotation = math.rad(rotation)
	local circle_steps = config.circle_steps
	local path = {}
	for i=0,circle_steps do
		local a
		-- :KLUDGE: we force last vertex on the first, since sin(x) is not always equal to sin(x+2*pi)
		if i==circle_steps then i = 0 end
		local a = rotation + math.pi * 2 * (i / circle_steps)
		table.insert(path, {
			x = x + r * math.cos(a),
			y = y + r * math.sin(a),
		})
	end
	return path
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
	print("warning: thermal primitive not yet supported, drawing a circle instead")
	local r = outer_diameter / 2
	rotation = math.rad(rotation)
	local circle_steps = config.circle_steps
	local path = {}
	for i=0,circle_steps do
		local a
		-- :KLUDGE: we force last vertex on the first, since sin(x) is not always equal to sin(x+2*pi)
		if i==circle_steps then i = 0 end
		local a = rotation + math.pi * 2 * (i / circle_steps)
		table.insert(path, {
			x = x + r * math.cos(a),
			y = y + r * math.sin(a),
		})
	end
	return path
end

local function compile_expression(expression)
	if type(expression)=='number' then
		return expression
	else
		return expression
			:gsub('%$(%d+)', function(n) return "_VARS["..n.."]" end)
			:gsub('%$(%a%w+)', function(k) return "_VARS['"..k.."']" end)
			:gsub('[xX]', '*')
	end
end
assert(compile_expression("1.08239X$1")=="1.08239*_VARS[1]")

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
			write("_VARS['"..instruction.name.."'] = "..compile_expression(instruction.expression).."\n")
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
	local paths
	local env = setmetatable({}, {
		__index=function(_, k)
			return function(...)
				local path = assert(macro_primitives[k], "no generator function for primitive "..tostring(k))(...)
				table.insert(paths, path)
			end
		end,
		__newindex=function(_, k, v)
			error("macro script is trying to write a global")
		end,
	})
	local rawchunk
	if _VERSION == 'Lua 5.2' then
		rawchunk = assert(load(source, nil, 't', env))
	elseif _VERSION == 'Lua 5.1' then
		rawchunk = assert(loadstring(source))
		setfenv(rawchunk, env)
	end
	local chunk = function(...)
		paths = {}
		config.circle_steps = circle_steps
		rawchunk(...)
		config.circle_steps = nil
		local path
		if #paths==1 then
			path = paths[1]
		else
			local tesselation = require 'tesselation'
			local surface = tesselation.surface()
			for _,path in ipairs(paths) do
				surface:extend(path)
			end
			paths = surface.contour
			assert(#paths==1, "macro scripts must generate a single contour")
			path = {}
			for _,point in ipairs(paths[1]) do
				table.insert(path, {x=point.x, y=point.y})
			end
		end
		return path
	end
	return chunk
end

return _M
