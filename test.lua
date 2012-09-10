local gerber = require 'gerber'

local data = assert(gerber.load("example2.ger"))

--assert(#data == 1)
--assert(#data[1].layers == 3)

assert(gerber.save(data, "tmp.ger"))

print("all tests passed successfully")
