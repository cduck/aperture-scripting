local os = require 'os'
local fs = require 'lfs'
local gerber = require 'gerber'
local excellon = require 'excellon'
local boards = require 'boards'
local extents = require 'boards.extents'
local manipulation = require 'boards.manipulation'

------------------------------------------------------------------------------

local function rmdir(dir)
	return os.execute('rm -rf '..dir)
end

local function diff(a, b)
	return os.execute('diff -durN '..a..' '..b)
end

------------------------------------------------------------------------------

assert(gerber.load("test/example2.grb"))
assert(boards.load("test/simple/simple"))

os.remove('test/copy.grb')
assert(gerber.save(assert(gerber.load("test/example2.grb")), "test/copy.grb"))
assert(diff('test/copy.grb.expected', 'test/copy.grb'))

os.remove('test/copy.drl')
assert(excellon.save(assert(excellon.load("test/example.drl")), "test/copy.drl"))
assert(diff('test/copy.drl.expected', 'test/copy.drl'))

-- copy a board
assert(rmdir('test/simple.copy'))
assert(fs.mkdir('test/simple.copy'))
assert(boards.save(assert(boards.load("test/simple/simple")), "test/simple.copy/simple"))
assert(diff('test/simple.copy.expected', 'test/simple.copy'))

-- copy a copy of a board
assert(rmdir('test/simple.copy2'))
assert(fs.mkdir('test/simple.copy2'))
assert(boards.save(assert(boards.load("test/simple.copy/simple")), "test/simple.copy2/simple"))
assert(diff('test/simple.copy.expected', 'test/simple.copy2'))

-- null offset, should be a copy
assert(rmdir('test/simple.offset-0-0'))
assert(fs.mkdir('test/simple.offset-0-0'))
assert(boards.save(assert(manipulation.offset_board(assert(boards.load("test/simple/simple")), 0, 0)), "test/simple.offset-0-0/simple"))
assert(diff('test/simple.copy.expected', 'test/simple.offset-0-0'))
-- move one inch to the right
assert(rmdir('test/simple.offset-1in-0'))
assert(fs.mkdir('test/simple.offset-1in-0'))
assert(boards.save(assert(manipulation.offset_board(assert(boards.load("test/simple/simple")), 254e8, 0)), "test/simple.offset-1in-0/simple"))
assert(diff('test/simple.offset-1in-0.expected', 'test/simple.offset-1in-0'))

local a = assert(boards.load_image('test/example.drl'))
local b = assert(manipulation.offset_image(a, 254e9, 0))
local c = assert(manipulation.merge_images(a, b))
assert(boards.save_image(c, 'test/merged.drl', 'excellon'))
assert(diff('test/merged.drl.expected', 'test/merged.drl'))
assert(rmdir('test/simple.merge-a'))
assert(fs.mkdir('test/simple.merge-a'))
local a = assert(boards.load('test/simple/simple', {keep_outlines_in_images=true}))
-- move one inch to the right
local b = assert(manipulation.offset_board(a, 254e8, 0))
local c = assert(manipulation.merge_boards(a, b))
boards.merge_apertures(c)
assert(boards.save(c, 'test/simple.merge-a/simple'))
assert(diff('test/simple.merge-a.expected', 'test/simple.merge-a'))

------------------------------------------------------------------------------

local image = boards.load_image('test/example2.grb')
manipulation.offset_image(image, 3, 4)
manipulation.rotate_image(image, 0)
manipulation.rotate_image(image, 90)
manipulation.rotate_image(image, 180)
manipulation.rotate_image(image, 270)

local board = assert(boards.load('test/simple/simple'))
board = assert(manipulation.rotate_board(board, 90))
assert(boards.save(board, 'test/output/tmp'))

------------------------------------------------------------------------------

local board = assert(boards.load("test/apertures"))
boards.generate_aperture_paths(board)
manipulation.rotate_board(board, 0)
manipulation.rotate_board(board, 90)
manipulation.rotate_board(board, 180)
manipulation.rotate_board(board, 270)

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

boards.merge_apertures(board)

extents.compute_board_extents(board)
board.outline = nil
extents.compute_board_extents(board)

local board = assert(boards.load("test/rotate"))
boards.generate_aperture_paths(board)
manipulation.rotate_board(board, 0)
manipulation.rotate_board(board, 90)
manipulation.rotate_board(board, 180)
manipulation.rotate_board(board, 270)
manipulation.rotate_board(board, 17)
manipulation.rotate_board(board, 97)
manipulation.rotate_board(board, 181)
manipulation.rotate_board(board, 271)

------------------------------------------------------------------------------

local board = assert(boards.load("test/paths"))
boards.interpolate_paths(board)

local board = assert(boards.load("test/paths", {unit='mm'}))

------------------------------------------------------------------------------

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

------------------------------------------------------------------------------

print("all tests passed successfully")
