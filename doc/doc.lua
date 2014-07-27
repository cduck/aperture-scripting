
------------------------------------------------------------------------------

readme '../README.md'
index {
	title = 'Gerber-ltools',
	header = [[A set of libraries and tools to manipulate PCB data files]],
	logo = {
		width = 128,
		alt = 'Gerber-ltools',
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

chapter('about', "About gerber-ltools", [[
Gerber-ltools is a set of Lua libraries to manipulate Gerber (RS-274X) files and other related vector files. It was designed as a generic framework to let custom scripts manipulate PCB design data, in particular assemble several PCBs into panels. It is also used by my [Gerber Viewer](http://piratery.net/grbv/) application to load PCB data files for visualization.

## Support

All support is done through direct email to me at [jerome.vuarand@gmail.com](mailto:jerome.vuarand@gmail.com). You might also be able to contact me through the [Lua mailing list](http://www.lua.org/lua-l.html) if your question is somewhat related to the Lua language and how to use it, or through the [Dangerous Prototypes forums](http://dangerousprototypes.com/forum/) for questions related to PCB design and Gerber data creation (most likely exported from a CAD software).

Feel free to ask for further developments. I can't guarantee that I'll develop everything you ask, but I want my code to be as useful as possible, so I'll do my best to help you. And if you find a bug please report it to me so that I can fix it for you and all the other users (this may seem obvious but automated crash reports in my Gerber Viewer demonstrated that very few people report their problems).

## Credits

These libraries are written and maintained by [Jérôme Vuarand](mailto:jerome.vuarand@gmail.com).

Gerber-ltools is available under an [MIT-style license](LICENSE.txt).

The logo was inspired by another kind of [Gerber](http://www.gerber.com/) and by the [Lua logo](http://www.lua.org/images/). Hopefully it will be seen as a tribute rather than a copyright infringement.
]])

chapter('download', "Download", [[
Gerber-ltools sources are available in its [Mercurial repository](http://hg.piratery.net/gerber-ltools/):

    hg clone http://hg.piratery.net/gerber-ltools/

Tarballs of the latest code can be downloaded directly from there: as [gz](http://hg.piratery.net/gerber-ltools/get/tip.tar.gz), [bz2](http://hg.piratery.net/gerber-ltools/get/tip.tar.bz2) or [zip](http://hg.piratery.net/gerber-ltools/get/tip.zip).
]])

chapter('installation', "Installation", [[
Gerber-ltools is not (at the moment) designed to be installed. Rather you should simply unzip one of the packages above or clone the source repository. Then make sure your Lua scripts can find its modules. It is written in pure Lua, so you don't need to compile anything.

There are a few dependencies. The only mandatory dependency is [LuaFileSystem](http://keplerproject.github.io/luafilesystem/). If you want to load SVG files you will need my [prtr-xml module](https://bitbucket.org/doub/xml). For font loading and text drawing you will need my [LuaFreeType module](https://bitbucket.org/doub/luafreetype). All of these can be installed with [LuaRocks](http://luarocks.org/):

	luarocks install luafilesystem
	luarocks install prtr-xml
	luarocks install freetype

If you're on Windows, and you don't have a working Lua installation, I recommend you download one of my [Gerber Viewer packages](http://piratery.net/grbv/downloads/). It contains gerber-ltools, along with a full working set of compiled libraries, a Lua interpreter and Lua modules, including all the optional dependencies for gerber-ltools. And as a bonus you get a 3D viewer for your generated PCBs files.
]])

footer()

------------------------------------------------------------------------------

header('manual')

chapter('manual', "Manual", [[
The gerber-ltools API is still fluctuating, so please consult the source and the examples to get an idea.
]])

footer()

------------------------------------------------------------------------------

header('examples')

chapter('examples', "Examples", [[
Here are some progressively more complex example scripts showing how you can use gerber-ltools.
]])

section('simple', "Loading a board", [[
The first step when using gerber-ltools usually consist in loading some board that you exported from your CAD software. First you need to load the `boards` module:

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
One of the most important features of gerber-ltools is its ability to panelize boards, ie. to assemble several boards into a larger one. This is probably why you want to use gerber-ltools. The module you need for that is `boards.panelization`:

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
We've seen above that the `panelize` function takes a layout table as first argument. A layout is a Lua array, so it can only have one dimension (either vertical or horizontal depending on the `panelize` third argument). But each element of the array can be either a board, or another sub-panel layout. This is how you construct complex panels in one step. Here we'll create a panel a bit more involved than in the previous example, with a single call to `panelize`:

	local simple_extents = extents.compute_board_extents(simple)
	local width = simple_extents.width * 2 + 2*mm
	local height = simple_extents.height * 2 + 14*mm
	local tabh = panelization.empty_board(width, 10*mm)
	local tabv = panelization.empty_board(10*mm, height)
	
	local layout = { tabv, {
		{ simple, simple180 },
		tabh,
		{ simple, simple180 },
	}, tabv }
	
	local panel = panelization.panelize(layout, {}, false)
	
	boards.merge_apertures(panel)
	boards.save(panel, './panel-layout')

The resulting 2D panel looks like this:

![](examples/panel-layout.png)
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
