local _M = {}

local table = require 'table'

local tinsert = table.insert
local tremove = table.remove

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

local load_section = {}

function load_section.HEADER(groupcodes)
	assert(#groupcodes % 2 == 0)
	local header = {}
	for i=1,#groupcodes,2 do
		local name = groupcodes[i]
		local value = groupcodes[i+1]
		assert(name.code==9)
		name = assert(name.data:match('^$(.*)$'))
		value = parse(value)
		header[name] = value
	end
	return header
end

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

local load_subclass = {}

function load_subclass.AcDbSymbolTable(groupcodes)
	-- :TODO: parse this subclass
	return nil
end

function load_subclass.AcDbSymbolTableRecord(groupcodes)
	-- :TODO: parse this subclass
	return nil
end

function load_subclass.AcDbViewportTableRecord(groupcodes)
	-- :TODO: parse this subclass
	return nil
end

function load_subclass.AcDbLinetypeTableRecord(groupcodes)
	-- :TODO: parse this subclass
	return nil
end

function load_subclass.AcDbLayerTableRecord(groupcodes)
	-- :TODO: parse this subclass
	return nil
end

function load_subclass.AcDbTextStyleTableRecord(groupcodes)
	-- :TODO: parse this subclass
	return nil
end

function load_subclass.AcDbRegAppTableRecord(groupcodes)
	-- :TODO: parse this subclass
	return nil
end

function load_subclass.AcDbDimStyleTableRecord(groupcodes)
	-- :TODO: parse this subclass
	return nil
end

function load_subclass.AcDbBlockTableRecord(groupcodes)
	-- :TODO: parse this subclass
	return nil
end

function load_subclass.AcDbEntity(groupcodes)
	-- :TODO: parse this subclass
	return nil
end

function load_subclass.AcDbPolyline(groupcodes)
	local subclass = {}
	for _,group in ipairs(groupcodes) do
		if group.code == 90 then
			subclass.vertex_count = parse(group)
		elseif group.code == 70 then
			subclass.flags = parse(group)
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

function load_subclass.AcDbDictionary(groupcodes)
	return {}
end

local function load_object(type, groupcodes)
	local object = {type=type, attributes={}}
	local subclasses = {}
	local subclass
	for _,group in ipairs(groupcodes) do
		local code = group.code
		if code==100 then
			local classname = group.data
			subclass = {}
			assert(subclasses[classname]==nil, "object has two "..classname.." subclasses")
			subclasses[classname] = subclass
		elseif subclass then
			table.insert(subclass, group)
		--	subclass[code] = parse(group)
		else
			object.attributes[code] = parse(group)
		end
	end
	for name,groupcodes in pairs(subclasses) do
		local subclass = assert(load_subclass[name], "no loader for subclass "..tostring(name))(groupcodes)
		object[name] = subclass
	end
	return object
end

local function load_table_header(groupcodes)
	return load_object(nil, groupcodes)
end

local function load_table_entry(type, groupcodes)
	return load_object(type, groupcodes)
end

local function load_table(groupcodes)
	local table = {header={}}
	local entry = table.header
	for _,groupcode in ipairs(groupcodes) do
		local code = groupcode.code
		local data = groupcode.data
		if code==0 then
			entry = {type=data}
			tinsert(table, entry)
		else
			tinsert(entry, groupcode)
		end
	end
	table.header = load_table_header(table.header)
	for i=1,#table do
		table[i] = load_table_entry(table[i].type, table[i])
	end
	return table
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
		local table = load_table(groupcodes)
		table.type = name
		tinsert(tables, table)
	end
	
	return tables
end

function load_section.BLOCKS(groupcodes)
	local section = {}
	return section
end

local function load_entity(type, groupcodes)
	return load_object(type, groupcodes)
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
	local type = table.remove(groupcodes, 1)
	assert(type.code==0)
	assert(type.data=='DICTIONARY')
	root_dictionary = load_object(nil, root_dictionary)
	
	local objects = {root_dictionary=root_dictionary}
	for _,groupcodes in ipairs(chunks) do
		local type = table.remove(groupcodes, 1)
		assert(type.code==0)
		local object = load_object(type.data, groupcodes)
		table.insert(objects, object)
	end
	
	return objects
end

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
			assert(entity.AcDbPolyline)
			local path = {aperture=aperture}
			for i,point in ipairs(entity.AcDbPolyline.vertices) do
				assert(point.z == 0, "3D entities are not yet supported")
				table.insert(path, {x=point.x*scale, y=point.y*scale, interpolation=i>1 and 'linear' or nil})
			end
			table.insert(layer, path)
		else
			error("unsupported entity type "..tostring(entity.type))
		end
	end
	
	local image = {
		file_path = file_path,
		name = nil,
		format = {},
		unit = 'MM',
		layers = layers,
	}
	
	return image
end


function _M.save(image, filepath)
	error("saving DXF is not yet implemented")
end

return _M
