--- This module contains several functions that will let you create panels, ie. assemblies of several small boards in larger 2D structures.
local _M = {}

local math = require 'math'
local table = require 'table'

local region = require 'boards.region'
local drawing = require 'boards.drawing'
local extents = require 'boards.extents'
local templates = require 'boards.templates'
local manipulation = require 'boards.manipulation'

------------------------------------------------------------------------------

local function empty_image()
	return {
		format = { integer = 2, decimal = 4, zeroes = 'L' },
		unit = 'in',
		layers = { { polarity = 'dark' } },
	}
end

--- Create an empty image, with a single empty dark layer, a default saved unit of `'in'`, and a number format specifying 2 integer digits, 4 decimal digits and missing leading zeroes.
function _M.empty_image()
	return empty_image()
end

--- Create an empty board, without any image. If *width* and *height* are specified, a simple rectangle outline of that size is created, with the bottom-left corner aligned on the origin.
function _M.empty_board(width, height)
	return {
		unit = 'pm',
		template = templates.default,
		images = {},
		extensions = {},
		formats = {},
		outline = width and height and {
			apertures = {},
			path = {
				{ x = 0, y = 0 },
				{ x = width, y = 0, interpolation = 'linear' },
				{ x = width, y = height, interpolation = 'linear' },
				{ x = 0, y = height, interpolation = 'linear' },
				{ x = 0, y = 0, interpolation = 'linear' },
			},
		},
	}
end

local function generate_tabs(side_a, side_b, options)
	assert(#side_b % 2 == 0)
	assert(#side_a % 2 == 0)
	
	-- remove A segments too short for a tab
	local side_a2 = {}
	for a=1,#side_a,2 do
		local on = side_a[a]
		local off = side_a[a+1]
		if off - on >= options.break_tab_width + options.routing_tool_diameter then
			table.insert(side_a2, on)
			table.insert(side_a2, off)
		end
	end
	side_a = side_a2
	
	-- remove B segments too short for a tab
	local side_b2 = {}
	for b=1,#side_b,2 do
		local on = side_b[b]
		local off = side_b[b+1]
		if off - on >= options.break_tab_width + options.routing_tool_diameter then
			table.insert(side_b2, on)
			table.insert(side_b2, off)
		end
	end
	side_b = side_b2
	
	-- merge sides into segments where we can put tabs between boards
	local tabs = {} -- tab centers
	local a,b = 1,1
	while a < #side_a and b < #side_b do
		local a0,a1 = side_a[a],side_a[a+1]
		local b0,b1 = side_b[b],side_b[b+1]
		local c0 = math.max(a0, b0)
		local c1 = math.min(a1, b1)
		if c1 - c0 >= options.break_tab_width + options.routing_tool_diameter then
			-- count how many tabs we can fit
			local n = math.ceil(((c1 - c0) - (options.break_tab_width + options.spacing)) / options.tab_interval)
			for i=0,n-1 do
				-- determine tab position
				local c = (c0 + c1) / 2 + (i - (n-1) / 2) * options.tab_interval
				table.insert(tabs, c)
			end
		end
		if a1 < b1 then
			a = a + 2
		else
			b = b + 2
		end
	end
	
	return tabs
end

local function route_tabs(panel, from, to, tabs, position, options, vertical)
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
	
	-- prepare the milling image
	if not panel.images.milling then
		panel.images.milling = empty_image()
	end
	if #panel.images.milling.layers==0 or panel.images.milling.layers[#panel.images.milling.layers].polarity=='clear' then
		table.insert(panel.images.milling.layers, { polarity = 'dark' })
	end
	
	-- prepare routing and tab-separation drills
	local spacer = drawing.circle_aperture(options.spacing)
	local breaker = drawing.circle_aperture(options.break_hole_diameter)
	
	-- we may not have anywhere to put tabs
	if #tabs == 0 then
		-- nowhere to put tabs, just cut (assume outer parts will connect the two subpanels)
		local a = from
		local b = to
		local w = position
		mill(panel.images.milling, spacer, w, a, b)
		return
	end
	
	-- prepare cut
	local w = position
	
	local route_gap = options.break_tab_width + options.routing_tool_diameter
	
	-- cut from edge to first tab-able segment
	if from < tabs[1] - route_gap / 2 then
		mill(panel.images.milling, spacer, w, from, tabs[1] - route_gap / 2)
	end
	
	-- determine the distance between the routing line center and the mouse bites
	local break_line_distance = options.spacing / 2 -- default aligns on board edge
	do
		local break_line_offset = options.break_line_offset
		if break_line_offset==nil or break_line_offset=='none' or break_line_offset=='edge' then
			-- keep on board edge
		elseif break_line_offset=='inside' then
			break_line_distance = break_line_distance + options.break_hole_diameter / 2
		elseif break_line_offset=='outside' then
			break_line_distance = break_line_distance - options.break_hole_diameter / 2
		elseif type(break_line_offset)=='number' then
			break_line_distance = break_line_distance - break_line_offset
		else
			error("unsuppoerted break hole offset option with value "..tostring(break_line_offset).." (a "..type(break_line_offset)..")")
		end
	end
	
	-- route between tabs
	for i=1,#tabs-1 do
		local c0,c1 = tabs[i],tabs[i+1]
		local a = c0 + route_gap / 2
		local b = c1 - route_gap / 2
		mill(panel.images.milling, spacer, w, a, b)
	end
	
	-- make tabs easy to break
	for _,c in ipairs(tabs) do
		local a = c - route_gap / 2
		local b = c + route_gap / 2
		-- small lines on soldermask
		if options.break_lines_on_soldermask and panel.images.top_soldermask then
			mill(panel.images.top_soldermask, breaker, w - break_line_distance, a, b)
			if break_line_distance ~= 0 then
				mill(panel.images.top_soldermask, breaker, w + break_line_distance, a, b)
			end
		end
		if options.break_lines_on_soldermask and panel.images.bottom_soldermask then
			mill(panel.images.bottom_soldermask, breaker, w - break_line_distance, a, b)
			if break_line_distance ~= 0 then
				mill(panel.images.bottom_soldermask, breaker, w + break_line_distance, a, b)
			end
		end
		-- drill "mouse bites" holes
		-- :TODO: drill all of route_gap instead of just options.break_tab_width
		local drill_count = math.floor(options.break_tab_width / options.break_hole_diameter / 2)
		for i=0,drill_count-1 do
			local z = (i - (drill_count-1) / 2) * options.break_hole_diameter * 2
			drill(panel.images.milling, breaker, w - break_line_distance, c + z)
			if break_line_distance ~= 0 then
				drill(panel.images.milling, breaker, w + break_line_distance, c + z)
			end
		end
	end
	
	-- cut from last tab-able segment to the edge
	if tabs[#tabs] + route_gap / 2 < to then
		mill(panel.images.milling, spacer, w, tabs[#tabs] + route_gap / 2, to)
	end
end

local function outline_tabs(panel, from, to, tabs, position, options, vertical)
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
	
	-- prepare the milling image
	if not panel.images.milling then
		panel.images.milling = empty_image()
	end
	if #panel.images.milling.layers==0 or panel.images.milling.layers[#panel.images.milling.layers].polarity=='clear' then
		table.insert(panel.images.milling.layers, { polarity = 'dark' })
	end
	
	-- prepare routing and tab-separation drills
	local breaker = drawing.circle_aperture(options.break_hole_diameter)
	
	-- prepare cut
	local w = position
	
	local route_gap = options.break_tab_width + options.routing_tool_diameter
	
	-- determine the distance between the routing line center and the mouse bites
	local break_line_distance = options.spacing / 2 -- default aligns on board edge
	do
		local break_line_offset = options.break_line_offset
		if break_line_offset==nil or break_line_offset=='none' or break_line_offset=='edge' then
			-- keep on board edge
		elseif break_line_offset=='inside' then
			break_line_distance = break_line_distance + options.break_hole_diameter / 2
		elseif break_line_offset=='outside' then
			break_line_distance = break_line_distance - options.break_hole_diameter / 2
		elseif type(break_line_offset)=='number' then
			break_line_distance = break_line_distance - break_line_offset
		else
			error("unsuppoerted break hole offset option with value "..tostring(break_line_offset).." (a "..type(break_line_offset)..")")
		end
	end
	
	-- make tabs easy to break
	for _,c in ipairs(tabs) do
		local a = c - route_gap / 2
		local b = c + route_gap / 2
		-- small lines on soldermask
		if options.break_lines_on_soldermask and panel.images.top_soldermask then
			mill(panel.images.top_soldermask, breaker, w - break_line_distance, a, b)
			if break_line_distance ~= 0 then
				mill(panel.images.top_soldermask, breaker, w + break_line_distance, a, b)
			end
		end
		if options.break_lines_on_soldermask and panel.images.bottom_soldermask then
			mill(panel.images.bottom_soldermask, breaker, w - break_line_distance, a, b)
			if break_line_distance ~= 0 then
				mill(panel.images.bottom_soldermask, breaker, w + break_line_distance, a, b)
			end
		end
		-- drill "mouse bites" holes
		-- :TODO: drill all of route_gap instead of just options.break_tab_width
		local drill_count = math.floor(options.break_tab_width / options.break_hole_diameter / 2)
		for i=0,drill_count-1 do
			local z = (i - (drill_count-1) / 2) * options.break_hole_diameter * 2
			drill(panel.images.milling, breaker, w - break_line_distance, c + z)
			if break_line_distance ~= 0 then
				drill(panel.images.milling, breaker, w + break_line_distance, c + z)
			end
		end
	end
end

local function route_corner(panel, path, from, to, options)
	local closed = path[1].x == path[#path].x and path[1].y == path[#path].y
	if closed and from == #path then from = 1 end
	if closed and to == #path then from = 1 end
	if from == to then
		-- :TODO: should we route around the point?
		return
	end
	
	if not closed then assert(from <= to) end
	
	-- prepare the milling image
	if not panel.images.milling then
		panel.images.milling = empty_image()
	end
	
	-- prepare routing
	local tool = drawing.circle_aperture(options.routing_tool_diameter)
	
	-- the routing path is the path offset to the right by a tool radius
	local offset = options.routing_tool_diameter / 2
	
	-- extract the part of path we want to offset
	local corner = {}
	table.insert(corner, { x = path[from].x, y = path[from].y })
	for i in coroutine.wrap(function()
		if to < from then
			for i=from+1,#path do
				coroutine.yield(i)
			end
			for i=2,to do
				coroutine.yield(i)
			end
		else
			for i=from+1,to do
				coroutine.yield(i)
			end
		end
	end) do
		table.insert(corner, path[i])
	end
	
	-- offset it
	local route = manipulation.offset_path_normal(corner, -offset)
	route.aperture = tool
	
	-- add it to the milling image
	local layers = panel.images.milling.layers
	table.insert(layers[#layers], route)
end

local function find_sides(outline)
	local path = outline.path
	local sides = {
		bottom = {},
		right = {},
		top = {},
		left = {},
	}
	
	-- find extents
	local extents = extents.compute_outline_extents(outline)
	local bottom,right,top,left = extents.bottom,extents.right,extents.top,extents.left
	
	-- find all linear segments on the extents
	for i=2,#path do
		local a,b = i-1,i
		if path[b].interpolation=='linear' then
			local x0,y0,x1,y1 = path[a].x,path[a].y,path[b].x,path[b].y
			if y0==bottom and y1==bottom then
				table.insert(sides.bottom, {a, b})
			elseif x0==right and x1==right then
				table.insert(sides.right, {a, b})
			elseif y0==top and y1==top then
				table.insert(sides.top, {a, b})
			elseif x0==left and x1==left then
				table.insert(sides.left, {a, b})
			end
		end
	end
	
	return sides
end

local function find_sides_stroke(outline)
	local sides = find_sides(outline)
	
	local sides2 = {}
	for k,side in pairs(sides) do
		local side2 = {}
		sides2[k] = side2
		-- make sure there's only one edge per side
		for i=1,#side-1 do
			assert(side[i][2] == side[i+1][1], "concave board outlines are not supported in 'stroke' routing mode")
		end
		-- skip every even segment
		assert(#side % 2 == 1, "in 'stroke' routing mode sides should have an odd number of segments")
		for i=1,#side,2 do
			table.insert(side2, {side[i][1], side[i][2]})
		end
	end
	
	assert(sides2.bottom[1][1]==1)
	return sides2
end

local function find_sides_outline(outline)
	local sides = find_sides(outline)
	
	local sides2 = {}
	for k,side in pairs(sides) do
		local side2 = {}
		sides2[k] = side2
		-- merge consecutive segments
		local a = side[1][1]
		for i=2,#side do
			if side[i][1] ~= side[i-1][2] then
				local b = side[i-1][2]
				table.insert(side2, {a, b})
				a = side[i][1]
			end
		end
		local b = side[#side][2]
		table.insert(side2, {a, b})
	end
	
	return sides2
end

local function build_edge(side)
	local edge = {}
	table.insert(edge, side[1][1])
	local size = 1
	for i=2,#side do
		if side[i][1] == side[i-1][2] then
			size = size + 1
			table.insert(edge, side[i][1])
		else
			-- bridge the gap
			table.insert(edge, side[i-1][2])
			table.insert(edge, side[i][1])
			-- each side side should have an odd size
			assert(size / 2 % 1 ~= 0)
			size = 1
		end
	end
	table.insert(edge, side[#side][2])
	return edge
end

local function reverse_table(t)
	local r = {}
	for i=#t,1,-1 do
		table.insert(r, t[i])
	end
	return r
end

local function merge_panels(panel_a, panel_b, options, vertical)
	-- get subpanel outlines
	local outline_a = panel_a.outline
	local outline_b = panel_b.outline
	
	-- check subpanel dimensions match
	local outline_a_extents = extents.compute_outline_extents(outline_a)
	local outline_b_extents = extents.compute_outline_extents(outline_b)
	local dimensions_match
	if vertical then
		dimensions_match = outline_a_extents.left == outline_b_extents.left and outline_a_extents.right == outline_b_extents.right
	else
		dimensions_match = outline_a_extents.bottom == outline_b_extents.bottom and outline_a_extents.top == outline_b_extents.top
	end
	assert(dimensions_match, "subpanel dimensions do no match")
	
	-- merge the board content (not the outlines)
	local merged = manipulation.merge_boards(panel_a, panel_b)
	
	-- create a new outline
	merged.outline = {
		apertures = {},
		path = {},
	}
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
	
	-- generate new outline and routing/drilling data
	if options.routing_mode == 'stroke' then
		-- find edges to put tabs on
		local sides_a = find_sides_stroke(outline_a)
		local sides_b = find_sides_stroke(outline_b)
		
		-- determine intervals were we can have tabs
		local positions_a,positions_b = {},{}
		if vertical then
			for _,edge in ipairs(sides_a.top) do
				table.insert(positions_a, 1, outline_a.path[edge[1]].x)
				table.insert(positions_a, 1, outline_a.path[edge[2]].x)
			end
			for _,edge in ipairs(sides_b.bottom) do
				table.insert(positions_b, outline_b.path[edge[1]].x)
				table.insert(positions_b, outline_b.path[edge[2]].x)
			end
		else
			for _,edge in ipairs(sides_a.right) do
				table.insert(positions_a, outline_a.path[edge[1]].y)
				table.insert(positions_a, outline_a.path[edge[2]].y)
			end
			for _,edge in ipairs(sides_b.left) do
				table.insert(positions_b, 1, outline_b.path[edge[1]].y)
				table.insert(positions_b, 1, outline_b.path[edge[2]].y)
			end
		end
		
		-- place the tabs
		local tabs = generate_tabs(positions_a, positions_b, options)
		local position
		if vertical then
			position = outline_a_extents.top + options.spacing / 2
		else
			position = outline_a_extents.right + options.spacing / 2
		end
		local from = math.min(positions_a[1], positions_b[1])
		local to = math.max(positions_a[#positions_a], positions_b[#positions_b])
		
		-- route the main slots
		route_tabs(merged, from, to, tabs, position, options, vertical)
		
		-- route corners
		local corners = {}
		if vertical then
			table.insert(corners, {outline=outline_a, from=sides_a.right[#sides_a.right][2], to=sides_a.top[1][1]})
			table.insert(corners, {outline=outline_a, from=sides_a.top[#sides_a.top][2], to=sides_a.left[1][1]})
			table.insert(corners, {outline=outline_b, from=sides_b.left[#sides_b.left][2], to=sides_b.bottom[1][1]})
			table.insert(corners, {outline=outline_b, from=sides_b.bottom[#sides_b.bottom][2], to=sides_b.right[1][1]})
		else
			table.insert(corners, {outline=outline_a, from=sides_a.bottom[#sides_a.bottom][2], to=sides_a.right[1][1]})
			table.insert(corners, {outline=outline_a, from=sides_a.right[#sides_a.right][2], to=sides_a.top[1][1]})
			table.insert(corners, {outline=outline_b, from=sides_b.top[#sides_b.top][2], to=sides_b.left[1][1]})
			table.insert(corners, {outline=outline_b, from=sides_b.left[#sides_b.left][2], to=sides_b.bottom[1][1]})
		end
		for _,corner in ipairs(corners) do
			route_corner(merged, corner.outline.path, corner.from, corner.to, options)
		end
		
		-- merge outlines
		if vertical then
			for i=1,sides_a.right[#sides_a.right][2] do
				table.insert(merged.outline.path, outline_a.path[i])
			end
			local pb = outline_b.path[sides_b.right[1][1]]
			table.insert(merged.outline.path, {interpolation='linear', x=pb.x, y=pb.y})
			for i=sides_b.right[1][1]+1,sides_b.left[#sides_b.left][2] do
				table.insert(merged.outline.path, outline_b.path[i])
			end
			local pa = outline_a.path[sides_a.left[1][1]]
			table.insert(merged.outline.path, {interpolation='linear', x=pa.x, y=pa.y})
			for i=sides_a.left[1][1]+1,#outline_a.path do
				table.insert(merged.outline.path, outline_a.path[i])
			end
		else
			for i=1,sides_a.bottom[#sides_a.bottom][2] do
				table.insert(merged.outline.path, outline_a.path[i])
			end
			local pb = outline_b.path[1]
			table.insert(merged.outline.path, {interpolation='linear', x=pb.x, y=pb.y})
			for i=2,sides_b.top[#sides_b.top][2] do
				table.insert(merged.outline.path, outline_b.path[i])
			end
			local pa = outline_a.path[sides_a.top[1][1]]
			table.insert(merged.outline.path, {interpolation='linear', x=pa.x, y=pa.y})
			for i=sides_a.top[1][1]+1,#outline_a.path do
				table.insert(merged.outline.path, outline_a.path[i])
			end
		end
	elseif options.routing_mode == 'outline' then
		-- find edges to put tabs on
		local sides_a = find_sides_outline(outline_a)
		local sides_b = find_sides_outline(outline_b)
		
		-- determine intervals were we can have tabs
		local positions_a,positions_b = {},{}
		if vertical then
			for _,edge in ipairs(sides_a.top) do
				table.insert(positions_a, 1, outline_a.path[edge[1]].x)
				table.insert(positions_a, 1, outline_a.path[edge[2]].x)
			end
			for _,edge in ipairs(sides_b.bottom) do
				table.insert(positions_b, outline_b.path[edge[1]].x)
				table.insert(positions_b, outline_b.path[edge[2]].x)
			end
		else
			for _,edge in ipairs(sides_a.right) do
				table.insert(positions_a, outline_a.path[edge[1]].y)
				table.insert(positions_a, outline_a.path[edge[2]].y)
			end
			for _,edge in ipairs(sides_b.left) do
				table.insert(positions_b, 1, outline_b.path[edge[1]].y)
				table.insert(positions_b, 1, outline_b.path[edge[2]].y)
			end
		end
		
		-- place the tabs
		local tabs = generate_tabs(positions_a, positions_b, options)
		local position
		if vertical then
			position = outline_a_extents.top + options.spacing / 2
		else
			position = outline_a_extents.right + options.spacing / 2
		end
		local sp = options.spacing / 2 -- half space
		local tr = options.routing_tool_diameter / 2 -- tool radius
		
		-- drill breaking tabs
		outline_tabs(merged, from, to, tabs, position, options, vertical)
		
		-- merge outlines, right up to the outer tabs
		if vertical then
			-- a bottom left to a top right
			for i=1,sides_a.top[1][1] do
				table.insert(merged.outline.path, outline_a.path[i])
			end
			-- right slot
			local tx = tabs[#tabs] + options.break_tab_width / 2
			local pa = outline_a.path[sides_a.top[1][1]]
			local pb = outline_b.path[sides_b.bottom[#sides_b.bottom][2]]
			table.insert(merged.outline.path, {interpolation='linear', x=tx + tr, y=pa.y})
			if tr ~= 0 then
				table.insert(merged.outline.path, {interpolation='circular', direction='clockwise', quadrant='single', cx=tx + tr, cy=pa.y + tr, x=tx, y=pa.y + tr})
			end
			if tr < sp then
				table.insert(merged.outline.path, {interpolation='linear', x=tx, y=pb.y - tr})
			end
			if tr ~= 0 then
				table.insert(merged.outline.path, {interpolation='circular', direction='clockwise', quadrant='single', cx=tx + tr, cy=pb.y - tr, x=tx + tr, y=pb.y})
			end
			table.insert(merged.outline.path, {interpolation='linear', x=pb.x, y=pb.y})
			-- b bottom right to b bottom left
			for i=sides_b.bottom[#sides_b.bottom][1]+1,#outline_b.path do
				table.insert(merged.outline.path, outline_b.path[i])
			end
			-- left slot
			local tx = tabs[1] - options.break_tab_width / 2
			local pb = outline_b.path[#outline_b.path]
			local pa = outline_a.path[sides_a.top[#sides_a.top][2]]
			table.insert(merged.outline.path, {interpolation='linear', x=tx - tr, y=pb.y})
			if tr ~= 0 then
				table.insert(merged.outline.path, {interpolation='circular', direction='clockwise', quadrant='single', cx=tx - tr, cy=pb.y - tr, x=tx, y=pb.y - tr})
			end
			if tr < sp then
				table.insert(merged.outline.path, {interpolation='linear', x=tx, y=pa.y + tr})
			end
			if tr ~= 0 then
				table.insert(merged.outline.path, {interpolation='circular', direction='clockwise', quadrant='single', cx=tx - tr, cy=pa.y + tr, x=tx - tr, y=pa.y})
			end
			table.insert(merged.outline.path, {interpolation='linear', x=pa.x, y=pa.y})
			-- a top left to a bottom left
			for i=sides_a.top[#sides_a.top][2]+1,#outline_a.path do
				table.insert(merged.outline.path, outline_a.path[i])
			end
		else
			-- a bottom left to a left bottom
			for i=1,sides_a.right[1][1] do
				table.insert(merged.outline.path, outline_a.path[i])
			end
			-- bottom slot
			local ty = tabs[1] - options.break_tab_width / 2
			local pa = outline_a.path[sides_a.right[1][1] ]
			local pb = outline_b.path[sides_b.left[#sides_b.left][2]]
			table.insert(merged.outline.path, {interpolation='linear', x=pa.x, y=ty - tr})
			if tr ~= 0 then
				table.insert(merged.outline.path, {interpolation='circular', direction='clockwise', quadrant='single', cx=pa.x + tr, cy=ty - tr, x=pa.x + tr, y=ty})
			end
			if tr < sp then
				table.insert(merged.outline.path, {interpolation='linear', x=pb.x - tr, y=ty})
			end
			if tr ~= 0 then
				table.insert(merged.outline.path, {interpolation='circular', direction='clockwise', quadrant='single', cx=pb.x - tr, cy=ty - tr, x=pb.x, y=ty - tr})
			end
			table.insert(merged.outline.path, {interpolation='linear', x=pb.x, y=pb.y})
			-- b left bottom to b bottom left
			for i=sides_b.left[#sides_b.left][2]+1,#outline_b.path do
				table.insert(merged.outline.path, outline_b.path[i])
			end
			-- b bottom left to b left top
			for i=2,sides_b.left[1][1] do
				table.insert(merged.outline.path, outline_b.path[i])
			end
			-- top slot
			local ty = tabs[#tabs] + options.break_tab_width / 2
			local pb = outline_b.path[sides_b.left[1][1]]
			local pa = outline_a.path[sides_a.right[#sides_a.right][2]]
			table.insert(merged.outline.path, {interpolation='linear', x=pb.x, y=ty + tr})
			if tr ~= 0 then
				table.insert(merged.outline.path, {interpolation='circular', direction='clockwise', quadrant='single', cx=pb.x - tr, cy=ty + tr, x=pb.x - tr, y=ty})
			end
			if tr < sp then
				table.insert(merged.outline.path, {interpolation='linear', x=pa.x + tr, y=ty})
			end
			if tr ~= 0 then
				table.insert(merged.outline.path, {interpolation='circular', direction='clockwise', quadrant='single', cx=pa.x + tr, cy=ty + tr, x=pa.x, y=ty + tr})
			end
			table.insert(merged.outline.path, {interpolation='linear', x=pa.x, y=pa.y})
			-- a right top to a bottom left
			for i=sides_a.right[#sides_a.right][2]+1,#outline_a.path do
				table.insert(merged.outline.path, outline_a.path[i])
			end
		end
		
		if #tabs >= 2 then
			-- aperture for edge cuts
			local cutout = drawing.circle_aperture(0)
			
			-- prepare the milling image
			if not merged.images.milling then
				merged.images.milling = empty_image()
			end
			if #merged.images.milling.layers==0 or merged.images.milling.layers[#merged.images.milling.layers].polarity=='clear' then
				table.insert(merged.images.milling.layers, { polarity = 'dark' })
			end
			
			for i=1,#tabs-1 do
				local z0 = tabs[i] + options.break_tab_width / 2
				local z1 = tabs[i+1] - options.break_tab_width / 2
				if vertical then
					-- find the old outline segments that fit between the tabs
					local a0,a1,b0,b1
					for _,segment in ipairs(sides_a.top) do
						local ax0 = outline_a.path[segment[1]].x
						local ax1 = outline_a.path[segment[2]].x
						if not a0 and z0 <= ax0 and ax0 <= z1 then
							a0 = segment[1]
						end
						if z0 <= ax1 and ax1 <= z1 then
							a1 = segment[2]
						end
					end
					for _,segment in ipairs(sides_b.bottom) do
						local bx0 = outline_b.path[segment[1]].x
						local bx1 = outline_b.path[segment[2]].x
						if z0 <= bx0 and bx0 <= z1 then
							b1 = segment[1]
						end
						if not b0 and z0 <= bx1 and bx1 <= z1 then
							b0 = segment[2]
						end
					end
					-- add an internal outline in the milling image
					local cut = { aperture = cutout }
					table.insert(cut, { x = z1 - tr, y = outline_a_extents.top })
					if a0 and a1 then
						for i=a1,a0 do
							table.insert(cut, outline_a.path[i])
						end
					end
					table.insert(cut, { interpolation = 'linear', x = z0 + tr, y = outline_a_extents.top })
					if tr ~= 0 then
						table.insert(cut, { interpolation = 'circular', direction = 'clockwise', quadrant = 'single', cx = z0 + tr, cy = outline_a_extents.top + tr, x = z0, y = outline_a_extents.top + tr })
					end
					if tr < sp then
						table.insert(cut, { interpolation = 'linear', x = z0, y = outline_b_extents.bottom - tr })
					end
					if tr ~= 0 then
						table.insert(cut, { interpolation = 'circular', direction = 'clockwise', quadrant = 'single', cx = z0 + tr, cy = outline_b_extents.bottom - tr, x = z0 + tr, y = outline_b_extents.bottom })
					end
					if b0 and b1 then
						for i=b0,b1 do
							table.insert(cut, outline_b.path[i])
						end
					end
					table.insert(cut, { interpolation = 'linear', x = z1 - tr, y = outline_b_extents.bottom })
					if tr ~= 0 then
						table.insert(cut, { interpolation = 'circular', direction = 'clockwise', quadrant = 'single', cx = z1 - tr, cy = outline_b_extents.bottom - tr, x = z1, y = outline_b_extents.bottom - tr })
					end
					if tr < sp then
						table.insert(cut, { interpolation = 'linear', x = z1, y = outline_a_extents.top + tr })
					end
					if tr ~= 0 then
						table.insert(cut, { interpolation = 'circular', direction = 'clockwise', quadrant = 'single', cx = z1 - tr, cy = outline_a_extents.top + tr, x = z1 - tr, y = outline_a_extents.top })
					end
					table.insert(merged.images.milling.layers[#merged.images.milling.layers], cut)
				else
					-- find the old outline segments that fit between the tabs
					local a0,a1,b0,b1
					for _,segment in ipairs(sides_a.right) do
						local ay0 = outline_a.path[segment[1]].y
						local ay1 = outline_a.path[segment[2]].y
						if z0 <= ay0 and ay0 <= z1 then
							a1 = segment[1]
						end
						if not a0 and z0 <= ay1 and ay1 <= z1 then
							a0 = segment[2]
						end
					end
					for _,segment in ipairs(sides_b.left) do
						local by0 = outline_b.path[segment[1]].y
						local by1 = outline_b.path[segment[2]].y
						if not b0 and z0 <= by0 and by0 <= z1 then
							b0 = segment[1]
						end
						if z0 <= by1 and by1 <= z1 then
							b1 = segment[2]
						end
					end
					-- add an internal outline in the milling image
					local cut = { aperture = cutout }
					table.insert(cut, { x = outline_a.path[a0].x, y = z0 + tr })
					for i=a0,a1 do
						table.insert(cut, outline_a.path[i])
					end
					table.insert(cut, { interpolation = 'linear', x = outline_a.path[a1].x, y = z1 - tr })
					if tr ~= 0 then
						table.insert(cut, { interpolation = 'circular', direction = 'clockwise', quadrant = 'single', cx = outline_a.path[a1].x + tr, cy = z1 - tr, x = outline_a.path[a1].x + tr, y = z1 })
					end
					if tr < sp then
						table.insert(cut, { interpolation = 'linear', x = outline_b.path[b0].x - tr, y = z1 })
					end
					if tr ~= 0 then
						table.insert(cut, { interpolation = 'circular', direction = 'clockwise', quadrant = 'single', cx = outline_b.path[b0].x - tr, cy = z1 - tr, x = outline_b.path[b0].x, y = z1 - tr })
					end
					for i=b1,b0 do
						table.insert(cut, outline_b.path[i])
					end
					table.insert(cut, { interpolation = 'linear', x = outline_b.path[b1].x, y = z0 + tr })
					if tr ~= 0 then
						table.insert(cut, { interpolation = 'circular', direction = 'clockwise', quadrant = 'single', cx = outline_b.path[b1].x - tr, cy = z0 + tr, x = outline_b.path[b1].x - tr, y = z0 })
					end
					if tr < sp then
						table.insert(cut, { interpolation = 'linear', x = outline_a.path[a1].x + tr, y = z0 })
					end
					if tr ~= 0 then
						table.insert(cut, { interpolation = 'circular', direction = 'clockwise', quadrant = 'single', cx = outline_a.path[a1].x + tr, cy = z0 + tr, x = outline_a.path[a1].x, y = z0 + tr })
					end
					table.insert(merged.images.milling.layers[#merged.images.milling.layers], cut)
				end
			end
		end
	else
		error("unsupported routing mode "..tostring(options.routing_mode))
	end
	
	return merged
end

--- Panelize the board specified in *layout*. The *layout* can have several levels, alternating horizontal (from left to right) and vertical (from bottom to top) directions. The direction of the root layer is vertical if *vertical* is true, horizontal otherwise.
--- 
--- *options* is a table which can be empty, or have any or all of the following options:
--- 
---   - `spacing` determines the gap between boards (default is 2 mm)
---   - `routing_tool_diameter` is the minimum diameter of the routing tool (default is `spacing`)
---   - `break_hole_diameter` is the diameter of breaking holes (mouse bites, default is 0.5 mm)
---   - `break_tab_width` is the width of the breaking tabs (default is 5 mm)
---   - `tab_interval` is the minimum interval between two breaking tabs on long edges (default is 77 mm)
---   - `break_lines_on_soldermask` determines whether to draw a break line on the soldermasks to ease panel breaking (default is true)
---   - `break_line_offset` is the position of the breaking holes relative to the board edges; it can have the following values:
---     - nil, `'none'` or `'edge'` will put the hole centers on the board edge (this is the default)
---     - `'inside'` will move the holes completely inside the board outline (offset by one hole radius); this is recommended if you want a clean board outline without the need to file the edge after depanelization
---     - `'outside'` will move the holes completely outside the board (offset by one hole radius); this is recommended if you want to file the board edge to have it look like it wasn't panelized
---     - a number value can specify any other offset; positive values extend outside the board, negative values inside the board
---   - `routing_mode` specifies how slots between boards are drawn; it can have the following values:
---     - `'stroke'` will use strokes and flashes on the milling layer, with the routing tool or drill diameter as aperture (this is the default)
---     - `'outline'` will draw zero-width outlines on the milling layer; this supports more complex outlines
--- 
--- Note that default values are internally specified in picometers. If your board use a different unit you'll need to override all options.
function _M.panelize(layout, options, vertical)
	local mm = 1e9
	if not options.spacing then
		options.spacing = 2*mm
	end
	if not options.routing_tool_diameter then
		options.routing_tool_diameter = options.spacing
	end
	assert(options.routing_tool_diameter <= options.spacing, "option 'routing_tool_diameter' must be smaller than option 'spacing'")
	if not options.routing_mode then
		options.routing_mode = 'stroke'
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
	if options.break_lines_on_soldermask==nil then
		options.break_lines_on_soldermask = true
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
		local subpanel_extents = extents.compute_outline_extents(subpanel.outline)
		local dx = left - subpanel_extents.left
		local dy = bottom - subpanel_extents.bottom
		if not panel then
			panel = manipulation.offset_board(subpanel, dx, dy)
		else
			local neighbour = manipulation.offset_board(subpanel, dx, dy)
			panel = merge_panels(panel, neighbour, options, vertical)
		end
		if vertical then
			bottom = bottom + subpanel_extents.height + options.spacing
		else
			left = left + subpanel_extents.width + options.spacing
		end
	end
	
	return panel
end

------------------------------------------------------------------------------

return _M
