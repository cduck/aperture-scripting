local _M = {}

local io = require 'io'
local math = require 'math'
local table = require 'table'
local lfs = require 'lfs'
local pathlib = require 'path'
local gerber = require 'gerber'
local excellon = require 'excellon'
local bom = require 'bom'
local dump = require 'dump'
local crypto = require 'crypto'
local region = require 'boards.region'

pathlib.install()

local unpack = unpack or table.unpack

------------------------------------------------------------------------------

-- all positions are in picometers
local aperture_scales = {
	IN_pm = 25400000000,
	MM_pm =  1000000000,
	IN_mm = 25.4,
	MM_mm =  1,
}

local circle_steps = 64

local function generate_aperture_path(aperture, board_unit)
	local shape = aperture.shape
	local macro = aperture.macro
	if not shape and not macro then
		return
	end
	local parameters = aperture.parameters
	local scale_name = aperture.unit..'_'..board_unit
	local scale = assert(aperture_scales[scale_name], "unsupported aperture scale "..scale_name)
	
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

local path_scales = {
	pm = 1,
	mm = 1e-9,
}

local function load_image(path, type, unit, template)
	print("loading "..tostring(path))
	local image
	if type=='drill' then
		image = excellon.load(path)
	elseif type=='bom' then
		image = bom.load(path, template.bom)
	else
		image = gerber.load(path)
	end
	
	-- scale the path data (sub-modules output picometers)
	local scale = assert(path_scales[unit], "unsupported board output unit "..tostring(unit))
	if scale ~= 1 then
		local k = 0
		for _,layer in ipairs(image.layers) do
			for _,path in ipairs(layer) do
				for _,point in ipairs(path) do
					point.x = point.x * scale
					point.y = point.y * scale
					if point.i then point.i = point.i * scale end
					if point.j then point.j = point.j * scale end
					k = k + 1
				end
			end
		end
	end
	
	-- collect apertures
	local apertures = {}
	for _,layer in ipairs(image.layers) do
		for _,path in ipairs(layer) do
			local aperture = path.aperture
			if aperture and not apertures[aperture] then
				apertures[aperture] = true
			end
		end
	end
	
	-- generate aperture paths
	for aperture in pairs(apertures) do
		generate_aperture_path(aperture, unit)
	end
	
	-- compute extents
	for aperture in pairs(apertures) do
		if not aperture.extents then
			aperture.extents = region()
			if aperture.path then
				for _,point in ipairs(aperture.path) do
					aperture.extents = aperture.extents + point
				end
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

local function save_image(image, path, type, unit, template)
	print("saving "..tostring(path))
	assert(unit == 'pm', "saving scaled images is not yet supported")
	if type=='drill' then
		return excellon.save(image, path)
	elseif type=='bom' then
		return bom.save(image, path, template.bom)
	else
		return gerber.save(image, path)
	end
end

------------------------------------------------------------------------------

local default_template = {
	patterns = {
		top_copper = '%.gtl',
		top_soldermask = '%.gts',
		top_silkscreen = '%.gto',
		top_paste = '%.gtp',
		bottom_copper = '%.gbl',
		bottom_soldermask = '%.gbs',
		bottom_silkscreen = '%.gbo',
		bottom_paste = '%.gbp',
		milling = {'%.gml', '%.gm1'},
		outline = {'%.oln', '%.out'},
		drill = {'%.drd', '%.txt'},
		bom = '%-bom.txt',
	},
	bom = {
		scale = {
			dimension = 1e9,
			angle = 1,
		},
		fields = {
			package = '3D Model',
			x = 'X',
			y = 'Y',
			angle = 'Angle',
			side = 'Side',
			name = 'Part',
		},
	},
}

function _M.load(path, options)
	if not options then options = {} end
	
	local board = {}
	
	board.unit = options.unit or 'pm'
	local template = default_template -- make that configurable
	board.template = template
	
	-- single file special case
	if type(path)=='string' and lfs.attributes(path, 'mode') then
		path = { path }
	end
	
	-- locate files
	local paths = {}
	local extensions = {}
	if type(path)~='table' and lfs.attributes(path, 'mode') then
		path = { path }
	end
	if type(path)=='table' then
		for _,path in ipairs(path) do
			path = pathlib.split(path)
			local found = false
			for image,patterns in pairs(template.patterns) do
				if type(patterns)=='string' then patterns = { patterns } end
				for _,pattern in ipairs(patterns) do
					local lpattern = '^'..pattern:gsub('[%%%.()]', {
						['.'] = '%.',
						['('] = '%(',
						[')'] = '%)',
						['%'] = '(.*)',
					})..'$'
					local basename = path.file:lower():match(lpattern)
					if basename then
						paths[image] = path
						extensions[image] = pattern
						found = true
						break
					end
				end
				if found then
					break
				end
			end
			if not found then
				print("cannot guess type of file "..tostring(path))
			end
		end
	else
		path = pathlib.split(path)
		local files = {}
		for file in lfs.dir(path.dir) do
			files[file:lower()] = file
		end
		for image,patterns in pairs(template.patterns) do
			if type(patterns)=='string' then patterns = { patterns } end
			for _,pattern in ipairs(patterns) do
				local file = files[pattern:gsub('%%', path.file):lower()]
				if file then
					paths[image] = path.dir / file
					extensions[image] = pattern
					found = true
					break
				end
			end
		end
	end
	if next(paths)==nil then
		return nil,"no image found"
	end
	board.extensions = extensions
	
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
		local image = load_image(path, type, board.unit, board.template)
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
		elseif type=='bom' then
			-- BOM is parts logical centers, unrelated to board actual dimension
		else
			board.extents = board.extents + image.extents
		end
	end
	if board.extents.empty then
		return nil,"board is empty"
	end
	
	return board
end

function _M.save(board, path)
	if pathlib.type(path) ~= 'path' then
		path = pathlib.split(path)
	end
	for type,image in pairs(board.images) do
		local pattern = assert(board.extensions[type])
		local path = path.dir / pattern:gsub('%%', path.file)
		local success,msg = save_image(image, path, type, board.unit, board.template)
		if not success then return nil,msg end
	end
	return true
end

------------------------------------------------------------------------------

local function find_image_outline(image)
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
	
	return path,lmax,pmax
end

local ignore_outline = {
	top_soldermask = true,
	bottom_soldermask = true,
}
_M.ignore_outline = ignore_outline

function _M.find_board_outlines(board)
	local outlines = {}
	-- gen raw list
	local max_area = -math.huge
	for type,image in pairs(board.images) do
		if not ignore_outline[type] then
			local path,ilayer,ipath = find_image_outline(image)
			if path then
				local area = (path.center_extents.right - path.center_extents.left) * (path.center_extents.top - path.center_extents.bottom)
				max_area = math.max(max_area, area)
				outlines[type] = {path=path, ilayer=ilayer, ipath=ipath, area=area}
			end
		end
	end
	-- filter the list
	for type,data in pairs(outlines) do
		-- igore all but the the largest ones
		if data.area < max_area then
			outlines[type] = nil
		end
	end
	return outlines
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
	if path.extents then
		copy.extents = offset_extents(path.extents, dx, dy)
	end
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
		unit = board.unit,
		template = board.template,
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

local function offset_side(side, dz)
	local copy = {}
	for i,z in ipairs(side) do
		copy[i] = z + dz
	end
	return copy
end

local function offset_panel(panel, dx, dy)
	local copy = offset_board(panel, dx, dy)
	copy.left = offset_side(panel.left, dy)
	copy.right = offset_side(panel.right, dy)
	copy.bottom = offset_side(panel.bottom, dx)
	copy.top = offset_side(panel.top, dx)
	return copy
end

------------------------------------------------------------------------------

local function rotate180_extents(extents)
	local copy = {}
	copy.left = -extents.right
	copy.right = -extents.left
	copy.bottom = -extents.top
	copy.top = -extents.bottom
	return region(copy)
end

local function rotate180_macro(macro)
	local copy = {
		name = macro.name,
		unit = macro.unit,
		script = macro.script,
		chunk = macro.chunk,
	}
	print("warning: macro rotation not yet implemented, assumed symmetrical")
	return copy
end

local symmetrical180_shapes = {
	circle = true,
	rectangle = true,
	obround = true,
}

local function rotate180_aperture(aperture, macros)
	local copy = {
		name = aperture.name,
		unit = aperture.unit,
		shape = aperture.shape,
		macro = nil,
		parameters = {},
	}
	-- copy parameters
	for k,v in pairs(aperture.parameters) do
		copy.parameters[k] = v
	end
	-- adjust parameters
	assert(not (aperture.shape and aperture.macro), "aperture has a shape and a macro")
	if aperture.macro then
		copy.macro = macros[aperture.macro]
		if not copy.macro then
			copy.macro = rotate180_macro(aperture.macro)
			macros[aperture.macro] = copy.macro
		end
	elseif symmetrical180_shapes[aperture.shape] then
		-- keep it that way
	elseif aperture.shape=='polygon' then
		local angle = copy.parameters[3] or 0
		angle = angle + 180
		if #copy.parameters==3 and angle==0 then
			copy.parameters[3] = nil
		else
			copy.parameters[3] = angle
		end
	elseif aperture.device then
		-- parts rotation is in the layer data
		copy.device = true
	else
		error("unsupported aperture shape")
	end
	return copy
end

local function rotate180_point(point)
	local copy = {}
	for k,v in pairs(point) do
		copy[k] = v
	end
	if copy.x then copy.x = -copy.x end
	if copy.y then copy.y = -copy.y end
	if copy.i then copy.i = -copy.i end
	if copy.j then copy.j = -copy.j end
	if copy.angle then copy.angle = (copy.angle + 180) % 360 end
	return copy
end

local function rotate180_path(path, apertures, macros)
	local copy = {
		unit = path.unit,
	}
	if path.extents then
		copy.extents = rotate180_extents(path.extents)
	end
	if path.aperture then
		copy.aperture = apertures[path.aperture]
		if not copy.aperture then
			copy.aperture = rotate180_aperture(path.aperture, macros)
			apertures[path.aperture] = copy.aperture
		end
	end
	for i,point in ipairs(path) do
		copy[i] = rotate180_point(point)
	end
	return copy
end

local function rotate180_layer(layer, apertures, macros)
	local copy = {
		polarity = layer.polarity,
	}
	for i,path in ipairs(layer) do
		copy[i] = rotate180_path(path, apertures, macros)
	end
	return copy
end

local function rotate180_image(image)
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
	copy.extents = rotate180_extents(image.extents)
	copy.center_extents = rotate180_extents(image.center_extents)
	
	-- apertures and macros are shared by layers and paths, so create an index to avoid duplicating them in the copy
	local apertures = {}
	local macros = {}
	
	-- move layers
	for i,layer in ipairs(image.layers) do
		copy.layers[i] = rotate180_layer(layer, apertures, macros)
	end
	
	return copy
end

local function rotate180_board(board)
	local copy = {
		unit = board.unit,
		template = board.template,
		extensions = {},
		images = {},
	}
	
	-- copy extensions
	for type,extension in pairs(board.extensions) do
		copy.extensions[type] = extension
	end
	
	-- rotate extents
	copy.extents = rotate180_extents(board.extents)
	
	-- rotate images
	for type,image in pairs(board.images) do
		copy.images[type] = rotate180_image(image)
	end
	
	return copy
end

function _M.rotate180(board)
	return rotate180_board(board)
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

local function copy_board(board)
	return offset_board(board, 0, 0)
end

local function copy_side(side)
	return offset_side(side, 0)
end

------------------------------------------------------------------------------

local function merge_layers(layer_a, layer_b)
	assert(layer_a.polarity == layer_b.polarity, "layer polarity mismatch ("..tostring(layer_a.polarity).." vs. "..tostring(layer_b.polarity)..")")
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
		assert(image_b.format[k] == v, "image format mismatch (field "..tostring(k)..": "..tostring(v)..' vs. '..tostring(image_b.format[k])..")")
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
	assert(board_a.unit == board_b.unit, "board unit mismatch")
	assert(board_a.template == board_b.template, "board template mismatch")
	local merged = {
		unit = board_a.unit,
		template = board_a.template,
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

local function merge_sides(side_a, side_b)
	local merged = {}
	for _,z in ipairs(side_a) do
		table.insert(merged, z)
	end
	for _,z in ipairs(side_b) do
		table.insert(merged, z)
	end
	return merged
end

local function merge_panels(panel_a, panel_b, vertical)
	local merged = merge_boards(panel_a, panel_b)
	if vertical then
		merged.left = merge_sides(panel_a.left, panel_b.left)
		merged.right = merge_sides(panel_a.right, panel_b.right)
		merged.bottom = copy_side(panel_a.bottom)
		merged.top = copy_side(panel_b.top)
	else
		merged.left = copy_side(panel_a.left)
		merged.right = copy_side(panel_b.right)
		merged.bottom = merge_sides(panel_a.bottom, panel_b.bottom)
		merged.top = merge_sides(panel_a.top, panel_b.top)
	end
	return merged
end

------------------------------------------------------------------------------

local function copy(v)
	local t = type(v)
	if t=='nil' or t=='number' or t=='string' then
		return v
	elseif t=='table' then
		local v2 = {}
		for k,v in pairs(v) do
			v2[copy(k)] = copy(v)
		end
		return setmetatable(v2, getmetatable(v))
	else
		error("uncopyable type "..t)
	end
end

local function decouple_image_apertures(image)
	-- decouple the apertures and macros
	for _,layer in ipairs(image.layers) do
		for _,path in ipairs(layer) do
			path.aperture = copy(path.aperture)
		end
	end
end

local function decouple_board_apertures(board)
	for _,image in pairs(board.images) do
		decouple_image_apertures(image)
	end
end

function _M.decouple_apertures(board)
	decouple_board_apertures(board)
end

local function merge_image_apertures(image)
	-- list apertures
	local apertures = {}
	local aperture_order = {}
	for _,layer in ipairs(image.layers) do
		for _,path in ipairs(layer) do
			local aperture = path.aperture
			if aperture then
				local s = assert(dump.tostring(aperture))
				if apertures[s] then
					aperture = apertures[s]
					path.aperture = aperture
				else
					apertures[s] = aperture
					table.insert(aperture_order, aperture)
				end
			end
		end
	end
	
	-- list macros
	local macros = {}
	local macro_order = {}
	for _,aperture in ipairs(aperture_order) do
		local macro = aperture.macro
		if macro then
			local s = dump.tostring(macro)
			if macros[s] then
				aperture.macro = macros[s]
			else
				macros[s] = macro
				table.insert(macro_order, macro)
			end
		end
	end
end

local function merge_board_apertures(board)
	for _,image in pairs(board.images) do
		merge_image_apertures(image)
	end
end

function _M.merge_apertures(board)
	merge_board_apertures(board)
end

------------------------------------------------------------------------------

local function value_to_pm(value, unit)
	assert(value:match('^(%d+)%.(%d+)$') or value:match('^(%d+)$'), "malformed number '"..value.."'")
	if unit=='pm' then
		return assert(tonumber(value), "number conversion failed")
	elseif unit=='mm' then
		-- simply move the dot 9 digits to the right
		local i,dm = value:match('^(%d+)%.(%d+)$')
		local dp
		if i and dm then
			if #dm < 9 then
				dp = '0'
				dm = dm..string.rep('0', 9 - #dm)
			else
				dp = dm:sub(10)
				dm = dm:sub(1, 9)
			end
		else
			i = value
			dp = '0'
			dm = '000000000'
		end
		return assert(tonumber(i..dm..'.'..dp), "number conversion failed")
	elseif unit=='in' then
		-- move the dot 8 digits to the right, and multiply by 254
		local i,dm = value:match('^(%d+)%.(%d+)$')
		local dp
		if i and dm then
			if #dm < 8 then
				dp = '0'
				dm = dm..string.rep('0', 8 - #dm)
			else
				dp = dm:sub(9)
				dm = dm:sub(1, 8)
			end
		else
			i = value
			dp = '0'
			dm = '00000000'
		end
		return 254 * assert(tonumber(i..dm..'.'..dp), "number conversion failed")
	else
		error("invalid unit '"..tostring(unit).."'")
	end
end

function _M.parse_distances(str)
	local numbers = {}
	for sign,value,unit in str:gmatch('([+-]?)([%d.]+)(%w*)') do
		if unit=='' then unit = 'mm' end
		local n = value_to_pm(value, unit)
		if sign=='-' then n = -n end
		table.insert(numbers, n)
	end
	return table.unpack(numbers)
end

local function empty_image()
	return {
		format = { integer = 2, decimal = 4, zeroes = 'L' },
		unit = 'IN',
		extents = region(),
		center_extents = region(),
		layers = { { polarity = 'dark' } },
	}
end

function _M.empty_board(width, height)
	return {
		unit = 'pm',
		template = default_template,
		images = {
			milling = empty_image(),
			drill = empty_image(),
			top_paste = empty_image(),
			bottom_paste = empty_image(),
			top_copper = empty_image(),
			bottom_copper = empty_image(),
			top_soldermask = empty_image(),
			bottom_soldermask = empty_image(),
		},
		extensions = {},
		extents = region{
			left = 0, right = width,
			bottom = 0, top = height,
		},
	}
end

local function board_to_panel(board)
	local panel = copy_board(board)
	panel.left = { board.extents.bottom, board.extents.top }
	panel.right = { board.extents.bottom, board.extents.top }
	panel.bottom = { board.extents.left, board.extents.right }
	panel.top = { board.extents.left, board.extents.right }
	-- panels need milling and drill images
	if not panel.images.milling then
		panel.images.milling = empty_image()
		panel.extensions.milling = 'gml'
	end
	if not panel.images.drill then
		panel.images.drill = empty_image()
		panel.extensions.drill = 'drd'
	end
	return panel
end

local function draw_path(image, aperture, ...)
	local path = {
		aperture = aperture,
		unit = image.unit,
	}
	for i=1,select('#', ...),2 do
		local x,y = select(i, ...)
		table.insert(path, { x = x, y = y })
	end
	table.insert(image.layers[#image.layers], path)
end
_M.draw_path = draw_path

local function cut_tabs(panel, side_a, side_b, position, options, vertical)
	-- prepare routing and tab-separation drills
	-- :FIXME: for some reason the diameter needs to be scaled here, this is wrong
	local mill = { shape = 'circle', parameters = { options.spacing / 25.4 / 1e9 } }
	local drill = { shape = 'circle', parameters = { options.break_hole_diameter / 25.4 / 1e9 } }
	
	-- iterate over sides
	local a,b = 1,1
	while a < #side_a and b < #side_b do
		local a0,a1 = side_a[a],side_a[a+1]
		local b0,b1 = side_b[b],side_b[b+1]
		local c0 = math.max(a0, b0)
		local c1 = math.min(a1, b1)
		-- :TODO: add multiple tabs on long edges
		if c1 - c0 > options.break_tab_width + options.spacing then
			local c = (c0 + c1) / 2
			local z1 = c0 - options.spacing / 2
			local z2 = c - (options.break_tab_width + options.spacing) / 2
			local z3 = c + (options.break_tab_width + options.spacing) / 2
			local z4 = c1 + options.spacing / 2
			local w = position
			-- a half-line before the tab and a half-line after
			if vertical then
				draw_path(panel.images.milling, mill, z1, w, z2, w)
				draw_path(panel.images.milling, mill, z3, w, z4, w)
			else
				draw_path(panel.images.milling, mill, w, z1, w, z2)
				draw_path(panel.images.milling, mill, w, z3, w, z4)
			end
			-- drill holes to make the tabs easy to break
			local drill_count = math.floor(options.break_tab_width / options.break_hole_diameter / 2)
			local min
			for i=0,drill_count-1 do
				local z = (i - (drill_count-1) / 2) * options.break_hole_diameter * 2
				if vertical then
					draw_path(panel.images.drill, drill, c + z, w - options.spacing / 2)
					draw_path(panel.images.drill, drill, c + z, w + options.spacing / 2)
				else
					draw_path(panel.images.drill, drill, w - options.spacing / 2, c + z)
					draw_path(panel.images.drill, drill, w + options.spacing / 2, c + z)
				end
			end
		end
		if a1 < b1 then
			a = a + 2
		else
			b = b + 2
		end
	end
end

function _M.panelize(layout, options, vertical)
	local mm = 1e9
	if not options.spacing then
		options.spacing = 2*mm
	end
	if not options.break_hole_diameter then
		options.break_hole_diameter = 0.5*mm
	end
	if not options.break_tab_width then
		options.break_tab_width = 5*mm
	end
	if #layout == 0 then
		-- this is not a layout but a board
		return board_to_panel(layout)
	end
	
	-- panelize subpanels
	assert(#layout >= 1)
	local subpanels = {}
	for i=1,#layout do
		-- panelize sublayout
		local child = _M.panelize(layout[i], options, not vertical)
		subpanels[i] = child
		-- discard the outline
		child.images.outline = nil
	end
	
	-- assemble the panel
	local left,bottom = 0,0
	local panel
	for _,subpanel in ipairs(subpanels) do
		local dx = left - subpanel.extents.left
		local dy = bottom - subpanel.extents.bottom
		if not panel then
			panel = offset_panel(subpanel, dx, dy)
		else
			local neighbour = offset_panel(subpanel, dx, dy)
			-- draw cut lines and break tabs
			-- see http://blogs.mentor.com/tom-hausherr/blog/2011/06/23/pcb-design-perfection-starts-in-the-cad-library-part-19/
			if vertical then
				cut_tabs(panel, panel.top, neighbour.bottom, bottom - options.spacing / 2, options, vertical)
			else
				cut_tabs(panel, panel.right, neighbour.left, left - options.spacing / 2, options, vertical)
			end
			panel = merge_panels(panel, neighbour, vertical)
		end
		if vertical then
			bottom = panel.extents.top + options.spacing
		else
			left = panel.extents.right + options.spacing
		end
	end
	
	-- regenerate an outline
	local outline = copy_image(panel.images.milling)
	outline.layers = {{polarity = 'dark'}}
	draw_path(outline, { unit = outline.unit, shape = 'circle', parameters = { 0 } },
		panel.extents.left, panel.extents.bottom,
		panel.extents.right, panel.extents.bottom,
		panel.extents.right, panel.extents.top,
		panel.extents.left, panel.extents.top,
		panel.extents.left, panel.extents.bottom)
	panel.images.outline = outline
	
	return panel
end

------------------------------------------------------------------------------

return _M
