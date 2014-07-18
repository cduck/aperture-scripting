SCRIPTS=save rotate panel panel2 panel3

build:$(patsubst %,%.gtl,$(SCRIPTS))

%.gtl:%.cfg
	lua $<

.PHONY:build
