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
local region = require 'boards.region'

pathlib.install()

local unpack = unpack or table.unpack

------------------------------------------------------------------------------

local scales = {
	IN = 25.4,
	MM = 1,
}

local circle_steps = 64

local function generate_aperture_path(aperture)
	local shape = aperture.shape
	local macro = aperture.macro
	local parameters = aperture.parameters
	local unit = aperture.unit
	local scale = assert(scales[unit], "unsupported aperture unit "..tostring(unit))
	
	local path
	local path
	if shape=='circle' then
		local d,hx,hy = unpack(parameters)
		assert(d, "circle apertures require at least 1 parameter")
		assert(not hx and not hy, "circle apertures with holes are not yet supported")
		path = {concave=true}
		if d ~= 0 then
			local r = d / 2 * scale
			for i=0,circle_steps do
				if i==circle_steps then i = 0 end -- :KLUDGE: sin(2*pi) is not zero, but an epsilon, so we force it
				local a = math.pi * 2 * (i / circle_steps)
				table.insert(path, {x=r*math.cos(a), y=r*math.sin(a)})
			end
		end
	elseif shape=='rectangle' then
		local x,y,hx,hy = unpack(parameters)
		assert(x and y, "rectangle apertures require at least 2 parameters")
		assert(not hx and not hy, "rectangle apertures with holes are not yet supported")
		path = {
			concave=true,
			{x=-x/2*scale, y=-y/2*scale},
			{x= x/2*scale, y=-y/2*scale},
			{x= x/2*scale, y= y/2*scale},
			{x=-x/2*scale, y= y/2*scale},
			{x=-x/2*scale, y=-y/2*scale},
		}
	elseif shape=='obround' then
		assert(circle_steps % 2 == 0, "obround apertures are only supported when circle_steps is even")
		local x,y,hx,hy = unpack(parameters)
		assert(x and y, "obround apertures require at least 2 parameters")
		assert(not hx and not hy, "obround apertures with holes are not yet supported")
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
	elseif shape=='polygon' then
		local d,steps,angle,hx,hy = unpack(parameters)
		assert(d and steps, "polygon apertures require at least 2 parameter")
		angle = angle or 0
		assert(not hx and not hy, "polygon apertures with holes are not yet supported")
		path = {concave=true}
		if d ~= 0 then
			local r = d / 2 * scale
			for i=0,steps do
				if i==steps then i = 0 end -- :KLUDGE: sin(2*pi) is not zero, but an epsilon, so we force it
				local a = math.pi * 2 * (i / steps) + math.rad(angle)
				table.insert(path, {x=r*math.cos(a), y=r*math.sin(a)})
			end
		end
	elseif macro then
		path = macro.chunk(unpack(parameters or {}))
		for _,point in ipairs(path) do
			point.x = point.x * scale
			point.y = point.y * scale
		end
	else
		error("unsupported aperture shape "..tostring(shape))
	end
	
	aperture.path = path
end

------------------------------------------------------------------------------

local function load_image(path, type)
	print("loading "..tostring(path))
	local image
	if type=='drill' then
		image = excellon.load(path)
	else
		image = gerber.load(path)
	end
	
	-- collect apertures
	local apertures = {}
	image.apertures = {}
	for _,layer in ipairs(image.layers) do
		for _,path in ipairs(layer) do
			local aperture = path.aperture
			if aperture and not apertures[aperture] then
				table.insert(image.apertures, aperture)
				apertures[aperture] = true
			end
		end
	end
	
	-- generate aperture paths
	for aperture in pairs(apertures) do
		generate_aperture_path(aperture)
	end
	
	-- compute extents
	for _,aperture in ipairs(image.apertures) do
		if not aperture.extents then
			aperture.extents = region()
			for	_,point in ipairs(aperture.path) do
				aperture.extents = aperture.extents + point
			end
		end
	end
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
			if aperture and not aperture.extents.empty then
				path.extents = path.extents * aperture.extents
			end
			image.center_extents = image.center_extents + path.center_extents
			image.extents = image.extents + path.extents
		end
	end
	
	return image
end

local function save_image(image, path, type)
	print("saving "..tostring(path))
	if type=='drill' then
		return excellon.save(image, path)
	else
		return gerber.save(image, path)
	end
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
		}
	else
		return nil
	end
end

function _M.load(path, options)
	if not options then options = {} end
	
	local board = {}
	
	-- single file special case
	if type(path)=='string' and lfs.attributes(path, 'mode') then
		path = { path }
	end
	
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
	return region(copy)
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
	local copy = {
		unit = path.unit,
	}
	copy.aperture = path.aperture
	for i,point in ipairs(path) do
		copy[i] = offset_point(point, dx, dy)
	end
	return copy
end

local function offset_layer(layer, dx, dy)
	local copy = {
		polarity = layer.polarity,
	}
	for i,path in ipairs(layer) do
		copy[i] = offset_path(path, dx, dy)
	end
	return copy
end

local function offset_image(image, dx, dy)
	local copy = {
		file_path = nil,
		name = image.name,
		format = {},
		unit = image.unit,
		layers = {},
	}
	
	-- copy format
	for k,v in pairs(image.format) do
		copy.format[k] = v
	end
	
	-- move extents
	copy.extents = offset_extents(image.extents, dx, dy)
	copy.center_extents = offset_extents(image.center_extents, dx, dy)
	
	-- move layers
	for i,layer in ipairs(image.layers) do
		copy.layers[i] = offset_layer(layer, dx, dy)
	end
	
	return copy
end

local function offset_board(board, dx, dy)
	local copy = {
		extensions = {},
		images = {},
	}
	
	-- copy extensions
	for type,extension in pairs(board.extensions) do
		copy.extensions[type] = extension
	end
	
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

local function copy_path(path)
	return offset_path(path, 0, 0)
end

local function copy_layer(layer)
	return offset_layer(layer, 0, 0)
end

local function copy_image(image)
	return offset_image(image, 0, 0)
end

------------------------------------------------------------------------------

local function merge_layers(layer_a, layer_b)
	assert(layer_a.polarity == layer_b.polarity, "layer polarity mismatch")
	local merged = {
		polarity = layer_a.polarity,
	}
	for i,path in ipairs(layer_a) do
		table.insert(merged, copy_path(path))
	end
	for i,path in ipairs(layer_b) do
		table.insert(merged, copy_path(path))
	end
	return merged
end

local function merge_images(image_a, image_b)
	assert(image_a.unit == image_b.unit, "image unit mismatch")
	local merged = {
		file_path = nil,
		name = nil,
		format = {},
		unit = image_a.unit,
		layers = {},
	}
	
	-- merge names
	if image_a.name or image_b.name then
		merged.name = (image_a.name or '<unknown>')..' merged with '..(image_b.name or '<unknown>')
	end
	
	-- copy format (and check that they are identical
	for k,v in pairs(image_a.format) do
		assert(image_b.format[k] == v, "image format mismatch")
		merged.format[k] = v
	end
	for k,v in pairs(image_b.format) do
		assert(image_a.format[k] == v, "image format mismatch")
	end
	
	-- merge extents
	merged.extents = image_a.extents + image_b.extents
	merged.center_extents = image_a.center_extents + image_b.center_extents
	
	-- merge layers
	for i=1,#image_a.layers do
		local layer_a = image_a.layers[i]
		local layer_b = image_b.layers[i]
		if layer_b then
			merged.layers[i] = merge_layers(layer_a, layer_b)
		else
			merged.layers[i] = copy_layer(layer_a)
		end
	end
	for i=#image_a.layers+1,#image_b.layers do
		merged.layers[i] = copy_layer(#image_b.layers[i])
	end
	
	return merged
end

local function merge_boards(board_a, board_b)
	local merged = {
		extensions = {},
		images = {},
	}
	
	-- merge extensions
	for type,extension in pairs(board_a.extensions) do
		merged.extensions[type] = extension
	end
	for type,extension in pairs(board_b.extensions) do
		-- prefer extensions from A in case of conflict
		if not merged.extensions[type] then
			merged.extensions[type] = extension
		end
	end
	
	-- merge extents
	merged.extents = board_a.extents + board_b.extents
	
	-- merge images
	for type,image_a in pairs(board_a.images) do
		local image_b = board_b.images[type]
		if image_b then
			merged.images[type] = merge_images(image_a, image_b)
		else
			merged.images[type] = copy_image(image_a)
		end
	end
	for type,image_b in pairs(board_b.images) do
		local image_a = board_a.images[type]
		if not image_a then
			merged.images[type] = copy_image(image_b)
		end
	end
	
	return merged
end

function _M.merge(board_a, board_b)
	return merge_boards(board_a, board_b)
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
