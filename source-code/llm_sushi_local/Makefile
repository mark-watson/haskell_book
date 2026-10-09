.PHONY: check run run-stream clean

# Prompt sent by `make run`. Override it on the command line, for example:
#   make run PROMPT="write a haiku about Haskell"
#   make run PROMPT="..." EXTRA="--max-tokens 100 --temperature 0.2"
PROMPT ?= how much is 4 + 11 + 13?
EXTRA ?=

check:
	cabal build all -O0

# `make run` / `make run-stream` also build the executable if needed.
run:
	cabal run llm-sushi-local -- $(EXTRA) "$(PROMPT)"

run-stream:
	cabal run llm-sushi-local -- --stream $(EXTRA) "$(PROMPT)"

clean:
	cabal clean
