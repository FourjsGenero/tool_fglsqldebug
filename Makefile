FORMS=$(patsubst %.per,%.42f,$(wildcard *.per))
MODULES=$(patsubst %.4gl,%.42m,$(wildcard *.4gl))

all: $(MODULES) $(FORMS)

run:: all
	fglrun fglsqldebug

%.42f: %.per
	fglform -M $<

%.42m: %.4gl
	fglcomp -M $<

clean::
	rm -f *.42?
	rm -f *.sch

