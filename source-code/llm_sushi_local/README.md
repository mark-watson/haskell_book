# Local LLM Command Line Client (Sushi)

**Book:** [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook) by Mark Watson — [read free online](https://leanpub.com/haskell-cookbook/read)

A command-line tool for interacting with a locally running LLM server that
exposes an OpenAI-compatible chat-completions API. It sends prompts to the
server's REST API and prints the model's reply — useful for quick queries
without leaving the terminal.

Defaults:

| Setting | Value |
| --- | --- |
| Base URL | `http://127.0.0.1:12345/v1` |
| Model | `Qwen3.8-Flash-Next-Sushi-2.6bpw` |

## Prerequisites

A local server listening on port 12345 that implements the OpenAI
`/v1/chat/completions` endpoint, with the model above loaded.

## Run

```bash
make run PROMPT="how much is 4 + 11 + 13?"
```

```bash
make run PROMPT="write a Python script to print out the 11th and 12th prime numbers"
```

```bash
cabal run llm-sushi-local -- "Write a Haskell hello world program"
```

Either form works; the second accepts the same options as the first.

### Streaming

Print tokens as they are generated instead of waiting for the whole reply:

```bash
make run-stream PROMPT="write a haiku about Haskell"
```

```bash
cabal run llm-sushi-local -- --stream "write a haiku about Haskell"
```

### Command line options

```
Usage: llm-sushi-local [OPTIONS] <prompt> [model]

  -s        --stream         print tokens as they arrive (server-sent events)
            --base-url=URL   API base url (default http://127.0.0.1:12345/v1)
  -m MODEL  --model=MODEL    model id (default Qwen3.8-Flash-Next-Sushi-2.6bpw)
  -t N      --temperature=N  sampling temperature, e.g. 0.7
            --max-tokens=N   maximum number of generated tokens
  -h        --help           show this help
```

The base URL and model can also come from the environment
(`SUSHI_BASE_URL`, `SUSHI_MODEL`) or from the optional second positional
argument, e.g. `llm-sushi-local "hi" some-other-model`. Precedence is:
positional argument, then option, then environment variable, then default.

## Files

| File | Purpose |
| --- | --- |
| `Main.hs` | Command-line client: option parsing, both request modes, output |
| `Sushi.hs` | JSON types for the OpenAI-compatible request and response |
| `llm-sushi-local.cabal` | Library and executable definitions |
| `Makefile` | `check`, `run`, `run-stream`, `clean` targets |

`Main.hs` calls the API in one of two ways: a single `/chat/completions`
request, or a streaming request whose server-sent events are read
incrementally so text appears as it is produced.

## License

Apache 2.0 — Copyright 2016-2026 Mark Watson. All rights reserved.
