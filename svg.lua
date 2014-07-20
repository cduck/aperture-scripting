local _M = {}

local xml = require 'xml'

local function load_style(str)
	local style = {}
	for pair in str:gmatch('[^;]+') do
		local name,value = pair:match('^([^:]*):(.*)$')
		assert(name and value, "malformed style '"..str.."'")
		style[name] = value
	end
	return style
end

local function style_polarity(style)
	if style.fill and style.fill ~= 'none' then
		if style.fill == '#000000' then
			return 'dark'
		elseif style.fill == '#ffffff' then
			return 'clear'
		else
			error("unsupported style fill color "..tostring(style.fill))
		end
	elseif style.stroke and style.stroke ~= 'none' then
		if style.stroke == '#000000' then
			return 'dark'
		elseif style.stroke == '#ffffff' then
			return 'clear'
		else
			error("unsupported style stroke color "..tostring(style.fill))
		end
	else
		error("cannot determine style polarity")
	end
end

local function load_path(str)
	local scale = 25.4e9 / 90 -- picometers per pixel
	local xscale = scale
	local yscale = -scale
	local path = {}
	for letter,params in str:gmatch('(%a)(%A*)') do
		if letter=='M' then
			assert(#path==0)
			local x,y = params:match('^([-0-9.]+)[^-0-9.]([-0-9.]+)$')
			assert(x and y)
			x,y = tonumber(x),tonumber(y)
			assert(x and y)
			x = x * xscale
			y = y * yscale
			table.insert(path, {x=x, y=y})
		elseif letter=='L' then
			local x,y = params:match('^([-0-9.]+)[^-0-9.]([-0-9.]+)$')
			assert(x and y)
			x,y = tonumber(x),tonumber(y)
			assert(x and y)
			x = x * xscale
			y = y * yscale
			table.insert(path, {x=x, y=y, interpolation='linear'})
		elseif letter=='A' then
			local rx,ry,angle,large,sweep,x,y = params:match('^([-0-9.]+)[^-0-9.]([-0-9.]+)[^-0-9.]([-0-9.]+)[^-0-9.]([-0-9.]+)[^-0-9.]([-0-9.]+)[^-0-9.]([-0-9.]+)[^-0-9.]([-0-9.]+)$')
			assert(rx and ry and angle and large and sweep and x and y)
			rx,ry,angle,large,sweep,x,y = tonumber(rx),tonumber(ry),tonumber(angle),tonumber(large),tonumber(sweep),tonumber(x),tonumber(y)
			rx = rx * scale
			ry = ry * scale
			x = x * xscale
			y = y * yscale
			assert(rx and ry and angle and large and sweep and x and y)
			large = large~=0
			sweep = sweep~=0
			-- :TODO: accept more cases
			assert(rx==ry and angle==0 and not sweep and not large)
			local x0,y0 = path[#path].x,path[#path].y
			local r = rx
			local dx = x - x0
			local dy = y - y0
			local dist = math.sqrt(dx*dx + dy*dy)
			dx = dx / dist
			dy = dy / dist
			local sin = dist / r / 2
			assert(sin <= 1)
			local angle = math.asin(sin)
			assert(angle <= math.pi / 2)
			local cos = math.cos(angle)
			local cx = (x0+x)/2 - dy * r * cos
			local cy = (y0+y)/2 + dx * r * cos
			local i = math.abs(cx-x0)
			local j = math.abs(cy-y0)
			table.insert(path, {x=x, y=y, i=i, j=j, interpolation='counterclockwise', quadrant='single'})
		elseif letter=='Z' then
			local x0,y0 = path[1].x,path[1].y
			local x1,y1 = path[#path].x,path[#path].y
			if x1 ~= x0 or y1 ~= y0 then
				table.insert(path, {x=x0, y=y0, interpolation='linear'})
			end
		else
			error("unsupported path element "..letter)
		end
	end
	return path
end

local function style_aperture(style)
	if style.stroke == 'none' and style.fill and style.fill ~= 'none' then
		return nil -- no stroke, fill, is a region
	elseif style.fill == 'none' and style.stroke and style.stroke ~= 'none' then
		assert(style['stroke-linecap'] == 'round')
		assert(style['stroke-linejoin'] == 'round')
		assert(style['stroke-opacity'] == '1')
		local name
		if style['marker'] then
			name = style['marker']:match('^url%((.*)%)$')
			if name and name:match('^%d+$') then
				name = tonumber(name)
			end
		end
		local width = style['stroke-width']
		local d,unit
		if width=='0' then
			d = 0
			unit = 'mm'
		else
			d,unit = width:match('^([-0-9.e]+)(%a%a)$')
			assert(d and unit, tostring(width).." doesn't not contain a valid line width")
			d = assert(tonumber(d), d.." is not a number") * 1e9
			unit = unit:lower()
			assert(unit=='mm' or unit=='in')
		end
		return {name=name, shape='circle', parameters={d}, unit=unit}
	else
		error("unsupported style")
	end
end

function _M.load(file_path)
	local file = assert(io.open(file_path, 'rb'))
	local content = assert(file:read('*all'))
	assert(file:close())
	local layers = {}
	local data = assert(xml.collect(content))
	assert(data[1]=='<?xml version="1.0" encoding="UTF-8" standalone="no"?>\n')
	local svg = data[2]
	assert(xml.label(svg)=='svg')
	for _,g in ipairs(svg) do
		assert(xml.label(g)=='g')
		local layer = {}
		if g.name then
			layer.name = g.name
		end
		for _,path in ipairs(g) do
			assert(xml.label(path)=='path')
			local style = load_style(path.style)
			if layer.polarity then
				assert(style_polarity(style)==layer.polarity)
			else
				layer.polarity = style_polarity(style)
			end
			local path2 = load_path(path.d)
			path2.aperture = style_aperture(style)
			table.insert(layer, path2)
		end
		table.insert(layers, layer)
	end
	return {
		file_path = file_path,
		name = svg.id,
		format = {},
		unit = 'PX',
		layers = layers,
	}
end

function _M.save(image, filepath)
	local file = assert(io.open(filepath, 'wb'))
	assert(file:write([[
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<svg
	xmlns="http://www.w3.org/2000/svg"
	version="1.1"
	height="100%"
	width="100%"
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
		local scale = 25.4e9 / 90 -- picometers per pixel
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
				local width
				if d == 0 then
					width = '0'
				else
				--	width = d..'mm'
					width = d..path.aperture.unit:lower()
				end
				assert(file:write('\t\t\tstyle="'))
				if path.aperture.name then
					assert(file:write('marker:url('..tostring(path.aperture.name)..');'))
				end
				assert(file:write('fill:none;stroke:'..color..';stroke-width:'..width..';stroke-linecap:round;stroke-linejoin:round;stroke-opacity:1"\n'))
			else
				-- fill
				assert(file:write('\t\t\tstyle="fill:'..color..';stroke:none"\n'))
			end
			assert(file:write('\t\t\td="'))
			for i,point in ipairs(path) do
				if i==1 then
					assert(file:write('M'..(point.x / xscale)..','..(point.y / yscale)..''))
				elseif point.interpolated then
					-- skip
				elseif point.interpolation=='linear' then
					if i==#path and point.x==path[1].x and point.y==path[1].y then
						assert(file:write('Z'))
					else
						assert(file:write('L'..(point.x / xscale)..','..(point.y / yscale)..''))
					end
				elseif (point.interpolation=='clockwise' or point.interpolation=='counterclockwise') and point.quadrant=='single' then
					local r = math.sqrt(point.i * point.i + point.j * point.j)
					local large = false
					local sweep = point.interpolation=='clockwise'
					assert(file:write('A'..(r / scale)..','..(r / scale)..' 0 '..(large and '1' or '0')..','..(sweep and '1' or '0')..' '..(point.x / xscale)..','..(point.y / yscale)..''))
					if i==#path and point.x==path[1].x and point.y==path[1].y then
						assert(file:write('Z'))
					end
				elseif (point.interpolation=='clockwise' or point.interpolation=='counterclockwise') and point.quadrant=='multi' then
					local r = math.sqrt(point.i * point.i + point.j * point.j)
					local x0,y0 = path[i-1].x,path[i-1].y
					local x1,y1 = point.x,point.y
					local dx0,dy0 = -point.i,-point.j
					local dx1 = dx0 + x1 - x0
					local dy1 = dy0 + y1 - y0
					local a0 = math.atan2(dy0, dx0)
					local a1 = math.atan2(dy1, dx1)
					local da = a1 - a0
					if point.interpolation=='clockwise' then da = -da end
					if da <= 0 then da = da + 2 * math.pi end
					local large = da >= math.pi
					local sweep = point.interpolation=='clockwise'
					assert(file:write('A'..(r / scale)..','..(r / scale)..' 0 '..(large and '1' or '0')..','..(sweep and '1' or '0')..' '..(x1 / xscale)..','..(y1 / yscale)..''))
					if i==#path and x1==path[1].x and y1==path[1].y then
						assert(file:write('Z'))
					end
				else
					error("unsupported point interpolation "..tostring(point.interpolation)..(point.quadrant and " "..point.quadrant.." quadrant" or ""))
				end
			end
			assert(file:write('"\n'))
			assert(file:write('\t\t/>\n'))
		end
		assert(file:write('\t</g>\n'))
	end
	assert(file:write([[
</svg>
]]))
	assert(file:close())
	return true
end

return _M

