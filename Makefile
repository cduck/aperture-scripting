GERBERS= \
	../boards/gerber/hub.gbl \
	../boards/gerber/hub.gbo \
	../boards/gerber/hub.gbs \
	../boards/gerber/hub.gml \
	../boards/gerber/hub.gtl \
	../boards/gerber/hub.gto \
	../boards/gerber/hub.gts \
	../boards/gerber/hub.txt \
	../boards/gerber/motor3-jtag.gbl \
	../boards/gerber/motor3-jtag.gbo \
	../boards/gerber/motor3-jtag.gbs \
	../boards/gerber/motor3-jtag.gml \
	../boards/gerber/motor3-jtag.gtl \
	../boards/gerber/motor3-jtag.gto \
	../boards/gerber/motor3-jtag.gts \
	../boards/gerber/motor3-jtag.txt \
	../boards/gerber/motor3.gbl \
	../boards/gerber/motor3.gbo \
	../boards/gerber/motor3.gbs \
	../boards/gerber/motor3.gml \
	../boards/gerber/motor3.gtl \
	../boards/gerber/motor3.gto \
	../boards/gerber/motor3.gts \
	../boards/gerber/motor3.txt \
	../boards/gerber/motor7-jtag.gbl \
	../boards/gerber/motor7-jtag.gbo \
	../boards/gerber/motor7-jtag.gbs \
	../boards/gerber/motor7-jtag.gml \
	../boards/gerber/motor7-jtag.gtl \
	../boards/gerber/motor7-jtag.gto \
	../boards/gerber/motor7-jtag.gts \
	../boards/gerber/motor7-jtag.txt \
	../boards/gerber/motor7.gbl \
	../boards/gerber/motor7.gbo \
	../boards/gerber/motor7.gbs \
	../boards/gerber/motor7.gml \
	../boards/gerber/motor7.gtl \
	../boards/gerber/motor7.gto \
	../boards/gerber/motor7.gts \
	../boards/gerber/motor7.txt \
	../boards/gerber/sensor.gbl \
	../boards/gerber/sensor.gbo \
	../boards/gerber/sensor.gbs \
	../boards/gerber/sensor.gml \
	../boards/gerber/sensor.gtl \
	../boards/gerber/sensor.gto \
	../boards/gerber/sensor.gts \
	../boards/gerber/sensor.txt

.PHONY:all
all:check merge test

.PHONY:check
check:
	grbcheck $(GERBERS)

.PHONY:merge
merge:
#	grbmerge -offset +0+0 example2.ger -offset +10+0 example2.ger merged.ger
	grbmerge -offset +0+0 ../boards/gerber/motor7.gtl -offset +0.82677+0 ../boards/gerber/motor7.gtl panel.gtl

.PHONY:copy
copy:
	grbcopy ../boards/gerber/motor7.gtl motor7.gtl

.PHONY:test
test:
	lua test.lua

