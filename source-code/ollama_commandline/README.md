# Ollama Command Line Client

**Book:** [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook) by Mark Watson — [read free online](https://leanpub.com/haskell-cookbook/read)

**Book Chapter:** [Command Line Tool to Use Local Ollama LLM Server](https://leanpub.com/read/haskell-cookbook/command-line-tool-to-use-local-ollama-llm-server)

A command-line tool for interacting with a locally running [Ollama](https://ollama.ai/) LLM server. Sends prompts to Ollama's REST API and prints the model's response — useful for quick queries without leaving the terminal.

## Prerequisites

- [Ollama](https://ollama.ai/) installed and running locally
- At least one model pulled (e.g., `ollama pull llama3`)

## Run

```bash
cabal run ollama-client -- "how much is 4 + 11 + 13?"
```

```bash
cabal run ollama-client -- "write a Python script to print out the 11th and 12th prime numbers"
```

```bash
cabal run ollama-client -- "Write a Haskell hello world program"
```

## License

Apache 2.0 — Copyright 2016-2026 Mark Watson. All rights reserved.
