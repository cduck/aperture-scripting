local _M = {}

local table = require 'table'

local tinsert = table.insert
local tremove = table.remove

------------------------------------------------------------------------------

local function parse(group)
	local code,data = group.code,group.data
	if false then
	elseif 0 <= code and code <= 9 then
		-- String (with the introduction of extended symbol names in AutoCAD 2000, the 255-character limit has been increased to 2049 single-byte characters not including the newline at the end of the line)
		return data
	elseif 10 <= code and code <= 39 then
		-- Double precision 3D point value
		return tonumber(data)
	elseif 40 <= code and code <= 59 then
		-- Double-precision floating-point value
		return tonumber(data)
	elseif 60 <= code and code <= 79 then
		-- 16-bit integer value
		return tonumber(data)
	elseif 90 <= code and code <= 99 then
		-- 32-bit integer value
		return tonumber(data)
	elseif code == 100 then
		-- String (255-character maximum; less for Unicode strings)
		return data
	elseif code == 102 then
		-- String (255-character maximum; less for Unicode strings)
		error("group code "..code.." parsing not implemented")
	elseif code == 105 then
		-- String representing hexadecimal (hex) handle value
		return data
	elseif 110 <= code and code <= 119 then
		-- Double precision floating-point value
		error("group code "..code.." parsing not implemented")
	elseif 120 <= code and code <= 129 then
		-- Double precision floating-point value
		error("group code "..code.." parsing not implemented")
	elseif 130 <= code and code <= 139 then
		-- Double precision floating-point value
		error("group code "..code.." parsing not implemented")
	elseif 140 <= code and code <= 149 then
		-- Double precision scalar floating-point value
		return tonumber(data)
	elseif 160 <= code and code <= 169 then
		-- 64-bit integer value
		error("group code "..code.." parsing not implemented")
	elseif 170 <= code and code <= 179 then
		-- 16-bit integer value
		return tonumber(data)
	elseif 210 <= code and code <= 239 then
		-- Double-precision floating-point value
		error("group code "..code.." parsing not implemented")
	elseif 270 <= code and code <= 279 then
		-- 16-bit integer value
		return tonumber(data)
	elseif 280 <= code and code <= 289 then
		-- 16-bit integer value
		return tonumber(data)
	elseif 290 <= code and code <= 299 then
		-- Boolean flag value
		error("group code "..code.." parsing not implemented")
	elseif 300 <= code and code <= 309 then
		-- Arbitrary text string
		error("group code "..code.." parsing not implemented")
	elseif 310 <= code and code <= 319 then
		-- String representing hex value of binary chunk
		error("group code "..code.." parsing not implemented")
	elseif 320 <= code and code <= 329 then
		-- String representing hex handle value
		error("group code "..code.." parsing not implemented")
	elseif 330 <= code and code <= 369 then
		-- String representing hex object IDs
		return data
	elseif 370 <= code and code <= 379 then
		-- 16-bit integer value
		error("group code "..code.." parsing not implemented")
	elseif 380 <= code and code <= 389 then
		-- 16-bit integer value
		error("group code "..code.." parsing not implemented")
	elseif 390 <= code and code <= 399 then
		-- String representing hex handle value
		error("group code "..code.." parsing not implemented")
	elseif 400 <= code and code <= 409 then
		-- 16-bit integer value
		error("group code "..code.." parsing not implemented")
	elseif 410 <= code and code <= 419 then
		-- String
		error("group code "..code.." parsing not implemented")
	elseif 420 <= code and code <= 429 then
		-- 32-bit integer value
		error("group code "..code.." parsing not implemented")
	elseif 430 <= code and code <= 439 then
		-- String
		error("group code "..code.." parsing not implemented")
	elseif 440 <= code and code <= 449 then
		-- 32-bit integer value
		error("group code "..code.." parsing not implemented")
	elseif 450 <= code and code <= 459 then
		-- Long
		error("group code "..code.." parsing not implemented")
	elseif 460 <= code and code <= 469 then
		-- Double-precision floating-point value
		error("group code "..code.." parsing not implemented")
	elseif 470 <= code and code <= 479 then
		-- String
		error("group code "..code.." parsing not implemented")
	elseif 480 <= code and code <= 481 then
		-- String representing hex handle value
		error("group code "..code.." parsing not implemented")
	elseif code == 999 then
		-- Comment (string)
		error("group code "..code.." parsing not implemented")
	elseif 1000 <= code and code <= 1009 then
		-- String (same limits as indicated with 0-9 code range)
		error("group code "..code.." parsing not implemented")
	elseif 1010 <= code and code <= 1059 then
		-- Double-precision floating-point value
		error("group code "..code.." parsing not implemented")
	elseif 1060 <= code and code <= 1070 then
		-- 16-bit integer value
		error("group code "..code.." parsing not implemented")
	elseif code == 1071 then
		-- 32-bit integer value
		error("group code "..code.." parsing not implemented")
	else
		error("unsupported group code "..tostring(code))
	end
end

local function groupcode_default(code, value)
	local data
	if false then
	elseif 0 <= code and code <= 9 then
		-- String (with the introduction of extended symbol names in AutoCAD 2000, the 255-character limit has been increased to 2049 single-byte characters not including the newline at the end of the line)
		assert(#value <= 2049)
		data = value
	elseif 10 <= code and code <= 39 then
		-- Double precision 3D point value
		data = tostring(value)
		assert((value == 0 or math.abs(tonumber(data) / value - 1) < 1e-9) and data:match('^[%d.]+$'))
	elseif 40 <= code and code <= 59 then
		-- Double-precision floating-point value
		data = tostring(value)
		assert((value == 0 or math.abs(tonumber(data) / value - 1) < 1e-9) and data:match('^[%d.]+$'))
	elseif 60 <= code and code <= 79 then
		-- 16-bit integer value
		data = tostring(value)
		assert(tonumber(data) == value and data:match('^%s*[%d]+$'))
	elseif 90 <= code and code <= 99 then
		-- 32-bit integer value
		data = tostring(value)
		assert(tonumber(data) == value and data:match('^[%d]+$'))
	elseif code == 100 then
		-- String (255-character maximum; less for Unicode strings)
		assert(#value <= 255)
		data = value
	elseif code == 102 then
		-- String (255-character maximum; less for Unicode strings)
		error("group code "..code.." unparsing not implemented")
	elseif code == 105 then
		-- String representing hexadecimal (hex) handle value
		assert(value:match('^%x+$'))
		data = value
	elseif 110 <= code and code <= 119 then
		-- Double precision floating-point value
		error("group code "..code.." unparsing not implemented")
	elseif 120 <= code and code <= 129 then
		-- Double precision floating-point value
		error("group code "..code.." unparsing not implemented")
	elseif 130 <= code and code <= 139 then
		-- Double precision floating-point value
		error("group code "..code.." unparsing not implemented")
	elseif 140 <= code and code <= 149 then
		-- Double precision scalar floating-point value
		data = tostring(value)
		assert((value == 0 or math.abs(tonumber(data) / value - 1) < 1e-9) and data:match('^[%d.]+$'))
	elseif 160 <= code and code <= 169 then
		-- 64-bit integer value
		error("group code "..code.." unparsing not implemented")
	elseif 170 <= code and code <= 179 then
		-- 16-bit integer value
		data = tostring(value)
		assert(tonumber(data) == value and data:match('^[%d]+$'))
	elseif 210 <= code and code <= 239 then
		-- Double-precision floating-point value
		error("group code "..code.." unparsing not implemented")
	elseif 270 <= code and code <= 279 then
		-- 16-bit integer value
		data = tostring(value)
		assert(tonumber(data) == value and data:match('^[%d]+$'))
	elseif 280 <= code and code <= 289 then
		-- 16-bit integer value
		data = tostring(value)
		assert(tonumber(data) == value and data:match('^[%d]+$'))
	elseif 290 <= code and code <= 299 then
		-- Boolean flag value
		error("group code "..code.." unparsing not implemented")
	elseif 300 <= code and code <= 309 then
		-- Arbitrary text string
		error("group code "..code.." unparsing not implemented")
	elseif 310 <= code and code <= 319 then
		-- String representing hex value of binary chunk
		error("group code "..code.." unparsing not implemented")
	elseif 320 <= code and code <= 329 then
		-- String representing hex handle value
		error("group code "..code.." unparsing not implemented")
	elseif 330 <= code and code <= 369 then
		-- String representing hex object IDs
		assert(value:match('^%x+$'))
		data = value
	elseif 370 <= code and code <= 379 then
		-- 16-bit integer value
		error("group code "..code.." unparsing not implemented")
	elseif 380 <= code and code <= 389 then
		-- 16-bit integer value
		error("group code "..code.." unparsing not implemented")
	elseif 390 <= code and code <= 399 then
		-- String representing hex handle value
		error("group code "..code.." unparsing not implemented")
	elseif 400 <= code and code <= 409 then
		-- 16-bit integer value
		error("group code "..code.." unparsing not implemented")
	elseif 410 <= code and code <= 419 then
		-- String
		error("group code "..code.." unparsing not implemented")
	elseif 420 <= code and code <= 429 then
		-- 32-bit integer value
		error("group code "..code.." unparsing not implemented")
	elseif 430 <= code and code <= 439 then
		-- String
		error("group code "..code.." unparsing not implemented")
	elseif 440 <= code and code <= 449 then
		-- 32-bit integer value
		error("group code "..code.." unparsing not implemented")
	elseif 450 <= code and code <= 459 then
		-- Long
		error("group code "..code.." unparsing not implemented")
	elseif 460 <= code and code <= 469 then
		-- Double-precision floating-point value
		error("group code "..code.." unparsing not implemented")
	elseif 470 <= code and code <= 479 then
		-- String
		error("group code "..code.." unparsing not implemented")
	elseif 480 <= code and code <= 481 then
		-- String representing hex handle value
		error("group code "..code.." unparsing not implemented")
	elseif code == 999 then
		-- Comment (string)
		error("group code "..code.." unparsing not implemented")
	elseif 1000 <= code and code <= 1009 then
		-- String (same limits as indicated with 0-9 code range)
		error("group code "..code.." unparsing not implemented")
	elseif 1010 <= code and code <= 1059 then
		-- Double-precision floating-point value
		error("group code "..code.." unparsing not implemented")
	elseif 1060 <= code and code <= 1070 then
		-- 16-bit integer value
		error("group code "..code.." unparsing not implemented")
	elseif code == 1071 then
		-- 32-bit integer value
		error("group code "..code.." unparsing not implemented")
	else
		error("unsupported group code "..tostring(code))
	end
	return {code=code, data=data}
end

local function groupcode_inkscape(code, value)
	local data
	if false then
	elseif code == 30 and value == 0 then
		data = "0.0"
	elseif 0 <= code and code <= 9 then
		-- String (with the introduction of extended symbol names in AutoCAD 2000, the 255-character limit has been increased to 2049 single-byte characters not including the newline at the end of the line)
		assert(#value <= 2049)
		data = value
	elseif 10 <= code and code <= 39 then -- Double precision 3D point value
		data = string.format("%.6f", value)
		assert((value == 0 or math.abs(tonumber(data) / value - 1) < 1e-9) and data:match('^[%d.]+$'))
	elseif 40 <= code and code <= 59 then -- Double-precision floating-point value
		data = string.format('%f', value)
		assert((value == 0 or math.abs(tonumber(data) / value - 1) < 1e-9) and data:match('^[%d.]+$'))
	elseif 60 <= code and code <= 79 then -- 16-bit integer value
		data = string.format('%d', value)
		assert(tonumber(data) == value and data:match('^%s*[%d]+$'))
	elseif 90 <= code and code <= 99 then -- 32-bit integer value
		data = tostring(value)
		assert(tonumber(data) == value and data:match('^[%d]+$'))
	elseif code == 100 then -- String (255-character maximum; less for Unicode strings)
		assert(#value <= 255)
		data = value
	elseif code == 105 then -- String representing hexadecimal (hex) handle value
		assert(value:match('^%x+$'))
		data = value
	elseif 140 <= code and code <= 149 then -- Double precision scalar floating-point value
		data = tostring(value)
		assert((value == 0 or math.abs(tonumber(data) / value - 1) < 1e-9) and data:match('^[%d.]+$'))
	elseif 170 <= code and code <= 179 then -- 16-bit integer value
		data = string.format('%6d', value)
		assert(tonumber(data) == value and data:match('^%s*[%d]+$'))
	elseif 270 <= code and code <= 279 then -- 16-bit integer value
		data = string.format('%6d', value)
		assert(tonumber(data) == value and data:match('^%s*[%d]+$'))
	elseif 280 <= code and code <= 289 then -- 16-bit integer value
		data = string.format('%6d', value)
		assert(tonumber(data) == value and data:match('^%s*[%d]+$'))
	elseif 330 <= code and code <= 369 then -- String representing hex object IDs
		assert(value:match('^%x+$'))
		data = value
	end
	return {code=code, data=data}
end

_M.format = nil
local function groupcode(...)
	if _M.format == 'inkscape' then
		return groupcode_inkscape(...)
	else
		return groupcode_default(...)
	end
end

------------------------------------------------------------------------------

local load_subclass = {}
local save_subclass = {}

function load_subclass_generic(groupcodes)
	local subclass = {}
	for _,group in ipairs(groupcodes) do
		local code = group.code
		local value = parse(group)
		table.insert(subclass, {code=code, value=value})
	end
	return subclass
end

function save_subclass_generic(subclass)
	local groupcodes = {}
	for _,group in ipairs(subclass) do
		table.insert(groupcodes, groupcode(group.code, group.value))
	end
	return groupcodes
end

function load_subclass.AcDbPolyline(groupcodes)
	local subclass = {}
	for _,group in ipairs(groupcodes) do
		local code = group.code
		if code == 90 then
			subclass.vertex_count = parse(group)
		elseif code == 70 then
			subclass.flags = parse(group)
		elseif code == 10 or code == 20 or code == 30 then
			-- treated below
		else
			error("unsupported code "..tostring(code).." in AcDbPolyline")
		end
	end
	local vertices = {}
	for i=1,subclass.vertex_count do vertices[i] = {} end
	local lastx,lasty,lastz = 0,0,0
	for _,group in ipairs(groupcodes) do
		if group.code == 10 then
			lastx = lastx + 1
			vertices[lastx].x = parse(group)
		elseif group.code == 20 then
			lasty = lasty + 1
			vertices[lasty].y = parse(group)
		elseif group.code == 30 then
			lastz = lastz + 1
			vertices[lastz].z = parse(group)
		end
	end
	for i=1,subclass.vertex_count do
		local vertex = vertices[i]
		assert(vertex.x and vertex.y and vertex.z)
	end
	subclass.vertex_count = nil
	subclass.vertices = vertices
	return subclass
end

function save_subclass.AcDbPolyline(subclass)
	local groupcodes = {}
	table.insert(groupcodes, groupcode(90, #subclass.vertices))
	table.insert(groupcodes, groupcode(70, subclass.flags))
	for _,vertex in ipairs(subclass.vertices) do
		table.insert(groupcodes, groupcode(10, vertex.x))
		table.insert(groupcodes, groupcode(20, vertex.y))
		if vertex.z then
			table.insert(groupcodes, groupcode(30, vertex.z))
		end
	end
	return groupcodes
end

function load_subclass.AcDbLine(groupcodes)
	local subclass = {}
	for _,group in ipairs(groupcodes) do
		local code = group.code
		if code == 39 then
			subclass.thickness = parse(group)
		elseif code == 10 then
			subclass.start_point = subclass.start_point or {}
			subclass.start_point.x = parse(group)
		elseif code == 20 then
			subclass.start_point = subclass.start_point or {}
			subclass.start_point.y = parse(group)
		elseif code == 30 then
			subclass.start_point = subclass.start_point or {}
			subclass.start_point.z = parse(group)
		elseif code == 11 then
			subclass.end_point = subclass.end_point or {}
			subclass.end_point.x = parse(group)
		elseif code == 21 then
			subclass.end_point = subclass.end_point or {}
			subclass.end_point.y = parse(group)
		elseif code == 31 then
			subclass.end_point = subclass.end_point or {}
			subclass.end_point.z = parse(group)
		elseif code == 210 then
			subclass.extrusion_direction = subclass.extrusion_direction or {}
			subclass.extrusion_direction.x = parse(group)
		elseif code == 220 then
			subclass.extrusion_direction = subclass.extrusion_direction or {}
			subclass.extrusion_direction.y = parse(group)
		elseif code == 230 then
			subclass.extrusion_direction = subclass.extrusion_direction or {}
			subclass.extrusion_direction.z = parse(group)
		else
			error("unsupported code "..tostring(code).." in AcDbLine")
		end
	end
	return subclass
end

function save_subclass.AcDbLine(subclass)
	local groupcodes = {}
	if subclass.thickness ~= nil then
		table.insert(groupcodes, groupcode(39, subclass.thickness))
	end
	if subclass.start_point ~= nil then
		if subclass.start_point.x ~= nil then
			table.insert(groupcodes, groupcode(10, subclass.start_point.x))
		end
		if subclass.start_point.y ~= nil then
			table.insert(groupcodes, groupcode(20, subclass.start_point.y))
		end
		if subclass.start_point.z ~= nil then
			table.insert(groupcodes, groupcode(30, subclass.start_point.z))
		end
	end
	if subclass.end_point ~= nil then
		if subclass.end_point.x ~= nil then
			table.insert(groupcodes, groupcode(11, subclass.end_point.x))
		end
		if subclass.end_point.y ~= nil then
			table.insert(groupcodes, groupcode(21, subclass.end_point.y))
		end
		if subclass.end_point.z ~= nil then
			table.insert(groupcodes, groupcode(31, subclass.end_point.z))
		end
	end
	if subclass.extrusion_direction ~= nil then
		if subclass.extrusion_direction.x ~= nil then
			table.insert(groupcodes, groupcode(210, subclass.extrusion_direction.x))
		end
		if subclass.extrusion_direction.y ~= nil then
			table.insert(groupcodes, groupcode(220, subclass.extrusion_direction.y))
		end
		if subclass.extrusion_direction.z ~= nil then
			table.insert(groupcodes, groupcode(230, subclass.extrusion_direction.z))
		end
	end
	return groupcodes
end

function load_subclass.AcDbDictionary(groupcodes)
	local keys = {}
	local values = {}
	for _,group in ipairs(groupcodes) do
		local code = group.code
		if code == 3 then
			table.insert(keys, parse(group))
		elseif code == 350 then
			table.insert(values, parse(group))
		else
			error("unsupported code "..tostring(code).." in AcDbDictionary")
		end
	end
	assert(#keys == #values, "number of keys and values don't match in AcDbDictionary")
	local subclass = {type='AcDbDictionary'}
	for i=1,#keys do
		table.insert(subclass, {key=keys[i], value=values[i]})
	end
	return subclass
end

function save_subclass.AcDbDictionary(subclass)
	local groupcodes = {}
	for _,pair in ipairs(subclass) do
		table.insert(groupcodes, groupcode(3, pair.key))
		table.insert(groupcodes, groupcode(350, pair.value))
	end
	return groupcodes
end

function load_subclass.AcDbTextStyleTableRecord(groupcodes)
	local subclass = {type='AcDbTextStyleTableRecord'}
	for _,group in ipairs(groupcodes) do
		local code = group.code
		if code == 2 then
			subclass.name = parse(group)
		elseif code == 70 then
			subclass.flags = parse(group)
		elseif code == 40 then
			subclass.text_height = parse(group)
		elseif code == 41 then
			subclass.width_factor = parse(group)
		elseif code == 50 then
			subclass.oblique_angle = parse(group)
		elseif code == 71 then
			subclass.generation_flags = parse(group)
		elseif code == 42 then
			subclass.last_height_used = parse(group)
		elseif code == 3 then
			subclass.primary_font_filename = parse(group)
		elseif code == 4 then
			subclass.big_font_filename = parse(group)
		else
			error("unsupported code "..tostring(code).." in AcDbTextStyleTableRecord")
		end
	end
	return subclass
end

function save_subclass.AcDbTextStyleTableRecord(subclass)
	local groupcodes = {}
	if subclass.name then
		table.insert(groupcodes, groupcode(2, subclass.name))
	end
	if subclass.flags then
		table.insert(groupcodes, groupcode(70, subclass.flags))
	end
	if subclass.text_height then
		table.insert(groupcodes, groupcode(40, subclass.text_height))
	end
	if subclass.width_factor then
		table.insert(groupcodes, groupcode(41, subclass.width_factor))
	end
	if subclass.oblique_angle then
		table.insert(groupcodes, groupcode(50, subclass.oblique_angle))
	end
	if subclass.generation_flags then
		table.insert(groupcodes, groupcode(71, subclass.generation_flags))
	end
	if subclass.last_height_used then
		table.insert(groupcodes, groupcode(42, subclass.last_height_used))
	end
	if subclass.primary_font_filename then
		table.insert(groupcodes, groupcode(3, subclass.primary_font_filename))
	end
	if subclass.big_font_filename then
		table.insert(groupcodes, groupcode(4, subclass.big_font_filename))
	end
	return groupcodes
end

function load_subclass.AcDbViewportTableRecord(groupcodes)
	local subclass = {type='AcDbViewportTableRecord'}
	for _,group in ipairs(groupcodes) do
		local code = group.code
		if code == 2 then
			subclass.name = parse(group)
		elseif code == 70 then
			subclass.flags = parse(group)
		elseif code == 10 then
			subclass.extents = subclass.extents or {}
			subclass.extents.left = parse(group)
		elseif code == 20 then
			subclass.extents = subclass.extents or {}
			subclass.extents.bottom = parse(group)
		elseif code == 11 then
			subclass.extents = subclass.extents or {}
			subclass.extents.right = parse(group)
		elseif code == 21 then
			subclass.extents = subclass.extents or {}
			subclass.extents.top = parse(group)
		elseif code == 12 then
			subclass.center = subclass.center or {}
			subclass.center.x = parse(group)
		elseif code == 22 then
			subclass.center = subclass.center or {}
			subclass.center.y = parse(group)
		elseif code == 13 then
			subclass.snap_base_point = subclass.snap_base_point or {}
			subclass.snap_base_point.x = parse(group)
		elseif code == 23 then
			subclass.snap_base_point = subclass.snap_base_point or {}
			subclass.snap_base_point.y = parse(group)
		elseif code == 14 then
			subclass.snap_spacing = subclass.snap_spacing or {}
			subclass.snap_spacing.x = parse(group)
		elseif code == 24 then
			subclass.snap_spacing = subclass.snap_spacing or {}
			subclass.snap_spacing.y = parse(group)
		elseif code == 15 then
			subclass.grid_spacing = subclass.grid_spacing or {}
			subclass.grid_spacing.x = parse(group)
		elseif code == 25 then
			subclass.grid_spacing = subclass.grid_spacing or {}
			subclass.grid_spacing.y = parse(group)
		elseif code == 16 then
			subclass.view_direction = subclass.view_direction or {}
			subclass.view_direction.x = parse(group)
		elseif code == 26 then
			subclass.view_direction = subclass.view_direction or {}
			subclass.view_direction.y = parse(group)
		elseif code == 36 then
			subclass.view_direction = subclass.view_direction or {}
			subclass.view_direction.z = parse(group)
		elseif code == 17 then
			subclass.view_target_point = subclass.view_target_point or {}
			subclass.view_target_point.x = parse(group)
		elseif code == 27 then
			subclass.view_target_point = subclass.view_target_point or {}
			subclass.view_target_point.y = parse(group)
		elseif code == 37 then
			subclass.view_target_point = subclass.view_target_point or {}
			subclass.view_target_point.z = parse(group)
		elseif code == 40 then
			subclass.view_height = parse(group)
		elseif code == 41 then
			subclass.viewport_aspect_ratio = parse(group)
		elseif code == 42 then
			subclass.lens_length = parse(group)
		elseif code == 43 then
			subclass.front_clipping_plane = parse(group)
		elseif code == 44 then
			subclass.back_clipping_plane = parse(group)
		elseif code == 50 then
			subclass.snap_rotation_angle = parse(group)
		elseif code == 51 then
			subclass.view_twist_angle = parse(group)
		elseif code == 71 then
			subclass.view_mode = parse(group)
		elseif code == 72 then
			subclass.circle_zoom_percent = parse(group)
		elseif code == 73 then
			subclass.fast_zoom_setting = parse(group)
		elseif code == 74 then
			subclass.ucsicon_setting = parse(group)
		elseif code == 75 then
			subclass.snap_on = parse(group) ~= 0
		elseif code == 76 then
			subclass.grid_on = parse(group) ~= 0
		elseif code == 77 then
			subclass.snap_style = parse(group)
		elseif code == 78 then
			subclass.snap_isopair = parse(group)
		elseif code == 281 then
			subclass.render_mode = parse(group)
		elseif code == 65 then
			subclass.ucsvp = parse(group)
		elseif code == 110 then
			subclass.ucs_origin = subclass.ucs_origin or {}
			subclass.ucs_origin.x = parse(group)
		elseif code == 120 then
			subclass.ucs_origin = subclass.ucs_origin or {}
			subclass.ucs_origin.y = parse(group)
		elseif code == 130 then
			subclass.ucs_origin = subclass.ucs_origin or {}
			subclass.ucs_origin.z = parse(group)
		elseif code == 111 then
			subclass.ucs_x_axis = subclass.ucs_x_axis or {}
			subclass.ucs_x_axis.x = parse(group)
		elseif code == 121 then
			subclass.ucs_x_axis = subclass.ucs_x_axis or {}
			subclass.ucs_x_axis.y = parse(group)
		elseif code == 131 then
			subclass.ucs_x_axis = subclass.ucs_x_axis or {}
			subclass.ucs_x_axis.z = parse(group)
		elseif code == 112 then
			subclass.ucs_y_axis = subclass.ucs_y_axis or {}
			subclass.ucs_y_axis.x = parse(group)
		elseif code == 122 then
			subclass.ucs_y_axis = subclass.ucs_y_axis or {}
			subclass.ucs_y_axis.y = parse(group)
		elseif code == 132 then
			subclass.ucs_y_axis = subclass.ucs_y_axis or {}
			subclass.ucs_y_axis.z = parse(group)
		elseif code == 79 then
			subclass.orthographic_type_of_ucs = parse(group)
		elseif code == 146 then
			subclass.elevation = parse(group)
		elseif code == 345 then
			subclass.named_ucs_record = parse(group)
		elseif code == 346 then
			subclass.orthographic_ucs_record = parse(group)
		else
			error("unsupported code "..tostring(code).." in AcDbViewportTableRecord")
		end
	end
	return subclass
end

function save_subclass.AcDbViewportTableRecord(subclass)
	local groupcodes = {}
	if subclass.name then
		table.insert(groupcodes, groupcode(2, subclass.name))
	end
	if subclass.flags ~= nil then
		table.insert(groupcodes, groupcode(70, subclass.flags))
	end
	if subclass.extents ~= nil then
		if subclass.extents.left ~= nil then
			table.insert(groupcodes, groupcode(10, subclass.extents.left))
		end
		if subclass.extents.bottom ~= nil then
			table.insert(groupcodes, groupcode(20, subclass.extents.bottom))
		end
		if subclass.extents.right ~= nil then
			table.insert(groupcodes, groupcode(11, subclass.extents.right))
		end
		if subclass.extents.top ~= nil then
			table.insert(groupcodes, groupcode(21, subclass.extents.top))
		end
	end
	if subclass.center ~= nil then
		if subclass.center.x ~= nil then
			table.insert(groupcodes, groupcode(12, subclass.center.x))
		end
		if subclass.center.y ~= nil then
			table.insert(groupcodes, groupcode(22, subclass.center.y))
		end
	end
	if subclass.snap_base_point ~= nil then
		if subclass.snap_base_point.x ~= nil then
			table.insert(groupcodes, groupcode(13, subclass.snap_base_point.x))
		end
		if subclass.snap_base_point.y ~= nil then
			table.insert(groupcodes, groupcode(23, subclass.snap_base_point.y))
		end
	end
	if subclass.snap_spacing ~= nil then
		if subclass.snap_spacing.x ~= nil then
			table.insert(groupcodes, groupcode(14, subclass.snap_spacing.x))
		end
		if subclass.snap_spacing.y ~= nil then
			table.insert(groupcodes, groupcode(24, subclass.snap_spacing.y))
		end
	end
	if subclass.grid_spacing ~= nil then
		if subclass.grid_spacing.x ~= nil then
			table.insert(groupcodes, groupcode(15, subclass.grid_spacing.x))
		end
		if subclass.grid_spacing.y ~= nil then
			table.insert(groupcodes, groupcode(25, subclass.grid_spacing.y))
		end
	end
	if subclass.view_direction ~= nil then
		if subclass.view_direction.x ~= nil then
			table.insert(groupcodes, groupcode(16, subclass.view_direction.x))
		end
		if subclass.view_direction.y ~= nil then
			table.insert(groupcodes, groupcode(26, subclass.view_direction.y))
		end
		if subclass.view_direction.z ~= nil then
			table.insert(groupcodes, groupcode(36, subclass.view_direction.z))
		end
	end
	if subclass.view_target_point ~= nil then
		if subclass.view_target_point.x ~= nil then
			table.insert(groupcodes, groupcode(17, subclass.view_target_point.x))
		end
		if subclass.view_target_point.y ~= nil then
			table.insert(groupcodes, groupcode(27, subclass.view_target_point.y))
		end
		if subclass.view_target_point.z ~= nil then
			table.insert(groupcodes, groupcode(37, subclass.view_target_point.z))
		end
	end
	if subclass.view_height ~= nil then
		table.insert(groupcodes, groupcode(40, subclass.view_height))
	end
	if subclass.viewport_aspect_ratio ~= nil then
		table.insert(groupcodes, groupcode(41, subclass.viewport_aspect_ratio))
	end
	if subclass.lens_length ~= nil then
		table.insert(groupcodes, groupcode(42, subclass.lens_length))
	end
	if subclass.front_clipping_plane ~= nil then
		table.insert(groupcodes, groupcode(43, subclass.front_clipping_plane))
	end
	if subclass.back_clipping_plane ~= nil then
		table.insert(groupcodes, groupcode(44, subclass.back_clipping_plane))
	end
	if subclass.snap_rotation_angle ~= nil then
		table.insert(groupcodes, groupcode(50, subclass.snap_rotation_angle))
	end
	if subclass.view_twist_angle ~= nil then
		table.insert(groupcodes, groupcode(51, subclass.view_twist_angle))
	end
	if subclass.view_mode ~= nil then
		table.insert(groupcodes, groupcode(71, subclass.view_mode))
	end
	if subclass.circle_zoom_percent ~= nil then
		table.insert(groupcodes, groupcode(72, subclass.circle_zoom_percent))
	end
	if subclass.fast_zoom_setting ~= nil then
		table.insert(groupcodes, groupcode(73, subclass.fast_zoom_setting))
	end
	if subclass.ucsicon_setting ~= nil then
		table.insert(groupcodes, groupcode(74, subclass.ucsicon_setting))
	end
	if subclass.snap_on then
		table.insert(groupcodes, groupcode(75, 1))
	end
	if subclass.grid_on then
		table.insert(groupcodes, groupcode(76, 1))
	end
	if subclass.snap_style ~= nil then
		table.insert(groupcodes, groupcode(77, subclass.snap_style))
	end
	if subclass.snap_isopair ~= nil then
		table.insert(groupcodes, groupcode(78, subclass.snap_isopair))
	end
	if subclass.render_mode ~= nil then
		table.insert(groupcodes, groupcode(281, subclass.render_mode))
	end
	if subclass.ucsvp ~= nil then
		table.insert(groupcodes, groupcode(65, subclass.ucsvp))
	end
	if subclass.ucs_origin ~= nil then
		if subclass.ucs_origin.x ~= nil then
			table.insert(groupcodes, groupcode(110, subclass.ucs_origin.x))
		end
		if subclass.ucs_origin.y ~= nil then
			table.insert(groupcodes, groupcode(120, subclass.ucs_origin.y))
		end
		if subclass.ucs_origin.z ~= nil then
			table.insert(groupcodes, groupcode(130, subclass.ucs_origin.z))
		end
	end
	if subclass.ucs_x_axis ~= nil then
		if subclass.ucs_x_axis.x ~= nil then
			table.insert(groupcodes, groupcode(111, subclass.ucs_x_axis.x))
		end
		if subclass.ucs_x_axis.y ~= nil then
			table.insert(groupcodes, groupcode(121, subclass.ucs_x_axis.y))
		end
		if subclass.ucs_x_axis.z ~= nil then
			table.insert(groupcodes, groupcode(131, subclass.ucs_x_axis.z))
		end
	end
	if subclass.ucs_y_axis ~= nil then
		if subclass.ucs_y_axis.x ~= nil then
			table.insert(groupcodes, groupcode(112, subclass.ucs_y_axis.x))
		end
		if subclass.ucs_y_axis.y ~= nil then
			table.insert(groupcodes, groupcode(122, subclass.ucs_y_axis.y))
		end
		if subclass.ucs_y_axis.z ~= nil then
			table.insert(groupcodes, groupcode(132, subclass.ucs_y_axis.z))
		end
	end
	if subclass.orthographic_type_of_ucs ~= nil then
		table.insert(groupcodes, groupcode(79, subclass.orthographic_type_of_ucs))
	end
	if subclass.elevation ~= nil then
		table.insert(groupcodes, groupcode(146, subclass.elevation))
	end
	if subclass.named_ucs_record ~= nil then
		table.insert(groupcodes, groupcode(345, subclass.named_ucs_record))
	end
	if subclass.orthographic_ucs_record ~= nil then
		table.insert(groupcodes, groupcode(346, subclass.orthographic_ucs_record))
	end
	return groupcodes
end

function load_subclass.AcDbEntity(groupcodes)
	local subclass = {
		type = 'AcDbEntity',
		line_type_name = 'BYLAYER',
		color = 'BYLAYER',
		line_type_scale = 1.0,
	}
	for _,group in ipairs(groupcodes) do
		local code = group.code
		if code == 67 then
			subclass.paper_space = parse(group) ~= 0
		elseif code == 8 then
			subclass.layer = parse(group)
		elseif code == 6 then
			subclass.line_type_name = parse(group)
		elseif code == 62 then
			local value = parse(group)
			if value == 0 then
				subclass.color = 'BYBLOCK'
			elseif value == 255 then
				assert(subclass.color == 'BYLAYER')
			else
				subclass.color = parse(group)
			end
		elseif code == 48 then
			subclass.line_type_scale = parse(group)
		elseif code == 60 then
			subclass.hidden = parse(group) ~= 0
		else
			error("unsupported code "..tostring(code).." in AcDbEntity")
		end
	end
	return subclass
end

function save_subclass.AcDbEntity(subclass)
	local groupcodes = {}
	if subclass.paper_space then
		table.insert(groupcodes, groupcode(67, 1))
	end
	assert(subclass.layer, "entity has no layer defined")
	table.insert(groupcodes, groupcode(8, subclass.layer))
	if subclass.line_type_name and subclass.line_type_name ~= 'BYLAYER' then
		table.insert(groupcodes, groupcode(6, subclass.line_type_name))
	end
	if subclass.color and subclass.color ~= 'BYLAYER' then
		if subclass.color == 'BYBLOCK' then
			table.insert(groupcodes, groupcode(62, 0))
		else
			table.insert(groupcodes, groupcode(62, subclass.color))
		end
	end
	if subclass.line_type_scale and subclass.line_type_scale ~= 1.0 then
		table.insert(groupcodes, groupcode(48, subclass.line_type_scale))
	end
	if subclass.hidden then
		table.insert(groupcodes, groupcode(60, 1))
	end
	return groupcodes
end

function load_subclass.AcDbSymbolTable(groupcodes)
	local subclass = {type='AcDbSymbolTable'}
	for _,group in ipairs(groupcodes) do
		local code = group.code
		if code == 70 then
			subclass.length = parse(group)
		else
			error("unsupported code "..tostring(code).." in AcDbSymbolTable")
		end
	end
	return subclass
end

function save_subclass.AcDbSymbolTable(subclass)
	local groupcodes = {}
	if subclass.length then
		table.insert(groupcodes, groupcode(70, subclass.length))
	end
	return groupcodes
end

local function load_object(type, groupcodes)
	local object = {
		type=type,
		attributes={},
	}
	local subclasses = {}
	local subclass
	for _,group in ipairs(groupcodes) do
		local code = group.code
		if code==100 then
			local classname = group.data
			subclass = { type = classname }
			table.insert(subclasses, subclass)
		elseif subclass then
			table.insert(subclass, group)
		--	subclass[code] = parse(group)
		else
			table.insert(object.attributes, {code=code, value=parse(group)})
		end
	end
	for _,groupcodes in ipairs(subclasses) do
		local classname = groupcodes.type
		local loader = load_subclass[classname] or load_subclass_generic
		local subclass = loader(groupcodes)
		subclass.type = classname
		table.insert(object, subclass)
	end
	if next(object.attributes)==nil then object.attributes = nil end
	return object
end

local function save_object(type, object)
	local groupcodes = {}
	if object.attributes then
		for _,group in ipairs(object.attributes) do
			table.insert(groupcodes, groupcode(group.code, group.value))
		end
	end
	for _,subclass in ipairs(object) do
		local classname = subclass.type
		table.insert(groupcodes, groupcode(100, classname))
		local saver = save_subclass[classname] or save_subclass_generic
		for _,group in ipairs(saver(subclass)) do
			table.insert(groupcodes, group)
		end
	end
	return groupcodes
end

------------------------------------------------------------------------------

local load_section = {}
local save_section = {}

--............................................................................

local header_codes = {
	ACADVER = 1,
	HANDSEED = 5,
	MEASUREMENT = 70,
}

function load_section.HEADER(groupcodes)
	local chunks = {}
	local chunk
	for _,group in ipairs(groupcodes) do
		local code = group.code
		if code == 9 then
			chunk = {}
			table.insert(chunk, group)
			table.insert(chunks, chunk)
		else
			table.insert(chunk, group)
		end
	end
	local headers = {}
	for _,chunk in pairs(chunks) do
		assert(#chunk >= 1)
		local name = table.remove(chunk, 1)
		assert(name.code == 9)
		name = assert(parse(name):match('^$(.*)$'))
		if header_codes[name] then
			assert(#chunk == 1)
			assert(chunk[1].code == header_codes[name])
			headers[name] = parse(chunk[1])
		else
			headers[name] = chunk
		end
	end
	return headers
end

function save_section.HEADER(headers)
	local names = {}
	for name in pairs(headers) do
		table.insert(names, name)
	end
	table.sort(names)
	local chunks = {}
	for _,name in ipairs(names) do
		local chunk = {}
		table.insert(chunk, groupcode(9, '$'..name))
		if header_codes[name] then
			table.insert(chunk, groupcode(header_codes[name], headers[name]))
		else
			for _,group in ipairs(headers[name]) do
				table.insert(chunk, group)
			end
		end
		table.insert(chunks, chunk)
	end
	local groupcodes = {}
	for _,chunk in ipairs(chunks) do
		for _,group in ipairs(chunk) do
			table.insert(groupcodes, group)
		end
	end
	return groupcodes
end

--............................................................................

function load_section.CLASSES(groupcodes)
	error("section not supported")
	local classes = {}
	local class
	for _,group in ipairs(groupcodes) do
		local code = group.code
		if code==0 then
			class = {}
			table.insert(classes, class)
		elseif code==1 then
			assert(class).class_dxf_record = parse(group)
		elseif code==2 then
			assert(class).class_name = parse(group)
		elseif code==3 then
			assert(class).app_name = parse(group)
		elseif code==90 then
			assert(class).flag90 = parse(group)
		elseif code==280 then
			assert(class).flag280 = parse(group)
		elseif code==281 then
			assert(class).flag281 = parse(group)
		else
			-- :TODO: save group code without interpreting it
		end
	end
	return classes
end

--............................................................................

local function load_table_header(groupcodes)
	return load_object(nil, groupcodes)
end

local function save_table_header(header)
	return save_object(nil, header)
end

local function load_table_record(type, groupcodes)
	return load_object(type, groupcodes)
end

local function save_table_record(type, record)
	return save_object(type, record)
end

local function load_table(type, groupcodes)
	local header = {}
	local records = {}
	local record = header
	for _,group in ipairs(groupcodes) do
		local code = group.code
		local data = group.data
		if code==0 then
			assert(data == type, "record type "..tostring(data).." differ from table type "..tostring(type))
			record = {}
			table.insert(records, record)
		else
			table.insert(record, group)
		end
	end
	
	header = load_table_header(header)
	local table = {type=type}
	for _,group in ipairs(header.attributes) do
		local code = group.code
		if code == 5 then
			table.handle = group.value
		elseif code == 330 then
			table.owner = group.value
		else
			error("unsupported code "..tostring(code).." in table header")
		end
	end
	assert(#header == 1)
	for _,subclass in ipairs(header) do
		if subclass.type == 'AcDbSymbolTable' then
		--	assert(subclass.length == #records) -- this is not required
		end
	end
	for _,record in ipairs(records) do
		record = load_table_record(type, record)
		assert(record.type == type)
		record.type = nil
		tinsert(table, record)
	end
	return table
end

local function save_table(table)
	local groupcodes = {}
	local header = {
		attributes = {},
		{ type = 'AcDbSymbolTable', length = #table },
	}
	if table.handle then tinsert(header.attributes, {code=5, value=table.handle}) end
	if table.owner then tinsert(header.attributes, {code=330, value=table.owner}) end
	for _,group in ipairs(save_table_header(header)) do
		tinsert(groupcodes, group)
	end
	for _,record in ipairs(table) do
		tinsert(groupcodes, groupcode(0, table.type))
		for _,group in ipairs(save_table_record(table.type, record)) do
			tinsert(groupcodes, group)
		end
	end
	return groupcodes
end

function load_section.TABLES(groupcodes)
	local chunks = {}
	local chunk
	for _,group in ipairs(groupcodes) do
		local code = group.code
		local data = group.data
		if code==0 and data=='TABLE' then
			chunk = {}
			tinsert(chunks, chunk)
		elseif code==0 and data=='ENDTAB' then
			chunk = nil
		else
			tinsert(chunk, group)
		end
	end
	
	local tables = {}
	for _,groupcodes in ipairs(chunks) do
		local name = tremove(groupcodes, 1)
		assert(name.code==2)
		name = name.data
		local table = load_table(name, groupcodes)
		tinsert(tables, table)
	end
	
	return tables
end

function save_section.TABLES(tables)
	local chunks = {}
	for _,table in ipairs(tables) do
		local chunk = save_table(table)
		tinsert(chunk, 1, groupcode(2, table.type))
		tinsert(chunks, chunk)
	end
	
	local groupcodes = {}
	for _,chunk in ipairs(chunks) do
		table.insert(groupcodes, groupcode(0, 'TABLE'))
		for _,group in ipairs(chunk) do
			table.insert(groupcodes, group)
		end
		table.insert(groupcodes, groupcode(0, 'ENDTAB'))
	end
	
	return groupcodes
end

--............................................................................

local function load_entity(type, groupcodes)
	return load_object(type, groupcodes)
end

local function save_entity(type, entity)
	return save_object(type, entity)
end

function load_section.ENTITIES(groupcodes)
	local chunks = {}
	local chunk
	for _,group in ipairs(groupcodes) do
		local code = group.code
		local data = group.data
		if code==0 then
			chunk = {group}
			table.insert(chunks, chunk)
		else
			table.insert(chunk, group)
		end
	end
	
	local entities = {}
	for _,groupcodes in ipairs(chunks) do
		local type = tremove(groupcodes, 1)
		assert(type.code==0)
		local entity = load_entity(type.data, groupcodes)
		table.insert(entities, entity)
	end
	
	return entities
end

function save_section.ENTITIES(entities)
	local chunks = {}
	for _,entity in ipairs(entities) do
		local chunk = save_entity(entity.type, entity)
		table.insert(chunk, 1, groupcode(0, entity.type))
		table.insert(chunks, chunk)
	end
	
	local groupcodes = {}
	for _,chunk in ipairs(chunks) do
		assert(chunk[1].code==0)
		for _,group in ipairs(chunk) do
			table.insert(groupcodes, group)
		end
	end
	return groupcodes
end

--............................................................................

function load_section.BLOCKS(groupcodes)
	local chunks = {}
	local chunk
	for _,group in ipairs(groupcodes) do
		local code = group.code
		local data = group.data
		if code==0 then
			chunk = {group}
			table.insert(chunks, chunk)
		else
			table.insert(chunk, group)
		end
	end
	
	local entities = {}
	for _,groupcodes in ipairs(chunks) do
		local type = tremove(groupcodes, 1)
		assert(type.code==0)
		local entity = load_entity(type.data, groupcodes)
		table.insert(entities, entity)
	end
	
	return entities
end

function save_section.BLOCKS(entities)
	local chunks = {}
	for _,entity in ipairs(entities) do
		local chunk = save_entity(entity.type, entity)
		table.insert(chunk, 1, groupcode(0, entity.type))
		table.insert(chunks, chunk)
	end
	
	local groupcodes = {}
	for _,chunk in ipairs(chunks) do
		assert(chunk[1].code==0)
		for _,group in ipairs(chunk) do
			table.insert(groupcodes, group)
		end
	end
	return groupcodes
end

--............................................................................

function load_section.OBJECTS(groupcodes)
	local chunks = {}
	local chunk
	for _,group in ipairs(groupcodes) do
		local code = group.code
		local data = group.data
		if code==0 then
			chunk = {group}
			table.insert(chunks, chunk)
		else
			table.insert(chunk, group)
		end
	end
	
	local root_dictionary = table.remove(chunks, 1)
	local type = table.remove(root_dictionary, 1)
	assert(type.code==0)
	assert(type.data=='DICTIONARY')
	root_dictionary = load_object(type.data, root_dictionary)
	
	local objects = {root_dictionary=root_dictionary}
	for _,groupcodes in ipairs(chunks) do
		local type = table.remove(groupcodes, 1)
		assert(type.code==0)
		local object = load_object(type.data, groupcodes)
		table.insert(objects, object)
	end
	
	return objects
end

function save_section.OBJECTS(objects)
	local chunks = {}
	
	local chunk = save_object(nil, objects.root_dictionary)
	table.insert(chunk, 1, groupcode(0, 'DICTIONARY'))
	table.insert(chunks, chunk)
	
	for _,object in ipairs(objects) do
		local chunk = save_object(object.type, object)
		table.insert(chunk, 1, groupcode(0, object.type))
		table.insert(chunks, chunk)
	end
	
	local groupcodes = {}
	for _,chunk in ipairs(chunks) do
		assert(chunk[1].code==0)
		for _,group in ipairs(chunk) do
			table.insert(groupcodes, group)
		end
	end
	
	return groupcodes
end

------------------------------------------------------------------------------

local function load_DXF(groupcodes)
	-- parse top level
	local chunks = {}
	local section
	for _,group in ipairs(groupcodes) do
		if group.code==0 and group.data=='SECTION' then
			section = {}
			table.insert(chunks, section)
		elseif group.code==0 and group.data=='ENDSEC' then
			section = nil
		elseif not section and group.code==0 and group.data=='EOF' then
			break
		else
			assert(section, "group code outside of any section")
			table.insert(section, group)
		end
	end
	
	-- convert sections
	local sections = {}
	for _,groupcodes in ipairs(chunks) do
		local name = table.remove(groupcodes, 1)
		assert(name.code==2)
		name = name.data
		local section = assert(load_section[name], "no loader for section "..tostring(name))(groupcodes)
	--	section.name = name
		sections[name] = section
	end
	
	return sections
end

local section_order = {'HEADER', 'TABLES', 'BLOCKS', 'ENTITIES', 'OBJECTS'}

local function save_DXF(sections)
	-- some checks
	for name in pairs(sections) do
		local found = false
		for _,name2 in ipairs(section_order) do
			if name2 == name then found = true; break end
		end
		assert(found, "unsuppoted DXF section "..tostring(name))
	end
	
	-- convert sections
	local chunks = {}
	for _,name in ipairs(section_order) do
		local section = sections[name]
		if section then
			local groupcodes = {}
			local groupcodes = assert(save_section[name], "no saver for section "..tostring(name))(section)
			table.insert(groupcodes, 1, groupcode(2, name))
			table.insert(chunks, groupcodes)
		end
	end
	
	-- unparse top level
	local groupcodes = {}
	for _,chunk in ipairs(chunks) do
		table.insert(groupcodes, groupcode(0, 'SECTION'))
		for _,group in ipairs(chunk) do
			table.insert(groupcodes, group)
		end
		table.insert(groupcodes, groupcode(0, 'ENDSEC'))
	end
	table.insert(groupcodes, groupcode(0, 'EOF'))
	
	return groupcodes
end

------------------------------------------------------------------------------

function _M.load(file_path)
	-- load lines
	local lines = {}
	for line in io.lines(file_path) do
		table.insert(lines, line)
	end
	assert(#lines % 2 == 0)
	
	-- group code and data
	local groupcodes = {}
	for i=1,#lines,2 do
		local code = assert(tonumber(lines[i]))
		local data = lines[i+1]
		if code==0 and data=='EOF' then
			assert(i==#lines-1)
			break
		end
		table.insert(groupcodes, {code=code, data=data})
	end
	
	local sections = load_DXF(groupcodes)
	
	local scale = 1e9
	
	local layers = {{polarity='dark'}}
	local layer = layers[1]
	local aperture = {shape='circle', parameters={0}, unit='MM', name=10}
	for _,entity in ipairs(sections.ENTITIES) do
		local npoints = 0
		if entity.type == 'LWPOLYLINE' then
			local vertices
			for _,subclass in ipairs(entity) do
				if subclass.type=='AcDbPolyline' then
					vertices = subclass.vertices
					break
				end
			end
			assert(vertices)
			local path = {aperture=aperture}
			for i,point in ipairs(vertices) do
				assert(point.z == 0, "3D entities are not yet supported")
				table.insert(path, {x=point.x*scale, y=point.y*scale, interpolation=i>1 and 'linear' or nil})
			end
			table.insert(layer, path)
		elseif entity.type == 'LINE' then
			local vertices
			for _,subclass in ipairs(entity) do
				if subclass.type=='AcDbLine' then
					vertices = {subclass.start_point, subclass.end_point}
					break
				end
			end
			assert(vertices)
			local path = {aperture=aperture}
			for i,point in ipairs(vertices) do
				assert(point.z == 0, "3D entities are not yet supported")
				table.insert(path, {x=point.x*scale, y=point.y*scale, interpolation=i>1 and 'linear' or nil})
			end
			table.insert(layer, path)
		else
			error("unsupported entity type "..tostring(entity.type))
		end
	end
	sections.ENTITIES = nil
	
	local image = {
		file_path = file_path,
		name = nil,
		format = {},
		unit = 'MM',
		layers = layers,
		dxf_sections = sections,
	}
	
	return image
end

function _M.save(image, file_path)
	assert(#image.layers == 1)
	assert(image.layers[1].polarity == 'dark')
	
	-- assemble DXF sections
	local sections = {}
	
	if image.dxf_sections then
		for k,v in pairs(image.dxf_sections) do
			sections[k] = v
		end
	end
	sections.ENTITIES = {}
	
	local scale = 1e9
	
	for ipath,path in ipairs(image.layers[1]) do
		local vertices = {}
		for i,point in ipairs(path) do
			if i > 1 then
				assert(not point.interpolated)
				assert(point.interpolation == 'linear')
			end
			table.insert(vertices, {x=point.x/scale, y=point.y/scale, z=0})
		end
		local entity = {
			type = 'LWPOLYLINE',
			attributes = {
				{code=5, value=string.format("%x", 0x100 + #sections.ENTITIES)},
			},
			{
				type = 'AcDbEntity',
				layer = "0",
				color = 7,
			},
			{
				type = 'AcDbPolyline',
				flags = 0,
				vertices = vertices,
			},
		}
		table.insert(sections.ENTITIES, entity)
	end
	
	-- generate group codes
	_M.format = image.format.dxf
	local groupcodes = save_DXF(sections)
	_M.format = nil
	
	-- write lines
	local lines = {}
	for i,group in ipairs(groupcodes) do
		local code,data = group.code,group.data
		assert(code, "group has no code")
		assert(data, "group has no data")
		table.insert(lines, string.format("%3d", code))
		table.insert(lines, group.data)
		if code==0 and data=='EOF' then
			assert(i==#groupcodes)
			break
		end
	end
	
	-- save lines
	local file = assert(io.open(file_path, 'wb'))
	for _,line in ipairs(lines) do
		assert(file:write(line..'\r\n'))
	end
	assert(file:close())
	
	return true
end

return _M
