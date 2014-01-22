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

local function unparse(value, code)
	local data
	if false then
	elseif 0 <= code and code <= 9 then
		-- String (with the introduction of extended symbol names in AutoCAD 2000, the 255-character limit has been increased to 2049 single-byte characters not including the newline at the end of the line)
		assert(#value <= 2049)
		data = value
	elseif 10 <= code and code <= 39 then
		-- Double precision 3D point value
		data = tostring(value)
		assert(tonumber(data) == value and data:match('^[%d.]+$'))
	elseif 40 <= code and code <= 59 then
		-- Double-precision floating-point value
		data = tostring(value)
		assert(tonumber(data) == value and data:match('^[%d.]+$'))
	elseif 60 <= code and code <= 79 then
		-- 16-bit integer value
		data = string.format('%6d', value)
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
		assert(tonumber(data) == value and data:match('^[%d.]+$'))
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

------------------------------------------------------------------------------

local load_subclass = {}
local save_subclass = {}

function load_subclass_generic(groupcodes)
	local subclass = {}
	for _,group in ipairs(groupcodes) do
		local code = group.code
		local value = parse(group)
		assert(type(value)~='table')
		local t = type(subclass[code])
		if t=='nil' then
			subclass[code] = value
		elseif t=='table' then
			table.insert(subclass[code], value)
		else
			subclass[code] = {subclass[code], value}
		end
	end
	return subclass
end

function save_subclass_generic(subclass)
	local codes = {}
	for code in pairs(subclass) do
		if code~='type' then
			table.insert(codes, code)
		end
	end
	table.sort(codes)
	local groupcodes = {}
	for _,code in ipairs(codes) do
		local value = subclass[code]
		local t = type(value)
		if t=='table' then
			for _,value in ipairs(value) do
				table.insert(groupcodes, unparse(value, code))
			end
		else
			table.insert(groupcodes, unparse(value, code))
		end
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
	table.insert(groupcodes, {code=90, data=#subclass.vertices})
	table.insert(groupcodes, {code=70, data=subclass.flags})
	for _,vertex in ipairs(subclass.vertices) do
		table.insert(groupcodes, {code=10, data=vertex.x})
		table.insert(groupcodes, {code=20, data=vertex.y})
		if vertex.z then
			table.insert(groupcodes, {code=30, data=vertex.z})
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
		table.insert(groupcodes, {code=3, data=pair.key})
		table.insert(groupcodes, {code=350, data=pair.value})
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
			object.attributes[code] = parse(group)
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
		for code,value in pairs(object.attributes) do
			table.insert(groupcodes, unparse(value, code))
		end
	end
	for _,subclass in ipairs(object) do
		local classname = subclass.type
		table.insert(groupcodes, {code=100, data=classname})
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

local header_order = {'ACADVER', 'HANDSEED', 'MEASUREMENT'}
local header_codes = {
	ACADVER = 1,
	HANDSEED = 5,
	MEASUREMENT = 70,
}

function save_section.HEADER(header)
	for name in pairs(header) do
		local found = false
		for _,name2 in ipairs(header_order) do if k2 == k then found = true; break end end
		assert(found, "unsupported header field "..tostring(name))
	end
	local groupcodes = {}
	for _,name in ipairs(header_order) do
		local value = header[name]
		if value ~= nil then
			table.insert(groupcodes, {code=9, data='$'..name})
			table.insert(groupcodes, unparse(value, header_codes[name]))
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

local function load_table_entry(type, groupcodes)
	return load_object(type, groupcodes)
end

local function save_table_entry(type, entry)
	return save_object(type, entry)
end

local function load_table(type, groupcodes)
	local table = {type=type, header={}}
	local entry = table.header
	for _,group in ipairs(groupcodes) do
		local code = group.code
		local data = group.data
		if code==0 then
			entry = {type=data}
			tinsert(table, entry)
		else
			tinsert(entry, group)
		end
	end
	table.header = load_table_header(table.header)
	for i,entry in ipairs(table) do
		assert(entry.type == type, "record type "..tostring(entry.type).." differ from table type "..tostring(type))
		entry = load_table_entry(entry.type, entry)
		assert(entry.type == type)
		entry.type = nil
		table[i] = entry
	end
	return table
end

local function save_table(table)
	local groupcodes = {}
	for _,group in ipairs(save_table_header(table.header)) do
		tinsert(groupcodes, group)
	end
	for _,entry in ipairs(table) do
		tinsert(groupcodes, {code=0, data=table.type})
		for _,group in ipairs(save_table_entry(table.type, entry)) do
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
		tinsert(chunk, 1, {code=2, data=table.type})
		tinsert(chunks, chunk)
	end
	
	local groupcodes = {}
	for _,chunk in ipairs(chunks) do
		table.insert(groupcodes, {code=0, data='TABLE'})
		for _,group in ipairs(chunk) do
			table.insert(groupcodes, group)
		end
		table.insert(groupcodes, {code=0, data='ENDTAB'})
	end
	
	return groupcodes
end

--............................................................................

function load_section.BLOCKS(groupcodes)
	local section = {}
	return section
end

function save_section.BLOCKS(section)
	local groupcodes = {}
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
		table.insert(chunk, 1, {code=0, data=entity.type})
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
	table.insert(chunk, 1, {code=0, data='DICTIONARY'})
	table.insert(chunks, chunk)
	
	for _,object in ipairs(objects) do
		local chunk = save_object(object.type, object)
		table.insert(chunk, 1, {code=0, data=object.type})
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
			table.insert(groupcodes, 1, {code=2, data=name})
			table.insert(chunks, groupcodes)
		end
	end
	
	-- unparse top level
	local groupcodes = {}
	for _,chunk in ipairs(chunks) do
		table.insert(groupcodes, {code=0, data='SECTION'})
		for _,group in ipairs(chunk) do
			table.insert(groupcodes, group)
		end
		table.insert(groupcodes, {code=0, data='ENDSEC'})
	end
	table.insert(groupcodes, {code=0, data='EOF'})
	
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

function _M.save(image, file_path)
	assert(#image.layers == 1)
	assert(image.layers[1].polarity == 'dark')
	
	-- assemble DXF sections
	local sections = {}
	
	sections.HEADER = {
		ACADVER = "AC1014",
		HANDSEED = "FFFF",
		MEASUREMENT = 1,
	}
	
	sections.TABLES = {}
	
	sections.BLOCKS = {}
	
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
				[5] = string.format("%x", 0x100 - 1 + ipath),
			},
			{
				type = 'AcDbEntity',
				[8] = "0", -- layer name
				[62] = 7, -- color number
			},
			{
				type = 'AcDbPolyline',
				flags = 0,
				vertices = vertices,
			},
		}
		table.insert(sections.ENTITIES, entity)
	end
	
	sections.OBJECTS = {
		root_dictionary = {
		--	type = 'DICTIONARY',
			attributes = {},
		},
	}
	
	-- generate group codes
	local groupcodes = save_DXF(sections)
	
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
