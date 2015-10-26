local _M = {}

local math = require 'math'
local table = require 'table'
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
	local tcode = assert(aperture.tcode)
	assert(aperture.unit=='pm', "basic apertures must be defined in picometers")
	assert(aperture.shape == 'circle', "only circle apertures are supported")
	local scale = scales[unit]
	local parameters = { 'C', C = aperture.diameter / scale }
	return _M.blocks.tool(tcode, parameters)
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
--	FMAT = true, -- Format 1 or 2
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

function _M.load(file_path, template)
	local data = _M.blocks.load(file_path, template)
	
	-- parse the data blocks
	local tools = {}
	local layer = {polarity='dark'}
	local layers = {layer}
	local unit = 'in'
	local default_unit = true
	local tool
	local x,y = 0,0
	local format = data.format
	local route_mode = 'drill'
	local fmat = 1
	local direction
	local path
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
			elseif header.name=='FMAT' then
				fmat = assert(tonumber(header.parameters[1]), "FMAT parameter is not a number")
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
			-- process mode changes
			if block.M==72 then
				assert(default_unit or unit=='in', "excellon files with mixtures of units not supported")
				unit = 'in'
				default_unit = false
			elseif block.M==71 then
				assert(default_unit or unit=='mm', "excellon files with mixtures of units not supported")
				unit = 'mm'
				default_unit = false
			elseif block.G==5 or block.G==81 and fmat==1 then
				assert(not path, "G"..block.G.." command while tool is down")
				route_mode = 'drill'
			elseif block.G==0 then
				route_mode = 'move'
			elseif block.G==1 then
				route_mode = 'linear'
		--	elseif block.G==2 then
		--		route_mode = 'circular'
		--		direction = 'clockwise'
		--	elseif block.G==3 then
		--		route_mode = 'circular'
		--		direction = 'counterclockwise'
			elseif block.G==85 then
				-- ignore (process below)
			elseif block.G==90 then
				-- absolute mode, ignore
			elseif block.M==15 then
				path = {aperture=tool, {x=x, y=y}}
				table.insert(layer, path)
			elseif block.M==16 or block.M==17 then
				path = nil
			elseif block.M==30 or block.M==2 and fmat==1 or block.M==0 and fmat==2 then
				-- end of program, ignore
			elseif (block.X or block.Y) and block.G==nil and block.M==nil then
				-- ignore (process below)
			else
				error("unsupported directive ("..tostring(block)..")")
			end
			-- process data
			if block.G==85 then
				assert(block.X and block.Y and block.X2 and block.Y2, "incomplete G85 command")
				local scale = scales[unit]
				local x0,y0
				x0 = block.X * scale
				y0 = block.Y * scale
				x = block.X2 * scale
				y = block.Y2 * scale
				table.insert(layer, {aperture=tool,
					{x=x0, y=y0},
					{x=x, y=y, interpolation='linear'},
				})
			elseif block.X or block.Y then
				assert(not block.T and not block.M)
				assert(tool, "no tool selected while drilling")
				local scale = scales[unit]
				if block.X then
					x = block.X * scale
				end
				if block.Y then
					y = block.Y * scale
				end
				if route_mode=='drill' then
					table.insert(layer, {aperture=tool, {x=x, y=y}})
				elseif route_mode=='move' then
					assert(not path, "G0 command while tool is down")
				elseif route_mode=='linear' then
					assert(path, "G1 command while tool is up")
					table.insert(path, {x=x, y=y, interpolation='linear'})
				else
					error("unsupported route mode "..route_mode)
				end
			end
		elseif tb=='comment' then
			-- ignore
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
		assert(layer.polarity=='dark', "layer has "..tostring(layer.polarity).." polarity")
		for _,path in ipairs(layer) do
			local aperture = path.aperture
			assert(aperture, "path has no aperture")
			if aperture and not apertures[aperture] then
				assert(aperture.shape == 'circle', "aperture is not a circle")
				apertures[aperture] = true
				table.insert(aperture_order, aperture)
			end
			for i=2,#path do
				local interpolation = path[i].interpolation
				assert(interpolation=='linear', "unsupported interpolation "..tostring(interpolation))
			end
		end
	end
	
	-- generate unique aperture names
	local aperture_names = {}
	local aperture_conflicts = {}
	for i,aperture in ipairs(aperture_order) do
		local tcode = tonumber(aperture.name)
		if not tcode or aperture_names[tcode] then
			table.insert(aperture_conflicts, aperture)
		else
			aperture_names[tcode] = aperture
			aperture.tcode = tcode
		end
	end
	for _,aperture in ipairs(aperture_conflicts) do
		for tcode=1,99 do -- be conservative here, for now
			if not aperture_names[tcode] then
				aperture_names[tcode] = aperture
				aperture.tcode = tcode
				break
			end
		end
		assert(aperture.tcode, "could not assign a unique tool number to aperture")
	end
	
	-- assemble a block array
	local data = {headers={}}
	
	local unit,tool
	local x,y = 0,0
	local unit = image.unit
	assert(scales[unit])
	
	local format = image.format
	if format and (
		format.zeroes~='T' or
		unit=='in' and (format.integer ~= 2 or format.decimal ~= 4) or
		unit=='mm' and (format.integer ~= 3 or format.decimal ~= 3)
		)
	then
		if unit=='in' and (format.integer ~= 2 or format.decimal ~= 4) or
			unit=='mm' and (format.integer ~= 3 or format.decimal ~= 3)
		then
			local i,d = format.integer,format.decimal
			table.insert(data.headers, string.format(';FILE_FORMAT=%d:%d', i, d))
		end
		local header = {}
		if unit == 'in' then
			table.insert(header, 'INCH')
		elseif unit == 'mm' then
			table.insert(header, 'METRIC')
		else
			error("unsupported unit")
		end
		if format.zeroes=='T' then
			table.insert(header, 'LZ')
		elseif format.zeroes=='L' then
			table.insert(header, 'TZ')
		else
			error("unsupported zero format "..tostring(format.zeroes).." for excellon file")
		end
		assert(#header >= 1)
		table.insert(data.headers, table.concat(header, ','))
	else
		if unit == 'in' then
			table.insert(data.headers, 'M72')
		elseif unit == 'mm' then
			table.insert(data.headers, 'M71')
		else
			error("unsupported unit")
		end
	end
	
	for _,aperture in ipairs(aperture_order) do
		table.insert(data.headers, save_tool(aperture, unit))
	end
	
	local route_mode = 'drill'
	for _,layer in ipairs(image.layers) do
		for _,path in ipairs(layer) do
			if path.aperture ~= tool then
				tool = path.aperture
				table.insert(data, _M.blocks.directive{T=tool.tcode})
			end
			local scale = 1 / scales[unit]
			if #path == 1 then
				if route_mode~='drill' then
					route_mode = 'drill'
					table.insert(data, _M.blocks.directive({ G = 0 }, image.format))
				end
				local flash = path[1]
				local px,py = flash.x * scale,flash.y * scale
				table.insert(data, _M.blocks.directive({
					-- :TODO: check if Excellon allow for modal coordinates
				--	X = (verbose or px ~= x) and px or nil,
				--	Y = (verbose or py ~= y) and py or nil,
					X = px,
					Y = py,
				}, image.format))
				x,y = px,py
			else
				local point = path[1]
				local px,py = point.x * scale,point.y * scale
				if x~=px or y~=py then
					if route_mode~='move' then
						route_mode = 'move'
						table.insert(data, _M.blocks.directive({ G = 0 }, image.format))
					end
				end
				table.insert(data, _M.blocks.directive({ X = px, Y = py }, image.format))
				x,y = px,py
				table.insert(data, _M.blocks.directive({ M = 15 }, image.format))
				for i=2,#path do
					local point = path[i]
					if point.interpolation=='linear' then
						if route_mode~='linear' then
							route_mode = 'linear'
							table.insert(data, _M.blocks.directive({ G = 1 }, image.format))
						end
						local point = path[i]
						local px,py = point.x * scale,point.y * scale
						table.insert(data, _M.blocks.directive({ X = px, Y = py }, image.format))
						x,y = px,py
					else
						error("unsupported interpolation "..tostring(point.interpolation))
					end
				end
				table.insert(data, _M.blocks.directive({ M = 16 }, image.format))
			end
		end
	end
	table.insert(data, _M.blocks.directive{M=30})
	
	local success,err = _M.blocks.save(data, file_path)
	
	-- clear aperture names
	for _,aperture in ipairs(aperture_order) do
		aperture.tcode = nil
	end
	
	return success,err
end

------------------------------------------------------------------------------

return _M
