# Rubber Bridge Game in Haskell

A text-based contract rubber bridge game with AI players, implementing Standard American bidding conventions and heuristic card play.

The project features a **decoupled architecture**, separating the game state, card/hand logic, bidding systems, and AI routines (housed in the library) from the terminal/CLI front-end. This separation makes it easy to implement a web/GUI interface (like `./Bridge_webkit`) in the future using the core game library.

---

## Architecture & Modules

The package contains a library (`bridge-game`) and a command line executable (`bridge-game`):

```
                       ┌────────────────────────────────────────────────────────┐
                       │               CLIENT (app/Main.hs)                     │
                       │   CLI event loop, user prompt parsing, text display    │
                       └───────────┬────────────────────────────────┬───────────┘
                                   |                                |
                                   v (Updates state)                v (Queries state)
                       ┌────────────────────────────────────────────────────────┐
                       │               ENGINE (src/Bridge/Engine.hs)            │
                       │   Pure game state transitions (applyBid, applyCard)    │
                       ├───────────────┬────────────────┬───────────────────────┤
                       │  BIDDING      │   PLAY         │   SCORING             │
                       │  (src/Bridge/ │  (src/Bridge/  │  (src/Bridge/         │
                       │   Bidding.hs) │   Play.hs)     │   Scoring.hs)         │
                       │               │                │                       │
                       │  • Opening /  │  • Heuristics  │  • Rubber bridge      │
                       │    Responding │    (Sequence,  │    above/below line   │
                       │  • AI logic   │    4th-best)   │  • Game/vul tracking  │
                       ├───────────────┴────────────────┴───────────────────────┤
                       │               CARDS (src/Bridge/Cards.hs)              │
                       │   HCP count, balanced hand checks, shuffle & deal      │
                       ├────────────────────────────────────────────────────────┤
                       │               TYPES (src/Bridge/Types.hs)              │
                       │   Suit, Rank, Card, Player, Strain, BidType, Phase     │
                       └────────────────────────────────────────────────────────┘
```

### Pure Library Modules (`src/Bridge/`)

* **[Types.hs](file:///Users/markwatson/GITHUB/haskell_book/source-code/Bridge_game/src/Bridge/Types.hs)**: Core type representations for suits, ranks, players (North, East, South, West), strains, and bids.
* **[Cards.hs](file:///Users/markwatson/GITHUB/haskell_book/source-code/Bridge_game/src/Bridge/Cards.hs)**: Card/hand representations, Fisher-Yates shuffle algorithm, dealing logic, HCP counting, and balanced hand shapes.
* **[Bidding.hs](file:///Users/markwatson/GITHUB/haskell_book/source-code/Bridge_game/src/Bridge/Bidding.hs)**: Standard American bidding system conventions, contract extraction from bidding history, and rule-based AI bid selections.
* **[Play.hs](file:///Users/markwatson/GITHUB/haskell_book/source-code/Bridge_game/src/Bridge/Play.hs)**: Game rules (following suit, ruffing, discarding), trick winner determination, and heuristic AI card plays.
* **[Scoring.hs](file:///Users/markwatson/GITHUB/haskell_book/source-code/Bridge_game/src/Bridge/Scoring.hs)**: Complete rubber bridge scorecard rules, games and rubber bonuses, and vulnerability tracking.
* **[Engine.hs](file:///Users/markwatson/GITHUB/haskell_book/source-code/Bridge_game/src/Bridge/Engine.hs)**: Orchestrates the pure state transitions of a single deal.

### Interactive CLI (`app/`)

* **[Main.hs](file:///Users/markwatson/GITHUB/haskell_book/source-code/Bridge_game/app/Main.hs)**: Implements the command-line game loops, parses user commands (e.g. `1H`, `Pass`, `AS`), and renders the visual bridge table and scoring card.

---

## Quick Start

### Build

Verify the build and compile using Cabal:

```bash
cabal build
```

### Run

Start a rubber of bridge against the AI (you sit at South, your partner is North, East-West are opponents):

```bash
cabal run bridge-game
```

---

## Command Inputs

### Bidding Format

| Input | Meaning |
|-------|---------|
| `1H` / `1h` | 1 Heart |
| `3NT` / `3nt` | 3 No Trump |
| `2S` / `2s` | 2 Spades |
| `PASS` / `P` / `p` | Pass |
| `DBL` / `X` / `x` | Double |
| `RDBL` / `XX` / `xx` | Redouble |
| `Q` / `QUIT` | Quit the game |

### Card Play Format

During card play, you can select cards in two ways:

1. **Numbered Selection (Recommended)**: Simply type the number (e.g. `1`, `2`, `3`) matching the indices shown in the legal plays list.
2. **Card Rank-Suit symbol**: Type the short name of the card, e.g. `AS` (Ace of Spades), `10C` (10 of Clubs), `3D` (3 of Diamonds), `KH` (King of Hearts).
