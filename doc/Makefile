
gendoc:logo.png
	../../doc/gendoc
	make -C examples

logo.png:logo.ps gerber-2000.png Makefile
	convert \
		logo.ps \
		'(' gerber-2000.png -trim +repage -resize 724x724 -crop 1080x1080-195-206\! -background none -flatten ')' \
		-compose blend -composite -resize 128x128 $@
