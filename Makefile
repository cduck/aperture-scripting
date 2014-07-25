
export LUA_PATH=./?.lua;;

.PHONY:test
test:test-check test-copy test-offset test-merge test-misc
	lua boards/manipulation.lua
	lua test-misc.lua

.PHONY:clean
clean:
	rm -rf test/copy.grb test/copy.drl test/merged.grb test/merged.drl test/simple.copy

