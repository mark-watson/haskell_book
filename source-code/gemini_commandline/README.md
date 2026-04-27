# Gemini Command Line Client

**Book:** [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook) by Mark Watson — [read free online](https://leanpub.com/haskell-cookbook/read)

**Book Chapter:** [Command Line Utility To Use the Google Gemini APIs](https://leanpub.com/read/haskell-cookbook/command-line-utility-to-use-the-google-gemini-apis)

A command-line tool for interacting with the Google Gemini LLM API. Similar to the `webchat` example, but designed as a CLI utility rather than a web application.

## Prerequisites

Set your Google AI API key:

```bash
export GOOGLE_API_KEY="your-api-key"
```

## Run

```bash
cabal run gemini -- "what is the square of pi?"
```

Example output:

```
Response:

The square of pi (π) is π multiplied by itself: π².
Since π is approximately 3.14159, π² is approximately 9.8696.
```

## Installing as a Permanent Command

To install the `gemini` binary on your path:

```bash
cabal build
cp $(find . -name gemini -type f | head -1) ~/bin/
gemini "what is 11 + 23?"
```

## License

Apache 2.0 — Copyright 2016-2026 Mark Watson. All rights reserved.
