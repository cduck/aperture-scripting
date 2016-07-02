-- Import libraries
local boards =       require 'boards'
local manipulation = require 'boards.manipulation'
local extents =      require 'boards.extents'
local panelization = require 'boards.panelization'

-- Constants
local mm = 1000000000

-- Load individual board gerbers
local simple = assert(boards.load('./test/simple/simple'))
--local rounded = assert(boards.load('./test/rounded/rounded'))

-- Calculate board sizes
local simpleExtents = extents.compute_board_extents(simple)
print(simpleExtents.width)
print(simpleExtents.height)

-- Create empty boards
local height = 10*mm
local width = simpleExtents.width * 2 + 2*mm
local tab = panelization.empty_board(width, height)

-- Rotate boards
local simple90 = manipulation.rotate_board(simple, 90)

-- Define panel layout
local layout = {
  tab,
  { simple90, simple90 },
  tab,
}



local panel = panelization.panelize(layout, {}, true)

-- Save the panel gerbers
boards.merge_apertures(panel)
assert(boards.save(panel, './temp/panel'))


