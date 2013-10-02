local _M = {}

--[[

Part
Value
Attributes
Package
Part Num
X
Y
Angle
Side
Mfg Name
VID
Mouser Part Num
DigiKey Part Num
Description
Package
Value
Tolerance
Rating
Min Qty

]]

local mm = 1e9

function _M.load(file_path)
	local name = file_path.file
	local unit = nil
	local top = { polarity = 'top' }
	local bottom = { polarity = 'bottom' }
	local layers = { top, bottom }
	
	local file = assert(io.open(file_path, 'rb'))
	local data = {}
	for line in file:lines() do
		local fields = {}
		for field in (line..'\t'):gmatch('([^\t]*)\t') do
			table.insert(fields, field)
		end
		table.insert(data, fields)
	end
	assert(file:close())
	
	local field_names = data[1]
	for i=2,#data do
		local fields = data[i]
		local part,pos,device = {},{},{}
		local section = part
		for i,field_name in ipairs(field_names) do
			section[field_name] = fields[i]
			if field_name=='Part Num' then
				section = pos
			elseif field_name=='Side' then
				section = device
			end
		end
		part.x = pos.X * mm
		part.y = pos.Y * mm
		part.angle = pos.Angle -- in degrees
		local layer
		if pos.Side=='top' then
			layer = top
		elseif pos.Side=='bottom' then
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

function _M.save(image, file_path)
	local file = assert(io.open(file_path, 'wb'))
	local field_names = image.format
	assert(#image.layers==2)
	
	assert(file:write(table.concat(field_names, '\t')..'\n'))
	for _,layer in ipairs(image.layers) do
		for _,path in ipairs(layer) do
			assert(path.aperture and path.aperture.device)
			local device = path.aperture.parameters
			local part = path[1]
			local pos = { Side = layer.polarity }
			for k,v in pairs(part) do
				if k=='x' then
					pos.X = v / mm
					part[k] = nil
				elseif k=='y' then
					pos.Y = v / mm
					part[k] = nil
				elseif k=='angle' then
					pos.Angle = v
					part[k] = nil
				end
			end
			local section = part
			local fields = {}
			for i,field_name in ipairs(field_names) do
				fields[i] = section[field_name]
				if field_name=='Part Num' then
					section = pos
				elseif field_name=='Side' then
					section = device
				end
			end
			assert(file:write(table.concat(fields, '\t')..'\n'))
		end
	end
	assert(file:close())
	return true
end

return _M
