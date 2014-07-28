SCRIPTS=save rotate panel panel-rotate panel-panel panel-layout drawing-fiducials
EXTS=oln drd gml gtl gts gto gbl gbs gbo

build:$(patsubst %,%.gtl,$(SCRIPTS))

%.gtl:%.cfg $(patsubst %,simple.%,$(EXTS))
	lua $<

clean:
	rm -f $(foreach ext,$(EXTS),$(patsubst %,%.$(ext),$(SCRIPTS)))

.PHONY:build clean
