# Text Processing Examples

**Book:** [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook) by Mark Watson — [read free online](https://leanpub.com/haskell-cookbook/read)

**Book Chapter:** [Text Processing](https://leanpub.com/read/haskell-cookbook/text-processing)

A collection of examples demonstrating common text processing tasks in Haskell: cleaning noisy text, parsing CSV files, and working with JSON using both the `aeson` and `Text.JSON` libraries.

## Run

```bash
stack build --exec CleanText
stack build --exec TestAESON
stack build --exec TestCSV
stack build --exec TestTextJSON
```

## Source Files

| File | Description |
|------|-------------|
| `CleanText.hs` | Strips noise characters and normalizes whitespace from text |
| `TestAESON.hs` | JSON encoding/decoding with `aeson` and `DeriveGeneric` |
| `TestTextJSON.hs` | JSON handling with `Text.JSON.Generic` |
| `TestCSV.hs` | CSV file parsing with the `csv` library |
| `test.csv` | Sample CSV data |

## License

Apache 2.0 — Copyright 2016-2026 Mark Watson. All rights reserved.
