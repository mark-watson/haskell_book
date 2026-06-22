# Graphical WebKit Desktop Interface for Rubber Bridge in Haskell

In the previous chapter, we developed a pure Contract Rubber Bridge game engine (`Bridge_game`) and ran it using an interactive Command Line Interface. Because our architecture was fully decoupled, all game domain types, state transition rules, and AI behaviors were encapsulated within a pure Haskell library. 

In this chapter, we build upon that foundation by developing a **graphical desktop GUI application** (`Bridge_webkit`) utilizing the native macOS WebKit bindings we explored in the WebKit FFI chapter (`webkit-haskell`). 

By embedding macOS’s native `WKWebView`, we create a visually premium card-table experience with:
- A beautiful green-felt felt-gradient board layout.
- Horizontal, curved card fanning utilizing CSS 3D transforms.
- Highlighting and scaling playable cards while disabling illegal plays.
- Real-time "We" vs "Them" trick counts.
- Step-by-step AI card play loops with visual delays, pacing opponent actions for comfortable human viewing.

The source code for this project is located in **haskell_book/source-code/Bridge_webkit**.

---

## Architectural Overview

The GUI application is structured as a native macOS Cocoa window wrapping a WebKit viewport. It communicates bidirectionally with a Haskell background thread via JSON-encoded FFI callbacks:

```
                  ┌────────────────────────────────────────────────────────┐
                  │                 FRONT-END (app/index.html)             │
                  │   - Curved card fanning, bidding box & scorecard panels │
                  │   - Sets 2-second delay between AI opponent turns      │
                  └───────────────────────────┬────────────────────────────┘
                                              │
                                              │ JSON FFI Messages via
                                              │ window.webkit_haskell.invoke
                                              v
                  ┌────────────────────────────────────────────────────────┐
                  │                 BACK-END (app/Main.hs)                 │
                  │   - Manages state using standard GHC IORef             │
                  │   - Dispatches FFI requests, returns JSON payloads     │
                  └───────────────────────────┬────────────────────────────┘
                                              │
                                              │ Imports Core Library
                                              v
                  ┌────────────────────────────────────────────────────────┐
                  │                 BRIDGE ENGINE LIBRARY                  │
                  │   - Resolves pure state transformations (Bridge_game)  │
                  └────────────────────────────────────────────────────────┘
```

When the user interacts with the HTML interface (such as choosing a bid or playing a card), the Javascript client invokes a backend command:
```javascript
const newState = await window.webkit_haskell.invoke("play-card", { card: "10S" });
renderUI(newState);
```
The GHC Haskell runtime handles the FFI request, transforms the game state using the pure `Bridge_game` engine rules, updates the local mutable `IORef` state container, and returns the modified state as JSON.

---

## The Backend FFI Dispatcher: `app/Main.hs`

The Haskell backend acts as the bridge dispatcher. It manages game mutable state inside an `IORef` wrap of the GHC `ActiveState` record:

```haskell
data ActiveState = ActiveState
  { currentGameState   :: GameState
  , currentRubberState  :: RubberState
  , randomGen           :: StdGen
  , lastTrickCards      :: [PlayedCard] -- Caches the last completed trick
  }
```

Because GHC's core engine clears the active trick immediately upon playing the 4th card (advancing the trick count and shifting active lead player), a direct state query would clear completed trick cards from the table too fast for a human to see. To resolve this, `ActiveState` caches the 4 played cards inside the `lastTrickCards` field before the engine sweeps them.

We define a state-stepping helper `playCardAndStep` to capture completed tricks and handle scoring transitions:

```haskell
playCardAndStep :: Card -> Player -> ActiveState -> ActiveState
playCardAndStep cardVal actor state =
  let gsVal = state.currentGameState
      currentTrick' = (actor, cardVal) : gsVal.currentTrick
      
      -- If playing the 4th card, cache the completed trick
      completedTrick =
        if length currentTrick' == 4
        then map (\(p, c) -> PlayedCard (show p) (show c)) (reverse currentTrick')
        else []
        
      gs' = applyCardPlay cardVal gsVal
      
      -- If the deal is complete, transition to Scoring rubber scores
      state' =
        if gs'.phase == Scoring
        then
          let
            rsVal = state.currentRubberState
            contractVal = maybe (SuitBid 1 NoTrump) id gs'.contract
            level = case contractVal of SuitBid l _ -> l; _ -> 1
            strain = case contractVal of SuitBid _ s -> s; _ -> NoTrump
            declarerVal = maybe South id gs'.declarer
            doubledVal = gs'.doubled
            tricksWon = if side declarerVal == 0 then gs'.tricksNs else gs'.tricksEw
            (rs', _) = scoreRubberDeal level strain tricksWon declarerVal doubledVal rsVal
            rs'' = rs' { dealsPlayed = rs'.dealsPlayed + 1, currentDealer = nextPlayer rs'.currentDealer }
          in state { currentGameState = gs', currentRubberState = rs'' }
        else
          state { currentGameState = gs' }
  in state' { lastTrickCards = completedTrick }
```

### Exposing the Step-by-Step AI Endpoint

To slow down opponent actions for the human player to see, we must decouple AI execution from the human play handler. Instead of running all subsequent AI plays recursively in a single thread tick, the backend exposes a single-play endpoint `"ai-play-single"`. 

This endpoint evaluates the current actor, runs the heuristic card selection AI exactly *once*, and returns the modified state:

```haskell
  registerHandler app "ai-play-single" $ \_ -> do
    putStrLn "[Haskell] Received ai-play-single command"
    state <- readIORef stateRef
    let gsVal = state.currentGameState
    case currentActor gsVal of
      Just actor -> do
        let isHuman = actor == South
            isDummy = Just actor == gsVal.dummy
            declarerSide = fmap side gsVal.declarer
            humanPlaysDummy = isDummy && (declarerSide == Just 0)
            humanPlaysThis = isHuman || humanPlaysDummy
        if humanPlaysThis
          then return $ Aeson.object ["error" Aeson..= ("It is human's turn to play, not AI." :: String)]
          else do
            let cardVal = aiSelectCard (gsVal.hands Map.! actor) (map snd gsVal.currentTrick) gsVal.trickLead gsVal.trumpSuit actor (maybe South id gsVal.declarer)
                state' = playCardAndStep cardVal actor state
            writeIORef stateRef state'
            stateFinal <- readIORef stateRef
            return $ Aeson.toJSON (makePayload stateFinal.currentGameState stateFinal.currentRubberState (stateFinal.currentRubberState.dealsPlayed + 1) stateFinal.lastTrickCards)
      Nothing ->
        return $ Aeson.object ["error" Aeson..= ("No active player found." :: String)]
```

---

## Frontend Layout & Design: `app/index.html`

The GUI is rendered using HTML5, vanilla CSS transitions, and client-side JavaScript. 

### 1. Card-Fanning Mechanics

We display the South player's cards in an elegant overlapping arc using CSS custom properties (`--index`, `--total`, and `--offset`) set by JS, mapping them onto 3D transformations:

```css
.south-hand .card {
  position: absolute;
  left: calc(50% - 34px);
  bottom: 20px;
  transform-origin: bottom center;
  /* Distribute cards horizontally by 54px and rotate by 2 degrees per card */
  transform: translateX(calc((var(--index) - (var(--total) - 1) / 2) * 54px)) 
             rotate(calc((var(--index) - (var(--total) - 1) / 2) * 2deg)) 
             translateY(calc(var(--offset) * 4px));
}
```

By using `54px` spacing (for a `68px` wide card), only a tiny portion overlaps, leaving the card suits and indices completely visible.

### 2. Player Turn Highlights & Click Disabling

When it is the South player's turn to play a card, we add the `.south-turn` class to the hand container. We then highlight legal playable cards, lifting them up and styling them with glowing borders while dimming and disabling unplayable cards:

```css
/* Lift legal cards slightly when it's your turn */
.south-hand.south-turn .card.legal {
  transform: translateX(calc((var(--index) - (var(--total) - 1) / 2) * 54px)) 
             rotate(calc((var(--index) - (var(--total) - 1) / 2) * 2deg)) 
             translateY(calc(var(--offset) * 4px - 18px)) 
             scale(1.12);
  z-index: 10;
  border-color: rgba(223, 178, 63, 0.4);
  box-shadow: 0 8px 16px rgba(0, 0, 0, 0.4), 0 0 10px rgba(223, 178, 63, 0.2);
}

/* Elevate legal card on mouse hover */
.south-hand.south-turn .card.legal:hover {
  transform: translateX(calc((var(--index) - (var(--total) - 1) / 2) * 54px)) 
             rotate(calc((var(--index) - (var(--total) - 1) / 2) * 2deg)) 
             translateY(-36px) 
             scale(1.28);
  z-index: 100;
  border-color: var(--gold);
  box-shadow: 0 15px 30px rgba(0,0,0,0.5), 0 0 20px var(--gold);
  cursor: pointer;
}

/* Grayscale and disable unplayable cards */
.south-hand.south-turn .card:not(.legal) {
  filter: brightness(0.4) grayscale(0.5);
  opacity: 0.5;
  pointer-events: none;
}
```

When it is another player's turn (or during the bidding auction), the `.south-turn` class is removed, revealing the human player's hand in full color and brightness without accidental hover movements.

### 3. We vs Them Scoreboard Panel

The Left Scorecard panel displays trick counts won by the human partnership (**"We (N-S)"**) and the AI opponents (**"Them (E-W)"**) at all times:

```html
<div class="tricks-counter-box" style="margin-top: 12px; margin-bottom: 12px; padding: 10px; background: rgba(0,0,0,0.25); border-radius: 10px; border: 1px solid rgba(255,255,255,0.05); display: flex; justify-content: space-around; align-items: center; text-align: center;">
  <div>
    <div style="font-size: 0.7em; text-transform: uppercase; color: rgba(255,255,255,0.5); font-weight: 700; letter-spacing: 0.5px;">We (N-S)</div>
    <div id="tricks-ns" style="font-size: 1.8rem; font-weight: 800; color: var(--gold);">0</div>
  </div>
  <div style="font-size: 0.9em; font-weight: 700; color: rgba(255,255,255,0.2);">VS</div>
  <div>
    <div style="font-size: 0.7em; text-transform: uppercase; color: rgba(255,255,255,0.5); font-weight: 700; letter-spacing: 0.5px;">Them (E-W)</div>
    <div id="tricks-ew" style="font-size: 1.8rem; font-weight: 800; color: #f3f4f6;">0</div>
  </div>
</div>
```

---

## Game Loop Delay & Timing Flow

To coordinate pauses between card plays, the JavaScript client checks if the next player is an AI and registers a `2000ms` delay before dispatching the FFI call:

```javascript
// Check if the current actor is driven by AI
function isAiTurn(state) {
  if (state.phase !== "Playing") return false;
  const actor = state.activeActor;
  if (!actor || actor === "South") return false;

  // North dummy play check: human declarer plays partner's cards
  const isNorthDummy = (actor === "North" && state.dummy === "North");
  const isNsDeclarer = (state.declarer === "North" || state.declarer === "South");
  if (isNorthDummy && isNsDeclarer) {
    return false;
  }

  return true;
}

let aiTimeout = null;

function checkAndTriggerAi() {
  if (aiTimeout) {
    clearTimeout(aiTimeout);
    aiTimeout = null;
  }
  if (isAiTurn(gameState)) {
    // Wait 2 seconds before making the AI play its card
    aiTimeout = setTimeout(triggerAiPlay, 2000);
  }
}

async function triggerAiPlay() {
  aiTimeout = null;
  const state = await invokeBackend('ai-play-single', {});
  if (state) {
    renderUI(state);
  }
}
```

Whenever a play completes a trick, GHC clears the active cards on the backend. The frontend handles this by rendering the `lastCompletedTrick` cache instead if `currentTrick` is empty, displaying a banner announcement such as *"East wins the trick!"* during the 2-second transition pause.

---

## Building and Running the Desktop Application

The graphical desktop client uses Cabal for dependency resolution and compilations.

### Compilation

Build the GUI package inside the `Bridge_webkit` directory:
```bash
cd source-code/Bridge_webkit
cabal build
```

This compiles GHC executable targets, imports local packages, builds the Cocoa FFI wrappers, and binds the HTML assets.

### Launching the Client

Execute the compiled application:
```bash
cabal run bridge-webkit
```

Upon launching, the native macOS window initializes, loads `app/index.html` into the embedded `WKWebView`, and begins the bridge bidding auction!


## Optional Practice Problems

1. Update the WebKit Bridge HTML frontend UI to show a prominent visual indicator indicating the current player with the lead, active bidder, and the current trump suit.
2. Implement a 'Suggest Play' button in the WebKit GUI that queries the backend AI engine to highlight the heuristically recommended card to play next.
