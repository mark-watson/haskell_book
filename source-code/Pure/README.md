# Pure Haskell Tutorial Examples

**Book:** [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook) by Mark Watson — [read free online](https://leanpub.com/haskell-cookbook/read)

**Book Chapter:** [Tutorial on Pure Haskell Programming](https://leanpub.com/read/haskell-cookbook/tutorial-on-pure-haskell-programming)

Code examples from the introductory tutorial chapter on "pure" Haskell — covering pattern matching, guards, `if`/`then`/`else`, `let`/`where` bindings, `map`, chained function calls, and custom data types.

## Run

The default Cabal/Stack target runs `Simple.hs`:

```bash
stack ghci
```

or:

```bash
cabal build
cabal run
```

To run other files individually use `runghc`:

```bash
runghc MapExamples.hs
runghc Cases.hs
runghc ChainedCalls.hs
runghc Guards.hs
```

> **Tip:** If a file imports a library listed in the `.cabal` file, use
> `cabal exec runghc -- Guards.hs` to run it inside the Cabal sandbox.

## Source Files

| File | Description |
|------|-------------|
| `Simple.hs` | Basic function definitions (default main target) |
| `Guards.hs` | Pattern matching with guards and `Maybe` |
| `Cases.hs` | `case` expressions |
| `ChainedCalls.hs` | Composing and chaining functions |
| `MapExamples.hs` | Using `map`, `foldl`, `foldr` |
| `Conditionals.hs` | Conditional expressions |
| `IfThenElses.hs` | `if`/`then`/`else` examples |
| `LetAndWhere.hs` | `let` and `where` bindings |
| `MyColors.hs` | Custom data types with `deriving` |
| `NoIO.hs` | Pure computations with no I/O |

## License

Apache 2.0 — Copyright 2016-2026 Mark Watson. All rights reserved.
