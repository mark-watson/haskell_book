# Knowledge Graph Creator

**Book:** [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook) by Mark Watson — [read free online](https://leanpub.com/haskell-cookbook/read)

**Book Chapter:** [Knowledge Graph Creator](https://leanpub.com/read/haskell-cookbook/knowledge-graph-creator)

Extracts entities and relationships from natural text to build a knowledge graph. The tool uses NLP techniques (part-of-speech tagging, entity recognition) to identify subjects, predicates, and objects, then outputs them as structured graph data. Optionally integrates with a Python coreference resolution server for improved entity linking.

## Prerequisites

To use coreference resolution, start the Python server first — see `python_utils/` for setup.

## Run

```bash
# Default test input
stack build --fast --exec KGCreator-exe

# Custom input file with output directory
stack build --fast --exec "KGCreator-exe test_data outtest"
```

## Project Structure

| Path | Description |
|------|-------------|
| `app/` | Main executable entry point |
| `src/` | Core library: NLP processing and graph construction |
| `test/` | Test suite |
| `test_data/` | Sample input text files |
| `python_utils/` | Python utilities for coreference resolution |

## License

AGPL version 3 — Copyright 2016-2026 Mark Watson. See <https://markwatson.com/opensource/> for an alternative commercial license.
