local _M = {}

local io = require 'io'
local math = require 'math'
local table = require 'table'
local lfs = require 'lfs'
local pathlib = require 'path'
local gerber = require 'gerber'
local excellon = require 'excellon'
local dump = require 'dump'
local crypto = require 'crypto'

pathlib.install()

local unpack = unpack or table.unpack

------------------------------------------------------------------------------

local scales = {
	IN = 25.4,
	MM = 1,
}

local circle_steps = 64
--local circle_steps = 360

local macro_primitives = {}

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
	print("moiré primitive not yet supported, drawing a circle instead")
	local r = outer_diameter / 2
	rotation = math.rad(rotation)
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

function macro_primitives.thermal(x, y, outer_diameter, inner_diameter, gap_thickness, rotation)
	assert(type(x)=='number')
	assert(type(y)=='number')
	assert(type(outer_diameter)=='number')
	assert(type(inner_diameter)=='number')
	assert(type(gap_thickness)=='number')
	assert(type(rotation)=='number')
	assert(x==0 and y==0 or rotation==0, "rotation is only allowed if the center point is on the origin")
	print("thermal primitive not yet supported, drawing a circle instead")
	local r = outer_diameter / 2
	rotation = math.rad(rotation)
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
	assert(rotation==0, "non-zero rotation of outline macro primitive is not yet supported")
	return path
end

--[[
function macro_primitives.circle(exposure, diameter, x, y)
	assert(exposure, "unexposed circle primitives are not supported")
	assert(type(diameter)=='number')
	assert(type(x)=='number')
	assert(type(y)=='number')
	return macro_primitives.polygon(exposure, circle_steps, x, y, diameter, 0)
end
--]]

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

local function load_macro(data, unit)
	local macro = {}
	macro.name = data.name
	assert(#data.script==1 and data.script[1].type=='primitive', "only macros with 1 primitive are supported")
	local script = "local _VARS = {...}\n"
	for _,instruction in ipairs(data.script) do
		if instruction.type=='comment' then
			-- ignore
		elseif instruction.type=='variable' then
			script = script.."_VARS['"..instruction.name.."'] = "..compile_expression(instruction.expression).."\n"
		elseif instruction.type=='primitive' then
			script = script..instruction.shape.."("
			for i,expression in ipairs(instruction.parameters) do
				if i > 1 then script = script..", " end
				script = script..compile_expression(expression)
			end
			script = script..")\n"
		else
			error("unsupported macro instruction type "..tostring(instruction.type))
		end
	end
--	print("========================================")
--	print(script)
--	print("========================================")
	local paths
	local env = setmetatable({}, {
		__index=function(_, k)
			return function(...)
--				print("primitive", k, ...)
				local path = assert(macro_primitives[k], "no generator function for primitive "..tostring(k))(...)
				table.insert(paths, path)
			end
		end,
		__newindex=function(_, k, v)
			error("macro script is trying to write a global")
		end,
	})
	local chunk
	if _VERSION == 'Lua 5.2' then
		chunk = assert(load(script, nil, 't', env))
	elseif _VERSION == 'Lua 5.1' then
		chunk = assert(loadstring(script))
		setfenv(chunk, env)
	end
	macro.script = function(...)
		paths = {}
		chunk(...)
		assert(#paths==1, "macro scripts must generate a single path")
		return paths[1]
	end
	return macro
end

local function load_aperture(data, macros, unit)
	local dcode = data.dcode
	local shape = data.shape
	local scale = assert(scales[unit], "unsupported aperture unit "..tostring(unit))
	local extents,path
	if shape=='C' then
		local d,hx,hy = unpack(data.parameters)
		assert(d, "circle apertures require at least 1 parameter")
		assert(not hx and not hy, "circle apertures with holes are not yet supported")
		extents = {
			left = -d / 2 * scale,
			right = d / 2 * scale,
			bottom = -d / 2 * scale,
			top = d / 2 * scale,
		}
		path = {concave=true}
		if d ~= 0 then
			local r = d / 2 * scale
			for i=0,circle_steps do
				if i==circle_steps then i = 0 end -- :KLUDGE: sin(2*pi) is not zero, but an epsilon, so we force it
				local a = math.pi * 2 * (i / circle_steps)
				table.insert(path, {x=r*math.cos(a), y=r*math.sin(a)})
			end
		end
	elseif shape=='R' then
		local x,y,hx,hy = unpack(data.parameters)
		assert(x and y, "rectangle apertures require at least 2 parameters")
		assert(not hx and not hy, "rectangle apertures with holes are not yet supported")
		extents = {
			left = -x / 2 * scale,
			right = x / 2 * scale,
			bottom = -y / 2 * scale,
			top = y / 2 * scale,
		}
		path = {
			concave=true,
			{x=-x/2*scale, y=-y/2*scale},
			{x= x/2*scale, y=-y/2*scale},
			{x= x/2*scale, y= y/2*scale},
			{x=-x/2*scale, y= y/2*scale},
			{x=-x/2*scale, y=-y/2*scale},
		}
	elseif shape=='O' then
		assert(circle_steps % 2 == 0, "obround apertures are only supported when circle_steps is even")
		local x,y,hx,hy = unpack(data.parameters)
		assert(x and y, "obround apertures require at least 2 parameters")
		assert(not hx and not hy, "obround apertures with holes are not yet supported")
		extents = {
			left = -x / 2 * scale,
			right = x / 2 * scale,
			bottom = -y / 2 * scale,
			top = y / 2 * scale,
		}
		path = {concave=true}
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
	elseif shape=='P' then
		local d,steps,angle,hx,hy = unpack(data.parameters)
		assert(d and steps, "polygon apertures require at least 2 parameter")
		angle = angle or 0
		assert(not hx and not hy, "polygon apertures with holes are not yet supported")
		extents = {
			left = -d / 2 * scale,
			right = d / 2 * scale,
			bottom = -d / 2 * scale,
			top = d / 2 * scale,
		}
		path = {concave=true}
		if d ~= 0 then
			local r = d / 2 * scale
			for i=0,steps do
				if i==steps then i = 0 end -- :KLUDGE: sin(2*pi) is not zero, but an epsilon, so we force it
				local a = math.pi * 2 * (i / steps) + math.rad(angle)
				table.insert(path, {x=r*math.cos(a), y=r*math.sin(a)})
			end
		end
	elseif data.macro or macros and macros[shape] then
		local macro = data.macro or macros[shape]
		path = macro.script(unpack(data.parameters or {}))
		extents = {
			left = math.huge,
			right = -math.huge,
			bottom = math.huge,
			top = -math.huge,
		}
		for _,point in ipairs(path) do
			point.x = point.x * scale
			point.y = point.y * scale
			extents.left = math.min(extents.left, point.x)
			extents.right = math.max(extents.right, point.x)
			extents.bottom = math.min(extents.bottom, point.y)
			extents.top = math.max(extents.top, point.y)
		end
	else
		error("unsupported aperture shape "..tostring(shape))
	end
	
	local aperture = {
		id = dcode,
		extents = extents,
		path = path,
	}
	
	return aperture
end

local function load_gerber(file_path)
	-- load the high level gerber data
	local layers = gerber.load(file_path)
	
	-- adjust the apertures and macros
	local macros = {}
	local apertures = {}
	for _,layer in ipairs(layers) do
		for _,path in ipairs(layer) do
			local aperture = path.aperture
			if aperture then
				local aperture2 = apertures[aperture]
				if not aperture2 then
					local macro = aperture.macro
					if macro then
						local macro2 = macros[macro]
						if not macro2 then
							macro2 = load_macro(macro, macro.unit)
							macros[macro] = macro2
						end
						aperture.macro = macro2
					end
					aperture2 = load_aperture(aperture, nil, aperture.unit)
					apertures[aperture] = aperture2
				end
				path.aperture = aperture2
			end
		end
	end
	
	-- compute paths extents
	for _,layer in ipairs(layers) do
		for _,path in ipairs(layer) do
			local center_extents = {
				left = math.huge,
				right = -math.huge,
				bottom = math.huge,
				top = -math.huge,
			}
			for _,point in ipairs(path) do
				center_extents.left = math.min(center_extents.left, point.x)
				center_extents.right = math.max(center_extents.right, point.x)
				center_extents.bottom = math.min(center_extents.bottom, point.y)
				center_extents.top = math.max(center_extents.top, point.y)
			end
			path.center_extents = center_extents
			local extents = {
				left = center_extents.left,
				right = center_extents.right,
				bottom = center_extents.bottom,
				top = center_extents.top,
			}
			local aperture = path.aperture
			if aperture then
				extents.left = extents.left + aperture.extents.left
				extents.right = extents.right + aperture.extents.right
				extents.bottom = extents.bottom + aperture.extents.bottom
				extents.top = extents.top + aperture.extents.top
			end
			path.extents = extents
		end
	end
	
	-- compute image extents
	local center_extents = {
		left = math.huge,
		right = -math.huge,
		bottom = math.huge,
		top = -math.huge,
	}
	local extents = {
		left = math.huge,
		right = -math.huge,
		bottom = math.huge,
		top = -math.huge,
	}
	for _,layer in ipairs(layers) do
		for _,path in ipairs(layer) do
			center_extents.left = math.min(center_extents.left, path.center_extents.left)
			center_extents.right = math.max(center_extents.right, path.center_extents.right)
			center_extents.bottom = math.min(center_extents.bottom, path.center_extents.bottom)
			center_extents.top = math.max(center_extents.top, path.center_extents.top)
			extents.left = math.min(extents.left, path.extents.left)
			extents.right = math.max(extents.right, path.extents.right)
			extents.bottom = math.min(extents.bottom, path.extents.bottom)
			extents.top = math.max(extents.top, path.extents.top)
		end
	end
	
	-- generate image
	local image = {
		file_path = file_path,
		center_extents = center_extents,
		extents = extents,
		apertures = apertures,
		layers = layers,
	}
	
	return image
end

------------------------------------------------------------------------------

local function load_tool(data, macros, unit)
	local tcode = data.tcode
	local shape = data.shape
	local scale = assert(scales[unit], "unsupported tool unit "..tostring(unit))
	local d = data.parameters.C
	assert(d, "tools require at least a diameter (C parameter)")
	local extents = {
		left = -d / 2 * scale,
		right = d / 2 * scale,
		bottom = -d / 2 * scale,
		top = d / 2 * scale,
	}
	local path = {concave=true}
	local r = d / 2 * scale
	for i=0,circle_steps-1 do
		local a = i * math.pi * 2 / circle_steps
		table.insert(path, {x=r*math.cos(a), y=r*math.sin(a)})
	end
	-- :KLUDGE: sin(2*pi) is not zero, but an epsilon, so we force it
	table.insert(path, {x=r, y=0})
	
	local aperture = {
		id = tcode,
		extents = extents,
		path = path,
	}
	
	return aperture
end

local function load_excellon(file_path)
	local data = excellon.load(file_path)
	
	-- parse the data blocks
	local macros = {}
	local tools = {}
	local layer = {}
	local layers = {layer}
	local unit,tool
	local x,y = 0,0
	for _,header in ipairs(data.headers) do
		local th = header.type or type(header)
		if th=='tool' then
			local tool = load_tool(header, macros, unit)
			tools[tool.id] = tool
		elseif th=='string' then
			if header=='M72' then
				unit = 'IN'
			elseif header:match('^;') then
				-- ignore
			elseif header=='INCH,LZ' then
				unit = 'IN'
			else
				error("unsupported header "..header)
			end
		else
			error("unsupported header type "..tostring(header.type))
		end
	end
	for _,block in ipairs(data) do
		local tb = block.type
		if tb=='directive' then
			if block.T then
				assert(not block.X and not block.Y and not block.M)
				tool = tools[block.T]
			elseif block.M==72 then
				unit = 'IN'
			elseif block.M==71 then
				unit = 'MM'
			elseif block.M==30 then
				-- end of program, ignore
			elseif block.X or block.Y then
				-- drill
				assert(not block.T and not block.M)
				assert(tool, "no tool selected while drilling")
				local scale = assert(scales[unit], "unsupported drill unit "..tostring(unit))
				if block.X then
					x = block.X * scale
				end
				if block.Y then
					y = block.Y * scale
				end
				table.insert(layer, {
					aperture = tool,
					center_extents = { left = x, right = x, bottom = y, top = y },
					extents = { left = x + tool.extents.left, right = x + tool.extents.right, bottom = y + tool.extents.bottom, top = y + tool.extents.top },
					{ x = x, y = y },
				})
			else
				error("unsupported directive ("..tostring(block)..")")
			end
		else
			error("unsupported block type "..tostring(block.type))
		end
	end
	
	-- compute image extents
	local center_extents = {
		left = math.huge,
		right = -math.huge,
		bottom = math.huge,
		top = -math.huge,
	}
	local extents = {
		left = math.huge,
		right = -math.huge,
		bottom = math.huge,
		top = -math.huge,
	}
	for _,layer in ipairs(layers) do
		for _,path in ipairs(layer) do
			center_extents.left = math.min(center_extents.left, path.center_extents.left)
			center_extents.right = math.max(center_extents.right, path.center_extents.right)
			center_extents.bottom = math.min(center_extents.bottom, path.center_extents.bottom)
			center_extents.top = math.max(center_extents.top, path.center_extents.top)
			extents.left = math.min(extents.left, path.extents.left)
			extents.right = math.max(extents.right, path.extents.right)
			extents.bottom = math.min(extents.bottom, path.extents.bottom)
			extents.top = math.max(extents.top, path.extents.top)
		end
	end
	
	local image = {
		file_path = file_path,
		center_extents = center_extents,
		extents = extents,
		apertures = tools,
		layers = layers,
	}
	
	return image
end

------------------------------------------------------------------------------

local layer_guess = {
	gtl = 'top_copper',
	gts = 'top_soldermask',
	gto = 'top_silkscreen',
	gtp = 'top_paste',
	gbl = 'bottom_copper',
	gbs = 'bottom_soldermask',
	gbo = 'bottom_silkscreen',
	gbp = 'bottom_paste',
	gml = 'milling',
	gm1 = 'milling',
	oln = 'outline',
	out = 'outline',
	drd = 'drill',
	txt = 'drill',
}

local function exterior(path)
	local total = 0
	for i=1,#path-1 do
		local p0 = path[i-1] or path[#path-1]
		local p1 = path[i]
		local p2 = path[i+1] or path[1]
		local dx1 = p1.x - p0.x
		local dy1 = p1.y - p0.y
		local dx2 = p2.x - p1.x
		local dy2 = p2.y - p1.y
		local l1 = math.sqrt(dx1*dx1+dy1*dy1)
		local l2 = math.sqrt(dx2*dx2+dy2*dy2)
		local angle = math.asin((dx1*dy2-dy1*dx2)/(l1*l2))
		total = total + angle
	end
	return total > 0
end

local function find_outline(image)
	-- :TODO: connect lines, since EAGLE generate discontinuous data
	
	-- find path with largest area
	local amax,lmax,pmax = -math.huge
	for l,layer in ipairs(image.layers) do
		for p,path in ipairs(layer) do
			local width = path.extents.right - path.extents.left
			local height = path.extents.top - path.extents.bottom
			local a = width * height
			if a > amax then
				amax,lmax,pmax = a,l,p
			end
		end
	end
	if not lmax or not pmax then return nil end
	local path = image.layers[lmax][pmax]
	-- check that the path has the same extents as the image
	if path.extents.left ~= image.extents.left
		or path.extents.right ~= image.extents.right
		or path.extents.bottom ~= image.extents.bottom
		or path.extents.top ~= image.extents.top then
		return nil
	end
	-- check that the path is long enough to enclose a region
	if #path < 3 then
		return nil
	end
	-- check that the path is closed
	if path[1].x ~= path[#path].x or path[1].y ~= path[#path].y then
		return nil
	end
	-- check that path is a line, not a region
	if not path.aperture then
		return nil
	end
	-- :TODO: check that all other paths are within the outline
	
	-- convert to a region
	local outline = { extents = path.extents }
	for _,point in ipairs(path) do
		table.insert(outline, point)
	end
	if not exterior(outline) then
		local reverse = { extents = outline.extents }
		for i=#outline,1,-1 do
			table.insert(reverse, outline[i])
		end
		outline = reverse
	end
	
	return outline,lmax,pmax
end

local ignore_outline = {
	top_soldermask = true,
	bottom_soldermask = true,
}

local function load_image(path, type)
	print("loading "..tostring(path))
	local image
	if type=='drill' then
		image = load_excellon(path)
	else
		image = load_gerber(path)
	end
	if not ignore_outline[type] then
		local outline,ilayer,ipath = find_outline(image)
		if outline then
			print("outline found")
			image.outline = outline
			table.remove(image.layers[ilayer], ipath)
			if #image.layers[ilayer] == 0 then
				table.remove(image.layers, ilayer)
			end
		end
	end
	return image
end

local function save_metadata(cache_directory, hash, image)
	local metadata = {}
--	for k,v in pairs(image) do
--		metadata[k] = v
--	end
--	metadata.layers = nil
	metadata.center_extents = image.center_extents
	metadata.extents = image.extents
	if image.outline then
		metadata.outline = true
	end
	dump.tofile(metadata, tostring(cache_directory / (hash..'.lua')))
end

function _M.load(path, options)
	if not options then options = {} end
	
	local board = {}
	
	-- locate files
	local paths = {}
	if type(path)=='table' then
		for _,path in ipairs(path) do
			path = pathlib.split(path)
			local extension = path.file:match('%.([^.]+)$'):lower()
			local type = layer_guess[extension]
			if type then
				paths[type] = path
			else
				print("cannot guess type of file "..tostring(path))
			end
		end
	elseif lfs.attributes(path, 'mode') then
		paths.top_copper = pathlib.split(path)
	else
		path = pathlib.split(path)
		for file in lfs.dir(path.dir) do
			if file:sub(1, #path.file)==path.file then
				local extension = file:sub(#path.file+1):lower()
				if extension:sub(1,1)=='.' then extension = extension:sub(2) end
				local path = path.dir / file
				local type = layer_guess[extension]
				if type then
					paths[type] = path
				else
					print("cannot guess type of file "..tostring(path))
				end
			end
		end
	end
	if next(paths)==nil then
		return nil,"no image found"
	end
	
	-- create cache directory
	if options.cache_directory then
		board.cache_directory = pathlib.split(options.cache_directory)
		if not lfs.attributes(board.cache_directory, 'mode') then
			lfs.mkdir(board.cache_directory)
		end
	end
	
	-- determine file hashes
	local hashes = {}
	for type,path in pairs(paths) do
		local file = assert(io.open(path, "rb"))
		local content = assert(file:read('*all'))
		assert(file:close())
		local hash = crypto.evp.digest('md5', content):lower()
		hashes[type] = hash
	end
	board.hashes = hashes
	
	-- load image metadata
	local images = {}
	for type,path in pairs(paths) do
		local hash = hashes[type]
		local image
		if board.cache_directory then
			local metapath = board.cache_directory / (hash..'.lua')
			if lfs.attributes(metapath, 'mode') then
				local metadata = dofile(metapath)
				metadata.path = path
				metadata.type = type
				metadata.hash = hash
				image = metadata
			end
		end
		if not image then
			image = load_image(path, type)
			if board.cache_directory then
				save_metadata(board.cache_directory, hash, image)
			end
		end
		images[type] = image
	end
	board.images = images
	
	-- compute board extents
	local extents = {
		left = math.huge,
		right = -math.huge,
		bottom = math.huge,
		top = -math.huge,
	}
	for type,image in pairs(images) do
		if type=='milling' or type=='drill' then
			-- only extend to the points centers
			extents.left = math.min(extents.left, image.center_extents.left)
			extents.bottom = math.min(extents.bottom, image.center_extents.bottom)
			extents.right = math.max(extents.right, image.center_extents.right)
			extents.top = math.max(extents.top, image.center_extents.top)
		elseif (type=='top_silkscreen' or type=='bottom_silkscreen') and not options.silkscreen_extends_board then
			-- don't extend with these
		else
			extents.left = math.min(extents.left, image.extents.left)
			extents.bottom = math.min(extents.bottom, image.extents.bottom)
			extents.right = math.max(extents.right, image.extents.right)
			extents.top = math.max(extents.top, image.extents.top)
		end
	end
	if extents.right <= extents.left or extents.top <= extents.bottom then
		return nil,"board is empty"
	end
	extents.width = extents.right - extents.left
	extents.height = extents.top - extents.bottom
	board.extents = extents
	
	-- compute special outline hash
	local outline_name = {}
	for type,image in pairs(images) do
		if image.outline then
			table.insert(outline_name, hashes[type])
		end
	end
	table.sort(outline_name)
	outline_name = table.concat(outline_name, ":")
	if outline_name == "" then
		local l = board.extents.left
		local r = board.extents.right
		local t = board.extents.top
		local b = board.extents.bottom
		outline_name = "l="..l..":r="..r..":t="..t..":b="..b
	end
	if board.hashes.milling then
		outline_name = outline_name..":m="..board.hashes.milling
	end
	if board.hashes.drill then
		outline_name = outline_name..":d="..board.hashes.drill
	end
	local outline_hash = crypto.evp.digest('md5', outline_name):lower()
	board.outline_hash = outline_hash
	
	return board
end

function _M.load_layers(board, image)
	-- lazily load the gerber data if necessary
	if not image.layers then
		local metadata = image
		assert(metadata.path)
		local image = load_image(metadata.path, metadata.type)
		if board.cache_directory then
			save_metadata(board.cache_directory, metadata.hash, image)
		end
		-- replace metadata with image everywhere it's referenced by swapping content
		for k in pairs(metadata) do metadata[k] = nil end
		for k,v in pairs(image) do metadata[k] = v end
	end
end

------------------------------------------------------------------------------

return _M
