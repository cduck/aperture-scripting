
gendoc:logo.png
	../../doc/gendoc
	make -C examples

logo.png:logo.ps gerber-2000.png Makefile aperture.png
	convert \
		-resize 1080x1080 \
		canvas:none canvas:gray75 aperture.png \
		-compose src-over -composite \
		logo.ps -composite \
		'(' gerber-2000.png -trim +repage -resize 724x724 -crop 1080x1080-195-206\! -background none -flatten ')' -composite \
		-resize 128x128 $@

aperture.png:aperture.gto rasterize.conf
	rasterize

aperture.gto:gen-logo.lua
	lua $<

