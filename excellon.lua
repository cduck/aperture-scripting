local _M = {}

local math = require 'math'
local table = require 'table'
local dump = require 'dump'
_M.blocks = require 'excellon.blocks'

------------------------------------------------------------------------------

-- all positions in picometers (1e-12 meters)
local scales = {
	['in'] = 25400000000 / 10 ^ _M.blocks.decimal_shift,
	mm     =  1000000000 / 10 ^ _M.blocks.decimal_shift,
}
for unit,scale in pairs(scales) do
	assert(math.floor(scale)==scale)
end

------------------------------------------------------------------------------

local function load_tool(data, unit)
	local tcode = data.tcode
	local scale = scales[unit]
	
	local d = data.parameters.C
	assert(d, "tool "..tostring(tcode).." require at least a diameter (C parameter)")
	return {
		name = tcode,
		unit = 'pm',
		shape = 'circle',
		diameter = d * scale,
	}
end

local function save_tool(aperture, unit)
	local name = assert(aperture.save_name)
	assert(aperture.unit=='pm', "basic apertures must be defined in picometers")
	assert(aperture.shape == 'circle', "only circle apertures are supported")
	local scale = scales[unit]
	local parameters = { 'C', C = aperture.diameter / scale }
	return _M.blocks.tool(name, parameters)
end

------------------------------------------------------------------------------

local ignored_headers = {
	-- from http://www.excellon.com/manuals/program.htm
--	AFS = true, -- Automatic Feeds and Speeds
--	ATC = true, -- Automatic Tool Change
--	BLKD = true, -- Delete all Blocks starting with a slash (/)
--	CCW = true, -- Clockwise or Counterclockwise Routing
--	CP = true, -- Cutter Compensation
	DETECT = true, -- Broken Tool Detection
--	DN = true, -- Down Limit Set
--	DTMDIST = true, -- Maximum Rout Distance Before Toolchange
--	EXDA = true, -- Extended Drill Area
	FMAT = true, -- Format 1 or 2
--	FSB = true, -- Turns the Feed/Speed Buttons off
--	HPCK = true, -- Home Pulse Check
--	ICI = true, -- Incremental Input of Part Program Coordinates
--	INCH = true, -- Measure Everything in Inches
--	METRIC = true, -- Measure Everything in Metric
--	M48 = true, -- Beginning of Part Program Header
--	M95 = true, -- End of Header
--	NCSL = true, -- NC Slope Enable/Disable
--	OM48 = true, -- Override Part Program Header
--	OSTOP = true, -- Optional Stop Switch
--	OTCLMP = true, -- Override Table Clamp
--	PCKPARAM = true, -- Set up pecking tool,depth,infeed and retract parameters
--	PF = true, -- Floating Pressure Foot Switch
--	PPR = true, -- Programmable Plunge Rate Enable
--	PVS = true, -- Pre-vacuum Shut-off Switch
--	['R,C'] = true, -- Reset Clocks
--	['R,CP'] = true, -- Reset Program Clocks
--	['R,CR'] = true, -- Reset Run Clocks
--	['R,D'] = true, -- Reset All Cutter Distances
--	['R,H'] = true, -- Reset All Hit Counters
--	['R,T'] = true, -- Reset Tool Data
--	SBK = true, -- Single Block Mode Switch
--	SG = true, -- Spindle Group Mode
--	SIXM = true, -- Input From External Source
--	T = true, -- Tool Information
--	TCST = true, -- Tool Change Stop
--	UP = true, -- Upper Limit Set
--	VER = true, -- Selection of X and Y Axis Version
--	Z = true, -- Zero Set
--	ZA = true, -- Auxiliary Zero
--	ZC = true, -- Zero Correction
--	ZS = true, -- Zero Preset
--	['Z+#'] = true, ['Z-#'] = true, -- Set Depth Offset
--	['%'] = true, -- Rewind Stop
--	['#/#/#'] = true, -- Link Tool for Automatic Tool Change
--	['/'] = true, -- Clear Tool Linking
}

function _M.load(file_path)
	local data = _M.blocks.load(file_path)
	
	-- parse the data blocks
	local tools = {}
	local layer = {polarity='dark'}
	local layers = {layer}
	local unit = 'in'
	local default_unit = true
	local tool
	local x,y = 0,0
	local format = data.format
	for _,header in ipairs(data.headers) do
		local th = header.type or type(header)
		if th=='tool' then
			local name = header.tcode
			local tool = load_tool(header, unit)
			tools[name] = tool
		elseif th=='comment' then
			-- ignore
		elseif th=='header' then
			if header.name=='M72' then
				assert(default_unit or unit=='in', "excellon files with mixtures of units not supported")
				unit = 'in'
				default_unit = false
			elseif header.name=='M71' then
				assert(default_unit or unit=='mm', "excellon files with mixtures of units not supported")
				unit = 'mm'
				default_unit = false
			elseif header.name=='INCH' then
				assert(default_unit or unit=='in', "excellon files with mixtures of units not supported")
				unit = 'in'
				default_unit = false
			elseif header.name=='METRIC' then
				assert(default_unit or unit=='mm', "excellon files with mixtures of units not supported")
				unit = 'mm'
				default_unit = false
			elseif ignored_headers[header.name] then
				print("ignored Excellon header "..header.name..(#header.parameters==0 and "" or (" with value "..table.concat(header.parameters, ","))))
			else
				error("unsupported header "..header.name..(#header.parameters==0 and "" or (" with value "..table.concat(header.parameters, ","))))
			end
		else
			error("unsupported header type "..th)
		end
	end
	for _,block in ipairs(data) do
		local tb = block.type
		if tb=='tool' then
			local name = assert(block.tcode)
			assert(not block.X and not block.Y and not block.M)
			tool = tools[name]
			if not tool then
				if name==0 then
					-- T0 seem to reset the tool
					tool = nil
				else
					-- assume it's an inline tool definition
					tool = load_tool(block, unit)
					tools[name] = tool
				end
			end
		elseif tb=='directive' then
			if block.M==72 then
				assert(default_unit or unit=='in', "excellon files with mixtures of units not supported")
				unit = 'in'
				default_unit = false
			elseif block.M==71 then
				assert(default_unit or unit=='mm', "excellon files with mixtures of units not supported")
				unit = 'mm'
				default_unit = false
			elseif block.G==5 then
				-- drill mode, ignore
			elseif block.G==90 then
				-- absolute mode, ignore
			elseif block.M==30 then
				-- end of program, ignore
			elseif block.X or block.Y then
				-- drill
				assert(not block.T and not block.M)
				assert(tool, "no tool selected while drilling")
				local scale = scales[unit]
				if block.X then
					x = block.X * scale
				end
				if block.Y then
					y = block.Y * scale
				end
				table.insert(layer, {aperture=tool, {x=x, y=y}})
			else
				error("unsupported directive ("..tostring(block)..")")
			end
		elseif type(block)=='string' then
			error("unsupported block '"..block.."'")
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
	assert(#image.layers == 1, "excellon image has more than 1 layer")
	
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
		if not name or aperture_names[name] then
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
	
	if unit == 'in' then
		table.insert(data.headers, 'M72')
	elseif unit == 'mm' then
		table.insert(data.headers, 'M71')
	else
		error("unsupported unit")
	end
	
	for _,aperture in ipairs(aperture_order) do
		table.insert(data.headers, save_tool(aperture, unit))
	end
	
	for _,layer in ipairs(image.layers) do
		for _,path in ipairs(layer) do
			if path.aperture ~= tool then
				tool = path.aperture
				table.insert(data, _M.blocks.directive{T=tool.save_name})
			end
			local scale = 1 / scales[unit]
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
