local _M = {}

local io = require 'io'
local table = require 'table'
local path = require 'boards.path'
local manipulation = require 'boards.manipulation'

local exterior = path.exterior

------------------------------------------------------------------------------

function _M.circle_aperture(diameter, unit)
	assert(unit==nil)
	local aperture = { shape = 'circle', unit = 'pm', diameter = diameter }
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
		assert(FT.Outline_Decompose(glyph.outline, {
			move_to = function(pos)
				path = {pos}
				table.insert(paths, path)
				lastpos = pos
			end,
			line_to = function(pos)
				assert(pos.x and pos.y)
				table.insert(path, {x=pos.x, y=pos.y, interpolation='linear'})
				lastpos = pos
			end,
			conic_to = function(control, pos)
				table.insert(path, {x1=control.x, y1=control.y, x=pos.x, y=pos.y, interpolation='quadratic'})
				lastpos = pos
			end,
			cubic_to = function(control1, control2, pos)
				table.insert(path, {x1=control1.x, y1=control1.y, x2=control2.x, y2=control2.y, x=pos.x, y=pos.y, interpolation='cubic'})
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
	
	if #image.layers == 0 then
		table.insert(image.layers, { polarity = polarity })
	end
	local base_layer = #image.layers
	local ilayer
	for i,char in ipairs(text) do
		if i > 1 then
			x = x + get_kerning(fontname, text[i-1], char) * scale
		end
		
		local glyph = get_glyph(fontname, char)
		
		ilayer = base_layer
		for icontour,contour in ipairs(glyph.contours) do
			local path = manipulation.offset_path(manipulation.scale_path(contour, scale), x, y)
			local clockwise_outline = not glyph.flags.REVERSE_FILL
			local outline = exterior(path) ~= clockwise_outline -- compare before mirror
			local path_polarity = outline and polarity or (polarity=='clear' and 'dark' or 'clear')
			if mirror then
				for _,point in ipairs(path) do
					point.x = -point.x
				end
			end
			local layer = image.layers[ilayer]
			while layer and layer.polarity ~= path_polarity do
				ilayer = ilayer + 1
				layer = image.layers[ilayer]
			end
			if not layer then
				layer = { polarity = path_polarity }
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
