local gerber = require 'gerber'
local boards = require 'boards'
local manipulation = require 'boards.manipulation'

local image = boards.load_image('test/example2.grb')
manipulation.offset_image(image, 3, 4)
manipulation.rotate_image(image, 0)
manipulation.rotate_image(image, 90)
manipulation.rotate_image(image, 180)
manipulation.rotate_image(image, 270)

local board = assert(boards.load('test/simple/simple'))
board = assert(manipulation.rotate_board(board, 90))
assert(boards.save(board, 'test/tmp/tmp'))

print("all tests passed successfully")
