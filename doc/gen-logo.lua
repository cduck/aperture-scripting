local file = assert(io.open("aperture.gto", 'wb'))

local spacing = 42
local dout = 948
local din = dout * 0.90
local angle = math.rad(35)

local x,y,s = -17,-28,1080
local hs = s / 2
local left = -hs + x
local bottom = -hs - y
local right = hs + x
local top = hs - y

assert(file:write([[
%MOMM*%
%FSTAX33Y33*%
%ADD10C,0*%
%ADD11C,]]..dout..[[*%
%ADD12C,]]..spacing..[[*%
%ADD13C,2*%
%LPD*%
D10*
]]))
assert(file:write((string.format([[
%+08.3fY%+08.3fD02*
X%+08.3fD01*
Y%+08.3fD01*
X%+08.3fD01*
Y%+08.3fD01*
]], left, bottom, right, top, left, bottom):gsub('%.', ''))))
assert(file:write([[
D11*
X0Y0D03*
%LPC*%
D12*
]]))

local polygon = {}
for i=0,7 do
	local r = din / 2
	local a1 = angle + i * math.pi / 4 - math.pi / 8
	local x1 = r * math.cos(a1)
	local y1 = r * math.sin(a1)
	local a2 = angle + i * math.pi / 4 + math.pi / 8
	local x2 = r * math.cos(a2)
	local y2 = r * math.sin(a2)
	x2 = x2 + (x2 - x1) * 2
	y2 = y2 + (y2 - y1) * 2
	-- a*x + b*y = c
	-- y = (-a/b) * x + c/b
	local geom2d = require 'geom2d'
	local p1 = geom2d.point(x1, y1)
	local p2 = geom2d.point(x2, y2)
	local line = geom2d.line(p1, p2)
	local c = geom2d.point(0, 0)
	local r = (dout + spacing) / 2
	local circle = geom2d.circle(c, r)
	local i1,i2 = geom2d.intersect(line, circle)
	local x2,y2 = i2.x,i2.y
	
	table.insert(polygon, {x=x1, y=y1})
	
	assert(file:write((string.format([[
X%+08.3fY%+08.3fD02*
X%+08.3fY%+08.3fD01*
]], x1, y1, x2, y2):gsub('%.', ''))))
end

assert(file:write([[
G36*
]]))
assert(file:write((string.format([[
X%+08.3fY%+08.3fD02*
]], polygon[#polygon].x, polygon[#polygon].y):gsub('%.', ''))))
for i,point in ipairs(polygon) do
	assert(file:write((string.format([[
X%+08.3fY%+08.3fD01*
]], point.x, point.y):gsub('%.', ''))))
end
assert(file:write([[
G37*
]]))

assert(file:write([[
M02*
]]))


assert(file:close())
