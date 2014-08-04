local _M = {}
local _NAME = ... or 'test'

local math = require 'math'
local table = require 'table'
local region = require 'boards.region'

------------------------------------------------------------------------------

local function copy_point(point)
	return {
		x = point.x,
		y = point.y,
		cx = point.cx,
		cy = point.cy,
		x1 = point.x1,
		y1 = point.y1,
		x2 = point.x2,
		y2 = point.y2,
		interpolation = point.interpolation,
		direction = point.direction,
		quadrant = point.quadrant,
	}
end

local reverse_direction = {
	clockwise = 'counterclockwise',
	counterclockwise = 'clockwise',
}

local function reverse_path(path)
	local reverse = {}
	-- start with the end point
	reverse[1] = {x=path[#path].x, y=path[#path].y}
	-- reverse each segment
	for i=#path-1,1,-1 do
		local point = path[i]
		local params = path[i+1] -- interpolation params are in the previous point
		local interpolation = params.interpolation
		if interpolation=='linear' then
			table.insert(reverse, {x=point.x, y=point.y, interpolation='linear'})
		elseif interpolation=='circular' then
			local direction = assert(reverse_direction[params.direction], "unsupported circular direction "..tostring(params.direction))
			table.insert(reverse, {x=point.x, y=point.y, cx=params.cx, cy=params.cy, interpolation='circular', direction=direction, quadrant=params.quadrant})
		elseif interpolation=='quadratic' then
			-- single control point stays the same
			table.insert(reverse, {x=point.x, y=point.y, x1=params.x1, y1=params.y1, interpolation='quadratic'})
		elseif interpolation=='cubic' then
			-- swap control points
			table.insert(reverse, {x=point.x, y=point.y, x1=params.x2, y1=params.y2, x2=params.x1, y2=params.y1, interpolation='cubic'})
		else
			error("unsupported interpolation "..tostring(interpolation))
		end
	end
	return reverse
end

local function append_path(parent, child)
	local nparent = #parent
	--[[
	-- :FIXME: this code was somehow preserving corners but should check interpolation mode
	if (child[1].x==child[2].x or child[1].y==child[2].y) and parent[nparent].x~=parent[nparent-1].x and parent[nparent].y~=parent[nparent-1].y then
		parent[nparent] = copy_point(child[1])
		parent[nparent].interpolation = 'linear'
	end
	--]]
	if child[1].x~=parent[#parent].x or child[1].y~=parent[#parent].y then
		-- insert a small linear segment
		nparent = nparent + 1
		parent[nparent] = {x=child[1].x, y=child[1].y, interpolation='linear'}
	end
	for i=2,#child do
		parent[nparent+i-1] = copy_point(child[i])
	end
end

local function prepend_path(parent, child)
	local nparent = #parent
	local nchild = #child
	local keep_first = child[#child].x~=parent[1].x or child[#child].y~=parent[1].y
	local a,b,offset
	if keep_first then
		-- insert a small linear segment
		parent[1] = {x=parent[1].x, y=parent[1].y, interpolation='linear'}
		a,b,offset = 1,nparent,nchild
	else
		a,b,offset = 2,nparent,nchild-1 -- this will drop parent[1]
	end
	for i=b,a,-1 do
		parent[i+offset] = copy_point(parent[i])
	end
	--[[
	-- :FIXME: this code was somehow preserving corners but should check interpolation mode
	if (child[nchild].x==child[nchild-1].x or child[nchild].y==child[nchild-1].y) and parent[nchild].x~=parent[nchild+1].x and parent[nchild].y~=parent[nchild+1].y then
		parent[nchild] = copy_point(child[nchild])
	end
	--]]
	for i=1,nchild do
		parent[i] = copy_point(child[i])
	end
end

local function point_to_node(point, epsilon)
	assert(epsilon ~= 0)
	local x = math.floor(point.x / epsilon + 0.5)
	local y = math.floor(point.y / epsilon + 0.5)
	return x..':'..y
end

local function close_path(path, epsilon)
	assert(#path >= 3)
	assert(point_to_node(path[1], epsilon) == point_to_node(path[#path], epsilon))
	assert(path[1].interpolation == nil)
	if path[#path].x==path[1].x and path[#path].y==path[1].y then
		-- path is already closed
		return
	end
	local first_segment_is_linear = path[2].interpolation == 'linear'
	local first_segment_is_vertical = first_segment_is_linear and path[1].x == path[2].x
	local first_segment_is_horizontal = first_segment_is_linear and path[1].y == path[2].y
	local first_segment_is_axis_aligned = first_segment_is_vertical or first_segment_is_horizontal
	local last_segment_is_linear = path[#path].interpolation == 'linear'
	local last_segment_is_vertical = last_segment_is_linear and path[#path].x == path[#path-1].x
	local last_segment_is_horizontal = last_segment_is_linear and path[#path].y == path[#path-1].y
	local last_segment_is_axis_aligned = last_segment_is_vertical or last_segment_is_horizontal
	if first_segment_is_axis_aligned and last_segment_is_axis_aligned then
		-- adjust both segments both toward the point where their supporting lines intersect
		assert(first_segment_is_vertical == not first_segment_is_horizontal)
		assert(last_segment_is_vertical == not last_segment_is_horizontal)
		if first_segment_is_vertical and last_segment_is_vertical then
			path[#path].y = path[1].y
		elseif first_segment_is_horizontal and last_segment_is_horizontal then
			path[#path].x = path[1].x
		elseif first_segment_is_vertical and last_segment_is_horizontal then
			path[#path].x = path[1].x
			path[1].y = path[#path].y
		elseif first_segment_is_horizontal and last_segment_is_vertical then
			path[#path].y = path[1].y
			path[1].x = path[#path].x
		else
			error("unexpected case")
		end
	elseif last_segment_is_axis_aligned then
		path[1].x = path[#path].x
		path[1].y = path[#path].y
	elseif first_segment_is_axis_aligned then
		path[#path].x = path[1].x
		path[#path].y = path[1].y
	elseif first_segment_is_linear then
		path[1].x = path[#path].x
		path[1].y = path[#path].y
	elseif last_segment_is_linear then
		path[#path].x = path[1].x
		path[#path].y = path[1].y
	else
		-- insert a linear segment
		-- :TODO: try to drag one of the two curves instead
		path[#path+1] = {x=path[1].x, y=path[1].y, interpolation='linear'}
	end
end

local function merge_layer_paths(layer, epsilon)
	assert(epsilon ~= 0)
	local layer_nodes = {}
	local merged = {}
	local indices = {}
	local closed = {}
	for ipath,path in ipairs(layer) do
		if #path >= 2 and path.aperture then
			indices[path] = ipath
			local a = point_to_node(path[1], epsilon)
			local b = point_to_node(path[#path], epsilon)
			if a==b then
				-- ignore closed paths
				closed[path] = true
			else
				-- only connect paths with the same aperture
				local nodes = layer_nodes[path.aperture]
				if not nodes then
					nodes = {}
					layer_nodes[path.aperture] = nodes
				end
				-- find neighbours
				local left,la,lb = nodes[a]
				local right,ra,rb = nodes[b]
				nodes[a] = nil
				nodes[b] = nil
				-- find neighbour nodes
				if left then assert(indices[left]); la,lb = point_to_node(left[1], epsilon),point_to_node(left[#left], epsilon) end
				if right then assert(indices[right]); ra,rb = point_to_node(right[1], epsilon),point_to_node(right[#right], epsilon) end
				-- connect
				if left and right and left == right then
					-- this path closes another path
					if lb == a and b == la then
						-- la -> lb -> a -> b
						append_path(left, path)
						close_path(left, epsilon)
						merged[path] = true
						-- path is closed, don't re-insert
						closed[path] = true
					else
						-- la -> lb - b <- a
						local rpath = reverse_path(path)
						-- la -> lb -> b -> a
						append_path(left, rpath)
						close_path(left, epsilon)
						merged[path] = true
						-- path is closed, don't re-insert
						closed[path] = true
					end
				elseif left and right then
					-- this path connects two other paths
					assert(a==la or a==lb)
					assert(b==ra or b==rb)
					nodes[la],nodes[lb],nodes[ra],nodes[rb] = nil
					if lb == a and b == ra then
						-- la -> lb -> a -> b -> ra -> rb
						append_path(left, path)
						append_path(left, right)
						merged[path] = true
						merged[right] = true
						assert(indices[left])
						nodes[la] = left
						nodes[rb] = left
					elseif la == a and b == ra then
						-- lb <- la - a -> b -> ra -> rb
						local rleft = reverse_path(left)
						-- lb -> la -> a -> b -> ra -> rb
						prepend_path(right, path)
						prepend_path(right, rleft)
						merged[path] = true
						merged[left] = true
						assert(indices[right])
						nodes[lb] = right
						nodes[rb] = right
					elseif lb == a and b == rb then
						-- la -> lb -> a -> b - rb <- ra
						local rright = reverse_path(right)
						-- la -> lb -> a -> b -> rb -> ra
						append_path(left, path)
						append_path(left, rright)
						merged[path] = true
						merged[right] = true
						assert(indices[left])
						nodes[la] = left
						nodes[ra] = left
					elseif la == a and b == rb then
						-- lb <- la - a -> b - rb <- ra
						local rpath = reverse_path(path)
						-- ra -> rb -> b -> a -> la -> lb
						append_path(right, rpath)
						append_path(right, left)
						merged[path] = true
						merged[left] = true
						assert(indices[right])
						nodes[ra] = right
						nodes[lb] = right
					end
				elseif left then
					assert(a==la or a==lb)
					nodes[la],nodes[lb] = nil
					if lb==a then
						assert(la ~= b) -- loops should have matched before
						-- la -> lb -> a -> b
						append_path(left, path)
						merged[path] = true
						assert(indices[left])
						nodes[la] = left
						nodes[b] = left
					else
						assert(b ~= lb) -- loops should have matched before
						-- lb <- la - a -> b
						local rpath = reverse_path(path)
						-- b -> a -> la -> lb
						prepend_path(left, rpath)
						merged[path] = true
						assert(indices[left])
						nodes[b] = left
						nodes[lb] = left
					end
				elseif right then
					assert(b==ra or b==rb)
					nodes[ra],nodes[rb] = nil
					if b==ra then
						assert(a ~= rb) -- loops should have matched before
						-- a -> b -> ra -> rb
						append_path(path, right)
						merged[right] = true
						assert(indices[path])
						nodes[a] = path
						nodes[rb] = path
					else
						assert(ra ~= a) -- loops should have matched before
						-- a -> b - rb <- ra
						local rpath = reverse_path(path)
						-- ra -> rb -> b -> a
						append_path(right, rpath)
						merged[path] = true
						assert(indices[right])
						nodes[ra] = right
						nodes[a] = right
					end
				else
					assert(indices[path])
					nodes[a] = path
					nodes[b] = path
				end
			end
		end
	end
	for i=#layer,1,-1 do
		if merged[layer[i]] then
			table.remove(layer, i)
		end
	end
end

function _M.merge_image_paths(image, epsilon)
	for _,layer in ipairs(image.layers) do
		merge_layer_paths(layer, epsilon)
	end
end

------------------------------------------------------------------------------

if _NAME=='test' then
	require 'test'
	
	local a = { {x=0, y=0}, {x=1, y=1, interpolation='linear'} }
	local b = { {x=1, y=1}, {x=0, y=0, interpolation='linear'} }
	expect(b, reverse_path(a))
	local a = { {x=0, y=0}, {x=1, y=1, cx=1, cy=0, interpolation='circular', direction='clockwise', quadrant='single'} }
	local b = { {x=1, y=1}, {x=0, y=0, cx=1, cy=0, interpolation='circular', direction='counterclockwise', quadrant='single'} }
	expect(b, reverse_path(a))
	local a = { {x=0, y=0}, {x=1, y=1, cx=1, cy=0, interpolation='circular', direction='counterclockwise', quadrant='multi'} }
	local b = { {x=1, y=1}, {x=0, y=0, cx=1, cy=0, interpolation='circular', direction='clockwise', quadrant='multi'} }
	expect(b, reverse_path(a))
	local a = { {x=0, y=0}, {x1=1, y1=0, x=1, y=1, interpolation='quadratic'} }
	local b = { {x=1, y=1}, {x1=1, y1=0, x=0, y=0, interpolation='quadratic'} }
	expect(b, reverse_path(a))
	local a = { {x=0, y=0}, {x1=0, y1=1, x2=1, y2=1, x=1, y=0, interpolation='cubic'} }
	local b = { {x=1, y=0}, {x1=1, y1=1, x2=0, y2=1, x=0, y=0, interpolation='cubic'} }
	expect(b, reverse_path(a))
	
	local a = { {x=0, y=0}, {x=1, y=0, interpolation='linear'} }
	local b = { {x=1, y=0}, {x=1, y=1, interpolation='linear'} }
	local c = { {x=0, y=0}, {x=1, y=0, interpolation='linear'}, {x=1, y=1, interpolation='linear'} }
	append_path(a, b)
	expect(c, a)
	local a = { {x=0, y=0}, {x=1, y=0, interpolation='linear'} }
	local b = { {x=1, y=1}, {x=1, y=2, interpolation='linear'} }
	local c = { {x=0, y=0}, {x=1, y=0, interpolation='linear'}, {x=1, y=1, interpolation='linear'}, {x=1, y=2, interpolation='linear'} }
	append_path(a, b)
	expect(c, a)
	
	local a = { {x=0, y=0}, {x=1, y=0, interpolation='linear'} }
	local b = { {x=1, y=0}, {x=1, y=1, interpolation='linear'} }
	local c = { {x=0, y=0}, {x=1, y=0, interpolation='linear'}, {x=1, y=1, interpolation='linear'} }
	prepend_path(b, a)
	expect(c, b)
	local a = { {x=0, y=0}, {x=1, y=0, interpolation='linear'} }
	local b = { {x=1, y=1}, {x=1, y=2, interpolation='linear'} }
	local c = { {x=0, y=0}, {x=1, y=0, interpolation='linear'}, {x=1, y=1, interpolation='linear'}, {x=1, y=2, interpolation='linear'} }
	prepend_path(b, a)
	expect(c, b)
	
	local function mklayer(data)
		local aperture = {}
		local layer = { polarity = 'dark' }
		for ipath,path in ipairs(data) do
			layer[ipath] = { aperture = aperture }
			for ipoint,point in ipairs(path) do
				layer[ipath][ipoint] = { x = point.x, y = point.y, interpolation = ipoint > 1 and 'linear' or nil }
			end
		end
		return layer
	end
	
	-- merge_layer_paths coverage
	local layer = mklayer{
		{ {x=0, y=0}, {x=1, y=0}, {x=1, y=1}, {x=0, y=0} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=0, y=0}, {x=1, y=0}, {x=1, y=1}, {x=0, y=0} },
	}, layer)
	
	local layer = mklayer{
		{ {x=1, y=0}, {x=1, y=1}, {x=0, y=0} },
		{ {x=0, y=0}, {x=1, y=0} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=1, y=0}, {x=1, y=1}, {x=0, y=0}, {x=1, y=0} },
	}, layer)
	
	local layer = mklayer{
		{ {x=1, y=0}, {x=1, y=1}, {x=0, y=0} },
		{ {x=1, y=0}, {x=0, y=0} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=1, y=0}, {x=1, y=1}, {x=0, y=0}, {x=1, y=0} },
	}, layer)
	
	local layer = mklayer{
		{ {x=0, y=0}, {x=0, y=1} },
		{ {x=1, y=1}, {x=1, y=0} },
		{ {x=0, y=1}, {x=1, y=1} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=0, y=0}, {x=0, y=1}, {x=1, y=1}, {x=1, y=0} },
	}, layer)
	
	local layer = mklayer{
		{ {x=0, y=1}, {x=0, y=0} },
		{ {x=1, y=1}, {x=1, y=0} },
		{ {x=0, y=1}, {x=1, y=1} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=0, y=0}, {x=0, y=1}, {x=1, y=1}, {x=1, y=0} },
	}, layer)
	
	local layer = mklayer{
		{ {x=0, y=0}, {x=0, y=1} },
		{ {x=1, y=0}, {x=1, y=1} },
		{ {x=0, y=1}, {x=1, y=1} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=0, y=0}, {x=0, y=1}, {x=1, y=1}, {x=1, y=0} },
	}, layer)
	
	local layer = mklayer{
		{ {x=0, y=1}, {x=0, y=0} },
		{ {x=1, y=0}, {x=1, y=1} },
		{ {x=0, y=1}, {x=1, y=1} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=1, y=0}, {x=1, y=1}, {x=0, y=1}, {x=0, y=0} },
	}, layer)
	
	local layer = mklayer{
		{ {x=0, y=0}, {x=1, y=0} },
		{ {x=1, y=0}, {x=1, y=1} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=0, y=0}, {x=1, y=0}, {x=1, y=1} },
	}, layer)
	
	local layer = mklayer{
		{ {x=1, y=0}, {x=0, y=0} },
		{ {x=1, y=0}, {x=1, y=1} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=1, y=1}, {x=1, y=0}, {x=0, y=0} },
	}, layer)
	
	local layer = mklayer{
		{ {x=1, y=0}, {x=0, y=0} },
		{ {x=1, y=1}, {x=1, y=0} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=1, y=1}, {x=1, y=0}, {x=0, y=0} },
	}, layer)
	
	local layer = mklayer{
		{ {x=0, y=0}, {x=1, y=0} },
		{ {x=1, y=1}, {x=1, y=0} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=0, y=0}, {x=1, y=0}, {x=1, y=1} },
	}, layer)
	
	-- some specific tests that previously failed
	local layer = mklayer{
		{ {x=0, y=0}, {x=1, y=0} },
		{ {x=1, y=0}, {x=1, y=1} },
		{ {x=1, y=1}, {x=0, y=1} },
		{ {x=0, y=1}, {x=0, y=0} },
	}
	merge_layer_paths(layer, 0.1)
	expect(1, #layer)
	local layer = mklayer{
		{ {x=1, y=0}, {x=0, y=0} },
		{ {x=1, y=1}, {x=1, y=0} },
		{ {x=0, y=1}, {x=1, y=1} },
		{ {x=0, y=0}, {x=0, y=1} },
	}
	merge_layer_paths(layer, 0.1)
	expect(1, #layer)
	
	-- close_path coverage
	local layer = mklayer{
		{ {x=0, y=0}, {x=0, y=1}, {x=1, y=0}, {x=0, y=-1} },
		{ {x=0, y=-1}, {x=0, y=0.01} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=0, y=0}, {x=0, y=1}, {x=1, y=0}, {x=0, y=-1}, {x=0, y=0} },
	}, layer)
	
	local layer = mklayer{
		{ {x=0, y=0}, {x=1, y=0}, {x=0, y=1}, {x=-1, y=0} },
		{ {x=-1, y=0}, {x=0.01, y=0} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=0, y=0}, {x=1, y=0}, {x=0, y=1}, {x=-1, y=0}, {x=0, y=0} },
	}, layer)
	
	local layer = mklayer{
		{ {x=0, y=0}, {x=0, y=1}, {x=1, y=0} },
		{ {x=1, y=0}, {x=0.01, y=0} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=0, y=0}, {x=0, y=1}, {x=1, y=0}, {x=0, y=0} },
	}, layer)
	
	local layer = mklayer{
		{ {x=0, y=0}, {x=1, y=0}, {x=0, y=1} },
		{ {x=0, y=1}, {x=0, y=0.01} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=0, y=0}, {x=1, y=0}, {x=0, y=1}, {x=0, y=0} },
	}, layer)
	
	local layer = mklayer{
		{ {x=0, y=0.01}, {x=1, y=0}, {x=0, y=1} },
		{ {x=0, y=1}, {x=0, y=0} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=0, y=0}, {x=1, y=0}, {x=0, y=1}, {x=0, y=0} },
	}, layer)
	
	local layer = mklayer{
		{ {x=0, y=0}, {x=1, y=0}, {x=0, y=1} },
		{ {x=0, y=1}, {x=0.01, y=0} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=0, y=0}, {x=1, y=0}, {x=0, y=1}, {x=0, y=0} },
	}, layer)
	
	local layer = mklayer{
		{ {x=0, y=0.01}, {x=1, y=0}, {x=0, y=1} },
		{ {x=0, y=1}, {x=0.01, y=0} },
	}
	merge_layer_paths(layer, 0.1)
	expect(mklayer{
		{ {x=0.01, y=0}, {x=1, y=0}, {x=0, y=1}, {x=0.01, y=0} },
	}, layer)
	
	local aperture = {}
	local layer = { polarity = 'dark',
		{ aperture=aperture,
			{x=0, y=0},
			{x=1, y=1, cx=0, cy=1, interpolation='circular', direction='counterclockwise', quadrant='single'},
			{x=0, y=1, interpolation='linear' },
		},
		{ aperture=aperture,
			{x=0, y=1},
			{x=0.01, y=0, interpolation='linear'},
		},
	}
	merge_layer_paths(layer, 0.1)
	expect({ polarity = 'dark',
		{ aperture=aperture,
			{x=0, y=0},
			{x=1, y=1, cx=0, cy=1, interpolation='circular', direction='counterclockwise', quadrant='single'},
			{x=0, y=1, interpolation='linear' },
			{x=0, y=0, interpolation='linear'},
		},
	}, layer)
	
	local aperture = {}
	local layer = { polarity = 'dark',
		{ aperture=aperture,
			{x=0, y=0},
			{x=1, y=1, cx=0, cy=1, interpolation='circular', direction='counterclockwise', quadrant='single'},
			{x=0, y=1, interpolation='linear' },
		},
		{ aperture=aperture,
			{x=0, y=1},
			{x=-1, y=1, interpolation='linear' },
			{x=0.01, y=0, cx=0, cy=1, interpolation='circular', direction='counterclockwise', quadrant='single'},
		},
	}
	merge_layer_paths(layer, 0.1)
	expect({ polarity = 'dark',
		{ aperture=aperture,
			{x=0, y=0},
			{x=1, y=1, cx=0, cy=1, interpolation='circular', direction='counterclockwise', quadrant='single'},
			{x=0, y=1, interpolation='linear' },
			{x=-1, y=1, interpolation='linear'},
			{x=0.01, y=0, cx=0, cy=1, interpolation='circular', direction='counterclockwise', quadrant='single'},
			{x=0, y=0, interpolation='linear' },
		},
	}, layer)
end

------------------------------------------------------------------------------

return _M
