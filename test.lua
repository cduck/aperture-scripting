local gerber = require 'gerber'

local data = assert(gerber.parse('example2.ger'))

local file = io.open("tmp.ger", "wb")
for _,block in ipairs(data) do
	if block.type=='directive' then
		file:write(tostring(block)..'*\r\n')
	else
		file:write('%'..tostring(block):gsub('\n', '\r\n')..'*%\r\n')
	end
end
file:close()
--assert(#data == 1)
--assert(#data[1].layers == 3)

print("all tests passed successfully")
