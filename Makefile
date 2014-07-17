
export LUA_PATH=./?.lua;;
export PATH:=.:$(PATH)

.PHONY:test
test:test-check test-copy test-offset test-merge test-misc

.PHONY:test-check
test-check:
	grbcheck test/example2.grb
	brdcheck test/simple/simple

.PHONY:test-copy
test-copy:
	@rm -rf test/copy.grb
	grbcopy test/example2.grb test/copy.grb
	diff -durN test/copy.grb.expected test/copy.grb
#	@rm -rf test/copy.drl
#	drlcopy test/example.drl test/copy.drl
#	diff -durN test/copy.drl.expected test/copy.drl
	# copy a board
	@rm -rf test/simple.copy
	@mkdir test/simple.copy
	brdcopy test/simple/simple test/simple.copy/simple
	diff -durN test/simple.copy.expected test/simple.copy
	# copy a copy of a board
	@rm -rf test/simple.copy2
	@mkdir test/simple.copy2
	brdcopy test/simple.copy/simple test/simple.copy2/simple
	diff -durN test/simple.copy.expected test/simple.copy2

.PHONY:test-offset
test-offset:
	# null offset, should be a copy
	@rm -rf test/simple.offset-0-0
	@mkdir test/simple.offset-0-0
	brdoffset test/simple/simple 0 0 test/simple.offset-0-0/simple
	diff -durN test/simple.copy.expected test/simple.offset-0-0
	# move one inch to the right
	@rm -rf test/simple.offset-1in-0
	@mkdir test/simple.offset-1in-0
	brdoffset test/simple/simple 1in 0 test/simple.offset-1in-0/simple
	diff -durN test/simple.offset-1in-0.expected test/simple.offset-1in-0

.PHONY:test-merge
test-merge:
#	drlmerge -offset +0+0 test/example.drl -offset +10+0 test/example.drl test/merged.drl
#	diff -durN test/merged.drl.expected test/merged.drl
	# move one inch to the right
	@rm -rf test/simple.merge-a
	@mkdir test/simple.merge-a
	brdmerge -offset +0+0 test/simple/simple -offset +25.4+0 test/simple/simple test/simple.merge-a/simple
	diff -durN test/simple.merge-a.expected test/simple.merge-a

.PHONY:test-misc
test-misc:
	lua boards/manipulation.lua
	lua test-misc.lua

.PHONY:clean
clean:
	rm -rf test/copy.grb test/copy.drl test/merged.grb test/merged.drl test/simple.copy

