.SUFFIXES: .erl .beam

.erl.beam:
	erlc -W $<

MODS = watcher

all: compile

compile: ${MODS:%=%.beam}


clean:	
	rm -rf *.beam erl_crash.dump