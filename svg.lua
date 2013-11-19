local _M = {}

function _M.load(filepath)
	error("not implemented")
end

function _M.save(image, filepath)
	local file = assert(io.open(filepath, 'wb'))
	assert(file:write([[
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
	xmlns="http://www.w3.org/2000/svg"
	version="1.1"
]]))
	if image.name then
		assert(file:write('\tid="'..image.name..'"\n'))
	end
	assert(file:write([[
>
]]))
	for _,layer in ipairs(image.layers) do
		local color
		if layer.polarity=='clear' then
			color = '#ffffff'
		else
			color = '#000000'
		end
		assert(file:write('\t<g'))
		if layer.name then
			assert(file:write(' id="'..layer.name..'"'))
		end
		assert(file:write('>\n'))
		local scale = 90 / 25.4e9 -- pixels per picometer
		local xscale = scale
		local yscale = -scale
		for _,path in ipairs(layer) do
			assert(file:write('\t\t<path\n'))
			if path.aperture then
				-- stroke
				assert(path.aperture.shape=='circle', "only circle apertures are supported")
				local d,hx,hy = table.unpack(path.aperture.parameters)
				assert(d, "circle apertures require at least 1 parameter")
				assert(not hx and not hy, "circle apertures with holes are not yet supported")
			--	assert(file:write('\t\t\tstyle="fill:none;stroke:'..color..';stroke-width:'..d..';stroke-linecap:round;stroke-linejoin:round;stroke-opacity:1"\n'))
				assert(file:write('\t\t\tstyle="fill:none;stroke:'..color..';stroke-width:0.1mm;stroke-linecap:round;stroke-linejoin:round;stroke-opacity:1"\n'))
			else
				-- fill
				assert(file:write('\t\t\tstyle="fill:'..color..';stroke:none"\n'))
			end
			assert(file:write('\t\t\td="'))
			for i,point in ipairs(path) do
				if i==1 then
					assert(file:write('M'..(point.x * xscale)..','..(point.y * yscale)..''))
				elseif point.interpolation=='linear' then
					if i==#path and point.x==path[1].x and point.y==path[1].y then
						assert(file:write('Z'))
					else
						assert(file:write('L'..(point.x * xscale)..','..(point.y * yscale)..''))
					end
				elseif point.interpolation=='counterclockwise' then
					assert(point.quadrant=='single', "only single quadrant counterclockwise circular arcs are supported")
					local r = math.sqrt(point.i * point.i + point.j * point.j)
					assert(file:write('A'..(r * scale)..','..(r * scale)..' 0 0,0 '..(point.x * xscale)..','..(point.y * yscale)..''))
					if i==#path and point.x==path[1].x and point.y==path[1].y then
						assert(file:write('Z'))
					end
				else
					error("unsupported point interpolation "..tostring(point.interpolation))
				end
			end
			assert(file:write('"\n'))
			assert(file:write('\t\t/>\n'))
		end
		assert(file:write('</g>\n'))
	end
	assert(file:write([[
</svg>
]]))
	assert(file:close())
	return true
end

return _M

