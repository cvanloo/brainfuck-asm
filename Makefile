.PHONY: build search

KERNEL_HEADERS := /usr/src/linux-zen/include/

build: brainfuck.s
	as brainfuck.s -g -o bf.o
	ld bf.o 

search:
	grep -rn '#define $(term)' $(KERNEL_HEADERS)
