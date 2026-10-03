.PHONY: build check run-pi run-e list clean

build:
	cabal build all

# Fast, unoptimised build used while developing (same as the other projects
# in this repository).
check:
	cabal build all -O0

run-pi:
	cabal run pi

run-e:
	cabal run e

list:
	cabal run pi -- --list
	cabal run e -- --list

clean:
	cabal clean
