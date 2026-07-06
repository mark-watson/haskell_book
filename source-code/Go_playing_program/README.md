# Go Game — Terminal-based Go with AI Opponent

Play Go (Weiqi/Baduk) against an AI engine in your terminal.

## Prerequisites

- GHC 9.6+ and Cabal 3.0+

## Build & Run

```bash
# Build
cabal build

# Run (starts an interactive 9×9 game as Black)
cabal run

# Run (starts an interactive 13x13 game as Black)
cabal run go-game -- 13


# Run (starts an interactive 13x13 game as Black with a lower 1500 skill level)
cabal run go-game -- 13 1500
```

### Controls

- Enter moves as column+row, e.g. `F4`
- Type `pass` to pass
- Type `resign` to resign
- Type `quit` to exit
- Type `s` to see the AI's move scores

## Debugging — Building with Tracing

To get detailed call stacks for runtime errors, build with profiling and debug info:

```bash
cabal build --enable-profiling --ghc-options="-g -fprof-late"
```

Then run with GHC's `-xc` RTS flag to get cost-centre-based stack traces:

```bash
cabal run go-game -- +RTS -xc -RTS
```

For more detailed profiling output (function call counts, allocation, time):

```bash
# Build
cabal build --enable-profiling --ghc-options="-fprof-auto -fprof-late -prof"

# Run with profiling
cabal run go-game -- +RTS -xc -p -RTS

# View profile report
less go-game.prof
```

### RTS Options Summary

| Flag | Purpose |
|------|---------|
| `+RTS -xc -RTS` | Print call stack on runtime error |
| `+RTS -p -RTS` | Generate `go-game.prof` profiling report |
| `+RTS -hc -RTS` | Generate heap profile (use `hp2ps` to visualize) |
| `+RTS -s -RTS` | Print summary statistics after execution |

### Quick Trace Without Profiling

If profiling libraries aren't installed, you can add `error` traces manually at suspicious `V.!` call sites, e.g.:

```haskell
import GHC.Stack (HasCallStack, withFrozenCallStack)

stoneAt :: HasCallStack => Board -> Int -> Stone
stoneAt b i
  | i < 0 || i >= V.length (boardGrid b) = error $ "stoneAt: index out of bounds " ++ show i
  | otherwise = intToStone (boardGrid b V.! i)
```
