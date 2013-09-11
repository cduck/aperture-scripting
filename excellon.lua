local _M = {}

local math = require 'math'
local table = require 'table'
local dump = require 'dump'
_M.blocks = require 'excellon.blocks'

------------------------------------------------------------------------------

local scales = {
	IN = 25.4,
	MM = 1,
}

------------------------------------------------------------------------------

local function load_tool(data, unit)
	local tcode = data.tcode
	local d = data.parameters.C
	assert(d, "tools require at least a diameter (C parameter)")
	return {
		name = tcode,
		unit = unit,
		shape = 'circle',
		parameters = { d },
	}
end

local function save_tool(aperture)
	local name = assert(aperture.save_name)
	assert(aperture.shape == 'circle', "only circle apertures are supported")
	local parameters = { 'C', C = aperture.parameters[1] }
	return _M.blocks.tool(name, parameters)
end

------------------------------------------------------------------------------

function _M.load(file_path)
	local data = _M.blocks.load(file_path)
	
	-- parse the data blocks
	local tools = {}
	local layer = {}
	local layers = {layer}
	local unit,tool
	local x,y = 0,0
	local format = data.format
	for _,header in ipairs(data.headers) do
		local th = header.type or type(header)
		if th=='tool' then
			local name = header.tcode
			local tool = load_tool(header, unit)
			tools[name] = tool
		elseif th=='string' then
			if header=='M72' then
				assert(not unit or unit=='IN', "excellon files with mixtures of units not supported")
				unit = 'IN'
			elseif header:match('^;') then
				-- ignore
			elseif header=='INCH,LZ' or header=='INCH,TZ' then
				assert(not unit or unit=='IN', "excellon files with mixtures of units not supported")
				unit = 'IN'
			elseif header=='METRIC,LZ' or header=='METRIC,TZ' then
				assert(not unit or unit=='MM', "excellon files with mixtures of units not supported")
				unit = 'MM'
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
				assert(not unit or unit=='IN', "excellon files with mixtures of units not supported")
				unit = 'IN'
			elseif block.M==71 then
				assert(not unit or unit=='MM', "excellon files with mixtures of units not supported")
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
				table.insert(layer, {aperture=tool, unit=unit, {x=x, y=y}})
			else
				error("unsupported directive ("..tostring(block)..")")
			end
		else
			error("unsupported block type "..tostring(block.type))
		end
	end
	
	local image = {
		file_path = file_path,
		format = format,
		unit = unit,
		layers = layers,
	}
	
	return image
end

function _M.save(image, file_path)
	assert(#image.layers == 1)
	
	-- list apertures
	local apertures = {}
	local aperture_order = {}
	for _,layer in ipairs(image.layers) do
		for _,path in ipairs(layer) do
			assert(#path == 1, "path has several points")
			local aperture = path.aperture
			assert(aperture, "path has no aperture")
			if aperture and not apertures[aperture] then
				assert(aperture.shape == 'circle', "aperture is not a circle")
				apertures[aperture] = true
				table.insert(aperture_order, aperture)
			end
		end
	end
	
	-- generate unique aperture names
	local aperture_names = {}
	local aperture_conflicts = {}
	for i,aperture in ipairs(aperture_order) do
		local name = aperture.name
		if aperture_names[name] then
			table.insert(aperture_conflicts, aperture)
		else
			aperture_names[name] = aperture
			aperture.save_name = name
		end
	end
	for _,aperture in ipairs(aperture_conflicts) do
		for name=1,99 do -- be conservative here, for now
			if not aperture_names[name] then
				aperture_names[name] = aperture
				aperture.save_name = name
				break
			end
		end
		assert(aperture.save_name, "could not assign a unique name to aperture")
	end
	
	-- assemble a block array
	local data = {headers={}}
	
	local unit,tool
	local x,y = 0,0
	local unit = image.unit
	assert(scales[unit])
	
	if unit == 'IN' then
		table.insert(data.headers, 'M72')
	else
		error("unsupported unit")
	end
	
	for _,aperture in ipairs(aperture_order) do
		table.insert(data.headers, save_tool(aperture))
	end
	
	for _,layer in ipairs(image.layers) do
		for _,path in ipairs(layer) do
			if path.aperture ~= tool then
				tool = path.aperture
				table.insert(data, _M.blocks.directive{T=tool.save_name})
			end
			local scale = 1 / scales[path.unit]
			local flash = path[1]
			local px,py = flash.x * scale,flash.y * scale
			table.insert(data, _M.blocks.directive({
				D = 3,
				-- :TODO: check if Excellon allow for modal coordinates
			--	X = (verbose or px ~= x) and px or nil,
			--	Y = (verbose or py ~= y) and py or nil,
				X = px,
				Y = py,
			}, image.format))
			x,y = px,py
		end
	end
	table.insert(data, _M.blocks.directive{M=30})
	
	local success,err = _M.blocks.save(data, file_path)
	
	-- clear aperture names
	for _,aperture in ipairs(aperture_order) do
		aperture.save_name = nil
	end
	
	return success,err
end

------------------------------------------------------------------------------

return _M
