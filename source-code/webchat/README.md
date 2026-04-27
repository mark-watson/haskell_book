# Gemini Web Chat Application

**Book:** [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook) by Mark Watson — [read free online](https://leanpub.com/haskell-cookbook/read)

**Book Chapter:** [A Web Application For Using the Google Gemini APIs](https://leanpub.com/read/haskell-cookbook/a-web-application-for-using-the-google-gemini-apis)

A web-based chat interface for the Google Gemini LLM API, built with Haskell. This is the web application counterpart to the `gemini_commandline` example — instead of a CLI, it serves a browser-based chat UI.

## Prerequisites

Set your Google AI API key:

```bash
export GOOGLE_API_KEY="your-api-key"
```

## Run

```bash
cabal run
```

Then open your browser to:

```
http://localhost:3000
```

## License

Apache 2.0 — Copyright 2016-2026 Mark Watson. All rights reserved.
