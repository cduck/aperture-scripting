
MODULES= \
	boards \
	boards.aperture \
	boards.drawing \
	boards.extents \
	boards.interpolation \
	boards.macro \
	boards.manipulation \
	boards.panelization \
	boards.pathmerge \
	boards.region \
	boards.spline \
	boards.templates \
	bom \
	dxf \
	dxf.defaults \
	dxf.defaults_inkscape \
	excellon \
	excellon.blocks \
	gerber \
	gerber.blocks \
	svg \

TESTS=$(patsubst %,test-%,$(MODULES))
ifeq ($(OS),Windows_NT)
SLASH=$(subst a,,a\a)
LUA=lua.exe
else
SLASH=/
LUA=lua
endif

export LUA_PATH=.$(SLASH)?.lua;;

.PHONY:test test-init $(TESTS)

test:test-init $(TESTS)
	@$(LUA) -lluacov test-misc.lua >/dev/null
	@luacov
	@$(LUA) -e "print((io.open('luacov.report.out', 'rb'):read('*all'):gsub('^.*\n(====*\r?\nSummary)', '%1'):gsub('\r?\n$$', '')))"

test-init:
	@rm -f luacov*

$(TESTS):
	@lua -lluacov .$(SLASH)$(subst .,$(SLASH),$(patsubst test-%,%,$@)).lua

.PHONY:clean
clean:
	rm -rf test/copy.grb test/copy.drl test/merged.grb test/merged.drl test/simple.copy

