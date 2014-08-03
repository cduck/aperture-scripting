local _M = {}
local _NAME = ... or 'test'

local _type = type
local function type(v)
	local mt = getmetatable(v)
	return mt and mt.__type or _type(v)
end

local point_mt = {__type='point'}
function point_mt:__tostring()
	return "point("..self.x..", "..self.y..")"
end
function _M.point(x, y)
	return setmetatable({x=x, y=y}, point_mt)
end

local line_mt = {__type='line'}
function line_mt:__tostring()
	if self.a == 0 then
		return "line: "..(self.b==1 and "" or tostring(self.b)).."y = "..tostring(self.c)
	elseif self.b == 0 then
		return "line: "..(self.a==1 and "" or tostring(self.a)).."x = "..tostring(self.c)
	else
		return "line: "..(self.a==1 and "" or tostring(self.a)).."x + "..(self.b==1 and "" or tostring(self.b)).."y = "..tostring(self.c)
	end
end
function _M.line(...)
	local a,b,c
	local argc = select('#', ...)
	if argc==3 then
		a,b,c = ...
		assert(type(a)=='number')
		assert(type(b)=='number')
		assert(type(c)=='number')
	elseif argc==2 then
		local p1,p2 = ...
		assert(type(p1)=='point')
		assert(type(p2)=='point')
		local x1,y1,x2,y2 = p1.x,p1.y,p2.x,p2.y
		if x1==x2 then
			if y1==y2 then
				return
			end
			a = 1
			b = 0
			c = x1
	--		print("1>", a, b, c)
		else
			-- y = mx + k
			local m = (y2-y1)/(x2-x1)
			local k = y1 - m*x1
	--		print(">", m, k)
			a = -m
			b = 1
			c = k
	--		print("2>", a, b, c)
		end
	else
		error("invalid argument count")
	end
	-- ax + by = c
	if c==0 then
		if b==0 then
			a = 1
		else
			a = a / b
		end
	elseif a==0 then
		c = c / b
		b = 1
	elseif b==0 then
		c = c / a
		a = 1
	else
		a = a / c
		b = b / c
		c = 1
	end
	return setmetatable({a=a, b=b, c=c}, line_mt)
end

local circle_mt = {__type='circle'}
function circle_mt:__tostring()
	return "circle("..tostring(self.c)..", "..tostring(self.r)..")"
--	return "circle: (x-"..self.c.x..")^2 + (y-"..self.c.y..")^2 = "..self.r.."^2"
end
function _M.circle(c, r)
	return setmetatable({c=c, r=r}, circle_mt)
end

function _M.intersect(A, B)
	local ta,tb = type(A),type(B)
	-- see http://en.wikipedia.org/wiki/Intersection_(Euclidean_geometry)
	if type(A)=='circle' and type(B)=='line' or type(A)=='line' and type(B)=='circle' then
		local C,L = A,B
		if type(A)=='line' and type(B)=='circle' then
			C,L = B,A
		end
--		print("C>", C, "L>", L)
		local r = C.r
		local a,b,c = L.a,L.b,L.c
		local discriminant = r^2*(a^2+b^2)-c^2
		if discriminant < 0 then
			return
		elseif discriminant == 0 then
			local denominator = a^2+b^2
			local x = a*c/denominator
			local y = b*c/denominator
			return _M.point(x, y)
		else
			discriminant = math.sqrt(discriminant)
			local denominator = a^2+b^2
			local x1 = (a*c+b*discriminant)/denominator
			local y1 = (b*c-a*discriminant)/denominator
			local x2 = (a*c-b*discriminant)/denominator
			local y2 = (b*c+a*discriminant)/denominator
			local p1,p2 = _M.point(x1, y1),_M.point(x2, y2)
		--	if x1 > x2 or x1 == x2 and y1 > y2 then
		--		return p2,p1
		--	else
				return p1,p2
		--	end
		end
	else
		error("unsupported intersection")
	end
end

if _NAME=='test' then
	local test = require 'test'
	test.epsilon = 1e-12
	local P = _M.point
	local L = _M.line
	local C = _M.circle
	local intersect = _M.intersect
	--[[
	expect(L(P(-1, 1), P(1, 1)), L(P(-2, 1), P(2, 1)))
	expect(P(0, 1), _M.intersect(C(P(0, 0), 1), L(P(-1, 1), P(1, 1))))
	local c,l = C(P(0, 0), 1),L(P(-1, 0), P(1, 0))
	expect(2, select('#', _M.intersect(c, l)))
	expect(P(-1, 0), select(1, _M.intersect(c, l)))
	expect(P(1, 0), select(2, _M.intersect(c, l)))
	--]]
	local c,l = C(P(0, 0), 1),L(P(-1, 0.5), P(1, 0.5))
--	print(">", _M.intersect(c, l))
	expect(2, select('#', _M.intersect(c, l)))
	expect(P(math.cos(math.pi*5/6), 0.5), select(1, _M.intersect(c, l)))
	expect(P(math.cos(math.pi*1/6), 0.5), select(2, _M.intersect(c, l)))
	local c = C(P(0, 0), 379.2)
	local l = L(-0.0027571481551589, -0.0007387756215878, 1)
	expect(2, select('#', _M.intersect(c, l)))
--	local c,l = C(P(0, 0), 1),L(P(-2, 0), P(2, 1))
--	print(">", _M.intersect(c, l))
--	print(_M.intersect(_M.circle(_M.point(0, 0), 1), _M.line(_M.point(-1, 1), _M.point(1, 1))))
end

return _M
