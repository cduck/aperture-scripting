local _M = {}

local table = require 'table'

------------------------------------------------------------------------------

function _M.draw_path(image, aperture, ...)
	local path = {
		aperture = aperture,
		unit = image.unit,
	}
	for i=1,select('#', ...),2 do
		local x,y = select(i, ...)
		table.insert(path, { x = x, y = y, interpolation = i > 1 and 'linear' or nil })
	end
	table.insert(image.layers[#image.layers], path)
end

------------------------------------------------------------------------------

return _M
