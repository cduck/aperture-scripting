
.PHONY:test
test:test-check test-copy test-merge test-misc

.PHONY:test-check
test-check:
	grbcheck test/example2.grb

.PHONY:test-copy
test-copy:
	grbcopy test/example2.grb test/copy.grb
	diff -q test/copy.grb test/copy.grb.expected
	drlcopy test/example.drl test/copy.drl
	diff -q test/copy.drl test/copy.drl.expected

.PHONY:test-merge
test-merge:
	grbmerge -offset +0+0 test/example2.grb -offset +10+0 test/example2.grb test/merged.grb
	diff -q test/merged.grb test/merged.grb.expected
	drlmerge -offset +0+0 test/example.drl -offset +10+0 test/example.drl test/merged.drl
	diff -q test/merged.drl test/merged.drl.expected

.PHONY:test-misc
test-misc:
	lua test.lua

.PHONY:clean
clean:
	rm -f test/copy.grb test/copy.drl test/merged.grb test/merged.drl

