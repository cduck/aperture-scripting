local _M = {}

------------------------------------------------------------------------------

_M.default_template = {
	patterns = {
		top_copper = '%.gtl',
		top_soldermask = '%.gts',
		top_silkscreen = '%.gto',
		top_paste = '%.gtp',
		bottom_copper = '%.gbl',
		bottom_soldermask = '%.gbs',
		bottom_silkscreen = '%.gbo',
		bottom_paste = '%.gbp',
		milling = {'%.gml', '%.gm1'},
		outline = {'%.oln', '%.out'},
		drill = {'%.drd', '%.txt'},
		bom = '%-bom.txt',
	},
	path_merge_radius = 0.1, -- mm
	bom = {
		scale = {
			dimension = 1e9,
			angle = 1,
		},
		fields = {
			package = '3D Model',
			x = 'X',
			y = 'Y',
			angle = 'Angle',
			side = 'Side',
			name = 'Part',
			x_offset = 'X Offset',
			y_offset = 'Y Offset',
			angle_offset = 'Angle Offset',
		},
	},
}

------------------------------------------------------------------------------

return _M
