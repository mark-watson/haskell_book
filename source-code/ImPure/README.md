# Impure Haskell Tutorial Examples

**Book:** [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook) by Mark Watson — [read free online](https://leanpub.com/haskell-cookbook/read)

**Book Chapter:** [Tutorial on Impure Haskell Programming](https://leanpub.com/read/haskell-cookbook/tutorial-on-impure-haskell-programming)

Code examples from the "impure" Haskell tutorial chapter, covering I/O operations, the `do` notation, `let` bindings within `do` blocks, `fmap` over I/O actions, and word-frequency analysis on text files.

## Run

You can run the examples interactively:

```bash
stack ghci
```

or build and run individual programs:

```bash
stack build
stack exec CommonWords
stack exec DoLetExample
stack exec DoLetExample2
stack exec DoLetExample3
stack exec FmapExample
```

## Source Files

| File | Description |
|------|-------------|
| `CommonWords.hs` | Reads text files and finds the most common words |
| `DoLetExample.hs` | Demonstrates `let` bindings inside `do` blocks |
| `DoLetExample2.hs` | Variation on `do`/`let` patterns |
| `DoLetExample3.hs` | Further `do`/`let` examples |
| `FmapExample.hs` | Using `fmap` to transform I/O results |
| `text1.txt`, `text2.txt` | Sample text files for `CommonWords` |

## License

Apache 2.0 — Copyright 2016-2026 Mark Watson. All rights reserved.
