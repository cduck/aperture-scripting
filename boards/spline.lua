local _M = {}
local _NAME = ... or 'test'

local table = require 'table'

if _NAME=='test' then
	require 'test'
end

local modes = {}

local quadratic = {}
modes.quadratic = quadratic

function quadratic.pos(t, x0, x1, x2)
	local _t = 1 - t
	return _t*_t * x0 + 2*_t*t * x1 + t*t * x2
end

function quadratic.vel(t, x0, x1, x2)
	local _t = 1 - t
	return 2*_t * (x1 - x0) + 2*t * (x2 - x1)
end

function quadratic.acc(t, x0, x1, x2)
	return 2 * (x2 - 2*x1 + x0)
end

function quadratic.jer(t, x0, x1, x2)
	return 0
end

local cubic = {}
modes.cubic = cubic

function cubic.pos(t, x0, x1, x2, x3)
	local _t = 1 - t
	return _t*_t*_t * x0 + 3*_t*_t*t * x1 + 3*_t*t*t * x2 + t*t*t * x3
end

function cubic.vel(t, x0, x1, x2, x3)
	local _t = 1 - t
	return 3*_t*_t * (x1 - x0) + 6*_t*t * (x2 - x1) + 3*t*t * (x3 - x2)
end

function cubic.acc(t, x0, x1, x2, x3)
	local _t = 1 - t
	return 6*_t * (x2 - 2*x1 + x0) + 6*t * (x3 - 2*x2 + x1)
end

function cubic.jer(t, x0, x1, x2, x3)
	return 6 * (x3 - 2*x2 + x1) - 6 * (x2 - 2*x1 + x0)
end

for _,mode in pairs(modes) do
	local pos = mode.pos
	local vel = mode.vel
	local acc = mode.acc
	local jer = mode.jer
	
	function mode.curvature(t, x0, y0, x1, y1, x2, y2, x3, y3)
		-- see http://mathworld.wolfram.com/Curvature.html
		-- see http://en.wikipedia.org/wiki/Osculating_circle#Mathematical_description
		-- see http://blog.avangardo.com/2010/10/acceleration-on-curve-path/
		local vx = vel(t, x0, x1, x2, x3)
		local vy = vel(t, y0, y1, y2, y3)
		local ax = acc(t, x0, x1, x2, x3)
		local ay = acc(t, y0, y1, y2, y3)
		local k = (vx*ay - ax*vy) / (vx*vx + vy*vy) ^ (3/2)
		return k
	end
	
	function mode.curvature_derivative(t, x0, y0, x1, y1, x2, y2, x3, y3)
		-- derivate the above
		local vx = vel(t, x0, x1, x2, x3)
		local vy = vel(t, y0, y1, y2, y3)
		local ax = acc(t, x0, x1, x2, x3)
		local ay = acc(t, y0, y1, y2, y3)
		local jx = jer(t, x0, x1, x2, x3)
		local jy = jer(t, y0, y1, y2, y3)
		local vk = (2*(vx^2+vy^2)*(jy*vx-jx*vy)+6*(ax*vy-vx*ay)*(vx*ax+vy*ay))/(2*(vx^2+vy^2)^(5/2))
		return vk
	end
end

if _NAME=='test' then
	require 'test'
	expect(-1, quadratic.curvature(0.5, 0, 0, 1, 1, 2, 0))
	expect(1, quadratic.curvature(0.5, 0, 0, 1, -1, 2, 0))
	--[===[
	for i=0,100 do
		local t = i / 100
		print(t, quadratic.curvature(t, 0, 0, 1, 5, 2, 0),
			quadratic.curvature_derivative(t, 0, 0, 1, 5, 2, 0))
--		print("", quadratic.pos(t, 0, 1, 2), quadratic.pos(t, 0, 1, 0))
	end
	for i=0,100 do
		local t = i / 100
--		print(t, quadratic.curvature(t, 0, 0, 0.5, 0.5, 1, 0.5),
--			quadratic.curvature_derivative(t, 0, 0, 0.5, 0.5, 1, 0.5))
--		print("", quadratic.pos(t, 0, 1, 2), quadratic.pos(t, 0, 1, 0))
	end
--	expect(-1, cubic.curvature(0.5, 0, 0, 0, 1, 2, 1, 2, 0))
--	expect(1, cubic.curvature(0.5, 0, 0, 0, -1, 2, -2, 2, 0))
	for i=0,100 do
		local t = i / 100
--		print(t, cubic.curvature(t, 0, 0, 0, 1, 2, 1, 2, 0),
--			cubic.curvature_derivative(t, 0, 0, 0, 1, 2, 1, 2, 0))
--		print(t, cubic.pos(t, 0, 0, 2, 2),
--			cubic.curvature_derivative(t, 0, 0, 0, 1, 2, 1, 2, 0))
	end
	--]===]
end

function _M.quadratic(x0, y0, x1, y1, x2, y2)
	return {mode='quadratic', x0=x0, y0=y0, x1=x1, y1=y1, x2=x2, y2=y2}
end

function _M.cubic(x0, y0, x1, y1, x2, y2, x3, y3)
	return {mode='cubic', x0=x0, y0=y0, x1=x1, y1=y1, x2=x2, y2=y2, x3=x3, y3=y3}
end

local function draw(a, b, points, t)
	table.insert(a, points[1])
	if #points > 1 then
		local _t = 1 - t
		local points2 = {}
		for i=1,#points-1 do
			points2[i] = {
				x = _t * points[i].x + t * points[i+1].x,
				y = _t * points[i].y + t * points[i+1].y,
			}
		end
		draw(a, b, points2, t)
	end
	table.insert(b, points[#points])
end

local function split(spline, t)
	local mode = spline.mode
	local a,b = {mode=mode},{mode=mode}
	local n
	if mode=='quadratic' then
		n = 3
	elseif mode=='cubic' then
		n = 4
	else
		error("unsupported spline mode "..tostring(mode))
	end
	local pa,pb = {},{}
	local points = {}
	for i=1,n do
		points[i] = {x=spline['x'..(i-1)], y=spline['y'..(i-1)]}
	end
	draw(pa, pb, points, t)
	assert(#pa==n)
	assert(#pb==n)
	for i=1,n do
		a['x'..(i-1)],a['y'..(i-1)] = pa[i].x,pa[i].y
		b['x'..(i-1)],b['y'..(i-1)] = pb[i].x,pb[i].y
	end
	return a,b
end

local function monotonic_split(spline)
	local mode,x0,y0,x1,y1,x2,y2,x3,y3 = spline.mode,spline.x0,spline.y0,spline.x1,spline.y1,spline.x2,spline.y2,spline.x3,spline.y3
	if modes[mode].curvature(0, x0, y0, x1, y1, x2, y2, x3, y3) == 0 then
		return {spline}
	end
	local splits = {}
	local last_t = 0
	local last_cd = modes[mode].curvature_derivative(0, x0, y0, x1, y1, x2, y2, x3, y3)
	for i=1,100 do
		local t = i / 100
		local cd = modes[mode].curvature_derivative(t, x0, y0, x1, y1, x2, y2, x3, y3)
		if cd == 0 and i <= 99 then
			table.insert(splits, t)
		elseif last_cd*cd < 0 then
			local ta,tb,tc = last_t,t
			local a,b = last_cd,cd
			while true do
				tc = (ta + tb) / 2
				if tc==ta or tc==tb then break end
				local c = modes[mode].curvature_derivative(tc, x0, y0, x1, y1, x2, y2, x3, y3)
				if c==0 then
					break
				elseif a*c < 0 then
					tb,b = tc,c
				elseif c*b < 0 then
					ta,a = tc,c
				else
					error("unexpected case")
				end
			end
			table.insert(splits, tc)
		end
		last_t = t
		last_cd = cd
	end
	local splines = {}
	local last_split = 0
	for _,tsplit in ipairs(splits) do
		local t = (tsplit - last_split) / (1 - last_split)
		local a,b = split(spline, t)
		table.insert(splines, a)
		spline = b
		last_split = t
	end
	table.insert(splines, spline)
	return splines
end

if _NAME=='test' then
	local c = _M.quadratic(0, 0, 0.5, 0.5, 1, 0.5)
	expect(1, #monotonic_split(c))
	local c = _M.quadratic(0, 0, 1, 1, 2, 0)
	expect(2, #monotonic_split(c))
	local c = _M.cubic(0, 0, 0, 1, 2, 1, 2, 0)
	expect(4, #monotonic_split(c))
	
	local function monotonic(spline)
		local mode,x0,y0,x1,y1,x2,y2,x3,y3 = spline.mode,spline.x0,spline.y0,spline.x1,spline.y1,spline.x2,spline.y2,spline.x3,spline.y3
		local c0 = modes[mode].curvature(0, x0, y0, x1, y1, x2, y2, x3, y3)
		local cd0 = modes[mode].curvature_derivative(0, x0, y0, x1, y1, x2, y2, x3, y3)
		for i=1,100 do
			local t = i / 100
			local c = modes[mode].curvature(t, x0, y0, x1, y1, x2, y2, x3, y3)
			local cd = modes[mode].curvature_derivative(t, x0, y0, x1, y1, x2, y2, x3, y3)
			if c*c0 <= -1e-14 then return false end
			if cd*cd0 <= -1e-14 then return false end
		end
		return true
	end
	local c = _M.cubic(0, 0, 0, 1, 2, 1, 2, 0)
	local t = monotonic_split(c)
	expect(4, #t)
	expect(true, monotonic(t[1]))
	expect(true, monotonic(t[2]))
	expect(true, monotonic(t[3]))
	expect(true, monotonic(t[4]))
end

local function intersect(p0, v0, p1, v1)
--	x = p0.x + k0 * v0.x = p1.x + k1 * v1.x
--	y = p0.y + k0 * v0.y = p1.y + k1 * v1.y
	
--	k1 = (p0.y + k0 * v0.y - p1.y) / v1.y
--	p0.x + k0 * v0.x = p1.x + (p0.y + k0 * v0.y - p1.y) / v1.y * v1.x
--	p0.x * v1.y + k0 * v0.x * v1.y = p1.x * v1.y + (p0.y + k0 * v0.y - p1.y) * v1.x
--	p0.x * v1.y + k0 * v0.x * v1.y = p1.x * v1.y + p0.y * v1.x + k0 * v0.y * v1.x - p1.y * v1.x
--	k0 * v0.x * v1.y - k0 * v0.y * v1.x = p1.x * v1.y + p0.y * v1.x - p1.y * v1.x - p0.x * v1.y
--	k0 * (v0.x * v1.y - v0.y * v1.x) = p1.x * v1.y + p0.y * v1.x - p1.y * v1.x - p0.x * v1.y
	local denom = v0.x * v1.y - v0.y * v1.x
	if denom ~= 0 then
		local k0 = (p1.x * v1.y + p0.y * v1.x - p1.y * v1.x - p0.x * v1.y) / denom
		return p0 + k0 * v0
	end
end

local function biarc(spline)
	local geometry = require 'geometry'
	local vector = geometry.vector
	
	local A,B,tA,tB
	if spline.mode=='quadratic' then
		A = vector(spline.x0, spline.y0)
		tA = vector(spline.x1 - spline.x0, spline.y1 - spline.y0).normalized
		B = vector(spline.x2, spline.y2)
		tB = vector(spline.x1 - spline.x2, spline.y1 - spline.y2).normalized
	elseif spline.mode=='cubic' then
		A = vector(spline.x0, spline.y0)
		tA = vector(spline.x1 - spline.x0, spline.y1 - spline.y0).normalized
		B = vector(spline.x3, spline.y3)
		tB = vector(spline.x2 - spline.x3, spline.y2 - spline.y3).normalized
	else
		error("unsuported spline mode")
	end
	local up = (tA ^ -tB).z
	assert(up ~= 0, "linear "..spline.mode.." spline")
	if up > 0 then
		up = 'counterclockwise'
	else
		up = 'clockwise'
	end
	local nA = vector(-tA.y, tA.x)
	local nB = vector(-tB.y, tB.x)
	local C = intersect(A, tA, B, tB)
	assert((C-A) * tA > 0)
	assert((C-B) * tB > 0)
	local a = (C-B).norm
	local b = (A-C).norm
	local c = (B-A).norm
	local P = (a*A + b*B + c*C) * (1 / (a + b + c))
	-- arc from A to P
	local AP = P - A
	local D = (P + A) * 0.5
	local tD = AP.normalized
	local nD = vector(-tD.y, tD.x)
	local C1 = intersect(A, nA, D, nD)
	local arc1 = {mode='arc', x0=A.x, y0=A.y, cx=C1.x, cy=C1.y, x1=P.x, y1=P.y, direction=up}
	-- arc from P to B
	local BP = P - B
	local E = (P + B) * 0.5
	local tE = BP.normalized
	local nE = vector(-tE.y, tE.x)
	local C2 = intersect(B, nB, E, nE)
	local arc2 = {mode='arc', x0=P.x, y0=P.y, cx=C2.x, cy=C2.y, x1=B.x, y1=B.y, direction=up}
	
	return arc1,arc2
end

function _M.convert_to_arcs(spline, epsilon)
	local splines = monotonic_split(spline)
	local arcs = {}
	local i = 1
	while i <= #splines do
		local a,b = biarc(splines[i])
		-- :TODO: if error too large, split spline
		table.insert(arcs, a)
		table.insert(arcs, b)
		i = i + 1
	end
	return arcs
end

if _NAME=='test' then
	local epsilon = 0.01
	local c = _M.quadratic(0, 0, 1, 1, 2, 0)
	local arcs = _M.convert_to_arcs(c, epsilon)
	expect(4, #arcs)
	--[[
	for i,arc in ipairs(arcs) do
		print(i)
		for k,v in pairs(arc) do print("", k, v) end
	end
	--]]
	local c = _M.cubic(0, 0, 0, 1, 2, 1, 2, 0)
	local arcs = _M.convert_to_arcs(c, epsilon)
	expect(8, #arcs)
end

return _M
