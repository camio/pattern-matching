.PHONY: all
all: pattern_matching.html

%.html: %.md
	pandoc -s $< > $@
