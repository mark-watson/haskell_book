# FastTag — Part-of-Speech Tagger

**Book:** [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook) by Mark Watson — [read free online](https://leanpub.com/haskell-cookbook/read)

**Book Chapter:** [Natural Language Processing Tools](https://leanpub.com/read/haskell-cookbook/natural-language-processing-tools)

A Haskell implementation of the FastTag part-of-speech (POS) tagger. Given a sentence, FastTag assigns a grammatical tag (noun, verb, adjective, etc.) to each word using a lexicon derived from Eric Brill's tagger and the MedPost medical tagging lexicon.

The lexicon data is stored as Haskell source code that builds a `Data.Map` at runtime for fast word lookups.

## Run

```bash
stack build
stack exec fasttag
```

## How It Works

1. Tokenize input text into words.
2. Look up each word in the lexicon map to get candidate POS tags.
3. Apply contextual rules (based on Brill's transformation-based learning) to refine tags.

## Acknowledgments

- **Eric Brill** — lexicon and trained rule set: <http://www.cs.jhu.edu/~brill/>
- **MedPost team** — medical tagging lexicon: <http://mmtx.nlm.nih.gov/MedPost_SKR.shtml>
- **Brant Chee** — bug reports and fixes for the Java version of FastTag

## License

LGPL3 or Apache 2.0 (your choice) — Copyright 2016-2026 Mark Watson.
