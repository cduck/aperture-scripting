local _M = {}

local region = require 'boards.region'

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
	return { path }
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
	return { path }
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
	return { path }
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
	return { path }
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
	return { path }
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
	assert(cross_hair_length >= outer_diameter, "unsupported moiré configuration") -- :TODO: this is a hard beast to tackle
	assert(cross_hair_thickness > 0, "unsupported moiré configuration") -- :FIXME: this is just concentric rings
	local r = outer_diameter / 2
	rotation = math.rad(rotation)
	local circle_steps = config.circle_steps
	local quadrant_steps = math.ceil(circle_steps / 4)
	
	local paths = {}
	
	-- draw exterior
	local path = {}
	-- start with right cross hair
	quadrant_point(path, 0, x, y, {
		x = cross_hair_length / 2,
		y = -cross_hair_thickness / 2,
	})
	for q=0,3 do
		-- cross hair end
		quadrant_point(path, q, x, y, {
			x = cross_hair_length / 2,
			y = cross_hair_thickness / 2,
		})
		-- intersection with outer circle
		local a0 = math.asin(cross_hair_thickness / 2 / r)
		local a1 = math.pi/2 - a0
		-- draw a quadrant
		for i=0,quadrant_steps do
			local a = a0 + (a1 - a0) * i / quadrant_steps
			quadrant_point(path, q, x, y, {
				x = r * math.cos(a),
				y = r * math.sin(a),
			})
		end
		-- straight segment to cross hair end
		quadrant_point(path, q, x, y, {
			x = cross_hair_thickness / 2,
			y = cross_hair_length / 2,
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
					local a = a1 + (a0 - a1) * i / quadrant_steps
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
				quadrant_point(path, q, x, y, {
					x = cross_hair_thickness / 2,
					y = cross_hair_thickness / 2,
				})
			else
				local a0 = math.asin(cross_hair_thickness / 2 / r1)
				local a1 = math.pi/2 - a0
				for i=0,quadrant_steps do
					local a = a0 + (a1 - a0) * i / quadrant_steps
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
	return { path }
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
	local current_paths
	local env = setmetatable({}, {
		__index=function(_, k)
			return function(...)
				local paths2 = assert(macro_primitives[k], "no generator function for primitive "..tostring(k))(...)
				for _,path in ipairs(paths2) do
					table.insert(current_paths, path)
				end
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
		current_paths = {}
		config.circle_steps = circle_steps
		rawchunk(...)
		config.circle_steps = nil
		local paths = current_paths
		current_paths = nil
		--[[
		-- this code splits overlapping paths
		if #paths>=2 then
			local tesselation = require 'tesselation'
			local surface = tesselation.surface()
			for _,path in ipairs(paths) do
				if region.exterior(path) then
					surface:extend(path)
				else
					local reverse = {}
					for i=1,#path do
						reverse[i] = path[#path+1-i]
					end
					surface:drill(reverse, {x=0, y=0})
				end
			end
			paths = surface.contour
		end
		--]]
		return paths
	end
	return chunk
end

return _M
