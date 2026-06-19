# Haskell WebKit Rubber Bridge GUI Application

A premium, modern desktop graphical user interface (GUI) for the contract rubber bridge game. 

This application utilizes a **decoupled architecture**, reusing the core domain data, Standard American bidding conventions, and heuristic AI rules from the library in `./Bridge_game`, and wrapping it inside a native macOS Cocoa window using the FFI callbacks of `webkit-haskell`.

---

## Architecture Overview

```
                      ┌────────────────────────────────────────────────────────┐
                      │              NATIVE WINDOW (FRONT-END)                 │
                      │   - app/index.html (Felt table, fanning hands UI)      │
                      │   - Bid Board overlay selector, Scorecard Panel        │
                      └───────────────────────────┬────────────────────────────┘
                                                  |
                                                  | JSON messages via
                                                  | window.webkit_haskell.invoke
                                                  v
                      ┌────────────────────────────────────────────────────────┐
                      │                 HASKELL BACK-END                       │
                      │   - app/Main.hs (FFI endpoints, state tracking IORef)  │
                      │   - Synchronizes human bids and autoplay AI loops      │
                      └───────────────────────────┬────────────────────────────┘
                                                  |
                                                  v
                      ┌────────────────────────────────────────────────────────┐
                      │               BRIDGE GAME LIBRARY (CORE)               │
                      │   - Bridge.Engine, Bidding, Cards, Play, Scoring       │
                      │   - Pure state transformers (applyBid, applyCardPlay)  │
                      └────────────────────────────────────────────────────────┘
```

---

## Features

* **Wood & Felt green table layout**: Radial gradient felt board mimicking traditional card playing tables.
* **Curved Card Fanning**: The user's hand (South) is arranged in a realistic curved fanning format using CSS transforms. Cards raise, outline in gold, and show glowing shadows on hover if they represent a legal play.
* **Auto-Lead & Autoplay AI Loops**: When the human player plays a card or makes a bid, the backend automatically runs all consecutive AI turns (East, West, North) until the human's input is needed again, keeping the UI state perfectly synchronized.
* **Smart Bidding board**: An overlay bidding box with disabled buttons for invalid/under-bid contracts.
* **Score Sheet Card**: Formatted as a traditional paper card sheet below and above-the-line scores for N-S and E-W, tracking games won and active vulnerabilities.

---

## File Structure

```
Bridge_webkit/
├── bridge-webkit.cabal   # Cabal package dependencies configuration
├── cabal.project         # Multi-package project layout mapping
├── stack.yaml            # Stack tool resolver mapping
└── app/
    ├── Main.hs           # Haskell wrapper, state managers & FFI handler registers
    └── index.html        # HTML, CSS styling sheet, and Javascript DOM engines
```

---

## API Bridge Endpoints

Communication between the JS webview and GHC Haskell backend is governed by five JSON-based endpoints registered in `Main.hs`:

1. **`get-state`**: Queries the current game and scorecard status. Returns a `GameStatePayload` object containing hand lists, bidding history, played trick cards, and active legal card codes.
2. **`bid`**: Submits a bid string (e.g. `"PASS"`, `"1H"`, `"3NT"`, `"DBL"`). Automatically calculates subsequent AI bids and updates state.
3. **`play-card`**: Plays a card (e.g. `"AS"`, `"10D"`). Verifies play legality, executes trick/deal score checking, and runs AI responses.
4. **`next-deal`**: Advances the rubber to the next deal, rotating the dealer and adjusting vulnerability.
5. **`reset-game`**: Aborts the active rubber, clearing scorecards and dealing new hands.

---

## Quick Start

### Prerequisites

Ensure you are running on macOS (required by `webkit-haskell` native Objective-C/Cocoa frameworks).

### Build

Navigate to the `Bridge_webkit` directory and compile:

```bash
cd source-code/Bridge_webkit
cabal build
```

This compiles `bridge-game` (library), `webkit-haskell` (C sources & Cocoa wrappers), and link-builds the `bridge-webkit` GUI app.

### Run

Start the desktop app:

```bash
cabal run bridge-webkit
```
