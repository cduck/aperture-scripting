local gerber = require 'gerber'

local data = assert(gerber.parse('example2.ger'))

local file = io.open("tmp.ger", "wb")
for _,group in ipairs(data) do
	if group.type=='parameters' then
		file:write('%')
		for i,block in ipairs(group) do
			file:write(block..'*')
			if i==#group then
				file:write('%')
			end
			file:write('\r\n')
		end
	elseif group.type=='directive' then
		file:write(tostring(group)..'*\r\n')
	else
		error("unexpected group of type "..tostring(group.type))
	end
end
file:close()
--assert(#data == 1)
--assert(#data[1].layers == 3)

print("all tests passed successfully")
