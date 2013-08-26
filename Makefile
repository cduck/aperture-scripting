
.PHONY:test
test:test-check test-copy test-merge test-misc

.PHONY:test-check
test-check:
	grbcheck test/example2.grb
	brdcheck test/simple/simple

.PHONY:test-copy
test-copy:test/simple.copy
#	grbcopy test/example2.grb test/copy.grb
#	diff -durN test/copy.grb.expected test/copy.grb
#	drlcopy test/example.drl test/copy.drl
#	diff -durN test/copy.drl.expected test/copy.drl
	brdcopy test/simple/simple test/simple.copy/simple
	diff -durN test/simple test/simple.copy

test/simple.copy:
	mkdir test/simple.copy

.PHONY:test-merge
test-merge:
#	grbmerge -offset +0+0 test/example2.grb -offset +10+0 test/example2.grb test/merged.grb
#	diff -durN test/merged.grb.expected test/merged.grb
#	drlmerge -offset +0+0 test/example.drl -offset +10+0 test/example.drl test/merged.drl
#	diff -durN test/merged.drl.expected test/merged.drl

.PHONY:test-misc
test-misc:
	lua test.lua

.PHONY:clean
clean:
	rm -rf test/copy.grb test/copy.drl test/merged.grb test/merged.drl test/simple.copy

