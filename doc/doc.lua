
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

## %chapterid%.1 - General library description

TODO

## %chapterid%.2 - Boards

TODO

## %chapterid%.3 - Images

TODO

## %chapterid%.4 - Manipulation

TODO

## %chapterid%.5 - Panelization

TODO

## %chapterid%.6 - Drawing

TODO
]])

footer()

------------------------------------------------------------------------------

header('examples')

chapter('examples', "Examples", [[
Here are some progressively more complex example scripts showing how you can use gerber-ltools.

## %chapterid%.1 - Loading a board

TODO

## %chapterid%.2 - Saving a board

TODO

## %chapterid%.3 - Rotating a board

TODO

## %chapterid%.4 - Merging boards

TODO

## %chapterid%.5 - Panelizing boards

TODO

## %chapterid%.6 - Drawing additional data

TODO
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
