local _M = {}

local math = require 'math'
local table = require 'table'
local macro = require 'boards.macro'

local unpack = unpack or table.unpack

------------------------------------------------------------------------------

local aperture_scales = {
	in_pm = 25400000000,
	mm_pm =  1000000000,
	in_mm = 25.4,
	mm_mm =  1,
}

local function generate_aperture_hole(x, y, scale, circle_steps)
	local path
	if y then
		path = {
			{x=-x/2*scale, y=-y/2*scale},
			{x=-x/2*scale, y= y/2*scale},
			{x= x/2*scale, y= y/2*scale},
			{x= x/2*scale, y=-y/2*scale},
			{x=-x/2*scale, y=-y/2*scale},
		}
	elseif x and x ~= 0 then
		local d = x
		path = {}
		local r = d / 2 * scale
		for i=0,circle_steps do
			if i==circle_steps then i = 0 end -- :KLUDGE: sin(2*pi) is not zero, but an epsilon, so we force it
			local a = -math.pi * 2 * (i / circle_steps)
			table.insert(path, {x=r*math.cos(a), y=r*math.sin(a)})
		end
	end
	return path
end

function _M.generate_aperture_paths(aperture, board_unit, circle_steps)
	local shape = aperture.shape
	if not shape and not aperture.macro then
		return {}
	end
	local parameters = aperture.parameters
	local scale_name = aperture.unit..'_'..board_unit
	local scale = assert(aperture_scales[scale_name], "unsupported aperture scale "..scale_name)
	
	local paths
	if shape=='circle' then
		local d,hx,hy = aperture.diameter,aperture.hole_width,aperture.hole_height
		assert(d, "circle aperture has no diameter")
		local path = {concave=true}
		if d ~= 0 then
			local r = d / 2 * scale
			for i=0,circle_steps do
				if i==circle_steps then i = 0 end -- :KLUDGE: sin(2*pi) is not zero, but an epsilon, so we force it
				local a = math.pi * 2 * (i / circle_steps)
				table.insert(path, {x=r*math.cos(a), y=r*math.sin(a)})
			end
		end
		local hole = generate_aperture_hole(hx, hy, scale, circle_steps)
		paths = { path, hole }
	elseif shape=='rectangle' then
		local x,y,hx,hy = aperture.width,aperture.height,aperture.hole_width,aperture.hole_height
		assert(x, "rectangle aperture has no width")
		assert(y, "rectangle aperture has no height")
		local path = {
			concave=true,
			{x=-x/2*scale, y=-y/2*scale},
			{x= x/2*scale, y=-y/2*scale},
			{x= x/2*scale, y= y/2*scale},
			{x=-x/2*scale, y= y/2*scale},
			{x=-x/2*scale, y=-y/2*scale},
		}
		local hole = generate_aperture_hole(hx, hy, scale, circle_steps)
		paths = { path, hole }
	elseif shape=='obround' then
		assert(circle_steps % 2 == 0, "obround apertures are only supported when circle_steps is even")
		local x,y,hx,hy = aperture.width,aperture.height,aperture.hole_width,aperture.hole_height
		assert(x, "obround aperture has no width")
		assert(y, "obround aperture has no height")
		local path = {concave=true}
		if y > x then
			local straight = (y - x) * scale
			local r = x / 2 * scale
			for i=0,circle_steps/2 do
				local a = math.pi * 2 * (i / circle_steps)
				table.insert(path, {x=r*math.cos(a), y=r*math.sin(a)+straight/2})
			end
			for i=circle_steps/2,circle_steps do
				if i==circle_steps then i = 0 end -- :KLUDGE: sin(2*pi) is not zero, but an epsilon, so we force it
				local a = math.pi * 2 * (i / circle_steps)
				table.insert(path, {x=r*math.cos(a), y=r*math.sin(a)-straight/2})
			end
			table.insert(path, {x=r, y=straight/2})
		else
			local straight = (x - y) * scale
			local r = y / 2 * scale
			for i=0,circle_steps/2 do
				local a = math.pi * 2 * (i / circle_steps)
				table.insert(path, {x=r*math.sin(a)+straight/2, y=-r*math.cos(a)})
			end
			for i=circle_steps/2,circle_steps do
				if i==circle_steps then i = 0 end -- :KLUDGE: sin(2*pi) is not zero, but an epsilon, so we force it
				local a = math.pi * 2 * (i / circle_steps)
				table.insert(path, {x=r*math.sin(a)-straight/2, y=-r*math.cos(a)})
			end
			table.insert(path, {x=straight/2, y=-r})
		end
		local hole = generate_aperture_hole(hx, hy, scale, circle_steps)
		paths = { path, hole }
	elseif shape=='polygon' then
		local d,steps,angle,hx,hy = aperture.diameter,aperture.steps,aperture.angle,aperture.hole_width,aperture.hole_height
		assert(d, "polygon aperture has no diameter")
		assert(steps, "polygon aperture has no number of vertices")
		angle = angle or 0
		local path = {concave=true}
		if d ~= 0 then
			local r = d / 2 * scale
			for i=0,steps do
				if i==steps then i = 0 end -- :KLUDGE: sin(2*pi) is not zero, but an epsilon, so we force it
				local a = math.pi * 2 * (i / steps) + math.rad(angle)
				table.insert(path, {x=r*math.cos(a), y=r*math.sin(a)})
			end
		end
		local hole = generate_aperture_hole(hx, hy, scale, circle_steps)
		paths = { path, hole }
	elseif aperture.macro then
		local chunk = macro.compile(aperture.macro, circle_steps)
		local data = chunk(unpack(aperture.parameters or {}))
		paths = {}
		for i,dpath in ipairs(data) do
			local path = {}
			for j,point in ipairs(dpath) do
				path[j] = {
					x = point.x * scale,
					y = point.y * scale,
				}
			end
			paths[i] = path
		end
	else
		error("unsupported aperture shape "..tostring(shape))
	end
	
	return paths
end

------------------------------------------------------------------------------

return _M
