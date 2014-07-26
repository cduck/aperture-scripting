SCRIPTS=save rotate panel panel2 panel3
EXTS=oln drd gml gtl gto gts gbl gbo gbs

build:$(patsubst %,%.gtl,$(SCRIPTS))

%.gtl:%.cfg
	lua $<

clean:
	rm -f $(foreach ext,$(EXTS),$(patsubst %,%.$(ext),$(SCRIPTS)))

.PHONY:build clean
