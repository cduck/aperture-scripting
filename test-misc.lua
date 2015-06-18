local os = require 'os'
local fs = require 'lfs'
local gerber = require 'gerber'
local excellon = require 'excellon'
local boards = require 'boards'
local extents = require 'boards.extents'
local manipulation = require 'boards.manipulation'
local panelization = require 'boards.panelization'
local interpolation = require 'boards.interpolation'

local function log(s, ...)
	print('- '..s, ...)
end

------------------------------------------------------------------------------

local function rmdir(dir)
	return os.execute('rm -rf '..dir)
end

local function diff(a, b)
	return os.execute('diff -durN '..a..' '..b)
end

------------------------------------------------------------------------------

log 'load gerber'
assert(gerber.load("test/example2.grb"))
log 'load board'
assert(boards.load("test/simple/simple"))

log 'copy gerber'
os.remove('test/copy.grb')
assert(gerber.save(assert(gerber.load("test/example2.grb")), "test/copy.grb"))
assert(diff('test/copy.grb.expected', 'test/copy.grb'))

log 'copy excellon'
os.remove('test/copy.drl')
assert(excellon.save(assert(excellon.load("test/example.drl")), "test/copy.drl"))
assert(diff('test/copy.drl.expected', 'test/copy.drl'))
for _,test in ipairs{'a', 'b', 'c'} do
	os.remove('test/excellon/'..test..'.drl')
	assert(excellon.save(assert(excellon.load("test/excellon/"..test..".drl.in")), "test/excellon/"..test..".drl"))
	assert(diff('test/excellon/'..test..'.drl.out', 'test/excellon/'..test..'.drl'))
end

log 'copy board'
assert(rmdir('test/simple.copy'))
assert(fs.mkdir('test/simple.copy'))
assert(boards.save(assert(boards.load("test/simple/simple")), "test/simple.copy/simple"))
assert(diff('test/simple.copy.expected', 'test/simple.copy'))

log 'copy copy of board'
assert(rmdir('test/simple.copy2'))
assert(fs.mkdir('test/simple.copy2'))
assert(boards.save(assert(boards.load("test/simple.copy/simple")), "test/simple.copy2/simple"))
assert(diff('test/simple.copy.expected', 'test/simple.copy2'))

log 'null offset' -- should be a copy
assert(rmdir('test/simple.offset-0-0'))
assert(fs.mkdir('test/simple.offset-0-0'))
assert(boards.save(assert(manipulation.offset_board(assert(boards.load("test/simple/simple")), 0, 0)), "test/simple.offset-0-0/simple"))
assert(diff('test/simple.copy.expected', 'test/simple.offset-0-0'))
log 'move one inch to the right'
assert(rmdir('test/simple.offset-1in-0'))
assert(fs.mkdir('test/simple.offset-1in-0'))
assert(boards.save(assert(manipulation.offset_board(assert(boards.load("test/simple/simple")), 254e8, 0)), "test/simple.offset-1in-0/simple"))
assert(diff('test/simple.offset-1in-0.expected', 'test/simple.offset-1in-0'))

log 'manipulate excellon'
local a = assert(boards.load_image('test/example.drl'))
local b = assert(manipulation.offset_image(a, 254e9, 0))
local c = assert(manipulation.merge_images(a, b))
assert(boards.save_image(c, 'test/merged.drl', 'excellon'))
assert(diff('test/merged.drl.expected', 'test/merged.drl'))
assert(rmdir('test/simple.merge-a'))
assert(fs.mkdir('test/simple.merge-a'))
log 'manipulate board'
local a = assert(boards.load('test/simple/simple', {keep_outlines_in_images=true}))
-- move one inch to the right
local b = assert(manipulation.offset_board(a, 254e8, 0))
local c = assert(manipulation.merge_boards(a, b))
boards.merge_apertures(c)
assert(boards.save(c, 'test/simple.merge-a/simple'))
assert(diff('test/simple.merge-a.expected', 'test/simple.merge-a'))

------------------------------------------------------------------------------

local image = boards.load_image('test/example2.grb')
log 'offset gerber'
manipulation.offset_image(image, 3, 4)
log 'rotate gerber (0)'
manipulation.rotate_image(image, 0)
log 'rotate gerber (90)'
manipulation.rotate_image(image, 90)
log 'rotate gerber (180)'
manipulation.rotate_image(image, 180)
log 'rotate gerber (270)'
manipulation.rotate_image(image, 270)

log 'rotate board'
local board = assert(boards.load('test/simple/simple'))
board = assert(manipulation.rotate_board(board, 90))
assert(boards.save(board, 'test/output/tmp'))

------------------------------------------------------------------------------

log 'load all apertures'
local board = assert(boards.load("test/apertures"))
boards.generate_aperture_paths(board)

log 'save all apertures'
assert(boards.save(board, "test/output/apertures"))

log 'rotate all apertures'
manipulation.rotate_board(board, 0)
local rotated = manipulation.rotate_board(board, 90)
manipulation.rotate_board(board, 180)
manipulation.rotate_board(board, 270)

log 'save rotated apertures'
assert(boards.save(rotated, "test/output/apertures-rotated"))

log 'compute aperture extents'
local apertures = {}
for _,image in pairs(board.images) do
	for _,layer in ipairs(image.layers) do
		for  _,path in ipairs(layer) do
			if path.aperture then
				apertures[path.aperture] = true
			end
		end
	end
end
for aperture in pairs(apertures) do
	extents.compute_aperture_extents(aperture)
end

log 'merge apertures'
boards.merge_apertures(board)

log 'compute board extents (with outline)'
extents.compute_board_extents(board)
log 'compute board extents (without outline)'
board.outline = nil
extents.compute_board_extents(board)

log 'load rotatable apertures'
local board = assert(boards.load("test/rotate"))
boards.generate_aperture_paths(board)

log 'save rotatable apertures'
assert(boards.save(board, "test/output/rotate"))

log 'rotate rotatable apertures'
manipulation.rotate_board(board, 0)
manipulation.rotate_board(board, 90)
manipulation.rotate_board(board, 180)
manipulation.rotate_board(board, 270)
manipulation.rotate_board(manipulation.rotate_board(board, 180), 180)
local rotated = manipulation.rotate_board(board, 17)
manipulation.rotate_board(board, 97)
manipulation.rotate_board(board, 181)
manipulation.rotate_board(board, 271)
manipulation.rotate_board(manipulation.rotate_board(board, 180), 17)

log 'save rotated rotatable apertures'
assert(boards.save(rotated, "test/output/rotate-rotated"))

------------------------------------------------------------------------------

log 'load all macros'
local board = assert(boards.load("test/macros"))

------------------------------------------------------------------------------

log 'check all paths'
local board = assert(boards.load("test/paths"))
log 'interpolate paths'
interpolation.interpolate_board_paths(board, 0.01e-9)

log 'load paths as mm'
local board = assert(boards.load("test/paths", {unit='mm'}))

------------------------------------------------------------------------------

log 'load board with BOM'
local board = assert(boards.load("test/pwrsppl"))

log 'save board with BOM'
assert(boards.save(board, "test/output/pwrsppl"))

log 'rotate board with BOM (90°)'
local rotated = manipulation.rotate_board(board, 90)

log 'save rotated board with BOM (90°)'
assert(boards.save(rotated, "test/output/pwrsppl-rotated90"))

log 'rotate board with BOM (17°)'
local rotated = manipulation.rotate_board(board, 17)

log 'save rotated board with BOM (17°)'
assert(boards.save(rotated, "test/output/pwrsppl-rotated17"))

------------------------------------------------------------------------------

log 'change board unit'
local board = assert(boards.load("test/units"))
for _,image in pairs(board.images) do
	image.unit = 'mm'
	image.format = {integer=3, decimal=4, zeroes='L'}
end
assert(boards.save(board, "test/output/units"))
assert(diff("test/output/units.gts", "test/output/units.gtl"))

------------------------------------------------------------------------------

log 'panelize rounded corners'
local rounded = assert(boards.load('test/rounded/rounded'))
rounded.extensions.milling = '%.gml'
rounded.formats.milling = 'gerber'
local roundedh = assert(boards.load('test/rounded/roundedh'))
roundedh.extensions.milling = '%.gml'
roundedh.formats.milling = 'gerber'

local panel = panelization.panelize({ rounded, rounded }, {}, false)
boards.merge_apertures(panel)
assert(boards.save(panel, 'test/rounded/panelh'))
assert(diff('test/rounded/panelh-expected.oln', 'test/rounded/panelh.oln'))
assert(diff('test/rounded/panelh-expected.gml', 'test/rounded/panelh.gml'))

local panel = panelization.panelize({ rounded, rounded }, {}, true)
boards.merge_apertures(panel)
assert(boards.save(panel, 'test/rounded/panelv'))
assert(diff('test/rounded/panelv-expected.oln', 'test/rounded/panelv.oln'))
assert(diff('test/rounded/panelv-expected.gml', 'test/rounded/panelv.gml'))

local panel = panelization.panelize({ { rounded, rounded }, { rounded, rounded } }, {}, true)
boards.merge_apertures(panel)
assert(boards.save(panel, 'test/rounded/panel2'))
assert(diff('test/rounded/panel2-expected.oln', 'test/rounded/panel2.oln'))
assert(diff('test/rounded/panel2-expected.gml', 'test/rounded/panel2.gml'))

local panel = panelization.panelize({ rounded, rounded }, { routing_mode = 'outline' }, false)
boards.merge_apertures(panel)
assert(boards.save(panel, 'test/rounded/panelho'))
assert(diff('test/rounded/panelho-expected.oln', 'test/rounded/panelho.oln'))
assert(diff('test/rounded/panelho-expected.gml', 'test/rounded/panelho.gml'))

local panel = panelization.panelize({ rounded, rounded }, { routing_mode = 'outline' }, true)
boards.merge_apertures(panel)
assert(boards.save(panel, 'test/rounded/panelvo'))
assert(diff('test/rounded/panelvo-expected.oln', 'test/rounded/panelvo.oln'))
assert(diff('test/rounded/panelvo-expected.gml', 'test/rounded/panelvo.gml'))

local panel = panelization.panelize({ { rounded, rounded }, { rounded, rounded } }, { routing_mode = 'outline' }, true)
boards.merge_apertures(panel)
assert(boards.save(panel, 'test/rounded/panel2o'))
assert(diff('test/rounded/panel2o-expected.oln', 'test/rounded/panel2o.oln'))
assert(diff('test/rounded/panel2o-expected.gml', 'test/rounded/panel2o.gml'))

------------------------------------------------------------------------------

log 'run example panels'
fs.chdir('doc/examples')

dofile('save.cfg')
dofile('rotate.cfg')
dofile('panel.cfg')
dofile('panel-rotate.cfg')
dofile('empty.cfg')
dofile('panel-panel.cfg')
dofile('panel-layout.cfg')
dofile('drawing-fiducials.cfg')
dofile('drawing-text.cfg')
dofile('empty-save.cfg')

------------------------------------------------------------------------------

log 'all tests passed successfully'
