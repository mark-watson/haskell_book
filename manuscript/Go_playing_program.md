# A Go Playing Program in Haskell

The game of Go, also known as Weiqi in China and Baduk in Korea, is one of the oldest board games still widely played, with a history stretching back over two and a half thousand years. It is also one of the deepest. Two players take turns placing stones on a grid; the rules themselves can be stated in a few sentences, yet the strategic complexity that emerges from them is vast. It is no accident that Go was the last of the classic board games to fall to computer play. Chess programs reached world-champion strength in 1997, but it was not until 2016, with DeepMind's AlphaGo, that a Go program could defeat a top human professional. Between those dates, the best Go engines relied not on brute-force search but on a hybrid of Monte Carlo simulation and hand-crafted heuristic knowledge that is exactly the style of engine we will study in this chapter.

Back in the late 1970s, long before artificial intelligence was a mainstream topic, I tried to push the boundaries of what home computers could achieve. I developed Honninbo Warrior, what I believe was the first commercial Go program built specifically for the Apple II. While academic researchers at the time relied on more powerful computers to handle the staggering mathematical complexity of Go, I managed to squeeze a functional evaluation algorithm into the severe memory limits of early consumer microcomputers.

The program in this chapter is a complete, terminal-based Go application written in Haskell. You can play a game against the AI in your terminal, on board sizes of 9×9, 13×13, or 19×19. The AI is not a single monolithic brain but a federation of specialized engines, rather it is comprised of a tactical engine for local combat, a strategic engine for whole-board evaluation, a joseki engine for opening patterns, a Monte Carlo Tree Search engine for stochastic look-ahead, and a rule engine with nineteen heuristic rules that adjust move scores. A master agent orchestrates these engines, weighting their contributions according to the phase of the game.

Dear reader, this is the most architecturally complex example in this book, and I want to use it to illustrate how a larger Haskell program can be decomposed into pure, independently testable modules that cooperate to produce sophisticated behavior. The key design idea is this: each engine is a pure function from a board position to a list of scored candidate moves, and the master agent combines these lists with phase-dependent weights. The only impurity lives in the main game loop and in the MCTS engine's use of `IORef` for its mutable search tree.

## Project Structure

The project is a Cabal project with a single executable and seven source modules:

```
go_program.hs/
├── go-game.cabal
├── src/
│   ├── Board.hs       -- Board representation, captures, ko, scoring
│   ├── Tactical.hs    -- Atari, ladders, captures, saves
│   ├── Strategic.hs   -- Influence maps, territory, moyo
│   ├── Joseki.hs      -- Corner opening patterns, fuseki
│   ├── MCTS.hs        -- Monte Carlo Tree Search with UCT + RAVE
│   ├── Rules.hs       -- 19 heuristic rule adjustments
│   ├── Agent.hs       -- Master agent: orchestrates all engines
│   └── Main.hs        -- Terminal game loop
```

Build and run with:

```bash
cabal build
cabal run                       # 9×9 game, default strength
cabal run go-game -- 13         # 13×13 game
cabal run go-game -- 19 1500    # 19×19 game, strength 1500 playouts
```

The defaults are playing strength of 3000 (highest setting) and a 9x9 board.

The first command-line argument selects the board size (9, 13, or 19); the second sets the AI strength as a playout budget. Larger boards automatically scale down the playout count and time limit because there are more legal moves to consider.

## Board Representation: Immutable Vectors and Pure Rules

The `Board` module is the foundation. Every other module operates on the `Board` type, and the correctness of the entire program depends on getting the board representation and the move-generation logic right. Let us look at the core data type:

```haskell{line-numbers: true}
data Color = Black | White
  deriving (Eq, Ord, Show, Enum)

data Stone = Empty | Occupied !Color
  deriving (Eq, Ord, Show)

data Board = Board
  { boardGrid     :: !(V.Vector Int)    -- 0=empty, 1=black, 2=white
  , boardSz       :: !Int               -- edge length (9, 13, or 19)
  , boardToMove   :: !Color             -- whose turn
  , boardPrevHash :: !Word32            -- hash of prior position (ko)
  , boardLastMove :: !(Maybe Int)       -- flat index of last move
  , boardCaptures :: !(Int, Int)        -- (Black's captures, White's captures)
  } deriving (Show)
```

The grid is a flat, unboxed `Vector Int` in row-major order. For a 19×19 board this is 361 integers that is small enough to fit comfortably in cache. Unboxed vectors store the integers directly without the pointer indirection of a boxed vector, which matters when the MCTS engine is cloning boards thousands of times per second.

The `boardPrevHash` field stores a hash of the position that existed before the last move. This is the simplest possible ko detection: if playing a move would recreate the position from two moves ago, the move is illegal. A more sophisticated implementation would track the full positional super-ko history, but for a hobbyist engine a single-position hash is sufficient and keeps the board compact.

Because the `Vector` is immutable, "modifying" the board produces a new board. The `cloneBoard` function is telling:

```haskell{line-numbers: true}
cloneBoard :: Board -> Board
cloneBoard b = b  -- immutable data - identity clone
```

The comment says it all. There is nothing to clone because the data is already immutable. When the MCTS engine needs to explore a branch, it calls `tryPlay`, which produces a new `Board` sharing the old vector's structure through `V.//` (a functional update that copies only the changed elements). This is the Haskell approach to game-tree search: no mutation, no undo stacks, just pure functions that return new states.

### Playing a Move: Captures, Suicide, and Ko

The `tryPlay` function is the heart of the rules engine. Given a board and a flat index, it returns `Maybe Board` that can be `Nothing` if the move is illegal, or `Just` the new board if it is legal. Let us walk through it:

```haskell{line-numbers: true}
tryPlay :: Board -> Int -> Maybe Board
tryPlay b i
  | i < 0 || i >= boardSz b * boardSz b = error "out of bounds"
  | boardGrid b V.! i /= 0 = Nothing     -- occupied
  | otherwise = do
      let color    = colorToInt (boardToMove b)
          enemy    = colorToInt (opp (boardToMove b))
          sz       = boardSz b
          trial0   = boardGrid b V.// [(i, color)]
          nbs      = neighbors b i
          (trial1, removed) = removeDeadGroups trial0 sz enemy nbs
          ownLibs  = countGroupLibs trial1 sz color i
      if ownLibs == 0
        then Nothing                       -- suicide
        else do
          let newHash = hashGrid trial1
          if boardPrevHash b /= 0 && newHash == boardPrevHash b
            then Nothing                   -- ko
            else Just (updateBoard ...)
```

The logic follows the standard Go rules in order:

1. **Place the stone** on the trial grid.
2. **Remove dead enemy groups**: after placing the stone, check each neighboring enemy group. If any has zero liberties, remove it. This is where captures happen.
3. **Check for suicide**: after removing captured enemy stones, check whether the newly placed stone's own group has any liberties. If not, the move is suicide and is illegal.
4. **Check for ko**: hash the resulting position and compare it to `boardPrevHash`. If they match, the move recreates the previous position and is illegal.

The order matters. A move that looks like suicide can become legal if it first captures enemy stones, opening up liberties. This is why the suicide check happens *after* removing dead enemy groups, not before.

### Group Detection via Flood Fill

Underpinning the rules is the concept of a *group*: a connected set of same-colored stones that share a fate. If one stone in a group is captured, they all are. The `groupInfo` function performs a flood fill from a seed stone, collecting all connected same-color stones and counting their distinct liberties:

```haskell{line-numbers: true}
groupInfo :: Board -> Int -> GroupInfo
groupInfo b seed
  | boardGrid b V.! seed == 0 = GroupInfo [] 0
  | otherwise = go [seed] IS.empty IS.empty [] 0
  where
    color = boardGrid b V.! seed
    go []     _gSeen _lSeen stones libs = GroupInfo (reverse stones) libs
    go (x:xs) gSeen  lSeen  stones libs =
      let stones' = x : stones
          nbs     = neighbors b x
          (xs', gSeen', lSeen', libs') = foldr step (xs, gSeen, lSeen, libs) nbs
      in  go xs' gSeen' lSeen' stones' libs'

    step nb (!stk, !gs, !ls, !l)
      | v == 0    = if IS.member nb ls
                    then (stk, gs, ls, l)
                    else (stk, gs, IS.insert nb ls, l + 1)
      | v == color = if IS.member nb gs
                     then (stk, gs, ls, l)
                     else (nb : stk, IS.insert nb gs, ls, l)
      | otherwise  = (stk, gs, ls, l)
      where v = boardGrid b V.! nb
```

This is a worklist-based flood fill using two `IntSet`s: one for stones already seen (`gSeen`) and one for liberties already counted (`lSeen`). The worklist (`xs`) holds stones to explore. For each neighbor of the current stone, if the neighbor is empty and not yet counted as a liberty, it is added to the liberty set; if it is a same-color stone not yet visited, it is added to the worklist; if it is an enemy stone, it is ignored. The use of `IntSet` keeps the membership checks O(log n) and deduplicates naturally.

The `BangPatterns` extension is important here. Without it, the accumulator tuples would build up thunks and the flood fill would leak memory on large boards. The strict pattern `(!stk, !gs, !ls, !l)` forces evaluation of each component at each step, keeping the memory footprint constant.

### Territory and Scoring

When both players pass, the game ends and the score is computed. The program uses area scoring (Chinese-style): each stone on the board counts as one point for its color, and each empty region that borders only one color counts as territory for that color.

```haskell{line-numbers: true}
areaScore :: Board -> Double
areaScore b =
  let (blackStones, whiteStones) = V.foldl' countSt (0, 0) grid
      territory = computeTerritory b n
  in  fromIntegral (blackStones + fst territory)
    - fromIntegral (whiteStones + snd territory)
```

The `computeTerritory` function flood-fills each empty region, tracking whether it touches black, white, or both. A region that touches only black is black territory; only white is white territory; both is neutral (dame). The result is returned from Black's perspective, with komi (compensation for White going second) subtracted later by the agent.

## The Multi-Engine Architecture

Now we come to the central design idea of the AI. Rather than a single evaluation function, the program runs five independent engines, each producing a list of `ScoredMove` values:

```haskell{line-numbers: true}
data ScoredMove = ScoredMove
  { smIndex  :: !Int       -- flat board index of the candidate move
  , smScore  :: !Double    -- how good the move is (engine-dependent scale)
  , smReason :: !String    -- human-readable explanation
  } deriving (Show, Eq)
```

The `smReason` field is worth noting. Every move comes with a textual explanation of *why* the engine suggested it, e.g., "capture 3 stone(s) in atari", "reduce enemy moyo", "joseki: 44-ikken-kakari-extend", "MCTS: 247 visits, 58.3% win rate". When the AI makes its final choice, it concatenates all the reasons that contributed to the winning move, so the human player can see the AI's thinking. This is a small touch but it makes debugging and play-testing far more informative.

The master agent in `Agent.hs` runs all engines, then merges their scores:

```haskell{line-numbers: true}
aggregateMoves :: GamePhase -> [ScoredMove] -> [ScoredMove] -> [ScoredMove]
               -> [ScoredMove] -> M.Map Int (Double, [String])
aggregateMoves phase tactical strategic joseki mcts =
  let (wTac, wStr, wJos, wMcts) =
        case phase of
          Opening -> (1.0, 1.2, 1.8, 1.0)
          Middle  -> (1.5, 1.3, 0.5, 1.3)
          Endgame -> (1.8, 1.0, 0.1, 1.5)
      ...
```

The weights shift as the game progresses. In the opening, joseki knowledge is most valuable (weight 1.8) because corner patterns matter most. In the middle game, tactical urgency and MCTS search dominate. In the endgame, tactical precision and MCTS are weighted highest, and joseki is nearly irrelevant (0.1). This phase-dependent weighting is a simple but effective way to encode the meta-strategic principle that different phases of Go demand different kinds of reasoning.

The aggregation uses a `Map Int (Double, [String])` keyed by board index. When two engines suggest the same move, their scores are added and their reasons are concatenated. This means a move that is both tactically sound and strategically promising gets a higher combined score than a move recommended by only one engine.

### Game Phase Detection

The phase is determined by the fill ratio of the board:

```haskell{line-numbers: true}
detectPhase :: Board -> GamePhase
detectPhase b =
  let ratio = fromIntegral filled / fromIntegral total
  in if ratio < 0.2 then Opening
     else if ratio < 0.6 then Middle
     else Endgame
```

On a 9×9 board (81 points), the opening ends when about 16 stones have been played. On a 19×19 board (361 points), the opening lasts until about 72 stones. These thresholds are rough but reasonable and they correspond to the point in the game where most corners and some of the sides have been claimed and fighting begins in earnest.

## The Tactical Engine: Local Combat

The tactical engine in `Tactical.hs` handles the urgent, local situations that demand immediate response: capturing stones in atari, saving your own stones from atari, putting enemy groups into atari, and detecting ladders.

A group is in *atari* when it has exactly one liberty, i.e., it only has one empty point (or “breathing space”) adjacent to it. If the opponent plays that liberty, the entire group is captured. Atari situations are the most tactically urgent positions in Go, and the tactical engine prioritizes them accordingly.

The engine generates five categories of moves:

1. **Captures**: for enemy groups in atari the computer plays on their single liberty to capture them. Score: 100 + size × 30. Capturing a 3-stone group scores 190.
2. **Saves**: for the computer’s groups in atari then extend to add liberties. If the extension gives the group two or more liberties, it is safe (score: 90 + size × 25). If the extension leads to a ladder that escapes, it is still worth playing (score: 40 + size × 10).
3. **Counter-atari**: when your own group is in atari, sometimes the best defense is to attack, putting an adjacent enemy group into atari instead, forcing a response.
4. **Atari attacks**: enemy groups with two liberties can be put into atari. If the atari also starts a working ladder, the score is much higher (60 + size × 15) because the group is likely doomed.
5. **Preventive reinforcement**: own groups with two liberties should be reinforced before they are pushed into atari.

### Ladder Detection

A *ladder* is a forcing sequence where a group with one liberty is chased across the board. The attacker repeatedly plays at the group's single liberty, and the defender extends, but each extension leaves the group with only one liberty again. The ladder *works* (the group is captured) if the sequence reaches the edge of the board or an obstruction before the group gains a second liberty. If the group reaches a point with two or more liberties, the ladder *breaks* and the group escapes.

```haskell{line-numbers: true}
ladderWorks :: Board -> Int -> Color -> Int -> Bool
ladderWorks board groupSeed attackerColor maxDepth =
  go board groupSeed 0
  where
    defColor = opp attackerColor
    go !b !seed !depth
      | depth >= maxDepth = False
      | otherwise =
          let libs = groupLiberties (groupInfo b seed)
          in case libs of
            0 -> True              -- captured
            _ | libs >= 3 -> False  -- escaped
              | libs == 2 -> False  -- escaped
              | otherwise ->        -- libs == 1: attacker plays the liberty
                  let lib = findLiberty b (groupStones (groupInfo b seed))
                  in case tryPlay (b { boardToMove = attackerColor }) lib of
                       Nothing -> False
                       Just b' ->
                         let defLibs = groupLiberties (groupInfo b' seed)
                         in case defLibs of
                           0 -> True
                           _ | defLibs >= 2 -> False
                             | otherwise -> go b'' seed (depth + 2)
                               where b'' = defender extends ...
```

The function is recursive: the attacker plays, the defender extends, and the process repeats. The `maxDepth` parameter limits how far the search extends. The tactical engine uses a depth of 40, while the rule engine uses 60 for more thorough analysis. The recursion terminates when the group is captured (0 liberties), escapes (2+ liberties), or the depth limit is reached (assumed escaped, conservatively).

This is a pure function: it creates trial boards with `tryPlay` and recurses on them. No mutation, no backtracking state to undo. Each recursive call gets its own immutable board. The cost is some allocation, but the benefit is that the code is straightforward and obviously correct.

## The Strategic Engine: Influence and Territory

While the tactical engine deals with local urgency, the strategic engine in `Strategic.hs` evaluates the whole-board picture. Its core abstraction is the *influence map*: a vector that assigns a floating-point value to every point on the board, representing how much each color's stones "radiate" influence to that point.

```haskell{line-numbers: true}
computeInfluence :: Board -> V.Vector Float
computeInfluence b =
  let radius = if sz <= 9 then 4 else if sz <= 13 then 5 else 6
      decay = 0.5
      baseStrength = 4.0
      stoneInfluence idx color =
        let sign = if color == Black then 1.0 else -1.0
        in [ (nr * sz + nc, val)
           | dr <- [-radius .. radius]
           , dc <- [-radius .. radius]
           , let dist = abs dr + abs dc
           , dist <= radius
           , let val = if dist == 0
                       then sign * baseStrength * 3
                       else sign * baseStrength * (decay ** fromIntegral dist)
           ]
  in V.accum (+) (V.replicate n 0.0) allUpdates
```

Each stone radiates influence that decays exponentially with Manhattan distance. A black stone at the center contributes +12.0 to its own point, +2.0 to each adjacent point, +1.0 to points two steps away, and so on, out to a radius of 4–6 depending on board size. White stones contribute negative values. The `V.accum (+)` call sums all contributions into a single influence vector.

This influence map drives several strategic move generators:

- **Extensions**: play in areas where your own influence is strong, to consolidate territory. The engine penalizes moves that create empty triangles (an inefficient shape) or that connect to groups that are already safe.
- **Moyo reduction**: if the opponent has built a thick wall of influence (but not yet solid territory), invade or reduce it. The engine looks for empty points where enemy influence is between 2.0 and 6.0: strong enough to be worth reducing, but not so strong that the invasion is suicidal.
- **Approach moves**: play near enemy groups to apply pressure, with care for edge distance and safety.
- **Connections**: if two friendly groups are close together, play a point that connects them, making both stronger.
- **Big points**: play on the third or fourth line in unclaimed areas. This is the classical "big point" concept from Go theory.

The strategic engine also estimates the score:

```haskell{line-numbers: true}
estimateScore :: StrategicEngine -> Double
estimateScore se =
  let score = foldl' count 0 [0 .. n - 1]
        where count !acc i =
                let stoneVal = case stoneAt b i of
                      Occupied Black -> 1
                      Occupied White -> -1
                      Empty          -> 0
                    terrVal = if stoneAt b i == Empty then seTerritory se V.! i else 0
                in acc + stoneVal + terrVal
  in fromIntegral score - 6.5
```

The komi of 6.5 is subtracted from Black's score, reflecting the standard compensation White receives for moving second. The half-point prevents draws.

## The Joseki Engine: Opening Patterns

*Joseki* are established corner opening sequences or moves that are considered equitable for both players. The Joseki engine in `Joseki.hs` encodes a small library of patterns as data:

```haskell{line-numbers: true}
data JosekiPattern = JP
  { jpName   :: !String
  , jpStones :: ![(Int, Int, Int)]  -- (dr, dc, colorInt)
  , jpSide   :: !Color              -- whose turn to play the reply
  , jpReply  :: !(Int, Int)         -- relative reply coordinate
  , jpWeight :: !Double
  } deriving (Show, Eq)
```

Each pattern specifies a set of stones in relative coordinates (from a corner origin), which color is to move, and what the joseki reply should be. For example:

```haskell
JP "44-ikken-kakari-extend" [(3, 3, 1), (2, 3, 2)] Black (3, 4) 65.0
```

This pattern says: if there is a black stone at the 4-4 point (relative coordinate (3,3)) and a white stone one space above it at (2,3), this is called an *ikken kakari* or one-space approach, then the joseki reply for Black is to extend to (3,4), the side extension. The weight of 65.0 reflects how strongly the engine recommends this move.

The clever part is corner symmetry. Each pattern is checked against all four corners of the board, with the coordinate system flipped appropriately:

```haskell{line-numbers: true}
corners :: Board -> [(Int, Int, Int, Int)]
corners b =
  let s = boardSize b
  in [ (0,     0,      1,  1)   -- top-left
     , (0,     s - 1,  1, -1)   -- top-right
     , (s - 1, 0,     -1,  1)   -- bottom-left
     , (s - 1, s - 1, -1, -1)   -- bottom-right
     ]
```

Each tuple is `(originRow, originCol, rowDirection, colDirection)`. By flipping the directions, the same pattern definition applies to all four corners without duplication. The engine also handles color swaps: if the same pattern appears but with colors reversed (because the human is White instead of Black), the pattern is matched with swapped color values.

When the board is nearly empty (move count ≤ 4), the engine also generates *fuseki* (opening) moves: star points and komoku (3-4 point) positions. Star points get a base score of 50 if they are in a corner region with no nearby stones, dropping to 30 if the corner is already contested.

The engine also penalizes empty triangles: the same shape check appears here as in the strategic engine, because empty triangles are universally bad:

```haskell{line-numbers: true}
createsEmptyTriangle :: Board -> Int -> Color -> Bool
createsEmptyTriangle b idx color =
  let topLefts = [ (r - 1, c - 1), (r - 1, c), (r, c - 1), (r, c) ]
      check tr tc =
        let corners = [ tr * sz + tc, tr * sz + tc + 1
                      , (tr + 1) * sz + tc, (tr + 1) * sz + tc + 1 ]
            friendly = length [ () | ci <- corners, ci == idx || boardGrid b V.! ci == colI ]
            emptyCount = length [ () | ci <- corners, ci /= idx && boardGrid b V.! ci == 0 ]
        in friendly == 3 && emptyCount == 1 && enemyCount == 0
  in any (uncurry check) topLefts
```

An empty triangle is a 2×2 box where three corners are friendly stones and one is empty. It is the quintessential "heavy" shape in Go because it uses three stones to control very little territory. The penalty reduces a joseki pattern's weight to 30% of its normal value if the resulting move would create an empty triangle.

## Monte Carlo Tree Search

The MCTS engine in `MCTS.hs` is the program's search component. Monte Carlo Tree Search works by playing thousands of simulated games (called *playouts*) from the current position, using the results to build a statistics tree that guides which moves to explore further.

The tree node stores both standard MCTS statistics (visits and wins) and RAVE statistics:

```haskell{line-numbers: true}
data MCTSNode = MCTSNode
  { nodeIndex      :: !Int        -- move that led here
  , nodeChildren   :: ![MCTSNode]
  , nodeUntried    :: ![Int]      -- moves not yet expanded
  , nodeVisits     :: !Int
  , nodeWins       :: !Double
  , nodeRaveVisits :: !Int
  , nodeRaveWins   :: !Double
  , nodeColor      :: !Color      -- color to move at this node
  , nodeExpanded   :: !Bool
  } deriving (Show)
```

RAVE (Rapid Action Value Estimation) is a technique that dramatically speeds up convergence in Go. The idea is that in Go, the value of a move is often similar regardless of exactly when it is played. RAVE tracks, for each move, how often it appeared in winning playouts across the entire tree, not just in the specific branch where it was tried. This gives a statistical "prior" for moves that have been tried only a few times in a particular branch but many times overall.

The child selection formula combines UCT exploitation and exploration with the RAVE estimate:

```haskell{line-numbers: true}
uctValue child
  | nodeVisits child == 0 = 1e9  -- always explore unvisited
  | otherwise =
      let winRate  = nodeWins child / fromIntegral (nodeVisits child)
          exploreT = exploit * sqrt (logN / fromIntegral (nodeVisits child))
          raveVal  = if nodeRaveVisits child > 0
                     then nodeRaveWins child / fromIntegral (nodeRaveVisits child)
                     else 0
          beta     = let rv = fromIntegral (nodeRaveVisits child)
                         v  = fromIntegral (nodeVisits child)
                         rb = mctsRaveBias eng
                     in  rv / (v + rv + 4 * rb * rb * v * rv)
      in  (1 - beta) * winRate + beta * raveVal + exploreT
```

The `beta` parameter interpolates between the direct win rate (reliable when a node has many visits) and the RAVE estimate (better when visits are few). As a node accumulates visits, `beta` shrinks and the direct win rate dominates. This is the standard RAVE formula from the research literature.

The search loop is time-limited and playout-limited:

```haskell{line-numbers: true}
let loop !playoutCount = do
      now <- getCurrentTime
      let elapsedMs = round (diffUTCTime now startTime * 1000) :: Int
      if playoutCount >= mctsMaxPlayouts eng || elapsedMs >= mctsTimeLimitMs eng
        then return ()
        else do
          root <- readIORef rootRef
          gen  <- readIORef genRef
          let (root', gen') = runPlayout eng board0 root rootColor gen
          writeIORef rootRef root'
          writeIORef genRef gen'
          loop (playoutCount + 1)
```

This is one of the few places in the program that uses `IORef`. The search tree is mutable because each playout modifies statistics along a path from root to leaf, and rebuilding the entire tree immutably on every playout would be expensive. The `IORef` holds the root node; each playout reads the root, runs the four-phase cycle (selection, expansion, simulation, backpropagation), and writes the modified root back. The random number generator is also kept in an `IORef` so that each playout can thread the generator state to the next.

### Playout Policy

The *playout* is the random simulation from a leaf to a terminal position and this is where MCTS gets its strategic knowledge. A purely random playout plays legal moves uniformly at random, which produces unrealistic games and weak play. This engine uses *heavy playouts*: the playout policy incorporates tactical knowledge.

```haskell{line-numbers: true}
playoutMove :: Board -> StdGen -> (Maybe Int, StdGen)
playoutMove board gen =
  let -- 1. Capture enemy atari groups
      captures = [ lib | i <- [0 .. n - 1]
                        , boardGrid board `vecAt` i == colorToInt' enemy
                        , groupLiberties (groupInfo board i) == 1
                        , let lib = findGroupLib board (groupStones (groupInfo board i))
                        , lib >= 0
                  ]
      -- 2. Collect candidate empty points (avoiding eyes and first line)
      allCandidates = [ i | i <- [0 .. n - 1]
                           , stoneAt board i == Empty
                           , not (isOwnEye board i color) ]
  in  case captures of
        (lib:_) -> (Just lib, gen)    -- always take captures
        []      -> candidates gen      -- otherwise play randomly
```

The playout policy has two rules: always capture enemy groups in atari (this is almost always correct), and avoid playing into your own eyes (filling your own eye is almost always wrong). Beyond that, moves are random, with a preference for non-edge points. This is a minimalist heavy playout and production engines like GNU Go use much richer pattern-based playout policies, but even these two rules produce dramatically more realistic simulations than pure randomness.

## The Rule Engine: Nineteen Heuristic Adjustments

The `Rules.hs` module is the largest in the project (over 1200 lines) and contains nineteen independent heuristic rules. Each rule is a function from `(Board, Int, Int, Color)` to a `Double` score delta, wrapped in a `Rule` record:

```haskell{line-numbers: true}
data Rule = Rule
  { ruleName     :: !String
  , ruleWeight   :: !Double
  , ruleEvaluate :: !(Board -> Int -> Int -> Color -> Double)
  }
```

The `ruleWeight` is a global multiplier applied to the rule's output. Rules with weight 3.0 (like "avoid-edge-unless-capture" and "avoid-self-atari") have three times the impact of rules with weight 1.0.

The rules are registered in a simple list:

```haskell{line-numbers: true}
buildStandardRules :: [Rule]
buildStandardRules =
  [ fourPointResponseRule
  , avoidDensePlacementRule
  , avoidEdgeUnlessCaptureRule
  , openingLinePreferenceRule
  , ladderAvoidanceRule
  , avoidSelfAtariRule
  , local7x7ContextRule
  , doubleAtariRule
  , avoidConnectingIsolatedStoneRule
  , respondToContactOnWeakStoneRule
  , tacticalSurvivalRule
  , cornerStrategyRule
  , playLightlyWhenAttachedRule
  , preferSidesOverCenterRule
  , emptyTriangleRule
  , lightConnectionRule
  , avoidWeakNewStoneRule
  , contactResponseRule
  , avoidLeavingGroupInAtariRule
  , cuttingRule
  ]
```

This is a data-driven design. Adding a new rule is as simple as writing a `Rule` value and adding it to the list. The rule engine evaluates every candidate move through every rule and sums the deltas:

```haskell{line-numbers: true}
evaluateMove :: RuleEngine -> Board -> Int -> Int -> Double
evaluateMove eng b i moveCount =
  let aiColor = boardToMove b
  in foldl' (\acc rule -> acc + ruleEvaluate rule b i moveCount aiColor * ruleWeight rule)
            0.0 (reRules eng)
```

Let me highlight a few of the more interesting rules.

**Avoid edge unless capturing** (weight 3.0): Playing on the first or second line in the opening is generally bad because edge stones control very little territory. This rule penalizes edge moves by -30 (first line) or -10 (second line), unless the move captures something or saves a group in atari. The penalty is further increased if the surrounding area is completely empty.

**Ladder avoidance** (weight 1.0): This rule does double duty. First, it penalizes moves that would put your own group into a working ladder. Second, it gives a bonus to moves that escape or break a ladder for a group already in danger. The rule includes a full ladder simulation (`simulateLadderPath`) that traces the sequence of forced moves, so it can identify which points on the board would break the ladder.

**Double atari** (weight 1.0): A move that puts two enemy groups into atari simultaneously is devastating because the opponent can only save one. This rule gives a bonus of 50 + (extraAtaris - 2) × 15 for such moves.

**Empty triangle and light shape** (weight 1.0): This rule penalizes moves that create empty triangles (35 per triangle), moves that connect directly to two or more friendly stones with no enemy nearby (15), and moves that extend an unbroken line of three or more stones (8 + 6 per extra stone). All penalties are waived if the move has a tactical justification, for example touching an enemy stone, saving a group in atari, or capturing stones.

**Contact response** (weight 2.0): When the opponent plays a contact move (a stone touching yours), the classical responses are the *hane* (diagonal contact) and the *extend* (straight extension). This rule gives a bonus of 30 for a hane that puts the contacting stone into atari, 20 for a regular hane, and 12 for an extend. It also penalizes direct connections that would put your own stones into atari.

**Cutting** (weight 2.0): A *cut* is a move that separates two enemy groups, preventing them from connecting. This rule gives a bonus of 30 + (groups - 1) × 15 + totalEnemyStones × 4, scaled by a safety factor based on the cutting stone's own liberties.

These rules encode Go knowledge in algorithmic form. No single rule is decisive: each contributes a small delta to the move's score but together they steer the AI away from amateur mistakes and toward moves that a club-level player would recognize as reasonable.

## The Master Agent: Orchestration

The `Agent.hs` module ties everything together. The `decideMove` function is the AI's entry point:

```haskell{line-numbers: true}
decideMove :: Board -> Int -> AgentOptions -> StdGen -> IO AgentResult
decideMove b moveCount opts gen = do
  let phase = detectPhase b

  -- 1. Run heuristic engines (pure)
  let tacticalMoves   = generateTacticalMoves b 40
      strategicEngine  = newStrategicEngine b
      strategicMoves   = generateStrategicMoves strategicEngine
      josekiMoves      = generateJosekiMoves b moveCount

  -- 2. Check for immediate tactical urgency (score >= 100)
  let urgentTactical = filter (\m -> smScore m >= 100) tacticalMoves
  if not (null urgentTactical)
    then return (result with best urgent tactical move ...)
    else do
      -- 3. Run MCTS search (impure: IORef, time limit)
      mctsMoves <- mctsSearch mctsEngine gen

      -- 4. Check resign
      -- 5. Check pass
      -- 6. Aggregate all engine scores with phase weights
      -- 6b. Apply rule-engine adjustments
      -- 7. Select best move (with MCTS boost for high-confidence moves)
      -- 8. Fallback to a reasonable move if nothing was found
```

The decision pipeline has a short-circuit: if the tactical engine finds a move with score ≥ 100 (a capture or a critical save), the AI plays it immediately without running MCTS. This is a performance optimization because there is no point spending two seconds on MCTS search when the right move is obvious tactically.

The resign and pass checks use the strategic engine's score estimate. The AI resigns if it is more than 30 points behind and fewer than 15% of the board points remain empty. It passes if MCTS thinks no move is worth more than 5 points and the AI is already ahead, or if the board is 85% full with no tactical moves available.

The final move selection includes an MCTS confidence boost:

```haskell{line-numbers: true}
let bestMctsMove =
      case mctsMoves of
        (best:_) | smScore best > 60.0 ->
           let currentVal = M.findWithDefault (0.0, []) (smIndex best) aggregate1
           in Just (smIndex best, fst currentVal + 50.0, smReason best)
        _ -> Nothing
```

If MCTS's top move has a win rate above 60%, it gets an additional 50-point boost in the aggregated score. This ensures that when MCTS has high confidence in a move, it can override the heuristic engines' recommendations.

## The Game Loop

The `Main.hs` module implements the terminal interface. The game state is a simple record:

```haskell{line-numbers: true}
data GameState = GameState
  { gsBoard             :: !Board
  , gsHistory           :: ![Board]      -- for undo
  , gsMoveCount         :: !Int
  , gsConsecutivePasses :: !Int
  , gsGameOver          :: !Bool
  , gsStrength          :: !Int          -- playout budget
  , gsGen               :: !StdGen
  }
```

The `gsHistory` field stores a list of previous boards, enabling the `undo` command to revert the last full turn (both the human's move and the AI's response). Because boards are immutable, undo is simply a matter of restoring a previous board from the history list, so no reverse-move logic required.

The board rendering uses Unicode characters for stones:

```haskell{line-numbers: true}
renderCell r c =
  let idx = r * sz + c
  in case stoneAt b idx of
    Occupied Black -> "● "
    Occupied White -> "○ "
    Empty -> if isStarPoint r c sz then "+ " else ". "
```

Star points (the traditional marked intersections) are drawn as `+`, empty points as `.`, black stones as `●`, and white stones as `○`. The column labels skip the letter `I` (a Go convention to avoid confusion with `1`):

```haskell
colsAlphabet = "ABCDEFGHJKLMNOPQRST"
```

The game loop alternates between `promptHuman` and `aiTurn`. The human's input is parsed as a coordinate like `D4` (column D, row 4) and converted to a flat board index. The AI's turn calls `decideMove` and displays the result, including the AI's reasoning:

```
  AI plays: F4
  Reason: joseki: 44-ikken-kakari-extend (117); extend influence (18)
  Phase: Opening
```

Here the AI played F4 because two engines agreed: the joseki engine recommended it as a one-space kakari extension (weighted score 117 in the opening phase), and the strategic engine recommended it as an influence extension (score 18). The concatenated reasons give the human player a window into the AI's multi-engine deliberation.

## Playing a Game

Let us look at a sample interaction. We start a 9×9 game with the default strength:

```
$ cabal run

╔══════════════════════════════════════════════╗
║      Go AI Engine CLI (Haskell v1.0)       ║
╚══════════════════════════════════════════════╝
  Board: 9x9  |  Strength: 3000 playouts
  You: Black (●)  |  AI: White (○)
  Commands: D4 / pass / resign / undo / score / help / quit

  A B C D E F G H J
9 . . . . . . . . .
8 . . . . . . . . .
7 . . . . . . . . .
6 . . . + . . + . .
5 . . . . . . . . .
4 . . + . + . + . .
3 . . . . . . . . .
2 . . . + . . + . .
1 . . . . . . . . .
  A B C D E F G H J
  ──────────────────────────────────────────────────
  Your turn (Black)  |  Move #1
  Captures: Black: 0  White: 0
  ──────────────────────────────────────────────────

  Your move (e.g. D4): f4
  You play: F4

  A B C D E F G H J
9 . . . . . . . . .
8 . . . . . . . . .
7 . . . . . . . . .
6 . . . + . . + . .
5 . . . . . . . . .
4 . . + . ● . + . .
3 . . . . . . . . .
2 . . . + . . + . .
1 . . . . . . . . .
  A B C D E F G H J
  ──────────────────────────────────────────────────
  AI's turn (White)  |  Move #2
  ──────────────────────────────────────────────────

  AI is thinking... (strength: 3000)
  AI plays: D4
  Reason: joseki: 44-kogeima-kakari-extend (55); big point (12)
  Phase: Opening
```

The human played F4, a corner star point. The AI responded with D4, the opposite corner star point, recommended by both the joseki engine (a knight's move extension pattern) and the strategic engine (a big point on the third line). The game continues with each side building corner frameworks, then transitioning to middle-game fighting as the groups come into contact.

## Design Notes

A few architectural choices in this program are worth reflecting on:

**Pure engines, impure shell.** The tactical, strategic, joseki, and rule engines are all pure functions. They take a `Board` and return `[ScoredMove]` or `Double` so no `IO` and no mutation are required. The only impure code is in `MCTS.hs` (which uses `IORef` for its mutable tree and `getCurrentTime` for its time limit) and in `Main.hs` (the terminal interaction). This separation makes the engines easy to test in GHCi: you can construct a board, call `generateTacticalMoves b 40`, and inspect the results without setting up any mock state or environment.

**Data-driven rules.** The rule engine is a list of `Rule` records, each with a name, weight, and evaluation function. Adding a new rule is a matter of writing one function and adding it to `buildStandardRules`. There is no registration framework, no plugin system because we just lists. This is the Haskell advantage: the simplicity of algebraic data types and higher-order functions makes lightweight extensibility natural.

**Immutable boards as first-class values.** The `Board` type is a record with an unboxed vector, strict fields, and a deriving `Show` instance. Boards are passed around, stored in history lists, used as keys in aggregations, and printed for debugging, all without any concern for aliasing or mutation. The `cloneBoard` function is the identity function, and that is the whole point: immutability means cloning is free.

**Phase-dependent weighting.** The master agent adjusts the weights of each engine based on the game phase. This is a simple form of meta-reasoning: the AI knows that joseki matters in the opening but not in the endgame, and that tactical precision matters most when the board is full and every liberty counts. Encoding this as a weight table rather than hard-coded if-then-else logic makes the meta-strategy easy to inspect and tune.

**Explainable moves.** Every `ScoredMove` carries a reason string, and the agent concatenates all reasons that contributed to the final move. This makes the AI's decisions transparent so you can see which engines agreed and which disagreed. In an era where AI explainability is increasingly important, this design choice is both practically useful for debugging and pedagogically valuable for understanding how the engines interact.

**The MCTS `IORef` compromise.** The search tree is mutable because each playout updates statistics along a path, and rebuilding the tree immutably on every playout would be too expensive for thousands of iterations per second. This is a pragmatic trade-off: the rest of the program is pure, but the MCTS engine uses `IORef` for performance. The `runPlayout` function itself is pure (it takes and returns a `StdGen` and produces a new root node), so the impurity is confined to the search loop that reads and writes the `IORef`.

## Wrap Up

We have built a complete Go-playing program with a multi-engine AI architecture. The key insight is that Go is too complex for a single evaluation function, so we decompose the problem into independent aspects (tactical urgency, strategic influence, opening patterns, stochastic search, and heuristic rules) and combine their outputs with phase-dependent weights. Each engine is a pure function that can be tested in isolation, and the only impurity lives in the MCTS search loop and the terminal interface.

This architecture is, in miniature, the same architecture that powered the best Go programs before the deep-learning revolution of AlphaGo. The difference is that AlphaGo replaced the hand-crafted feature detectors with neural networks, and the Monte Carlo playouts with neural network policy and value evaluation. But the overall structure, with multiple specialized evaluators whose outputs are combined, remains recognizable. The program in this chapter is a window into that earlier era of game AI, implemented in a language whose purity and type safety make the architecture unusually clear.

I encourage you to play a few games against the AI and then experiment with the engines. Try changing the phase weights in `aggregateMoves` and observe how the AI's opening play changes. Add a new rule to `buildStandardRules`, perhaps a rule that penalizes playing on top of your own influence, or a rule that rewards splitting the opponent's groups. The data-driven design makes these experiments straightforward.

## Optional Practice Problems

1. The joseki engine currently encodes patterns as a static list in `buildPatterns`. Replace this with a pattern loader that reads patterns from an external file (in a simple text format). Each line of the file should specify a pattern name, a list of relative stone positions with colors, the side to move, the reply coordinate, and the weight. This will let you expand the joseki library without recompiling.

	2. The MCTS playout policy is minimalist: it always captures atari groups and avoids eyes, but otherwise plays randomly. Add a pattern-based move generator to the playout: for each empty candidate point, check whether playing there would create a common local pattern (a 3-stone wall, a hane, a tiger's mouth, a bamboo joint) and give such moves higher probability of being selected. This should improve the playout quality and thus the MCTS search strength. Measure the improvement by playing 100 games between the old and new versions.