local _M = {}

function _M.load(file_path, template)
	local name = file_path.file
	local unit = nil
	local top = { polarity = 'top' }
	local bottom = { polarity = 'bottom' }
	local layers = { top, bottom }
	
	local file = assert(io.open(file_path, 'rb'))
	local data = {}
	for line in file:lines() do
		line = line:gsub('\r', '')
		local fields = {}
		for field in (line..'\t'):gmatch('([^\t]*)\t') do
			table.insert(fields, field)
		end
		table.insert(data, fields)
	end
	assert(file:close())
	
	local field_names = data[1]
	for i=2,#data do
		local array = data[i]
		local set = {}
		for i,field_name in ipairs(field_names) do
			if array[i] ~= "" and array[i] ~= "*" then
				set[field_name] = array[i]
			end
		end
		local package = set[template.fields.package]
		local part = {}
		part.name = set[template.fields.name]
		part.x = (set[template.fields.x] + (set[template.fields.x_offset] or 0)) * template.scale.dimension
		part.y = (set[template.fields.y] + (set[template.fields.y_offset] or 0)) * template.scale.dimension
		part.angle = (set[template.fields.angle] + (set[template.fields.angle_offset] or 0)) * template.scale.angle
		local side = set[template.fields.side]
		for _,field in pairs(template.fields) do
			set[field] = nil
		end
		local device = set
		device.package = package
		local layer
		if side=='top' then
			layer = top
		elseif side=='bottom' then
			layer = bottom
		else
			error("unexpected Side in BOM: "..tostring(pos.Side))
		end
		table.insert(layer, {
			aperture = {
				device = true,
				parameters = device,
			},
			part,
		})
	end
	
	local image = {
		file_path = file_path,
		name = image_name,
		format = field_names,
		unit = unit,
		layers = layers,
	}
	
	return image
end

function _M.save(image, file_path, template)
	local file = assert(io.open(file_path, 'wb'))
	local field_names = image.format
	assert(#image.layers==2)
	
	assert(file:write(table.concat(field_names, '\t')..'\n'))
	for _,layer in ipairs(image.layers) do
		for _,path in ipairs(layer) do
			assert(path.aperture and path.aperture.device)
			local device = path.aperture.parameters
			local part = path[1]
			local set = {}
			for k,v in pairs(device) do
				set[k] = v
			end
			set[template.fields.package] = device.package
			set[template.fields.name] = part.name
			set[template.fields.x] = part.x / template.scale.dimension
			set[template.fields.y] = part.y / template.scale.dimension
			set[template.fields.angle] = part.angle / template.scale.angle
			set[template.fields.side] = layer.polarity
			local array = {}
			for i,field_name in ipairs(field_names) do
				array[i] = set[field_name]
			end
			assert(file:write(table.concat(array, '\t')..'\n'))
		end
	end
	assert(file:close())
	return true
end

return _M
