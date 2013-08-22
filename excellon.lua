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

local function load_tool(data, unit)
	local tool = data
	tool.tcode = nil
	tool.unit = unit
	return tool
end

function _M.load(filename)
	local data = _M.blocks.load(filename)
	
	-- parse the data blocks
	local tools = {}
	local layer = {}
	local image = {layer}
	local unit,tool
	local x,y = 0,0
	for _,header in ipairs(data.headers) do
		local th = header.type or type(header)
		if th=='tool' then
			local name = header.tcode
			local tool = load_tool(header, unit)
			tools[name] = tool
		elseif th=='string' then
			if header=='M72' then
				unit = 'IN'
			elseif header:match('^;') then
				-- ignore
			elseif header=='INCH,LZ' then
				unit = 'IN'
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
				unit = 'IN'
			elseif block.M==71 then
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
				table.insert(layer, {
					aperture = tool,
					{ x = x, y = y },
				})
			else
				error("unsupported directive ("..tostring(block)..")")
			end
		else
			error("unsupported block type "..tostring(block.type))
		end
	end
	
	return image
end

function _M.save(image, filename)
	assert(#image == 1)
	local data = {headers={}}
--	data.headers
	return _M.blocks.save(data, filename)
end

------------------------------------------------------------------------------

return _M
