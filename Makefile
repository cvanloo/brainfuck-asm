.PHONY: build

build: brainfuck.s
	as brainfuck.s -g -o bf.o
	ld bf.o 
