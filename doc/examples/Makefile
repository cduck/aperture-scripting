SCRIPTS=save rotate panel panel-rotate panel-panel panel-layout drawing-fiducials
#EXTS=oln drd gml gtl gto gts gbl gbo gbs
EXTS=oln drd gml gtl gts gbl gbs

build:$(patsubst %,%.gtl,$(SCRIPTS))

%.gtl:%.cfg $(patsubst %,simple.%,$(EXTS))
	lua $<

clean:
	rm -f $(foreach ext,$(EXTS),$(patsubst %,%.$(ext),$(SCRIPTS)))

.PHONY:build clean
