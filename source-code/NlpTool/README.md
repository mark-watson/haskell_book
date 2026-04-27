# NLP Tool

**Book:** [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook) by Mark Watson — [read free online](https://leanpub.com/haskell-cookbook/read)

**Book Chapter:** [Natural Language Processing Tools](https://leanpub.com/read/haskell-cookbook/natural-language-processing-tools)

A comprehensive NLP toolkit in Haskell providing text categorization, summarization, and entity extraction. The project includes generated lexicon data files (built from Ruby scripts) that create in-memory `Data.Map` lookups for linguistic data such as city names linked to DBpedia URIs.

## Run

Build and run the main executable:

```bash
stack build --fast --exec NlpTool-exe
```

Or explore individual modules interactively:

```bash
stack ghci
```

```haskell
:l Categorize.hs
main

:l Summarize.hs
main
```

## Key Modules

| Module | Description |
|--------|-------------|
| `Summarize.hs` | Text summarization |
| `Entities.hs` | Named entity extraction |
| `Categorize.hs` | Text categorization |
| `WebApp.hs` | Optional web interface |
| `CityNamesDbpedia.hs` | Generated: city → DBpedia URI mappings |
| `Category1Gram.hs`, `Category2Gram.hs` | Generated: n-gram category data |

## Credits

- **Dmitry Antonyuk** — Haskell stemmer
- **Eric Kow** — sentence splitting code

## License

AGPL version 3 — Copyright 2014-2026 Mark Watson. All rights reserved. Contact the author for a commercial license.
