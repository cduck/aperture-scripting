
export LUA_PATH=./?.lua;;

.PHONY:test
test:
	lua boards/manipulation.lua
	lua test-misc.lua

.PHONY:clean
clean:
	rm -rf test/copy.grb test/copy.drl test/merged.grb test/merged.drl test/simple.copy

