{-# LANGUAGE BangPatterns #-}
-- | Main.hs — Command-line Go game in Haskell against the AI engine.
module Main where

import           Board
import           Agent
import           Strategic
import           System.Environment (getArgs)
import           System.IO          (hFlush, stdout)
import           System.Random      (getStdGen, splitGen, StdGen)
import           System.Exit        (exitSuccess)
import           Data.Char          (toLower, toUpper, isDigit)

-- ── Coordinate Helpers ────────────────────────────────────

colsAlphabet :: String
colsAlphabet = "ABCDEFGHJKLMNOPQRST"

indexToCoord :: Int -> Int -> String
indexToCoord sz idx =
  let r = idx `div` sz
      c = idx `mod` sz
      rowLabel = show (sz - r)
      colLabel = [colsAlphabet !! c]
  in colLabel ++ rowLabel

coordToIndex :: Int -> String -> Int
coordToIndex sz coord =
  case parseCoord (map toUpper coord) of
    Just (colChar, rowNum) ->
      let c = indexOf colChar colsAlphabet
          r = sz - rowNum
      in if c >= 0 && c < sz && r >= 0 && r < sz
         then r * sz + c
         else -1
    Nothing -> -1
  where
    parseCoord (x:xs)
      | x `elem` colsAlphabet && all isDigit xs && not (null xs) =
          Just (x, read xs :: Int)
    parseCoord _ = Nothing

    indexOf _ [] = -1
    indexOf chr (y:ys)
      | chr == y  = 0
      | otherwise = let idx = indexOf chr ys in if idx == -1 then -1 else idx + 1

-- ── Star Point Helpers ────────────────────────────────────

isStarPoint :: Int -> Int -> Int -> Bool
isStarPoint r c sz =
  let edge = if sz <= 9 then 2 else 3
      mid = (sz - 1) `div` 2
      pts = [ (rr, cc)
            | rr <- [edge, mid, sz - 1 - edge]
            , cc <- [edge, mid, sz - 1 - edge]
            , not (sz `mod` 2 == 0 && rr == mid && cc == mid)
            , not (sz <= 9 && rr == mid && cc == mid)
            ]
  in (r, c) `elem` pts

-- ── Board Rendering ───────────────────────────────────────

renderBoard :: Board -> String
renderBoard b =
  let sz = boardSize b
      rowLabelW = length (show sz)
      prefix = replicate (rowLabelW + 1) ' '

      header = prefix ++ concatMap (\cl -> cl : " ") (take sz colsAlphabet)

      renderRow r =
        let rowLabel = padLeft rowLabelW (show (sz - r)) ++ " "
            rowStones = concatMap (renderCell r) [0 .. sz - 1]
        in rowLabel ++ rowStones

      renderCell r c =
        let idx = r * sz + c
        in case stoneAt b idx of
          Occupied Black -> "● "
          Occupied White -> "○ "
          Empty -> if isStarPoint r c sz then "+ " else ". "

      rows = map renderRow [0 .. sz - 1]
      footer = header
  in unlines (header : rows ++ [footer])

padLeft :: Int -> String -> String
padLeft w s = replicate (w - length s) ' ' ++ s

-- ── State Representation ──────────────────────────────────

data GameState = GameState
  { gsBoard             :: !Board
  , gsHistory           :: ![Board]
  , gsMoveCount         :: !Int
  , gsConsecutivePasses :: !Int
  , gsGameOver          :: !Bool
  , gsStrength          :: !Int
  , gsGen               :: !StdGen
  }

showStatus :: GameState -> IO ()
showStatus gs = do
  let b = gsBoard gs
      toMove = case boardToMove b of
                 Black -> "Black"
                 White -> "White"
      who = if boardToMove b == Black then "Your turn" else "AI's turn"
      (bCaps, wCaps) = boardCaptures b
  putStrLn $ replicate 50 '─'
  putStrLn $ "  " ++ who ++ " (" ++ toMove ++ ")  |  Move #" ++ show (gsMoveCount gs + 1)
  putStrLn $ "  Captures — Black: " ++ show bCaps ++ "  White: " ++ show wCaps
  if gsConsecutivePasses gs == 1
    then putStrLn "  ⚠ One pass — another pass ends the game."
    else return ()
  putStrLn $ replicate 50 '─'

showScoreEstimate :: Board -> IO ()
showScoreEstimate b = do
  let strat = newStrategicEngine b
      score = estimateScore strat
      aiPerspective = -score -- AI is White
  putStrLn $ "\n  Score estimate (Black's perspective): " ++ (if score > 0 then "+" else "") ++ show score
  if aiPerspective > 0
    then putStrLn $ "  AI is ahead by " ++ show aiPerspective ++ " points."
    else putStrLn $ "  AI is behind by " ++ show (-aiPerspective) ++ " points."

fullDisplay :: GameState -> IO ()
fullDisplay gs = do
  putStrLn $ "\n" ++ renderBoard (gsBoard gs)
  showStatus gs

-- ── Game Loop ─────────────────────────────────────────────

main :: IO ()
main = do
  args <- getArgs
  let sz = case args of
             (x:_) | x `elem` ["9", "13", "19"] -> read x :: Int
             _ -> 9
      strength = case args of
                   (_:y:_) -> read y :: Int
                   _ -> 3000

  putStrLn "╔══════════════════════════════════════════════╗"
  putStrLn "║      Go — AI Engine CLI (Haskell v1.0)       ║"
  putStrLn "╚══════════════════════════════════════════════╝"
  putStrLn $ "  Board: " ++ show sz ++ "x" ++ show sz ++ "  |  Strength: " ++ show strength ++ " playouts"
  putStrLn "  You: Black (●)  |  AI: White (○)"
  putStrLn "  Commands: D4 / pass / resign / undo / score / help / quit"
  putStrLn ""

  gen <- getStdGen
  let b = emptyBoard sz
      gs = GameState
             { gsBoard             = b
             , gsHistory           = []
             , gsMoveCount         = 0
             , gsConsecutivePasses = 0
             , gsGameOver          = False
             , gsStrength          = strength
             , gsGen               = gen
             }
  fullDisplay gs
  gameLoop gs

gameLoop :: GameState -> IO ()
gameLoop gs
  | gsGameOver gs = do
      putStrLn "\n  Game over. Type 'new' for a new game or 'quit' to exit."
      promptHuman gs
  | boardToMove (gsBoard gs) == White = do
      aiTurn gs
  | otherwise = do
      promptHuman gs

promptHuman :: GameState -> IO ()
promptHuman gs = do
  putStr "\n  Your move (e.g. D4): "
  hFlush stdout
  line <- getLine
  let input = trim (map toLower line)
  case input of
    "quit" -> do
      putStrLn "  Goodbye!"
      exitSuccess
    "exit" -> do
      putStrLn "  Goodbye!"
      exitSuccess
    "help" -> do
      putStrLn "  Commands:"
      putStrLn "    D4       — play at column D, row 4"
      putStrLn "    pass     — pass your turn"
      putStrLn "    resign   — resign the game"
      putStrLn "    undo     — undo last full turn"
      putStrLn "    score    — show score estimate"
      putStrLn "    board    — redraw the board"
      putStrLn "    new      — start a new game"
      putStrLn "    quit     — exit"
      gameLoop gs
    "resign" -> do
      putStrLn "  You resign. AI wins!"
      gameLoop gs { gsGameOver = True }
    "undo" -> do
      case gsHistory gs of
        -- Revert both human and AI moves if possible
        (_prevAI:prevHuman:rest) -> do
          putStrLn "  Undid last turn."
          let gs' = gs
                     { gsBoard = prevHuman
                     , gsHistory = rest
                     , gsMoveCount = max 0 (gsMoveCount gs - 2)
                     , gsConsecutivePasses = 0
                     , gsGameOver = False
                     }
          fullDisplay gs'
          gameLoop gs'
        (prevHuman:rest) -> do
          putStrLn "  Undid last move."
          let gs' = gs
                     { gsBoard = prevHuman
                     , gsHistory = rest
                     , gsMoveCount = max 0 (gsMoveCount gs - 1)
                     , gsConsecutivePasses = 0
                     , gsGameOver = False
                     }
          fullDisplay gs'
          gameLoop gs'
        [] -> do
          putStrLn "  No history to undo."
          gameLoop gs
    "score" -> do
      showScoreEstimate (gsBoard gs)
      gameLoop gs
    "board" -> do
      fullDisplay gs
      gameLoop gs
    "new" -> do
      let sz = boardSize (gsBoard gs)
          b = emptyBoard sz
          gs' = gs
                  { gsBoard             = b
                  , gsHistory           = []
                  , gsMoveCount         = 0
                  , gsConsecutivePasses = 0
                  , gsGameOver          = False
                  }
      putStrLn "  New game started."
      fullDisplay gs'
      gameLoop gs'
    "pass" -> do
      let b = gsBoard gs
          b' = passMove b
          cp = gsConsecutivePasses gs + 1
          gameOver' = cp >= 2
          gs' = gs
                  { gsBoard             = b'
                  , gsHistory           = b : gsHistory gs
                  , gsMoveCount         = gsMoveCount gs + 1
                  , gsConsecutivePasses = cp
                  , gsGameOver          = gameOver'
                  }
      putStrLn "  You pass."
      if gameOver'
        then do
          putStrLn "\n  Two passes — game over!"
          showScoreEstimate b'
          gameLoop gs'
        else do
          fullDisplay gs'
          gameLoop gs'
    _ -> do
      let sz = boardSize (gsBoard gs)
          idx = coordToIndex sz input
      if idx < 0
        then do
          putStrLn "  Invalid coordinate. Use like: D4, Q16, etc."
          gameLoop gs
        else
          let b = gsBoard gs
          in case tryPlay b idx of
            Just b' -> do
              putStrLn $ "  You play: " ++ map toUpper input
              let gs' = gs
                          { gsBoard             = b'
                          , gsHistory           = b : gsHistory gs
                          , gsMoveCount         = gsMoveCount gs + 1
                          , gsConsecutivePasses = 0
                          }
              fullDisplay gs'
              gameLoop gs'
            Nothing -> do
              putStrLn "  Illegal move (suicide, ko, or occupied)."
              gameLoop gs

aiTurn :: GameState -> IO ()
aiTurn gs = do
  let b = gsBoard gs
      sz = boardSize b
      strength = gsStrength gs
      (gen1, gen2) = splitGen (gsGen gs)

  putStrLn $ "\n  AI is thinking... (strength: " ++ show strength ++ ")"

  let boardCells = sz * sz
      sizeScale = if boardCells <= 81 then 1.0 else if boardCells <= 169 then 0.6 else 0.3 :: Double
      scaledPlayouts = max 200 (round (fromIntegral strength * sizeScale) :: Int)
      scaledTime = if strength >= 3000 then 2000 else if strength >= 1500 then 1200 else 600

      opts = AgentOptions
               { aoTimeLimitMs = scaledTime
               , aoMaxPlayouts = scaledPlayouts
               , aoKomi        = 6.5
               , aoVerbose     = True
               }

  result <- decideMove b (gsMoveCount gs) opts gen1

  if arResign result
    then do
      putStrLn "  AI resigns! You win!"
      gameLoop gs { gsGameOver = True }
    else if arPass result
      then do
        putStrLn "  AI passes."
        putStrLn $ "  Reason: " ++ arReason result
        let b' = passMove b
            cp = gsConsecutivePasses gs + 1
            gameOver' = cp >= 2
            gs' = gs
                    { gsBoard             = b'
                    , gsHistory           = b : gsHistory gs
                    , gsMoveCount         = gsMoveCount gs + 1
                    , gsConsecutivePasses = cp
                    , gsGameOver          = gameOver'
                    , gsGen               = gen2
                    }
        if gameOver'
          then do
            putStrLn "\n  Two passes — game over!"
            showScoreEstimate b'
            gameLoop gs'
          else do
            fullDisplay gs'
            gameLoop gs'
      else do
        let aiIdx = arMove result
            coord = indexToCoord sz aiIdx
        putStrLn $ "  AI plays: " ++ coord
        putStrLn $ "  Reason: " ++ arReason result
        putStrLn $ "  Phase: " ++ show (arPhase result)

        -- Execute the move
        case tryPlay b aiIdx of
          Nothing -> do
            putStrLn $ "  WARNING: AI move " ++ coord ++ " was illegal! Trying fallback..."
            -- Prefer interior moves; allow edge only if capturing
            let edgeDistIdx idx =
                  let r = idx `div` sz; c = idx `mod` sz
                  in minimum [r, c, sz - 1 - r, sz - 1 - c]
                isCapturingIdx idx =
                  any (\nb -> stoneAt b nb == Occupied Black &&
                              groupLiberties (groupInfo b nb) == 1) (neighbors b idx)
                legalNonEyeIdx idx =
                  stoneAt b idx == Empty &&
                  not (isOwnEye b idx White) &&
                  isLegalMove b idx
                interiorMoves = [ i | i <- [0 .. sz*sz - 1], legalNonEyeIdx i, edgeDistIdx i >= 2 ]
                capturingEdgeMoves = [ i | i <- [0 .. sz*sz - 1], legalNonEyeIdx i, edgeDistIdx i < 2, isCapturingIdx i ]
                anyLegalMoves = [ i | i <- [0 .. sz*sz - 1], legalNonEyeIdx i ]
                fallbackMoves =
                  if not (null interiorMoves) then interiorMoves
                  else if not (null capturingEdgeMoves) then capturingEdgeMoves
                  else anyLegalMoves
            case fallbackMoves of
              (f:_) -> do
                let coord' = indexToCoord sz f
                case tryPlay b f of
                  Just b' -> do
                    putStrLn $ "  Fallback: " ++ coord'
                    let gs' = gs
                                { gsBoard             = b'
                                , gsHistory           = b : gsHistory gs
                                , gsMoveCount         = gsMoveCount gs + 1
                                , gsConsecutivePasses = 0
                                , gsGen               = gen2
                                }
                    fullDisplay gs'
                    gameLoop gs'
                  Nothing -> do
                    putStrLn "  AI passes (fallback was illegal)."
                    let b' = passMove b
                        cp = gsConsecutivePasses gs + 1
                        gameOver' = cp >= 2
                        gs' = gs
                                { gsBoard             = b'
                                , gsHistory           = b : gsHistory gs
                                , gsMoveCount         = gsMoveCount gs + 1
                                , gsConsecutivePasses = cp
                                , gsGameOver          = gameOver'
                                , gsGen               = gen2
                                }
                    if gameOver'
                      then do
                        putStrLn "\n  Two passes — game over!"
                        showScoreEstimate b'
                        gameLoop gs'
                      else do
                        fullDisplay gs'
                        gameLoop gs'
              [] -> do
                putStrLn "  AI passes (no legal fallback)."
                let b' = passMove b
                    cp = gsConsecutivePasses gs + 1
                    gameOver' = cp >= 2
                    gs' = gs
                            { gsBoard             = b'
                            , gsHistory           = b : gsHistory gs
                            , gsMoveCount         = gsMoveCount gs + 1
                            , gsConsecutivePasses = cp
                            , gsGameOver          = gameOver'
                            , gsGen               = gen2
                            }
                if gameOver'
                  then do
                    putStrLn "\n  Two passes — game over!"
                    showScoreEstimate b'
                    gameLoop gs'
                  else do
                    fullDisplay gs'
                    gameLoop gs'
          Just b' -> do
            let gs' = gs
                        { gsBoard             = b'
                        , gsHistory           = b : gsHistory gs
                        , gsMoveCount         = gsMoveCount gs + 1
                        , gsConsecutivePasses = 0
                        , gsGen               = gen2
                        }
            fullDisplay gs'
            gameLoop gs'

trim :: String -> String
trim = f . f
  where f = reverse . dropWhile (== ' ')
