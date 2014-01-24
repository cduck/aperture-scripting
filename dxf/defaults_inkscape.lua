local _M = {}

_M.sections = {
	OBJECTS = {
		root_dictionary = {
			type = "DICTIONARY",
			attributes = {
				{
					code = 5,
					value = "C",
				},
				{
					code = 330,
					value = "0",
				},
			},
			{
				type = "AcDbDictionary",
				{
					key = "ACAD_GROUP",
					value = "D",
				},
				{
					key = "ACAD_MLINESTYLE",
					value = "17",
				},
			},
		},
		{
			type = "DICTIONARY",
			attributes = {
				{
					code = 5,
					value = "D",
				},
				{
					code = 330,
					value = "C",
				},
			},
			{
				type = "AcDbDictionary",
			},
		},
		{
			type = "DICTIONARY",
			attributes = {
				{
					code = 5,
					value = "1A",
				},
				{
					code = 330,
					value = "C",
				},
			},
			{
				type = "AcDbDictionary",
			},
		},
		{
			type = "DICTIONARY",
			attributes = {
				{
					code = 5,
					value = "17",
				},
				{
					code = 330,
					value = "C",
				},
			},
			{
				type = "AcDbDictionary",
				{
					key = "STANDARD",
					value = "18",
				},
			},
		},
		{
			type = "DICTIONARY",
			attributes = {
				{
					code = 5,
					value = "19",
				},
				{
					code = 330,
					value = "C",
				},
			},
			{
				type = "AcDbDictionary",
			},
		},
	},
	BLOCKS = {
		{
			type = "BLOCK",
			attributes = {
				{
					code = 5,
					value = "20",
				},
				{
					code = 330,
					value = "1F",
				},
			},
			{
				color = "BYLAYER",
				layer = "0",
				line_type_name = "BYLAYER",
				line_type_scale = 1,
				type = "AcDbEntity",
			},
			{
				type = "AcDbBlockBegin",
				{
					code = 2,
					value = "*MODEL_SPACE",
				},
				{
					code = 70,
					value = 0,
				},
				{
					code = 10,
					value = 0,
				},
				{
					code = 20,
					value = 0,
				},
				{
					code = 30,
					value = 0,
				},
				{
					code = 3,
					value = "*MODEL_SPACE",
				},
				{
					code = 1,
					value = "",
				},
			},
		},
		{
			type = "ENDBLK",
			attributes = {
				{
					code = 5,
					value = "21",
				},
				{
					code = 330,
					value = "1F",
				},
			},
			{
				color = "BYLAYER",
				layer = "0",
				line_type_name = "BYLAYER",
				line_type_scale = 1,
				type = "AcDbEntity",
			},
			{
				type = "AcDbBlockEnd",
			},
		},
		{
			type = "BLOCK",
			attributes = {
				{
					code = 5,
					value = "1C",
				},
				{
					code = 330,
					value = "1B",
				},
			},
			{
				color = "BYLAYER",
				layer = "0",
				line_type_name = "BYLAYER",
				line_type_scale = 1,
				paper_space = true,
				type = "AcDbEntity",
			},
			{
				type = "AcDbBlockBegin",
				{
					code = 2,
					value = "*PAPER_SPACE",
				},
				{
					code = 1,
					value = "",
				},
			},
		},
		{
			type = "ENDBLK",
			attributes = {
				{
					code = 5,
					value = "1D",
				},
				{
					code = 330,
					value = "1B",
				},
			},
			{
				color = "BYLAYER",
				layer = "0",
				line_type_name = "BYLAYER",
				line_type_scale = 1,
				paper_space = true,
				type = "AcDbEntity",
			},
			{
				type = "AcDbBlockEnd",
			},
		},
	},
}

_M.sections.TABLES = {
	{
		type = "VPORT",
		handle = "8",
		owner = "0",
		{
			attributes = {
				{
					code = 5,
					value = "2E",
				},
				{
					code = 330,
					value = "8",
				},
			},
			{
				type = "AcDbSymbolTableRecord",
			},
			{
				type = "AcDbViewportTableRecord",
				name = "*ACTIVE",
				view_height = 341,
				center = {
					x = 210,
					y = 148.5,
				},
				flags = 0,
				viewport_aspect_ratio = 1.24,
				
				back_clipping_plane = 0,
				circle_zoom_percent = 100,
				fast_zoom_setting = 1,
				front_clipping_plane = 0,
				grid_on = false,
				lens_length = 50,
				snap_isopair = 0,
				snap_on = false,
				snap_rotation_angle = 0,
				snap_style = 0,
				ucsicon_setting = 3,
				view_mode = 0,
				view_twist_angle = 0,
				extents = {
					bottom = 0,
					left = 0,
					right = 1,
					top = 1,
				},
				grid_spacing = {
					x = 10,
					y = 10,
				},
				snap_base_point = {
					x = 0,
					y = 0,
				},
				snap_spacing = {
					x = 10,
					y = 10,
				},
				view_direction = {
					x = 0,
					y = 0,
					z = 1,
				},
				view_target_point = {
					x = 0,
					y = 0,
					z = 0,
				},
			},
		},
	},
	{
		type = "LTYPE",
		handle = "5",
		owner = "0",
		{
			attributes = {
				{
					code = 5,
					value = "14",
				},
				{
					code = 330,
					value = "5",
				},
			},
			{
				type = "AcDbSymbolTableRecord",
			},
			{
				type = "AcDbLinetypeTableRecord",
				{
					code = 2,
					value = "BYBLOCK",
				},
				{
					code = 70,
					value = 0,
				},
				{
					code = 3,
					value = "",
				},
				{
					code = 72,
					value = 65,
				},
				{
					code = 73,
					value = 0,
				},
				{
					code = 40,
					value = 0,
				},
			},
		},
		{
			attributes = {
				{
					code = 5,
					value = "15",
				},
				{
					code = 330,
					value = "5",
				},
			},
			{
				type = "AcDbSymbolTableRecord",
			},
			{
				type = "AcDbLinetypeTableRecord",
				{
					code = 2,
					value = "BYLAYER",
				},
				{
					code = 70,
					value = 0,
				},
				{
					code = 3,
					value = "",
				},
				{
					code = 72,
					value = 65,
				},
				{
					code = 73,
					value = 0,
				},
				{
					code = 40,
					value = 0,
				},
			},
		},
		{
			attributes = {
				{
					code = 5,
					value = "16",
				},
				{
					code = 330,
					value = "5",
				},
			},
			{
				type = "AcDbSymbolTableRecord",
			},
			{
				type = "AcDbLinetypeTableRecord",
				{
					code = 2,
					value = "CONTINUOUS",
				},
				{
					code = 70,
					value = 0,
				},
				{
					code = 3,
					value = "Solid line",
				},
				{
					code = 72,
					value = 65,
				},
				{
					code = 73,
					value = 0,
				},
				{
					code = 40,
					value = 0,
				},
			},
		},
	},
	{
		type = "LAYER",
		handle = "2",
		{
			attributes = {
				{
					code = 5,
					value = "50",
				},
			},
			{
				type = "AcDbSymbolTableRecord",
			},
			{
				type = "AcDbLayerTableRecord",
				{
					code = 2,
					value = "0",
				},
				{
					code = 70,
					value = 0,
				},
				{
					code = 6,
					value = "CONTINUOUS",
				},
			},
		},
	},
	{
		type = "STYLE",
		handle = "3",
		owner = "0",
		{
			attributes = {
				{
					code = 5,
					value = "11",
				},
				{
					code = 330,
					value = "3",
				},
			},
			{
				type = "AcDbSymbolTableRecord",
			},
			{
				big_font_filename = "",
				flags = 0,
				generation_flags = 0,
				last_height_used = 2.5,
				name = "STANDARD",
				oblique_angle = 0,
				primary_font_filename = "txt",
				text_height = 0,
				type = "AcDbTextStyleTableRecord",
				width_factor = 1,
			},
		},
	},
	{
		type = "VIEW",
		handle = "6",
		owner = "0",
	},
	{
		type = "UCS",
		handle = "7",
		owner = "0",
	},
	{
		type = "APPID",
		handle = "9",
		owner = "0",
		{
			attributes = {
				{
					code = 5,
					value = "12",
				},
				{
					code = 330,
					value = "9",
				},
			},
			{
				type = "AcDbSymbolTableRecord",
			},
			{
				type = "AcDbRegAppTableRecord",
				{
					code = 2,
					value = "ACAD",
				},
				{
					code = 70,
					value = 0,
				},
			},
		},
	},
	{
		type = "DIMSTYLE",
		handle = "A",
		owner = "0",
		{
			attributes = {
				{
					code = 105,
					value = "27",
				},
				{
					code = 330,
					value = "A",
				},
			},
			{
				type = "AcDbSymbolTableRecord",
			},
			{
				type = "AcDbDimStyleTableRecord",
				{
					code = 2,
					value = "ISO-25",
				},
				{
					code = 70,
					value = 0,
				},
				{
					code = 3,
					value = "",
				},
				{
					code = 4,
					value = "",
				},
				{
					code = 5,
					value = "",
				},
				{
					code = 6,
					value = "",
				},
				{
					code = 7,
					value = "",
				},
				{
					code = 40,
					value = 1,
				},
				{
					code = 41,
					value = 2.5,
				},
				{
					code = 42,
					value = 0.625,
				},
				{
					code = 43,
					value = 3.75,
				},
				{
					code = 44,
					value = 1.25,
				},
				{
					code = 45,
					value = 0,
				},
				{
					code = 46,
					value = 0,
				},
				{
					code = 47,
					value = 0,
				},
				{
					code = 48,
					value = 0,
				},
				{
					code = 140,
					value = 2.5,
				},
				{
					code = 141,
					value = 2.5,
				},
				{
					code = 142,
					value = 0,
				},
				{
					code = 143,
					value = 0.03937007874016,
				},
				{
					code = 144,
					value = 1,
				},
				{
					code = 145,
					value = 0,
				},
				{
					code = 146,
					value = 1,
				},
				{
					code = 147,
					value = 0.625,
				},
				{
					code = 71,
					value = 0,
				},
				{
					code = 72,
					value = 0,
				},
				{
					code = 73,
					value = 0,
				},
				{
					code = 74,
					value = 0,
				},
				{
					code = 75,
					value = 0,
				},
				{
					code = 76,
					value = 0,
				},
				{
					code = 77,
					value = 1,
				},
				{
					code = 78,
					value = 8,
				},
				{
					code = 170,
					value = 0,
				},
				{
					code = 171,
					value = 3,
				},
				{
					code = 172,
					value = 1,
				},
				{
					code = 173,
					value = 0,
				},
				{
					code = 174,
					value = 0,
				},
				{
					code = 175,
					value = 0,
				},
				{
					code = 176,
					value = 0,
				},
				{
					code = 177,
					value = 0,
				},
				{
					code = 178,
					value = 0,
				},
				{
					code = 270,
					value = 2,
				},
				{
					code = 271,
					value = 2,
				},
				{
					code = 272,
					value = 2,
				},
				{
					code = 273,
					value = 2,
				},
				{
					code = 274,
					value = 3,
				},
				{
					code = 340,
					value = "11",
				},
				{
					code = 275,
					value = 0,
				},
				{
					code = 280,
					value = 0,
				},
				{
					code = 281,
					value = 0,
				},
				{
					code = 282,
					value = 0,
				},
				{
					code = 283,
					value = 0,
				},
				{
					code = 284,
					value = 8,
				},
				{
					code = 285,
					value = 0,
				},
				{
					code = 286,
					value = 0,
				},
				{
					code = 287,
					value = 3,
				},
				{
					code = 288,
					value = 0,
				},
			},
		},
	},
	{
		type = "BLOCK_RECORD",
		handle = "1",
		owner = "0",
		{
			attributes = {
				{
					code = 5,
					value = "1F",
				},
				{
					code = 330,
					value = "1",
				},
			},
			{
				type = "AcDbSymbolTableRecord",
			},
			{
				type = "AcDbBlockTableRecord",
				{
					code = 2,
					value = "*MODEL_SPACE",
				},
			},
		},
		{
			attributes = {
				{
					code = 5,
					value = "1B",
				},
				{
					code = 330,
					value = "1",
				},
			},
			{
				type = "AcDbSymbolTableRecord",
			},
			{
				type = "AcDbBlockTableRecord",
				{
					code = 2,
					value = "*PAPER_SPACE",
				},
			},
		},
	},
}

return _M
