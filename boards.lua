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

local default_region = {
	left = math.huge,
	right = -math.huge,
	bottom = math.huge,
	top = -math.huge,
}

local region_mt = {}
local region_getters = {}
local region_methods = {}

local function region(orig)
	if not orig then orig = default_region end
	return setmetatable({
		left = orig.left,
		right = orig.right,
		bottom = orig.bottom,
		top = orig.top,
	}, region_mt)
end

function region_mt.__index(self, k)
	local getter = region_getters[k]
	if getter then
		return getter(self)
	end
	return region_methods[k]
end

function region_getters:empty()
	return self.right <= self.left or self.top <= self.bottom
end

function region_mt.__add(self, extension)
	if extension.x and extension.y then
		return region{
			left = math.min(self.left, extension.x),
			right = math.max(self.right, extension.x),
			bottom = math.min(self.bottom, extension.y),
			top = math.max(self.top, extension.y),
		}
	elseif extension.left and extension.right and extension.bottom and extension.top then
		return region{
			left = math.min(self.left, extension.left),
			right = math.max(self.right, extension.right),
			bottom = math.min(self.bottom, extension.bottom),
			top = math.max(self.top, extension.top),
		}
	else
		error("only points or other regions can be added to a region")
	end
end

function region_mt.__mul(a, b)
	if a.left and a.right and a.bottom and a.top and b.left and b.right and b.bottom and b.top then
		return region{
			left = a.left + b.left,
			right = a.right + b.right,
			bottom = a.bottom + b.bottom,
			top = a.top + b.top,
		}
	else
		error("regions can only be multiplied with other regions")
	end
end

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

local function complete_macro(macro)
	local unit = macro.unit
	assert(#macro.script==1 and macro.script[1].type=='primitive', "only macros with 1 primitive are supported")
	local source = "local _VARS = {...}\n"
	for _,instruction in ipairs(macro.script) do
		if instruction.type=='comment' then
			-- ignore
		elseif instruction.type=='variable' then
			source = source.."_VARS['"..instruction.name.."'] = "..compile_expression(instruction.expression).."\n"
		elseif instruction.type=='primitive' then
			source = source..instruction.shape.."("
			for i,expression in ipairs(instruction.parameters) do
				if i > 1 then source = source..", " end
				source = source..compile_expression(expression)
			end
			source = source..")\n"
		else
			error("unsupported macro instruction type "..tostring(instruction.type))
		end
	end
--	print("========================================")
--	print(source)
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
		chunk = assert(load(source, nil, 't', env))
	elseif _VERSION == 'Lua 5.1' then
		chunk = assert(loadstring(source))
		setfenv(chunk, env)
	end
	macro.chunk = function(...)
		paths = {}
		chunk(...)
		assert(#paths==1, "macro scripts must generate a single path")
		return paths[1]
	end
end

local function complete_aperture(aperture, macros)
	local dcode = aperture.dcode
	local shape = aperture.shape
	local unit = aperture.unit
	local scale = assert(scales[unit], "unsupported aperture unit "..tostring(unit))
	local extents,path
	if shape=='C' then
		local d,hx,hy = unpack(aperture.parameters)
		assert(d, "circle apertures require at least 1 parameter")
		assert(not hx and not hy, "circle apertures with holes are not yet supported")
		extents = region{
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
		local x,y,hx,hy = unpack(aperture.parameters)
		assert(x and y, "rectangle apertures require at least 2 parameters")
		assert(not hx and not hy, "rectangle apertures with holes are not yet supported")
		extents = region{
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
		local x,y,hx,hy = unpack(aperture.parameters)
		assert(x and y, "obround apertures require at least 2 parameters")
		assert(not hx and not hy, "obround apertures with holes are not yet supported")
		extents = region{
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
		local d,steps,angle,hx,hy = unpack(aperture.parameters)
		assert(d and steps, "polygon apertures require at least 2 parameter")
		angle = angle or 0
		assert(not hx and not hy, "polygon apertures with holes are not yet supported")
		extents = region{
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
	elseif aperture.macro then
		local macro = aperture.macro
		path = macro.chunk(unpack(aperture.parameters or {}))
		extents = region{
			left = math.huge,
			right = -math.huge,
			bottom = math.huge,
			top = -math.huge,
		}
		for _,point in ipairs(path) do
			point.x = point.x * scale
			point.y = point.y * scale
			extents = extents + point
		end
	else
		error("unsupported aperture shape "..tostring(shape))
	end
	
	aperture.extents = extents
	aperture.path = path
end

local function load_gerber(file_path)
	-- load the high level gerber data
	local layers = gerber.load(file_path)
	
	-- adjust the apertures and macros (generate paths and extents)
	local apertures = {}
	for _,layer in ipairs(layers) do
		for _,path in ipairs(layer) do
			local aperture = path.aperture
			if aperture and not aperture.path then
				local macro = aperture.macro
				if macro then
					if not macro.chunk then
						complete_macro(macro)
					end
				end
				complete_aperture(aperture)
				table.insert(apertures, aperture)
			end
		end
	end
	
	-- generate image
	local image = {
		file_path = file_path,
		apertures = apertures,
		layers = layers,
	}
	
	return image
end

local function save_gerber(image, file_path)
	return gerber.save(image.layers, file_path)
end

------------------------------------------------------------------------------

local function complete_tool(tool)
	local tcode = tool.tcode
	local shape = tool.shape
	local unit = tool.unit
	local scale = assert(scales[unit], "unsupported tool unit "..tostring(unit))
	local d = tool.parameters.C
	assert(d, "tools require at least a diameter (C parameter)")
	local extents = region{
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
	
	tool.extents = extents
	tool.path = path
end

local function load_excellon(file_path)
	-- load the high level excellon data
	local layers = excellon.load(file_path)
	
	-- adjust the apertures and macros (generate paths and extents)
	local apertures = {}
	for _,layer in ipairs(layers) do
		for _,path in ipairs(layer) do
			local aperture = path.aperture
			if aperture and not aperture.path then
				local macro = aperture.macro
				if macro then
					if not macro.chunk then
						complete_macro(macro)
					end
				end
				complete_tool(aperture)
				table.insert(apertures, aperture)
			end
		end
	end
	
	local image = {
		file_path = file_path,
		apertures = apertures,
		layers = layers,
	}
	
	return image
end

local function save_excellon(image, file_path)
	return excellon.save(image.layers, file_path)
end

------------------------------------------------------------------------------

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
	
	-- compute extents
	image.center_extents = region()
	image.extents = region()
	for _,layer in ipairs(image.layers) do
		for _,path in ipairs(layer) do
			path.center_extents = region()
			for _,point in ipairs(path) do
				path.center_extents = path.center_extents + point
			end
			path.extents = region(path.center_extents)
			local aperture = path.aperture
			if aperture then
				path.extents = path.extents * aperture.extents
			end
			image.center_extents = image.center_extents + path.center_extents
			image.extents = image.extents + path.extents
		end
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

local function save_image(image, path, type)
	print("saving "..tostring(path))
	if type=='drill' then
		return save_excellon(image, path)
	else
		return save_gerber(image, path)
	end
	--[[
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
	--]]
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

local function save_metadata(cache_directory, hash, image)
	local metadata = {}
	metadata.center_extents = image.center_extents
	metadata.extents = image.extents
	if image.outline then
		metadata.outline = true
	end
	dump.tofile(metadata, tostring(cache_directory / (hash..'.lua')))
end

local function load_metadata(cache_directory, hash, path, type)
	local metapath = cache_directory / (hash..'.lua')
	if lfs.attributes(metapath, 'mode') then
		local metadata = dofile(metapath)
		return {
			path = path,
			type = type,
			hash = hash,
			extents = region(metadata.extents),
			center_extents = region(metadata.center_extents),
			outline = metadata.outline,
		}
	else
		return nil
	end
end

function _M.load(path, options)
	if not options then options = {} end
	
	local board = {}
	
	-- locate files
	local paths = {}
	local extensions = {}
	if type(path)=='table' then
		for _,path in ipairs(path) do
			path = pathlib.split(path)
			local extension = path.file:match('%.([^.]+)$'):lower()
			local type = layer_guess[extension]
			if type then
				paths[type] = path
				extensions[type] = extension
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
					extensions[type] = extension
				else
					print("cannot guess type of file "..tostring(path))
				end
			end
		end
	end
	if next(paths)==nil then
		return nil,"no image found"
	end
	board.extensions = extensions
	
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
			image = load_metadata(board.cache_directory, hash, path, type)
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
	board.extents = region()
	for type,image in pairs(images) do
		if type=='milling' or type=='drill' then
			-- only extend to the points centers
			board.extents = board.extents + image.center_extents
		elseif (type=='top_silkscreen' or type=='bottom_silkscreen') and not options.silkscreen_extends_board then
			-- don't extend with these
		else
			board.extents = board.extents + image.extents
		end
	end
	if board.extents.empty then
		return nil,"board is empty"
	end
	
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

function _M.save(board, path)
	if pathlib.type(path) ~= 'path' then
		path = pathlib.split(path)
	end
--	print("not saving board to '"..tostring(path).."'")
	for type,image in pairs(board.images) do
		local extension = assert(board.extensions[type])
		local path = path.dir / (path.file..'.'..extension)
		local success,msg = save_image(image, path, type)
		if not success then return nil,msg end
	end
	return true
end

------------------------------------------------------------------------------

local function offset_extents(extents, dx, dy)
	local copy = {}
	copy.left = extents.left + dx
	copy.right = extents.right + dx
	copy.bottom = extents.bottom + dy
	copy.top = extents.top + dy
	return copy
end

local function offset_point(point, dx, dy)
	local copy = {}
	for k,v in pairs(point) do
		copy[k] = v
	end
	if copy.x then copy.x = copy.x + dx end
	if copy.y then copy.y = copy.y + dy end
	return copy
end

local function offset_path(path, dx, dy)
	local copy = {}
	copy.aperture = path.aperture
	for i,point in ipairs(path) do
		copy[i] = offset_point(point, dx, dy)
	end
	return copy
end

local function offset_layer(layer, dx, dy)
	local copy = {}
	for i,path in ipairs(layer) do
		copy[i] = offset_path(path, dx, dy)
	end
	return copy
end

local function offset_image(image, dx, dy)
	local copy = {
		file_path = nil,
		extents = {},
		layers = {},
	}
	
	-- move extents
	copy.extents = offset_extents(image.extents, dx, dy)
	
	-- move layers
	for i,layer in ipairs(image.layers) do
		copy.layers[i] = offset_layer(layer, dw, dy)
	end
	
	return copy
end

local function offset_board(board, dx, dy)
	local copy = {
		images = {},
	}
	
	-- move extents
	copy.extents = offset_extents(board.extents, dx, dy)
	
	-- move images
	for type,image in pairs(board.images) do
		copy.images[type] = offset_image(image, dx, dy)
	end
	
	return copy
end

function _M.offset(board, dx, dy)
	return offset_board(board, dx, dy)
end

------------------------------------------------------------------------------

function _M.panelize(options, layout)
	local panel = {}
	panel.extents = {
		left = math.huge,
		right = -math.huge,
		bottom = math.huge,
		top = -math.huge,
	}
	panel.images = {}
	return panel
end

------------------------------------------------------------------------------

return _M
