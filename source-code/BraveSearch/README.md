# Brave Search API Client

**Book:** [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook) by Mark Watson — [read free online](https://leanpub.com/haskell-cookbook/read)

**Book Chapter:** [Using the Brave Search API](https://leanpub.com/read/haskell-cookbook/using-the-brave-search-api)

A Haskell client for the [Brave Search API](https://brave.com/search/api/) that demonstrates making HTTP requests, parsing JSON responses, and working with REST APIs in Haskell.

## Prerequisites

Sign up for a free or paid account on the [Brave Search API page](https://brave.com/search/api/) and set your API key:

```bash
export BRAVE_SEARCH_API_KEY="BSAgQ-Nc5....."
```

## Run

```bash
cabal build
cabal run
```

## Source Files

| File | Description |
|------|-------------|
| `Main.hs` | Entry point |
| `BraveSearch.hs` | API client and JSON parsing |

## License

Apache 2.0 — Copyright 2016-2026 Mark Watson. All rights reserved.
