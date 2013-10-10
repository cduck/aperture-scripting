local _M = {}

local math = require 'math'
local table = require 'table'

local region = require 'boards.region'
local drawing = require 'boards.drawing'
local templates = require 'boards.templates'
local manipulation = require 'boards.manipulation'

------------------------------------------------------------------------------

local function offset_side(side, dz)
	local copy = {}
	for i,z in ipairs(side) do
		copy[i] = z + dz
	end
	return copy
end

local function offset_panel(panel, dx, dy)
	local copy = manipulation.offset_board(panel, dx, dy)
	copy.left = offset_side(panel.left, dy)
	copy.right = offset_side(panel.right, dy)
	copy.bottom = offset_side(panel.bottom, dx)
	copy.top = offset_side(panel.top, dx)
	return copy
end

------------------------------------------------------------------------------

local function copy_side(side)
	return offset_side(side, 0)
end

------------------------------------------------------------------------------

local function merge_sides(side_a, side_b)
	local merged = {}
	for _,z in ipairs(side_a) do
		table.insert(merged, z)
	end
	for _,z in ipairs(side_b) do
		table.insert(merged, z)
	end
	return merged
end

local function merge_panels(panel_a, panel_b, vertical)
	local merged = manipulation.merge_boards(panel_a, panel_b)
	if vertical then
		merged.left = merge_sides(panel_a.left, panel_b.left)
		merged.right = merge_sides(panel_a.right, panel_b.right)
		merged.bottom = copy_side(panel_a.bottom)
		merged.top = copy_side(panel_b.top)
	else
		merged.left = copy_side(panel_a.left)
		merged.right = copy_side(panel_b.right)
		merged.bottom = merge_sides(panel_a.bottom, panel_b.bottom)
		merged.top = merge_sides(panel_a.top, panel_b.top)
	end
	return merged
end

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
		extents = region{
			left = 0, right = width,
			bottom = 0, top = height,
		},
	}
end

local function board_to_panel(board)
	local panel = manipulation.copy_board(board)
	panel.left = { board.extents.bottom, board.extents.top }
	panel.right = { board.extents.bottom, board.extents.top }
	panel.bottom = { board.extents.left, board.extents.right }
	panel.top = { board.extents.left, board.extents.right }
	-- panels need milling and drill images
	if not panel.images.milling then
		panel.images.milling = empty_image()
		panel.extensions.milling = 'gml'
	end
	if not panel.images.drill then
		panel.images.drill = empty_image()
		panel.extensions.drill = 'drd'
	end
	return panel
end

local function cut_tabs(panel, side_a, side_b, position, options, vertical)
	-- prepare routing and tab-separation drills
	-- :FIXME: for some reason the diameter needs to be scaled here, this is wrong
	local mill = { shape = 'circle', parameters = { options.spacing / 25.4 / 1e9 } }
	local drill = { shape = 'circle', parameters = { options.break_hole_diameter / 25.4 / 1e9 } }
	
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
			else
				drawing.draw_path(panel.images.milling, mill, w, z1, w, z2)
				drawing.draw_path(panel.images.milling, mill, w, z3, w, z4)
			end
			-- drill holes to make the tabs easy to break
			local drill_count = math.floor(options.break_tab_width / options.break_hole_diameter / 2)
			local min
			for i=0,drill_count-1 do
				local z = (i - (drill_count-1) / 2) * options.break_hole_diameter * 2
				if vertical then
					drawing.draw_path(panel.images.drill, drill, c + z, w - options.spacing / 2)
					drawing.draw_path(panel.images.drill, drill, c + z, w + options.spacing / 2)
				else
					drawing.draw_path(panel.images.drill, drill, w - options.spacing / 2, c + z)
					drawing.draw_path(panel.images.drill, drill, w + options.spacing / 2, c + z)
				end
			end
		end
		if a1 < b1 then
			a = a + 2
		else
			b = b + 2
		end
	end
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
		return board_to_panel(layout)
	end
	
	-- panelize subpanels
	assert(#layout >= 1)
	local subpanels = {}
	local had_outline = false
	for i=1,#layout do
		-- panelize sublayout
		local child = _M.panelize(layout[i], options, not vertical)
		subpanels[i] = child
		-- discard the outline
		if child.images.outline then
		--	child.images.outline = nil
			had_outline = true
		end
	end
	
	-- assemble the panel
	local left,bottom = 0,0
	local panel
	for _,subpanel in ipairs(subpanels) do
		local dx = left - subpanel.extents.left
		local dy = bottom - subpanel.extents.bottom
		if not panel then
			panel = offset_panel(subpanel, dx, dy)
		else
			local neighbour = offset_panel(subpanel, dx, dy)
			-- draw cut lines and break tabs
			-- see http://blogs.mentor.com/tom-hausherr/blog/2011/06/23/pcb-design-perfection-starts-in-the-cad-library-part-19/
			if vertical then
				cut_tabs(panel, panel.top, neighbour.bottom, bottom - options.spacing / 2, options, vertical)
			else
				cut_tabs(panel, panel.right, neighbour.left, left - options.spacing / 2, options, vertical)
			end
			panel = merge_panels(panel, neighbour, vertical)
		end
		if vertical then
			bottom = panel.extents.top + options.spacing
		else
			left = panel.extents.right + options.spacing
		end
	end
	
	-- regenerate an outline
	local outline
	if had_outline then
		outline = manipulation.copy_image(panel.images.milling)
		outline.layers = {{polarity = 'dark'}}
		panel.images.outline = outline
	else
		-- if we had no separate outline image, assume it's in the milling image
		outline = panel.images.milling
	end
	drawing.draw_path(outline, { unit = outline.unit, shape = 'circle', parameters = { 0 } },
		panel.extents.left, panel.extents.bottom,
		panel.extents.right, panel.extents.bottom,
		panel.extents.right, panel.extents.top,
		panel.extents.left, panel.extents.top,
		panel.extents.left, panel.extents.bottom)
	
	return panel
end

------------------------------------------------------------------------------

return _M
