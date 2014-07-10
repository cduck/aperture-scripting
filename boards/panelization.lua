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
_M.empty_image = empty_image

function _M.empty_board(width, height)
	local extents = region(width and height and {
		left = 0, right = width,
		bottom = 0, top = height,
	})
	return {
		unit = 'pm',
		template = templates.default,
		images = {
			milling = empty_image(),
			drill = empty_image(),
			top_paste = empty_image(),
			bottom_paste = empty_image(),
			top_copper = empty_image(),
			bottom_copper = empty_image(),
			top_soldermask = empty_image(),
			bottom_soldermask = empty_image(),
			top_silkscreen = empty_image(),
			bottom_silkscreen = empty_image(),
		},
		extensions = {},
		formats = {},
		extents = extents,
		outline = width and height and {
			apertures = {},
			extents = extents,
			path = {
				extents = extents,
				center_extents = extents,
				{ x = 0, y = 0 },
				{ x = width, y = 0, interpolation = 'linear' },
				{ x = width, y = height, interpolation = 'linear' },
				{ x = 0, y = height, interpolation = 'linear' },
				{ x = 0, y = 0, interpolation = 'linear' },
			},
		},
	}
end

local function cut_tabs(panel, side_a, side_b, position, options, vertical)
	-- draw cut lines and break tabs
	-- see http://blogs.mentor.com/tom-hausherr/blog/2011/06/23/pcb-design-perfection-starts-in-the-cad-library-part-19/
	
	local mill,drill
	if vertical then
		function mill(image, aperture, w, z1, z2)
			drawing.draw_path(image, aperture, z1, w, z2, w)
		end
		function drill(image, aperture, w, z)
			drawing.draw_path(image, aperture, z, w)
		end
	else
		function mill(image, aperture, w, z1, z2)
			drawing.draw_path(image, aperture, w, z1, w, z2)
		end
		function drill(image, aperture, w, z)
			drawing.draw_path(image, aperture, w, z)
		end
	end
	
	-- prepare routing and tab-separation drills
	-- :FIXME: for some reason the diameter needs to be scaled here, this is wrong
	local spacer = drawing.circle_aperture(options.spacing / 25.4 / 1e9)
	local breaker = drawing.circle_aperture(options.break_hole_diameter / 25.4 / 1e9)
	
	assert(#side_b % 2 == 0)
	assert(#side_a % 2 == 0)
	
	-- remember the cut total dimension
	local from = math.min(side_a[1], side_b[1]) - options.spacing / 2
	local to = math.max(side_a[#side_a], side_b[#side_b]) + options.spacing / 2
	
	-- remove A segments too short for a tab
	local side_a2 = {}
	for a=1,#side_a,2 do
		local on = side_a[a]
		local off = side_a[a+1]
		if off - on >= options.break_tab_width + options.spacing then
			table.insert(side_a2, on)
			table.insert(side_a2, off)
		end
	end
	
	-- remove B segments too short for a tab
	local side_b2 = {}
	for b=1,#side_b,2 do
		local on = side_b[b]
		local off = side_b[b+1]
		if off - on >= options.break_tab_width + options.spacing then
			table.insert(side_b2, on)
			table.insert(side_b2, off)
		end
	end
	
	-- merge sides into segments where we can put tabs between boards
	local side = {}
	local a,b = 1,1
	while a < #side_a and b < #side_b do
		local a0,a1 = side_a[a],side_a[a+1]
		local b0,b1 = side_b[b],side_b[b+1]
		local c0 = math.max(a0, b0)
		local c1 = math.min(a1, b1)
		if c1 - c0 >= options.break_tab_width + options.spacing then
			table.insert(side, c0)
			table.insert(side, c1)
		end
		if a1 < b1 then
			a = a + 2
		else
			b = b + 2
		end
	end
	
	-- we may not have anywhere to put tabs
	if #side == 0 then
		-- nowhere to put tabs, just cut (assume outer parts will connect the two subpanels)
		local z1 = from
		local z4 = to
		local w = position
		mill(panel.images.milling, spacer, w, z1, z4)
		return
	end
	
	-- prepare cut
	local w = position
	
	-- cut from edge to first tab-able segment
	if from < side[1] then
		mill(panel.images.milling, spacer, w, from, side[1])
	end
	
	-- iterate over merged side
	for i=1,#side-1 do
		-- ends of this segment
		local c0 = side[i]
		local c1 = side[i+1]
		-- tabs in odd segments
		if i % 2 == 1 then
			-- count how many tabs we can fit
			local n = math.ceil(((c1 - c0) - (options.break_tab_width + options.spacing)) / options.tab_interval)
			for i=0,n-1 do
				-- determine tab position
				local c = (c0 + c1) / 2 + (i - (n-1) / 2) * options.tab_interval
				-- ends of the partial segment around this one tab
				local c0 = math.max(c0, c - options.tab_interval / 2)
				local c1 = math.min(c1, c + options.tab_interval / 2)
				-- ends of the two cuts on either side of the tab
				local z1 = c0
				local z2 = c - (options.break_tab_width + options.spacing) / 2
				local z3 = c + (options.break_tab_width + options.spacing) / 2
				local z4 = c1
				-- a half-line before the tab and a half-line after
				mill(panel.images.milling, spacer, w, z1, z2)
				mill(panel.images.milling, spacer, w, z3, z4)
				-- small lines on the edge of the tab to ease breaking
				mill(panel.images.top_soldermask, breaker, w - options.spacing / 2, z2, z3)
				mill(panel.images.top_soldermask, breaker, w + options.spacing / 2, z2, z3)
				mill(panel.images.bottom_soldermask, breaker, w - options.spacing / 2, z2, z3)
				mill(panel.images.bottom_soldermask, breaker, w + options.spacing / 2, z2, z3)
				-- drill holes to make the tabs easy to break
				local drill_count = math.floor(options.break_tab_width / options.break_hole_diameter / 2)
				for i=0,drill_count-1 do
					local z = (i - (drill_count-1) / 2) * options.break_hole_diameter * 2
					drill(panel.images.milling, breaker, w - options.spacing / 2, c + z)
					drill(panel.images.milling, breaker, w + options.spacing / 2, c + z)
				end
			end
		else
			-- just bridge the gap
			mill(panel.images.milling, spacer, w, c0, c1)
		end
	end
	
	-- cut from last tab-able segment to the edge
	if side[#side] < to then
		mill(panel.images.milling, spacer, w, side[#side], to)
	end
	
	-- :TODO: route corners
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
	region.recompute_path_extents(merged.outline.path)
	
	for i,point in ipairs(merged.outline.path) do
		if i > 1 then
			if not point.interpolation then
				merged.outline.path[i] = {x=point.x, y=point.y, interpolation='linear'}
			end
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
	if not options.tab_interval then
		options.tab_interval = 77*mm
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
