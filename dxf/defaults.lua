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
