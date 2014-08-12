
------------------------------------------------------------------------------

readme('../README.md', 'https://bitbucket.org/doub/aperture-scripting/raw/tip/doc/')
index {
	title = 'Aperture Scripting',
	header = [[Aperture Scripting<br/>A set of Lua libraries to manipulate PCB data files]],
	logo = {
		width = 128,
		alt = 'Aperture Scripting',
	},
	index = {
		{title="home"},
		{section='download', title="download"},
		{section='installation', title="installation"},
		{page='manual', title="manual"},
		{page='examples', title="examples"},
	},
}

------------------------------------------------------------------------------

header('index')

chapter('about', "About Aperture Scripting", [[
Aperture Scripting is a set of Lua libraries to manipulate Gerber (RS-274X) files and other related vector files. It was designed as a generic framework to let custom scripts manipulate PCB design data, in particular assemble several PCBs into panels. It is also used by my [Gerber Viewer](http://piratery.net/grbv/) application to load PCB data files for visualization.

## Support

All support is done through direct email to me at [jerome.vuarand@gmail.com](mailto:jerome.vuarand@gmail.com). You might also be able to contact me through the [Lua mailing list](http://www.lua.org/lua-l.html) if your question is somewhat related to the Lua language and how to use it, or through the [Dangerous Prototypes forums](http://dangerousprototypes.com/forum/) for questions related to PCB design and Gerber data creation (most likely exported from a CAD software).

Feel free to ask for further developments. I can't guarantee that I'll develop everything you ask, but I want my code to be as useful as possible, so I'll do my best to help you. And if you find a bug please report it to me so that I can fix it for you and all the other users (this may seem obvious but automated crash reports in my Gerber Viewer demonstrated that very few people report their problems).

## Credits

These libraries are written and maintained by [Jérôme Vuarand](mailto:jerome.vuarand@gmail.com).

Aperture Scripting is available under an [MIT-style license](LICENSE.txt).

The logo was inspired by another kind of [Aperture](http://en.wikipedia.org/wiki/Portal_(video_game)#Setting), another kind of [Gerber](http://www.gerber.com/) and by the [Lua logo](http://www.lua.org/images/). Hopefully it will be seen as a tribute rather than a copyright infringement.
]])

chapter('download', "Download", [[
Aperture Scripting sources are available in its [Mercurial repository](http://hg.piratery.net/aperture-scripting/):

    hg clone http://hg.piratery.net/aperture-scripting/

Tarballs of the latest code can be downloaded directly from there: as [gz](http://hg.piratery.net/aperture-scripting/get/tip.tar.gz), [bz2](http://hg.piratery.net/aperture-scripting/get/tip.tar.bz2) or [zip](http://hg.piratery.net/aperture-scripting/get/tip.zip).
]])

chapter('installation', "Installation", [[
Aperture Scripting is not (at the moment) designed to be installed. Rather you should simply unzip one of the packages above or clone the source repository. Then make sure your Lua scripts can find its modules. It is written in pure Lua, so you don't need to compile anything.

There are a few dependencies. The only mandatory dependency is [LuaFileSystem](http://keplerproject.github.io/luafilesystem/). If you want to load SVG files you will need my [prtr-xml module](https://bitbucket.org/doub/xml). For font loading and text drawing you will need my [LuaFreeType module](https://bitbucket.org/doub/luafreetype). All of these can be installed with [LuaRocks](http://luarocks.org/):

	luarocks install luafilesystem
	luarocks install prtr-xml
	luarocks install freetype

There's one more optional dependency not available on LuaRocks, it's [lhf's lgpc](http://www.tecgraf.puc-rio.br/~lhf/ftp/lua/#lgpc). This is not required for panelization, only for an advanced function that most people will never use.

If you're on Windows, and you don't have a working Lua installation, I recommend you download one of my [Gerber Viewer packages](http://piratery.net/grbv/downloads/). It contains Aperture Scripting, along with a full working set of compiled libraries, a Lua interpreter and Lua modules, including all the optional dependencies for Aperture Scripting. And as a bonus you get a 3D viewer for your generated PCBs files.
]])

footer()

------------------------------------------------------------------------------

header('manual')

chapter('manual', "Manual", [[
The Aperture Scripting API is still fluctuating. Below is a raw and sometimes incomplete reference, so please look at the examples and explore the source to get a better idea.
]])

local modules = {
	'boards',
	'boards.extents',
	'boards.manipulation',
	'boards.panelization',
	'boards.drawing',
}

local manual = {}

for _,module in ipairs(modules) do
	local lines = {}
	for line in assert(io.lines('../'..module:gsub('%.', '/')..'.lua')) do
		table.insert(lines, line)
	end
	local blocks = {}
	local i = 1
	while i <= #lines do
		local line = lines[i]
		if line:match('^%-%-%- ') then
			local block = {line:match('^%-*%s(.*)$')}
			i = i + 1
			while i <= #lines do
				local line = lines[i]
				if line:match('^%-%-') then
					table.insert(block, line:match('^%-*%s(.*)$'))
				else
					block.prototype = line
					break
				end
				i = i + 1
			end
			table.insert(blocks, block)
		end
		i = i + 1
	end
	local mdoc = {}
	mdoc.name = module
	if #blocks >= 1 and blocks[1].prototype=="local _M = {}" then
		mdoc.doc = table.concat(table.remove(blocks, 1), '\n')
	end
	for _,func in ipairs(blocks) do
		local name,params = assert(func.prototype:match('^function _M%.([%a_]+)%(([^)]*)%)$'))
		local fdoc = {
			name = name,
			params = params~="" and params or nil,
			doc = table.concat(func, '\n'),
		}
		table.insert(mdoc, fdoc)
	end
	table.insert(manual, mdoc)
end

local index = ''

for _,module in ipairs(manual) do
	index = index..'  - ['..module.name:gsub('_', '\\_')..'](#'..module.name..')\n'
	for _,func in ipairs(module) do
		index = index..'    - ['..func.name:gsub('_', '\\_')..'](#'..module.name..'.'..func.name..')\n'
	end
end

section('index', "Index", index)

for _,module in ipairs(manual) do
	section(module.name, module.name.." module", module.doc or "")
	for _,func in ipairs(module) do
		local name = module.name..'.'..func.name
		local title = name..' ('
		if func.params then
			title = title..' '..func.params..' '
		end
		title = title..')'
		entry(name, title, func.doc or "")
	end
end

footer()

------------------------------------------------------------------------------

header('examples')

chapter('examples', "Examples", [[
Here are some progressively more complex example scripts showing how you can use Aperture Scripting.
]])

section('simple', "Loading a board", [[
The first step when using Aperture Scripting usually consist in loading some board that you exported from your CAD software. First you need to load the `boards` module:

	local boards = require 'boards'

Then to load a board you use the `boards.load` function:

	local simple = assert(boards.load('./simple'))

This will simply print all the corresponding Gerber and Excellon file names, and validate the data (ie. if there is some loading error, you should get an error message). In all examples below we start from this *simple* board, which looks like that:

![](examples/simple.png)

]])

section('save', "Saving a board", [[
The final step of any manipulation script usually involves saving your board data. The function to call is `boards.save`:

	local simple = assert(boards.load('./simple'))
	
	assert(boards.save(simple, './save'))

However when you combine several boards into one (like in the panelization examples below), some data in the board may get duplicated, for example aperture definitions. To save on disk space a bit, and more importantly to simplify output files, it is a good idea to merge all identical apertures before saving:

	boards.merge_apertures(simple)
	assert(boards.save(simple, './save'))

As expected the output is identical to the input:

![](examples/save.png)
]])

section('rotate', "Rotating a board", [[
One common manipulation of boards consist in rotating them, for example because they are not square and better fit in another direction. Rotation and most manipulation are in the `boards.manipulation` module:

	local manipulation = require 'boards.manipulation'

To rotate a board call `manipulation.rotate_board` with the board and a direct angle value in degrees as arguments:

	local rotate = manipulation.rotate_board(simple, 90)
	
	assert(boards.save(rotate, './rotate'))

The result is the same board as above, but rotated 90°:

![](examples/rotate.png)
]])

section('panel', "Panelizing boards", [[
One of the most important features of Aperture Scripting is its ability to panelize boards, ie. to assemble several boards into a larger one. This is probably why you want to use Aperture Scripting. The module you need for that is `boards.panelization`:

	local panelization = require 'boards.panelization'

There you will find a `panelization.panelize` function that receives a layout table, an options table, a top-level orientation and that returns a new board object for the panel.

	local simple = assert(boards.load('./simple'))
	
	local panel = assert(panelization.panelize({ simple, simple }, {}, true))
	
	boards.merge_apertures(panel)
	assert(boards.save(panel, './panel'))

Here the layout contains two copies of the *simple* board. These are actually Lua references, but since we don't modify them during panelization you can reuse the same board object several times. The options table is empty to use the defaults. The third argument `true` means the panel top-level is vertical. We're making a vertical panel because the *simple* board has a slot on its left side which would prevent the insertion of a break tab.

The resulting panel looks like that:

![](examples/panel.png)

As you can see the `panelize` function automatically placed the sub-boards with a 2 mm gap, and it created a break tab to connect the two boards.
]])

section('panel-rotate', "Panelizing modified boards", [[
Of course you can combine the above operations to first modify the board, and then use the modified copy in a panel. Since our *simple* board has a slot on its left, we'll create a rotated copy with the slot on the right, so that we can create an horizontal panel.

	local simple = assert(boards.load('./simple'))
	local simple180 = manipulation.rotate_board(simple, 180)
	
	local panel = assert(panelization.panelize({ simple, simple180 }, {}, false))
	
	boards.merge_apertures(panel)
	assert(boards.save(panel, './panel-rotate'))

As we have seen above the `rotate_board` function returns the rotated board. This means the original board is left intact, and we can use both in the panel. Generally the functions in the `boards.manipulation` module will create copies of the input data, which is kept unmodified.

This time we passed `false` as third argument to `panelize`, which means we want a horizontal panel. The result of this panel is as follows:

![](examples/panel-rotate.png)

To verify that the right board has been rotated and not mirrored, you can check the little hole in the trace, which the left board has on the top-right, but which the right board has on the bottom-left.
]])

section('empty', "Creating empty boards", [[
Sometimes you not only want to manipulate and assemble existing boards, but you may want to create new boards on the fly. For example you may want to put spacers between boards in a panel to account for over-hanging components, or you might want to add a frame with tooling holes and fiduciaries.

The `panelization` module has a function named `empty_board` that lets you create such an empty board. You can either pass dimensions so that your board is created with a rectangle outline, or call the function without arguments to get a completely empty board without dimensions (to be used as a canvas for drawing, see below). We'll try to create a 1 cm breaking tab the same width as the panel above. First we need the simple board dimensions:

	local extents = require 'boards.extents'
	
	local simple_extents = extents.compute_board_extents(simple)

Then we can create the tab based on these dimensions. We'll assume the default 2 mm gap between boards:

	local height = 10*mm
	local width = simple_extents.width * 2 + 2*mm
	local tab = panelization.empty_board(width, height)

However since the board has no image (it's empty), you cannot save it on its own. We'll see later how to save a board generated from scratch, but we already can use that empty board in panels.
]])

section('panel-panel', "Panelizing panels", [[
A panel is just a board, so you can use it as input in a `panelize` call. This way you can create more complex panels in several steps (we'll see below how to achieve the same in one step). We'll reuse the rotated-panel above, and the empty tab we just created:

	local panel = panelization.panelize({ tab, panel, tab }, {}, true)
	boards.merge_apertures(panel)
	boards.save(panel, './panel-panel')

And here is the result:

![](examples/panel-panel.png)

One interesting thing to note is that each copy of the empty board is joined to the center panel with two breaking tabs. The `panelize` function will try to be smart about where to place breaking tabs. This can be controlled to some extents with the `options` table, or in the way the outline path is defined in the input boards, but that's a story for another day.
]])

section('panel-layout', "Complex panels in one step", [[
We've seen above that the `panelize` function takes a layout table as first argument. A layout is a Lua array, so it can only have one dimension (either vertical or horizontal depending on the `panelize` third argument). But each element of the array can be either a board, or another sub-panel layout. This is how you construct complex panels in one step. Here we'll create a panel with two levels like in the previous example, with a single call to `panelize`:

	local simple_extents = extents.compute_board_extents(simple)
	local height = simple_extents.height
	local width = simple_extents.width + 24*mm
	local tabv = panelization.empty_board(10*mm, height)
	local tabh = panelization.empty_board(width, 10*mm)
	
	local layout = {
		tabh,
		{ tabv, simple, tabv },
		tabh,
	}
	
	local panel = panelization.panelize(layout, {}, true)
	
	boards.merge_apertures(panel)
	boards.save(panel, './panel-layout')

The resulting 2D panel looks like this:

![](examples/panel-layout.png)
]])

section('drawing-fiducials', "Drawing on boards", [[
Aperture Scripting support some basic drawing functions that will let you add elements to your boards. This is mostly useful for panel tabs that you may add in your script, since it's usually better to add anything to your board in your CAD software if you can. However these Aperture Scripting features can be useful if your CAD software is limited in a way or another. All these functions are in the `drawing` submodule:

	local drawing = require 'boards.drawing'

As a first example we'll add three fiducials to the tabs in the previous panel. To avoid repetition we'll define a function to draw one fiducial. This is where using a programming language like Lua to define your panels starts to become really useful. First we need to define some apertures. Our fiducials will have a 1 millimeter disk on the copper layers, and a 3 millimeter disc on the soldermask layers:

	local fiducial_dot = drawing.circle_aperture(1*mm)
	local fiducial_ring = drawing.circle_aperture(3*mm)

Then we'll define a function taking an X and a Y position as parameters, and drawing a fiducial on all appropriate layers:

	local function draw_fiducial(x, y)
		drawing.draw_path(panel.images.top_copper, fiducial_dot, x, y)
		drawing.draw_path(panel.images.bottom_copper, fiducial_dot, x, y)
		drawing.draw_path(panel.images.top_soldermask, fiducial_ring, x, y)
		drawing.draw_path(panel.images.bottom_soldermask, fiducial_ring, x, y)
	end

The drawing function is named `draw_path` because the same functions can be used for flashes and strokes. If a single point is specified (as is the case here) it will be a flash, if more points are specified it will be a stroke. Finally we'll call the function three times with the three fiducial positions (calculated from the panel dimensions):

	local panel_extents = extents.compute_board_extents(panel)
	local width = panel_extents.width
	local height = panel_extents.height
	draw_fiducial(5*mm, height - 5*mm)
	draw_fiducial(width - 5*mm, 5*mm)
	draw_fiducial(width - 5*mm, height - 5*mm)

And the resulting boards:

![](examples/drawing-fiducials.png)
]])

section('drawing-text', "Drawing text", [[
Aperture Scripting has some basic support to load vector fonts and draw text. At the moment glyph outlines are approximated with Gerber regions made of circular arc segments, so they might not precisely fit the Bezier curves of your font (please tell me if you need something more precise, I can add some subdivision code).

To draw text, simply call the `drawing.draw_text` function. Parameters are the image on which to draw, the drawing polarity (`'dark'` for normal, `'clear'` for inverted), the font filename, the font size (roughly an uppercase letter height, but that depends on the font), a boolean telling whether to mirror the text (for bottom layers) or not, an alignment side (`'left'` or `'center'`), X and Y positions, and finally a string with the text itself in UTF-8. For example (reusing the horizontal tab width from the previous example):

	drawing.draw_text(panel.images.top_silkscreen, 'dark', "constantine.ttf", 6*mm, false, 'center', width / 2, 2.5*mm, "Aperture")

The resulting board now has some nice silkscreen text on the bottom tab:

![](examples/drawing-text.png)
]])

section('empty-save', "Saving a board made from scratch", [[
We've seen above how to create an empty board, but we can't draw on it or even save it empty readily: you first need to specify how it's structured and how it's to be serialized. So let's create a new empty board:

	local board = panelization.empty_board(50*mm, 10*mm)

The first step consist in adding some images to the board, because Aperture Scripting doesn't know what kind of image you need (it could try a standard board, but then you'd have to remove what you don't want or add what's non-standard anyway). Here we'll create an outline image, a top soldermask to get a nice color and a top silkscreen to write some text on top of it:

	board.images.outline = panelization.empty_image()
	board.images.top_silkscreen = panelization.empty_image()
	board.images.top_soldermask = panelization.empty_image()

Now all these are empty, including the outline, even though we said above that specifying dimensions for an empty board would create an outline. Aperture Scripting keeps tracks of outlines separately from other drawings on the board, because usually you don't want it to be drawn (for example if you have the outline on the copper layers you don't actually want a thin copper trace all around your board). But ultimately you want the outline to be saved in a Gerber image, either in a dedicated image as is the case here, or in another image (common cases are top silkscreen, top copper, or sometimes all layers). To do that, you will have to associate the outline with an aperture on each image you want it saved on. Here we'll create a zero-sized aperture and draw the outline on the *outline* image:

	board.outline.apertures.outline = drawing.circle_aperture(0)

So now we have some images, and even an outline drawn on one of them. But before you can save the board you need to specify what will be the filename of each image. This is done through a table in the board called *extensions*. It's named like that because when you save the board you specify a base name, and all you really need for individual images is the extension to append to the base name. So each extension is a pattern where the `%` character will be replaced with the base name.

	board.extensions.outline = '%.oln'
	board.extensions.top_silkscreen = '%.gto'
	board.extensions.top_soldermask = '%.gts'

The final step consist in telling Aperture Scripting what format each image should be saved as. Aperture Scripting has (partial) support for more than just the Gerber format. At the moment you can decently save drill data in Excellon format, BOM data in tab-separated text files, and there is some basic support for SVG and DXF images (please ask if you need more of that). But right now we only need Gerber:

	board.formats.outline = 'gerber'
	board.formats.top_silkscreen = 'gerber'
	board.formats.top_soldermask = 'gerber'

Now we can draw some text on the board (so it's not too boring) and save it:

	drawing.draw_text(board.images.top_silkscreen, 'dark', "constantine.ttf", 6*mm, false, 'center', 25*mm, 2.5*mm, "Aperture")
	boards.save(board, './empty-save')

And the final result is that:

![](examples/empty-save.png)
]])

footer()

------------------------------------------------------------------------------

--[[
Copyright (c) Jérôme Vuarand

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]

-- vi: ts=4 sts=4 sw=4 noet
