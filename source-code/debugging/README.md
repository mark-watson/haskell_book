# Debug Tracing Example

**Book:** [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook) by Mark Watson — [read free online](https://leanpub.com/haskell-cookbook/read)

**Book Chapter:** [Section 1 - Tutorial](https://leanpub.com/read/haskell-cookbook/section-1---tutorial)

Demonstrates debug-only tracing in Haskell using `Debug.Trace` (`trace` and `traceShow`). These functions let you print debugging output from pure code without introducing `IO` — useful during development but should be removed before production.

## Run

```bash
stack build --exec TraceTimerTest
```

## License

Apache 2.0 — Copyright 2018-2026 Mark Watson. All rights reserved.
