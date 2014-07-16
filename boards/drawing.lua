local _M = {}

local table = require 'table'
local region = require 'boards.region'

------------------------------------------------------------------------------

function _M.circle_aperture(diameter)
	local aperture = { shape = 'circle', parameters = { diameter } }
	return aperture
end

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

local success,result = pcall(require, 'freetype')
if not success then
	if not result:match("module 'freetype' not found") then
		error(result)
	end
else

local FT = result
local library = assert(FT.Init_FreeType())

-- use a unique font size, because Freetype can't deal with fonts too small or
-- too large, while this library should be able to be scale-independent
local font_size = 1000
local face_cache = {}
local glyph_cache = {}

local function get_face(fontname)
	local face_key = fontname
	local face = face_cache[face_key]
	if not face then
		face = assert(FT.Open_Face(library, {stream=assert(io.open(fontname, "rb"))}, 0))
		FT.Set_Char_Size(face, font_size, font_size, 0, 0)
		face_cache[face_key] = face
	end
	return face
end

local function get_glyph(fontname, char)
	local glyph_key = fontname..'\0'..char
	local glyph = glyph_cache[glyph_key]
	if not glyph then
		local face = get_face(fontname)
		local charcode = assert(FT.Get_Char_Index(face, char))
		
		assert(FT.Load_Glyph(face, charcode, {'DEFAULT', 'NO_HINTING', 'NO_AUTOHINT'}))
		
		local glyph_slot = face.glyph
		glyph = assert(FT.Get_Glyph(glyph_slot))
		assert(glyph.format == 'OUTLINE')
		
		local paths = {}
		local path
		local lastpos
		local curve_steps = 16
		assert(FT.Outline_Decompose(glyph.outline, {
			move_to = function(pos)
				path = {pos}
				table.insert(paths, path)
				lastpos = pos
			end,
			line_to = function(pos)
				assert(pos.x and pos.y)
				table.insert(path, pos)
				lastpos = pos
			end,
			conic_to = function(control, pos)
				local P0 = lastpos
				local P1 = control
				local P2 = pos
				for t=1,curve_steps do
					t = t / curve_steps
					local k1 = (1 - t) ^ 2
					local k2 = 2 * (1 - t) * t
					local k3 = t ^ 2
					local px = k1 * P0.x + k2 * P1.x + k3 * P2.x
					local py = k1 * P0.y + k2 * P1.y + k3 * P2.y
					table.insert(path, {x=px, y=py})
				end
				lastpos = pos
			end,
			cubic_to = function(control1, control2, pos)
				local P0 = lastpos
				local P1 = control1
				local P2 = control2
				local P3 = pos
				for t=1,curve_steps do
					t = t / curve_steps
					local k1 = (1 - t) ^ 3
					local k2 = 3 * (1 - t) ^ 2 * t
					local k3 = 3 * (1 - t) * t ^ 2
					local k4 = t ^ 3
					local px = k1 * P0.x + k2 * P1.x + k3 * P2.x + k4 * P3.x
					local py = k1 * P0.y + k2 * P1.y + k3 * P2.y + k4 * P3.y
					table.insert(path, {x=px, y=py})
				end
				lastpos = pos
			end,
		}))
		glyph = {
			left = glyph_slot.metrics.horiBearingX,
			width = glyph_slot.metrics.horiAdvance,
			contours = paths,
			flags = glyph.outline.flags,
		}
		glyph_cache[glyph_key] = glyph
	end
	return glyph
end

local function get_kerning(fontname, leftchar, rightchar)
	local face = get_face(fontname)
	local leftcharcode = assert(FT.Get_Char_Index(face, leftchar))
	local rightcharcode = assert(FT.Get_Char_Index(face, rightchar))
	local kerning = FT.Get_Kerning(face, leftcharcode, rightcharcode, 'DEFAULT')
	return kerning.x
end

local function clockwise(path)
	local total = 0
	for i=1,#path-1 do
		local p0 = path[i-1] or path[#path-1]
		local p1 = path[i]
		local p2 = path[i+1] or path[1]
		local dx1 = p1.x - p0.x
		local dy1 = p1.y - p0.y
		local dx2 = p2.x - p1.x
		local dy2 = p2.y - p1.y
		local l1 = math.sqrt(dx1*dx1+dy1*dy1)
		local l2 = math.sqrt(dx2*dx2+dy2*dy2)
		if l1 * l2 ~= 0 then
			local angle = math.asin((dx1*dy2-dy1*dx2)/(l1*l2))
			total = total + angle
		end
	end
	return total < 0
end

local function draw_text(image, polarity, fontname, size, mirror, halign, x, y, text)
	if #text == 0 then return end
	local scale = size / font_size
	
	text = {string.byte(text, 1, #text)}
	
	local textwidth = 0
	for i,char in ipairs(text) do
		if i > 1 then
			textwidth = textwidth + get_kerning(fontname, text[i-1], char) * scale
		end
		local glyph = get_glyph(fontname, char)
		textwidth = textwidth + glyph.width * scale
	end
	
	if halign == 'left' then
		-- keep user x
	elseif halign == 'center' then
		x = x - textwidth / 2
	elseif halign == 'x0' then
		local glyph = get_glyph(fontname, char[1])
		x = x + glyph.left * scale
	else
		error("unsupported horizontal alignment")
	end
	
	table.insert(image.layers, { polarity = polarity })
	local base_layer = #image.layers
	local ilayer
	for i,char in ipairs(text) do
		if i > 1 then
			x = x + get_kerning(fontname, text[i-1], char) * scale
		end
		
		local glyph = get_glyph(fontname, char)
		
		ilayer = base_layer
		for icontour,contour in ipairs(glyph.contours) do
			local path = {}
			for i,point in ipairs(contour) do
				if i == 1 then
					table.insert(path, {x = x + point.x * scale, y = y + point.y * scale})
				else
					table.insert(path, {x = x + point.x * scale, y = y + point.y * scale, interpolation='linear'})
				end
			end
			local clockwise_outline = not glyph.flags.REVERSE_FILL
			local outline = clockwise(path) == clockwise_outline -- compare before mirror
			local path_polarity = outline and polarity or (polarity=='clear' and 'dark' or 'clear')
			if mirror then
				for _,point in ipairs(path) do
					point.x = -point.x
				end
			end
			local layer = image.layers[ilayer]
			if layer.polarity ~= path_polarity then
				layer = { polarity = path_polarity }
				ilayer = ilayer + 1
				image.layers[ilayer] = layer
			end
			table.insert(layer, path)
		end
		
		x = x + glyph.width * scale
	end
end

_M.draw_text = draw_text

end

------------------------------------------------------------------------------

return _M
