--- This module contains several function that let you generate new image data dynamically. You can always manipulate images internal structures directly, but to maintain integrity (the format is rather complex) prefer using functions in this module.
local _M = {}

local io = require 'io'
local table = require 'table'
local path = require 'boards.path'
local manipulation = require 'boards.manipulation'

local exterior = path.exterior

------------------------------------------------------------------------------

--- Create a simple circular aperture. Note that all paths except regions require an aperture. Even zero-width paths require a zero-width aperture, which you can create by passing 0 as the *diameter*. This aperture unit is always `'pm'`, which is the unit of the *diameter*.
function _M.circle_aperture(diameter)
	local aperture = { shape = 'circle', unit = 'pm', diameter = diameter }
	return aperture
end

------------------------------------------------------------------------------

--- Draw a path on the specified *image* using the specified *aperture*. Every two extra arguments are the X and Y positions of an extra point, specified in board units (usually picometers). If the path has a single point, it is a flash. Otherwise it is a stroke with linear interpolation between points.
--- 
--- If no aperture is provided, the path is a region, which means it must have at least 4 points and be closed (ie. last point must be the same as the first point). If you want to create a region you need to explicitly pass `nil` as second argument to `draw_path` before the points data.
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

function _M.draw_path_ex(image, aperture, ...)
	local mode
	local args = {}
	local path
	for i=1,select('#', ...) do
		local arg = select(i, ...)
		if arg=='M' or arg=='L' or arg=='A' then
			assert(#args==0)
			mode = arg
		elseif type(arg)=='number' or type(arg)=='boolean' then
			table.insert(args, arg)
			if mode=='M' and #args==2 then
				path = {
					aperture = aperture,
					unit = image.unit,
					{ x = args[1], y = args[2] },
				}
				table.insert(image.layers[#image.layers], path)
				args = {}
			elseif mode=='L' and #args==2 then
				table.insert(path, { interpolation = 'linear', x = args[1], y = args[2] })
				args = {}
			elseif mode=='A' and #args==6 then
				local cx,cy,o,q,x,y = table.unpack(args)
				table.insert(path, {
					interpolation = 'circular',
					direction = o and 'clockwise' or 'counterclockwise',
					quadrant = q and 'single' or 'multi',
					cx = cx, cy = cy,
					x = x, y = y,
				})
				args = {}
			end
		else
			error("unsupported path argument "..tostring(arg).." ("..type(arg)..")")
		end
	end
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
				local p0,p1,p2 = lastpos,control,pos
				if p1.x==p0.x and p1.y==p0.y or p2.x==p1.x and p2.y==p1.y then
					p1,p2 = p2
				end
				if p2 and (p1.y-p0.y)/(p1.x-p0.x) == (p2.y-p1.y)/(p2.x-p1.x) then
					p1,p2 = p2
				end
				if p2 then
					table.insert(path, {x1=p1.x, y1=p1.y, x=p2.x, y=p2.y, interpolation='quadratic'})
				else
					table.insert(path, {x=p1.x, y=p1.y, interpolation='linear'})
				end
				lastpos = pos
			end,
			cubic_to = function(control1, control2, pos)
				local p0,p1,p2,p3 = lastpos,control1,control2,pos
				if p2.x==p1.x and p2.y==p1.y or p3.x==p2.x and p3.y==p2.y then
					p2,p3 = p3
				end
				if p1.x==p0.x and p1.y==p0.y or p2.x==p1.x and p2.y==p1.y then
					p1,p2 = p2
				end
				if p3 then
					table.insert(path, {x1=p1.x, y1=p1.y, x2=p2.x, y2=p2.y, x=p3.x, y=p3.y, interpolation='cubic'})
				elseif p2 then
					table.insert(path, {x1=p1.x, y1=p1.y, x=p2.x, y=p2.y, interpolation='quadratic'})
				else
					table.insert(path, {x=p1.x, y=p1.y, interpolation='linear'})
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

--- Draw some text on the *image* using the font file specified by *fontname*. *text* is the drawn text, as a string encoded in UTF-8.
--- 
--- Each glyph is converted to regions on the top image layer or new layers if necessary, with the outside contour having the specified *polarity* (either `'dark'` or `'clear'`), and the glyph cutouts having the opposite polarity.
--- 
--- *size* is the font size in image data units (most likely picometers) and correspond usually to the height of an uppercase letter (this depends on the font). The text is logically positionned at coordinates *x* and *y* (still in image data units), with *halign* specifying how text is horizontally aligned relative to this point. *halign* can be one of the following strings:
--- 
---   - `'left'`: the text logical position starts exactly on *x*
---   - `'x0'`: the first glyph `left` attribute (which may or may not be meaningful depending on the font) is aligned on *x*
---   - `'center'`: the text width is computed (including spacing and kerning) and the whole *text* string is centered on *x*
--- 
--- *mirror* is a boolean, indicating whether the text will read normally from left to right (if false) or be mirrored horizontally (if true). This is useful to draw text on bottom images. Note that is *mirror* is true and *halign* is `'left'`, it's the text right-most edge that will actually be on *x*.
function _M.draw_text(image, polarity, fontname, size, mirror, halign, x, y, text)
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
					for _,k in ipairs{'x', 'x1', 'x2', 'cx'} do
						local v = point[k]
						if v then
							point[k] = -v
						end
					end
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

end

------------------------------------------------------------------------------

return _M
