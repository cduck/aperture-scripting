local _M = {}

local math = require 'math'
local table = require 'table'

local region = require 'boards.region'
local drawing = require 'boards.drawing'
local templates = require 'boards.templates'
local manipulation = require 'boards.manipulation'

------------------------------------------------------------------------------

local function empty_image()
	return {
		format = { integer = 2, decimal = 4, zeroes = 'L' },
		unit = 'IN',
		extents = region(),
		center_extents = region(),
		layers = { { polarity = 'dark' } },
	}
end

function _M.empty_board(width, height)
	local extents = region{
		left = 0, right = width,
		bottom = 0, top = height,
	}
	return {
		unit = 'pm',
		template = templates.default_template,
		images = {
			milling = empty_image(),
			drill = empty_image(),
			top_paste = empty_image(),
			bottom_paste = empty_image(),
			top_copper = empty_image(),
			bottom_copper = empty_image(),
			top_soldermask = empty_image(),
			bottom_soldermask = empty_image(),
		},
		extensions = {},
		extents = extents,
		outline = {
			apertures = {},
			extents = extents,
			path = {
				extents = extents,
				{ x = 0, y = 0 },
				{ x = width, y = 0 },
				{ x = width, y = height },
				{ x = 0, y = height },
				{ x = 0, y = 0 },
			},
		},
	}
end

local function cut_tabs(panel, side_a, side_b, position, options, vertical)
	-- draw cut lines and break tabs
	-- see http://blogs.mentor.com/tom-hausherr/blog/2011/06/23/pcb-design-perfection-starts-in-the-cad-library-part-19/
	
	-- prepare routing and tab-separation drills
	-- :FIXME: for some reason the diameter needs to be scaled here, this is wrong
	local mill = { shape = 'circle', parameters = { options.spacing / 25.4 / 1e9 } }
	local drill = { shape = 'circle', parameters = { options.break_hole_diameter / 25.4 / 1e9 } }
	
	-- if sub-boards dimension mis-match, cut a clean border on the longest one
	if side_a[1] ~= side_b[1] then
		local a0 = side_a[1]
		local b0 = side_b[1]
		local c0 = math.min(a0, b0)
		local c1 = math.max(a0, b0)
		local z1 = c0 - options.spacing / 2
		local z4 = c1 - options.spacing / 2
		local w = position
		if vertical then
			drawing.draw_path(panel.images.milling, mill, z1, w, z4, w)
		else
			drawing.draw_path(panel.images.milling, mill, w, z1, w, z4)
		end
	end
	
	-- iterate over sides
	local a,b = 1,1
	while a < #side_a and b < #side_b do
		local a0,a1 = side_a[a],side_a[a+1]
		local b0,b1 = side_b[b],side_b[b+1]
		local c0 = math.max(a0, b0)
		local c1 = math.min(a1, b1)
		-- :TODO: add multiple tabs on long edges
		if c1 - c0 > options.break_tab_width + options.spacing then
			local c = (c0 + c1) / 2
			local z1 = c0 - options.spacing / 2
			local z2 = c - (options.break_tab_width + options.spacing) / 2
			local z3 = c + (options.break_tab_width + options.spacing) / 2
			local z4 = c1 + options.spacing / 2
			local w = position
			-- a half-line before the tab and a half-line after
			if vertical then
				drawing.draw_path(panel.images.milling, mill, z1, w, z2, w)
				drawing.draw_path(panel.images.milling, mill, z3, w, z4, w)
				drawing.draw_path(panel.images.top_soldermask, drill, z2, w - options.spacing / 2, z3, w - options.spacing / 2)
				drawing.draw_path(panel.images.top_soldermask, drill, z2, w + options.spacing / 2, z3, w + options.spacing / 2)
				drawing.draw_path(panel.images.bottom_soldermask, drill, z2, w - options.spacing / 2, z3, w - options.spacing / 2)
				drawing.draw_path(panel.images.bottom_soldermask, drill, z2, w + options.spacing / 2, z3, w + options.spacing / 2)
			else
				drawing.draw_path(panel.images.milling, mill, w, z1, w, z2)
				drawing.draw_path(panel.images.milling, mill, w, z3, w, z4)
				drawing.draw_path(panel.images.top_soldermask, drill, w - options.spacing / 2, z2, w - options.spacing / 2, z3)
				drawing.draw_path(panel.images.top_soldermask, drill, w + options.spacing / 2, z2, w + options.spacing / 2, z3)
				drawing.draw_path(panel.images.bottom_soldermask, drill, w - options.spacing / 2, z2, w - options.spacing / 2, z3)
				drawing.draw_path(panel.images.bottom_soldermask, drill, w + options.spacing / 2, z2, w + options.spacing / 2, z3)
			end
			-- drill holes to make the tabs easy to break
			local drill_count = math.floor(options.break_tab_width / options.break_hole_diameter / 2)
			local min
			for i=0,drill_count-1 do
				local z = (i - (drill_count-1) / 2) * options.break_hole_diameter * 2
				if vertical then
					drawing.draw_path(panel.images.milling, drill, c + z, w - options.spacing / 2)
					drawing.draw_path(panel.images.milling, drill, c + z, w + options.spacing / 2)
				else
					drawing.draw_path(panel.images.milling, drill, w - options.spacing / 2, c + z)
					drawing.draw_path(panel.images.milling, drill, w + options.spacing / 2, c + z)
				end
			end
		end
		if a1 < b1 then
			a = a + 2
		else
			b = b + 2
		end
	end
	
	-- if sub-boards dimension mis-match, cut a clean border on the longest one
	if side_a[#side_a] ~= side_b[#side_b] then
		local a1 = side_a[#side_a]
		local b1 = side_b[#side_b]
		local c0 = math.min(a1, b1)
		local c1 = math.max(a1, b1)
		local z1 = c0 + options.spacing / 2
		local z4 = c1 + options.spacing / 2
		local w = position
		if vertical then
			drawing.draw_path(panel.images.milling, mill, z1, w, z4, w)
		else
			drawing.draw_path(panel.images.milling, mill, w, z1, w, z4)
		end
	end
end

local function find_sides(outline)
	local path = outline.path
	local sides = {}
	
	-- first point should be left-most of the bottom-most
	sides.bottom_left = 1
	
	-- follow bottom
	sides.bottom_right = sides.bottom_left
	while sides.bottom_right < #path and path[sides.bottom_right+1].y == path[sides.bottom_right].y do
		sides.bottom_right = sides.bottom_right + 1
	end
	
	-- skip bottom-right rounded corner
	sides.right_bottom = sides.bottom_right
	while sides.right_bottom < #path and path[sides.right_bottom+1].x ~= path[sides.right_bottom].x do
		assert(path[sides.right_bottom+1].x > path[sides.right_bottom].x)
		sides.right_bottom = sides.right_bottom + 1
	end
	
	-- follow right
	sides.right_top = sides.right_bottom
	while sides.right_top < #path and path[sides.right_top+1].x == path[sides.right_top].x do
		sides.right_top = sides.right_top + 1
	end
	
	-- skip top-right rounded corner
	sides.top_right = sides.right_top
	while sides.top_right < #path and path[sides.top_right+1].y ~= path[sides.top_right].y do
		assert(path[sides.top_right+1].y > path[sides.top_right].y)
		sides.top_right = sides.top_right + 1
	end
	
	-- follow top
	sides.top_left = sides.top_right
	while sides.top_left < #path and path[sides.top_left+1].y == path[sides.top_left].y do
		sides.top_left = sides.top_left + 1
	end
	
	-- skip top-left rounded corner
	sides.left_top = sides.top_left
	while sides.left_top < #path and path[sides.left_top+1].x ~= path[sides.left_top].x do
		assert(path[sides.top_right+1].x < path[sides.top_right].x)
		sides.left_top = sides.left_top + 1
	end
	
	-- follow left
	sides.left_bottom = sides.left_top
	while sides.left_bottom < #path and path[sides.left_bottom+1].x == path[sides.left_bottom].x do
		sides.left_bottom = sides.left_bottom + 1
	end
	
	return sides
end

local function merge_panels(panel_a, panel_b, options, vertical)
	-- merge_boards doesn't merge outlines
	local merged = manipulation.merge_boards(panel_a, panel_b)
	
	local outline_a = panel_a.outline
	local outline_b = panel_b.outline
	
	if vertical then
		assert(outline_a.extents.left == outline_b.extents.left and outline_a.extents.right == outline_b.extents.right)
	else
		assert(outline_a.extents.bottom == outline_b.extents.bottom and outline_a.extents.top == outline_b.extents.top)
	end
	
	-- generate a new outline
	merged.outline = {
		apertures = {},
		path = {},
	}
	merged.outline.extents = outline_a.extents + outline_b.extents
	for type,aperture in pairs(outline_a.apertures) do
		merged.outline.apertures[type] = aperture
		if outline_b.apertures[type] then
			-- :TODO: ensure the two are identical
		--	assert(outline_b.apertures[type] == aperture)
		end
	end
	for type,aperture in pairs(outline_b.apertures) do
		merged.outline.apertures[type] = aperture
		if outline_a.apertures[type] then
			-- :TODO: ensure the two are identical
		--	assert(outline_a.apertures[type] == aperture)
		end
	end
	
	local sides_a = find_sides(outline_a)
	local sides_b = find_sides(outline_b)
	if vertical then
		-- cut tabs
		local side_a = {}
		for i=sides_a.top_left,sides_a.top_right,-1 do
			table.insert(side_a, outline_a.path[i].x)
		end
		local y_a = outline_a.path[sides_a.top_left].y
		local side_b = {}
		for i=sides_b.bottom_left,sides_b.bottom_right do
			table.insert(side_b, outline_b.path[i].x)
		end
		local y_b = outline_b.path[sides_b.bottom_left].y
		assert(y_a + options.spacing == y_b)
		cut_tabs(merged, side_a, side_b, (y_a + y_b) / 2, options, vertical)
		
		-- merge outlines
		for i=1,sides_a.top_right do
			table.insert(merged.outline.path, outline_a.path[i])
		end
		for i=sides_b.bottom_right,#outline_b.path do
			table.insert(merged.outline.path, outline_b.path[i])
		end
		for i=sides_a.top_left,#outline_a.path do
			table.insert(merged.outline.path, outline_a.path[i])
		end
	else
		-- cut tabs
		local side_a = {}
		for i=sides_a.right_bottom,sides_a.right_top do
			table.insert(side_a, outline_a.path[i].y)
		end
		local x_a = outline_a.path[sides_a.right_bottom].x
		local side_b = {}
		for i=sides_b.left_bottom,sides_b.left_top,-1 do
			table.insert(side_b, outline_b.path[i].y)
		end
		local x_b = outline_b.path[sides_b.left_bottom].x
		assert(x_a + options.spacing == x_b)
		cut_tabs(merged, side_a, side_b, (x_a + x_b) / 2, options, vertical)
		
		-- merge outlines
		assert(#merged.outline.path == 0)
		for i=1,sides_a.right_bottom do
			table.insert(merged.outline.path, outline_a.path[i])
		end
		for i=sides_b.left_bottom,#outline_b.path-1 do
			table.insert(merged.outline.path, outline_b.path[i])
		end
		for i=1,sides_b.left_top do
			table.insert(merged.outline.path, outline_b.path[i])
		end
		for i=sides_a.right_top,#outline_a.path do
			table.insert(merged.outline.path, outline_a.path[i])
		end
	end
	
	return merged
end

function _M.panelize(layout, options, vertical)
	local mm = 1e9
	if not options.spacing then
		options.spacing = 2*mm
	end
	if not options.break_hole_diameter then
		options.break_hole_diameter = 0.5*mm
	end
	if not options.break_tab_width then
		options.break_tab_width = 5*mm
	end
	if #layout == 0 then
		-- this is not a layout but a board
		return layout
	end
	
	-- panelize subpanels
	assert(#layout >= 1)
	local subpanels = {}
	for i=1,#layout do
		-- panelize sublayout
		local child = _M.panelize(layout[i], options, not vertical)
		assert(child.outline, "panelized boards must have an outline")
		subpanels[i] = child
	end
	
	-- assemble the panel
	local left,bottom = 0,0
	local panel
	for _,subpanel in ipairs(subpanels) do
		local dx = left - subpanel.outline.extents.left
		local dy = bottom - subpanel.outline.extents.bottom
		if not panel then
			panel = manipulation.offset_board(subpanel, dx, dy)
		else
			local neighbour = manipulation.offset_board(subpanel, dx, dy)
			panel = merge_panels(panel, neighbour, options, vertical)
		end
		if vertical then
			bottom = panel.outline.extents.top + options.spacing
		else
			left = panel.outline.extents.right + options.spacing
		end
	end
	
	return panel
end

------------------------------------------------------------------------------

return _M
