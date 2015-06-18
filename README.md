# 1 - About Aperture Scripting

Aperture Scripting is a set of Lua libraries to manipulate Gerber (RS-274X) files and other related vector files. It was designed as a generic framework to let custom scripts manipulate PCB design data, in particular assemble several PCBs into panels. It is also used by my [Gerber Viewer](http://piratery.net/grbv/) application to load PCB data files for visualization.

## Support

All support is done through direct email to me at [jerome.vuarand@gmail.com](mailto:jerome.vuarand@gmail.com). You might also be able to contact me through the [Lua mailing list](http://www.lua.org/lua-l.html) if your question is somewhat related to the Lua language and how to use it, or through the [Dangerous Prototypes forums](http://dangerousprototypes.com/forum/) for questions related to PCB design and Gerber data creation (most likely exported from a CAD software).

Feel free to ask for further developments. I can't guarantee that I'll develop everything you ask, but I want my code to be as useful as possible, so I'll do my best to help you. And if you find a bug please report it to me so that I can fix it for you and all the other users (this may seem obvious but automated crash reports in my Gerber Viewer demonstrated that very few people report their problems).

## Credits

These libraries are written and maintained by [Jérôme Vuarand](mailto:jerome.vuarand@gmail.com).

Aperture Scripting is available under an [MIT-style license](LICENSE.txt).

The logo was inspired by another kind of [Aperture](http://en.wikipedia.org/wiki/Portal_(video_game)#Setting), another kind of [Gerber](http://www.gerber.com/) and by the [Lua logo](http://www.lua.org/images/). Hopefully it will be seen as a tribute rather than a copyright infringement.

# 2 - Download

Aperture Scripting sources are available in its [Mercurial repository](http://hg.piratery.net/aperture-scripting/):

    hg clone http://hg.piratery.net/aperture-scripting/

Tarballs of the latest code can be downloaded directly from there: as [gz](http://hg.piratery.net/aperture-scripting/get/tip.tar.gz), [bz2](http://hg.piratery.net/aperture-scripting/get/tip.tar.bz2) or [zip](http://hg.piratery.net/aperture-scripting/get/tip.zip).

If you're on Windows, and you don't have a working Lua installation, I recommend you download one of my [Gerber Viewer packages](http://piratery.net/grbv/downloads/). It contains Aperture Scripting, along with a full working set of compiled libraries, a Lua interpreter and Lua modules, including all the mandatory and optional dependencies listed below. And as a bonus you get a 3D viewer for your generated PCBs files.

# 3 - Installation

Aperture Scripting is not (at the moment) designed to be installed. Rather you should simply unzip one of the packages above or clone the source repository. Then make sure your Lua scripts can find its modules. It is written in pure Lua, so you don't need to compile anything.

There are however several dependencies. The mandatory dependencies are as follow:

  - [LuaFileSystem](http://keplerproject.github.io/luafilesystem/): `luarocks install luafilesystem`
  - my [prtr-path](https://bitbucket.org/doub/path) module: `luarocks install prtr-path`

The following dependencies are optional:

  - for font loading and text drawing:
    - my [LuaFreeType](https://bitbucket.org/doub/luafreetype) module: `luarocks install freetype`
    - my [geometry](https://bitbucket.org/doub/geometry/) library: this needs to be installed manually
  - to load SVG files:
    - my [prtr-xml](https://bitbucket.org/doub/xml) module: `luarocks install prtr-xml`
  - for aperture path generation (not required for panelization or general board manipulation):
    - lhf's [lgpc](http://www.tecgraf.puc-rio.br/~lhf/ftp/lua/#lgpc) module: this needs to be installed manually

Again if you're on Windows, I recommend using a [Gerber Viewer package](http://piratery.net/grbv/downloads/).

# 4 - Manual

The Aperture Scripting API is still fluctuating. Below is a raw and sometimes incomplete reference, so please look at the examples and explore the source to get a better idea.

## 4.1 - Index

  - [boards](#boards)
    - [load\_image](#boards.load_image)
    - [save\_image](#boards.save_image)
    - [detect\_format](#boards.detect_format)
    - [load](#boards.load)
    - [save](#boards.save)
    - [merge\_apertures](#boards.merge_apertures)
    - [generate\_aperture\_paths](#boards.generate_aperture_paths)
  - [boards.extents](#boards.extents)
    - [compute\_aperture\_extents](#boards.extents.compute_aperture_extents)
    - [compute\_image\_extents](#boards.extents.compute_image_extents)
    - [compute\_board\_extents](#boards.extents.compute_board_extents)
  - [boards.manipulation](#boards.manipulation)
    - [copy\_point](#boards.manipulation.copy_point)
    - [offset\_point](#boards.manipulation.offset_point)
    - [offset\_path](#boards.manipulation.offset_path)
    - [offset\_layer](#boards.manipulation.offset_layer)
    - [offset\_image](#boards.manipulation.offset_image)
    - [offset\_outline](#boards.manipulation.offset_outline)
    - [offset\_board](#boards.manipulation.offset_board)
    - [offset\_path\_normal](#boards.manipulation.offset_path_normal)
    - [rotate\_aperture](#boards.manipulation.rotate_aperture)
    - [rotate\_point](#boards.manipulation.rotate_point)
    - [rotate\_path](#boards.manipulation.rotate_path)
    - [rotate\_layer](#boards.manipulation.rotate_layer)
    - [rotate\_image](#boards.manipulation.rotate_image)
    - [rotate\_outline](#boards.manipulation.rotate_outline)
    - [rotate\_board](#boards.manipulation.rotate_board)
    - [scale\_aperture](#boards.manipulation.scale_aperture)
    - [scale\_point](#boards.manipulation.scale_point)
    - [scale\_path](#boards.manipulation.scale_path)
    - [scale\_layer](#boards.manipulation.scale_layer)
    - [scale\_image](#boards.manipulation.scale_image)
    - [scale\_outline](#boards.manipulation.scale_outline)
    - [scale\_board](#boards.manipulation.scale_board)
    - [copy\_path](#boards.manipulation.copy_path)
    - [copy\_layer](#boards.manipulation.copy_layer)
    - [copy\_image](#boards.manipulation.copy_image)
    - [copy\_board](#boards.manipulation.copy_board)
    - [merge\_layers](#boards.manipulation.merge_layers)
    - [merge\_images](#boards.manipulation.merge_images)
    - [merge\_boards](#boards.manipulation.merge_boards)
  - [boards.panelization](#boards.panelization)
    - [empty\_image](#boards.panelization.empty_image)
    - [empty\_board](#boards.panelization.empty_board)
    - [panelize](#boards.panelization.panelize)
  - [boards.drawing](#boards.drawing)
    - [circle\_aperture](#boards.drawing.circle_aperture)
    - [draw\_path](#boards.drawing.draw_path)
    - [draw\_text](#boards.drawing.draw_text)

## 4.2 - boards module

This module is the main entry point for Aperture Scripting. It contains several high level functions to load and save boards.
### boards.load_image ( filepath, format, options )

Load the image in file *filepath*. *format* is one of the supported image formats as a string, or `nil` to trigger auto-detection. *options* is an optional table.

The *options* table can contain a field named `unit` that specifies the output length unit. Its value must be one of the supported length units as a string. The default is `'pm'`.
### boards.save_image ( image, filepath, format, options )

Save the *image* in the file *filepath*. *format* must be one of the supported image formats as a string. *options* is an optional table.

The *options* table can contain a field named `unit` that specifies the length unit of the input data. Its value must be one of the supported length units as a string, the default is `'pm'`. Note that at the moment only images in `'pm'` can be saved.

The unit used within the file is specified in the `unit` field of the *image* itself. Some formats also expect some more such fields, for example to specify the number of significant digits or whether to remove trailing zeroes (see the source, examples and individual format documentation for more details).
### boards.detect_format ( path )

Detect the format of the file *path*. Possible return values are `'gerber'`, `'excellon'`, `'dxf'`, `'svg'`, `'bom'` or `nil`.
### boards.load ( path, options )

Load the board specified by *path*, which can be either a string specifying a base path, or an array listing individual image file paths. *options* is an optional table.

The correspondance between the base path or paths table and individual images is based on a template, which can be specified in several ways:

  - If *path* is a string and ends with `'.conf'`, it is used as the template.
  - If *path* is a string and a file named *<path>.conf* exists, it is used as the template.
  - If *path* is an array and contains a string ending with `'.conf'`, this file is used as a template.
  - If the *options* table contain a field named `template` which string value corresponds to an existing file path, this file is used as a template.
  - If the *options* table contain a field named `template` which string value corresponds to a known template (see the `boards.templates` module), this template is used.
  - Otherwise the `default` template is used.

The template `patterns` field specifies a correspondance between filename patterns and image roles. If *path* is a string corresponding to an existing file, or an array of strings, these paths are matched against the template patterns and matching files are loaded as the corresponding images. If *path* is a string not corresponding to an existing file, it is used as a base path and matched against the template patterns to find files, which are loaded as the corresponding images if they exist.

All files format are automatically detected depending on content. The *options* table can contain a field named `unit` that specifies the output length unit. Its value must be one of the supported length units as a string. The default is `'pm'`.

Finally once all the files have been loaded a board outline is extracted from the various images. To avoid that last step and leave the outline paths in the images themselves (if you want to render them for example), you can set the *options* field `keep_outlines_in_images` to a true value.
### boards.save ( board, filepath )

Save the board *board* with the base name *filepath*. The board should contain fields `extensions` and `formats` that specify the individual file name pattern and file format (resp.) to use for each individual image. The input data unit should be specified in the board `unit` field (at the moment it must be `'pm'`).

Further format details and options on how to save each individual file should be specified in the images (as documented in [boards.save\_image](#boards.save_image)).
### boards.merge_apertures ( board )

Merge the identical apertures within each image of the board. This can save significant duplication when panelizing several identical or similar boards.
### boards.generate_aperture_paths ( board )

Generate a `paths` field in each aperture used in the *board*.

Most apertures are defined as ideal shapes (for example circles or rectangles). This function will generate a series of contours for each of these ideal shapes. These contours can be used for rasterization and rendering of the apertures. See the source code of [Gerber Viewer](http://piratery.net/grbv/) for more details on how to use these generated paths.

Note that to generate paths for apertures using macros, you will need the [lgpc module from lhf](http://www.tecgraf.puc-rio.br/~lhf/ftp/lua/#lgpc).
## 4.3 - boards.extents module

This module contain several functions to compute the extents of a board or its components. All extents are of type `region`, which is a table with fields `left`, `right`, `bottom` and `top`, virtual fields `width`, `height` `area` and `empty` and several operator overloads.
### boards.extents.compute_aperture_extents ( aperture )

Compute the extents of an aperture. This requires that the aperture paths have been previously generated (see [boards.generate\_aperture\_paths](#boards.generate_aperture_paths)).
### boards.extents.compute_image_extents ( image )

Compute the extents of an image. This does not include the aperture extents, if any.
### boards.extents.compute_board_extents ( board )

Compute the extents of a board. This does not include the aperture extents, if any.
## 4.4 - boards.manipulation module

This module contains many function to manipulate image data and whole boards. Most are self-explanatory. All these function create copies of the input data and won't reference it in the output, so the input can be later modified without the output to be affected.

The *apertures* and *macros* arguments of some of these functions are mapping tables used to preserve sharing of apertures and macros respectively. You can initialize these as empty tables and then pass them to all subsequent calls of the same category of manipulation function (ie. offset, rotate, scale, copy or merge).
### boards.manipulation.copy_point ( point, angle )


### boards.manipulation.offset_point ( point, dx, dy )


### boards.manipulation.offset_path ( path, dx, dy )


### boards.manipulation.offset_layer ( layer, dx, dy )


### boards.manipulation.offset_image ( image, dx, dy )


### boards.manipulation.offset_outline ( outline, dx, dy )


### boards.manipulation.offset_board ( board, dx, dy )


### boards.manipulation.offset_path_normal ( path, dn )


### boards.manipulation.rotate_aperture ( aperture, angle, macros )


### boards.manipulation.rotate_point ( point, angle )


### boards.manipulation.rotate_path ( path, angle, apertures, macros )


### boards.manipulation.rotate_layer ( layer, angle, apertures, macros )


### boards.manipulation.rotate_image ( image, angle, apertures, macros )


### boards.manipulation.rotate_outline ( outline, angle, apertures, macros )


### boards.manipulation.rotate_board ( board, angle )


### boards.manipulation.scale_aperture ( aperture, scale, macros )


### boards.manipulation.scale_point ( point, scale )


### boards.manipulation.scale_path ( path, scale, apertures, macros )


### boards.manipulation.scale_layer ( layer, scale, apertures, macros )


### boards.manipulation.scale_image ( image, scale, apertures, macros )


### boards.manipulation.scale_outline ( outline, scale, apertures, macros )


### boards.manipulation.scale_board ( board, scale )


### boards.manipulation.copy_path ( path, apertures, macros )


### boards.manipulation.copy_layer ( layer, apertures, macros )


### boards.manipulation.copy_image ( image, apertures, macros )


### boards.manipulation.copy_board ( board )


### boards.manipulation.merge_layers ( layer_a, layer_b, apertures, macros )


### boards.manipulation.merge_images ( image_a, image_b, apertures, macros )


### boards.manipulation.merge_boards ( board_a, board_b )


## 4.5 - boards.panelization module

This module contains several functions that will let you create panels, ie. assemblies of several small boards in larger 2D structures.
### boards.panelization.empty_image ()

Create an empty image, with a single empty dark layer, a default saved unit of `'in'`, and a number format specifying 2 integer digits, 4 decimal digits and missing leading zeroes.
### boards.panelization.empty_board ( width, height )

Create an empty board, without any image. If *width* and *height* are specified, a simple rectangle outline of that size is created, with the bottom-left corner aligned on the origin.
### boards.panelization.panelize ( layout, options, vertical )

Panelize the board specified in *layout*. The *layout* can have several levels, alternating horizontal (from left to right) and vertical (from bottom to top) directions. The direction of the root layer is vertical if *vertical* is true, horizontal otherwise.

*options* is a table which can be empty, or have any or all of the following options:

  - `spacing` determines the gap between boards (default is 2 mm)
  - `routing_tool_diameter` is the minimum diameter of the routing tool (default is `spacing`)
  - `break_hole_diameter` is the diameter of breaking holes (mouse bites, default is 0.5 mm)
  - `break_tab_width` is the width of the breaking tabs (default is 5 mm)
  - `tab_interval` is the minimum interval between two breaking tabs on long edges (default is 77 mm)
  - `break_lines_on_soldermask` determines whether to draw a break line on the soldermasks to ease panel breaking (default is true)
  - `break_line_offset` is the position of the breaking holes relative to the board edges; it can have the following values:
    - nil, `'none'` or `'edge'` will put the hole centers on the board edge (this is the default)
    - `'inside'` will move the holes completely inside the board outline (offset by one hole radius); this is recommended if you want a clean board outline without the need to file the edge after depanelization
    - `'outside'` will move the holes completely outside the board (offset by one hole radius); this is recommended if you want to file the board edge to have it look like it wasn't panelized
    - a number value can specify any other offset; positive values extend outside the board, negative values inside the board
  - `routing_mode` specifies how slots between boards are drawn; it can have the following values:
    - `'stroke'` will use strokes and flashes on the milling layer, with the routing tool or drill diameter as aperture (this is the default)
    - `'outline'` will draw zero-width outlines on the milling layer; this supports more complex outlines

Note that default values are internally specified in picometers. If your board use a different unit you'll need to override all options.
## 4.6 - boards.drawing module

This module contains several function that let you generate new image data dynamically. You can always manipulate images internal structures directly, but to maintain integrity (the format is rather complex) prefer using functions in this module.
### boards.drawing.circle_aperture ( diameter )

Create a simple circular aperture. Note that all paths except regions require an aperture. Even zero-width paths require a zero-width aperture, which you can create by passing 0 as the *diameter*. This aperture unit is always `'pm'`, which is the unit of the *diameter*.
### boards.drawing.draw_path ( image, aperture, ... )

Draw a path on the specified *image* using the specified *aperture*. Every two extra arguments are the X and Y positions of an extra point, specified in board units (usually picometers). If the path has a single point, it is a flash. Otherwise it is a stroke with linear interpolation between points.

If no aperture is provided, the path is a region, which means it must have at least 4 points and be closed (ie. last point must be the same as the first point). If you want to create a region you need to explicitly pass `nil` as second argument to `draw_path` before the points data.
### boards.drawing.draw_text ( image, polarity, fontname, size, mirror, halign, x, y, text )

Draw some text on the *image* using the font file specified by *fontname*. *text* is the drawn text, as a string encoded in UTF-8.

Each glyph is converted to regions on the top image layer or new layers if necessary, with the outside contour having the specified *polarity* (either `'dark'` or `'clear'`), and the glyph cutouts having the opposite polarity.

*size* is the font size in image data units (most likely picometers) and correspond usually to the height of an uppercase letter (this depends on the font). The text is logically positionned at coordinates *x* and *y* (still in image data units), with *halign* specifying how text is horizontally aligned relative to this point. *halign* can be one of the following strings:

  - `'left'`: the text logical position starts exactly on *x*
  - `'x0'`: the first glyph `left` attribute (which may or may not be meaningful depending on the font) is aligned on *x*
  - `'center'`: the text width is computed (including spacing and kerning) and the whole *text* string is centered on *x*

*mirror* is a boolean, indicating whether the text will read normally from left to right (if false) or be mirrored horizontally (if true). This is useful to draw text on bottom images. Note that is *mirror* is true and *halign* is `'left'`, it's the text right-most edge that will actually be on *x*.
# 5 - Examples

Here are some progressively more complex example scripts showing how you can use Aperture Scripting. To run them, copy the code in a text file and save that file, for example under the name `"panel.cfg"`. Then run that file through a Lua interpreter from your shell:

    lua panel.cfg

You might need to configure your `LUA_PATH` environment variable to let Lua find the Aperture Scripting modules. If you downloaded a Gerber Viewer package on Windows, you can simply run the lua.exe program from a command line:

    "D:\path\to\Gerber Viewer\lua.exe" panel.cfg

## 5.1 - Loading a board

The first step when using Aperture Scripting usually consist in loading some board that you exported from your CAD software. First you need to load the `boards` module:

	local boards = require 'boards'

Then to load a board you use the `boards.load` function:

	local simple = assert(boards.load('./simple'))

This will simply print all the corresponding Gerber and Excellon file names, and validate the data (ie. if there is some loading error, you should get an error message). In all examples below we start from this *simple* board, which looks like that:

![](https://bitbucket.org/doub/aperture-scripting/raw/tip/doc/examples/simple.png)


## 5.2 - Saving a board

The final step of any manipulation script usually involves saving your board data. The function to call is `boards.save`:

	local simple = assert(boards.load('./simple'))
	
	assert(boards.save(simple, './save'))

However when you combine several boards into one (like in the panelization examples below), some data in the board may get duplicated, for example aperture definitions. To save on disk space a bit, and more importantly to simplify output files, it is a good idea to merge all identical apertures before saving:

	boards.merge_apertures(simple)
	assert(boards.save(simple, './save'))

As expected the output is identical to the input:

![](https://bitbucket.org/doub/aperture-scripting/raw/tip/doc/examples/save.png)

## 5.3 - Rotating a board

One common manipulation of boards consist in rotating them, for example because they are not square and better fit in another direction. Rotation and most manipulation are in the `boards.manipulation` module:

	local manipulation = require 'boards.manipulation'

To rotate a board call `manipulation.rotate_board` with the board and a direct angle value in degrees as arguments:

	local rotate = manipulation.rotate_board(simple, 90)
	
	assert(boards.save(rotate, './rotate'))

The result is the same board as above, but rotated 90°:

![](https://bitbucket.org/doub/aperture-scripting/raw/tip/doc/examples/rotate.png)

## 5.4 - Panelizing boards

One of the most important features of Aperture Scripting is its ability to panelize boards, ie. to assemble several boards into a larger one. This is probably why you want to use Aperture Scripting. The module you need for that is `boards.panelization`:

	local panelization = require 'boards.panelization'

There you will find a `panelization.panelize` function that receives a layout table, an options table, a top-level orientation and that returns a new board object for the panel.

	local simple = assert(boards.load('./simple'))
	
	local panel = assert(panelization.panelize({ simple, simple }, {}, true))
	
	boards.merge_apertures(panel)
	assert(boards.save(panel, './panel'))

Here the layout contains two copies of the *simple* board. These are actually Lua references, but since we don't modify them during panelization you can reuse the same board object several times. The options table is empty to use the defaults. The third argument `true` means the panel top-level is vertical. We're making a vertical panel because the *simple* board has a slot on its left side which would prevent the insertion of a break tab.

The resulting panel looks like that:

![](https://bitbucket.org/doub/aperture-scripting/raw/tip/doc/examples/panel.png)

As you can see the `panelize` function automatically placed the sub-boards with a 2 mm gap, and it created a break tab to connect the two boards.

## 5.5 - Panelizing modified boards

Of course you can combine the above operations to first modify the board, and then use the modified copy in a panel. Since our *simple* board has a slot on its left, we'll create a rotated copy with the slot on the right, so that we can create an horizontal panel.

	local simple = assert(boards.load('./simple'))
	local simple180 = manipulation.rotate_board(simple, 180)
	
	local panel = assert(panelization.panelize({ simple, simple180 }, {}, false))
	
	boards.merge_apertures(panel)
	assert(boards.save(panel, './panel-rotate'))

As we have seen above the `rotate_board` function returns the rotated board. This means the original board is left intact, and we can use both in the panel. Generally the functions in the `boards.manipulation` module will create copies of the input data, which is kept unmodified.

This time we passed `false` as third argument to `panelize`, which means we want a horizontal panel. The result of this panel is as follows:

![](https://bitbucket.org/doub/aperture-scripting/raw/tip/doc/examples/panel-rotate.png)

To verify that the right board has been rotated and not mirrored, you can check the little hole in the trace, which the left board has on the top-right, but which the right board has on the bottom-left.

## 5.6 - Creating empty boards

Sometimes you not only want to manipulate and assemble existing boards, but you may want to create new boards on the fly. For example you may want to put spacers between boards in a panel to account for over-hanging components, or you might want to add a frame with tooling holes and fiduciaries.

The `panelization` module has a function named `empty_board` that lets you create such an empty board. You can either pass dimensions so that your board is created with a rectangle outline, or call the function without arguments to get a completely empty board without dimensions (to be used as a canvas for drawing, see below). We'll try to create a 1 cm breaking tab the same width as the panel above. First we need the simple board dimensions:

	local extents = require 'boards.extents'
	
	local simple_extents = extents.compute_board_extents(simple)

Then we can create the tab based on these dimensions. We'll assume the default 2 mm gap between boards:

	local height = 10*mm
	local width = simple_extents.width * 2 + 2*mm
	local tab = panelization.empty_board(width, height)

However since the board has no image (it's empty), you cannot save it on its own. We'll see later how to save a board generated from scratch, but we already can use that empty board in panels.

## 5.7 - Panelizing panels

A panel is just a board, so you can use it as input in a `panelize` call. This way you can create more complex panels in several steps (we'll see below how to achieve the same in one step). We'll reuse the rotated-panel above, and the empty tab we just created:

	local panel = panelization.panelize({ tab, panel, tab }, {}, true)
	boards.merge_apertures(panel)
	boards.save(panel, './panel-panel')

And here is the result:

![](https://bitbucket.org/doub/aperture-scripting/raw/tip/doc/examples/panel-panel.png)

One interesting thing to note is that each copy of the empty board is joined to the center panel with two breaking tabs. The `panelize` function will try to be smart about where to place breaking tabs. This can be controlled to some extents with the `options` table, or in the way the outline path is defined in the input boards, but that's a story for another day.

## 5.8 - Complex panels in one step

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

![](https://bitbucket.org/doub/aperture-scripting/raw/tip/doc/examples/panel-layout.png)

## 5.9 - Drawing on boards

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

![](https://bitbucket.org/doub/aperture-scripting/raw/tip/doc/examples/drawing-fiducials.png)

## 5.10 - Drawing text

Aperture Scripting has some basic support to load vector fonts and draw text. At the moment glyph outlines are approximated with Gerber regions made of circular arc segments, so they might not precisely fit the Bezier curves of your font (please tell me if you need something more precise, I can add some subdivision code).

To draw text, simply call the `drawing.draw_text` function. Parameters are the image on which to draw, the drawing polarity (`'dark'` for normal, `'clear'` for inverted), the font filename, the font size (roughly an uppercase letter height, but that depends on the font), a boolean telling whether to mirror the text (for bottom layers) or not, an alignment side (`'left'` or `'center'`), X and Y positions, and finally a string with the text itself in UTF-8. For example (reusing the horizontal tab width from the previous example):

	drawing.draw_text(panel.images.top_silkscreen, 'dark', "constantine.ttf", 6*mm, false, 'center', width / 2, 2.5*mm, "Aperture")

The resulting board now has some nice silkscreen text on the bottom tab:

![](https://bitbucket.org/doub/aperture-scripting/raw/tip/doc/examples/drawing-text.png)

## 5.11 - Saving a board made from scratch

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

![](https://bitbucket.org/doub/aperture-scripting/raw/tip/doc/examples/empty-save.png)

