# Design Overview: Go AI Engine in Haskell

## Architecture

The program follows a **multi-engine architecture** with a pure-functional core and an impure shell. Each engine is an independent module that evaluates a board position and produces scored candidate moves. A master agent orchestrates them.

```
┌─────────────────────────────────────────────────────────────┐
│                      Agent (decideMove)                     │
│  ┌─────────┐ ┌───────────┐ ┌─────────┐ ┌──────┐ ┌────────┐ │
│  │Tactical │ │Strategic  │ │ Joseki  │ │ MCTS │ │ Rules  │ │
│  │ Engine  │ │ Engine    │ │ Engine  │ │Engine│ │ Engine │ │
│  └────┬────┘ └─────┬─────┘ └────┬────┘ └──┬───┘ └────┬───┘ │
│       │            │            │         │        │      │
│       └────────────┴─────┬───────┴────┬────┴────────┘      │
│                          ▼           ▼                      │
│              aggregateMoves (phase-weighted)                │
│                          │                                   │
│                          ▼                                   │
│                   Best Move Selection                         │
└─────────────────────────────────────────────────────────────┘
```

## Core Data Types

**Board** (`Board.hs`) — Immutable, flat `Vector Int` (0=empty, 1=black, 2=white) with strict fields. Size 9, 13, or 19. Includes ko hash, captures, last move. `cloneBoard` is identity — immutability makes cloning free.

**ScoredMove** — `{ index, score, reason }`. Every engine returns `[ScoredMove]`. Reasons are concatenated for explainability.

**GamePhase** — Opening / Middle / Endgame, detected by board fill ratio (<20%, <60%, ≥60%).

## Engines

| Engine | Module | Responsibility | Key Technique |
|--------|--------|----------------|---------------|
| Tactical | `Tactical.hs` | Local combat: captures, atari, ladders, saves | Flood-fill group detection, recursive ladder simulation |
| Strategic | `Strategic.hs` | Whole-board: influence maps, territory, moyo, connections | Manhattan-distance influence radiation, flood-fill territory |
| Joseki | `Joseki.hs` | Corner patterns + fuseki | Data-driven pattern list with 4-corner symmetry |
| MCTS | `MCTS.hs` | Stochastic search | UCT + RAVE, heavy playouts (capture atari, avoid eyes), `IORef` tree |
| Rules | `Rules.hs` | 19 heuristic adjustments | Weighted rule list, each `Board → Int → Int → Color → Double` |

## Master Agent (`Agent.hs`)

1. Run pure engines (tactical, strategic, joseki)
2. **Short-circuit**: if tactical finds move ≥100 (capture/save), play immediately
3. Run MCTS (impure, time/playout limited)
4. Check resign (>30 pts behind, <15% empty)
5. Check pass (MCTS best <5 and ahead, or 85% full no tactical)
6. Aggregate with phase weights:
   - Opening: (1.0, 1.2, 1.8, 1.0)
   - Middle: (1.5, 1.3, 0.5, 1.3)
   - Endgame: (1.8, 1.0, 0.1, 1.5)
7. Apply rule-engine adjustments
8. MCTS confidence boost (+50 if winrate >60%)
9. Fallback to legal interior move

## Purity Strategy

- **Pure**: Board, Tactical, Strategic, Joseki, Rules — all `Board → [ScoredMove]` or `Double`
- **Impure**: MCTS (mutable tree via `IORef`, `getCurrentTime`), Main (terminal I/O)
- `runPlayout` is pure; only the search loop is impure

## Key Haskell Techniques

- **Unboxed Vectors** for board grid — cache-friendly, fast `V.//` updates
- **BangPatterns** on accumulators — prevents space leaks in flood fills
- **IntSet** for O(log n) deduplication in group detection
- **Data-driven rules** — list of `Rule` records, no plugin framework needed
- **Phase-dependent weights** — simple table, not hard-coded conditionals

## Build & Run

```bash
cabal build
cabal run                    # 9×9, default strength
cabal run go-game -- 13      # 13×13
cabal run go-game -- 19 1500 # 19×19, 1500 playouts
```

## Files

```
src/
├── Board.hs       # Board, moves, captures, ko, scoring
├── Tactical.hs    # Atari, ladders, captures, saves
├── Strategic.hs   # Influence, territory, moyo, connections
├── Joseki.hs      # Corner patterns, fuseki
├── MCTS.hs        # UCT+RAVE, heavy playouts
├── Rules.hs       # 19 heuristic rules
├── Agent.hs       # Orchestration, aggregation, decision
└── Main.hs        # Terminal game loop
```