{-# LANGUAGE BangPatterns #-}
-- | MasterAgent — top-level AI controller for playing Go against a human.
-- Orchestrates the specialized engines:
--   1. TacticalEngine  — local combat (atari, ladders, captures, saves)
--   2. StrategicEngine — whole-board strategy (influence, territory, moyo)
--   3. JosekiEngine    — opening theory (corner patterns, fuseki)
--   4. MCTSEngine      — stochastic search (UCT + RAVE + heavy playouts)
--   5. RuleEngine      — heuristic rule adjustments
module Agent
  ( GamePhase (..)
  , AgentOptions (..)
  , AgentResult (..)
  , decideMove
  , isLegalMove
  ) where

import           Board
import           Tactical
import           Strategic
import           Joseki
import           MCTS
import           Rules
import           System.Random (StdGen)
import           Data.List   (sortBy)
import           Data.Ord    (Down (..))
import qualified Data.Map.Strict as M

-- | Current phase of the game.
data GamePhase = Opening | Middle | Endgame
  deriving (Show, Eq)

-- | Options for the AI agent.
data AgentOptions = AgentOptions
  { aoTimeLimitMs :: !Int
  , aoMaxPlayouts :: !Int
  , aoKomi        :: !Double
  , aoVerbose     :: !Bool
  } deriving (Show)

-- | The result of the agent's decision.
data AgentResult = AgentResult
  { arMove         :: !Int          -- ^ Flat board index, or -1 for pass/resign
  , arPass         :: !Bool
  , arResign       :: !Bool
  , arReason       :: !String
  , arPhase        :: !GamePhase
  , arTactical     :: ![ScoredMove]
  , arStrategic    :: ![ScoredMove]
  , arJoseki       :: ![ScoredMove]
  , arMcts         :: ![ScoredMove]
  , arRules        :: ![(Int, Double, String)]
  } deriving (Show)

-- | Detect game phase based on filled ratio of board.
detectPhase :: Board -> GamePhase
detectPhase b =
  let sz = boardSize b
      total = sz * sz
      filled = length [ () | i <- [0 .. total - 1], stoneAt b i /= Empty ]
      ratio = fromIntegral filled / fromIntegral total :: Double
  in if ratio < 0.2 then Opening
     else if ratio < 0.6 then Middle
     else Endgame

-- | Check if the AI should pass (no good moves or game is ending).
shouldPass :: Board -> AgentOptions -> [ScoredMove] -> [ScoredMove] -> Bool
shouldPass b opts tactical mcts =
  let mctsPass =
        case mcts of
          (best:_) | smScore best < 5.0 ->
             let strat = newStrategicEngine b
                 score = estimateScore strat
                 aiColor = boardToMove b
                 aiAhead = if aiColor == Black
                           then score > aoKomi opts
                           else score < -aoKomi opts
             in aiAhead
          _ -> False

      sz = boardSize b
      total = sz * sz
      filled = length [ () | i <- [0 .. total - 1], stoneAt b i /= Empty ]
      fullPass = filled > round (fromIntegral total * 0.85 :: Double) && null tactical
  in mctsPass || fullPass

-- | Check if the AI should resign.
shouldResign :: Board -> AgentOptions -> Bool
shouldResign b _opts =
  let strat = newStrategicEngine b
      score = estimateScore strat
      aiColor = boardToMove b
      behind = if aiColor == Black then -score else score
      sz = boardSize b
      total = sz * sz
      filled = length [ () | i <- [0 .. total - 1], stoneAt b i /= Empty ]
      remaining = total - filled
  in behind > 30.0 && remaining < round (fromIntegral total * 0.15 :: Double)

-- | Aggregate moves from all engines with phase-based weighting.
aggregateMoves :: GamePhase -> [ScoredMove] -> [ScoredMove] -> [ScoredMove] -> [ScoredMove]
               -> M.Map Int (Double, [String])
aggregateMoves phase tactical strategic joseki mcts =
  let (wTac, wStr, wJos, wMcts) =
        case phase of
          Opening -> (1.0, 1.2, 1.8, 1.0)
          Middle  -> (1.5, 1.3, 0.5, 1.3)
          Endgame -> (1.8, 1.0, 0.1, 1.5)

      addMove mMap (ScoredMove idx score reason) weight =
        let weighted = score * weight
            fmtReason = reason ++ " (" ++ show (round weighted :: Int) ++ ")"
        in M.insertWith (\(scNew, rListNew) (scOld, rListOld) ->
                            (scNew + scOld, rListNew ++ rListOld))
                        idx (weighted, [fmtReason]) mMap

      mMap0 = foldl (\m mv -> addMove m mv wTac) M.empty tactical
      mMap1 = foldl (\m mv -> addMove m mv wStr) mMap0 strategic
      mMap2 = foldl (\m mv -> addMove m mv wJos) mMap1 joseki
      mMap3 = foldl (\m mv -> addMove m mv wMcts) mMap2 mcts
  in mMap3

-- | Main move decision function.
decideMove :: Board -> Int -> AgentOptions -> StdGen -> IO AgentResult
decideMove b moveCount opts gen = do
  let phase = detectPhase b

  -- 1. Run heuristic engines
  let tacticalMoves = generateTacticalMoves b 40
      strategicEngine = newStrategicEngine b
      strategicMoves = generateStrategicMoves strategicEngine
      josekiMoves = generateJosekiMoves b moveCount

  -- 2. Check for immediate tactical urgency (score >= 100)
  let urgentTactical = filter (\m -> smScore m >= 100) tacticalMoves
  if not (null urgentTactical)
    then do
      let best = head $ sortBy (\a y -> compare (Down (smScore a)) (Down (smScore y))) urgentTactical
      return AgentResult
        { arMove      = smIndex best
        , arPass      = False
        , arResign    = False
        , arReason    = smReason best
        , arPhase     = phase
        , arTactical  = tacticalMoves
        , arStrategic = strategicMoves
        , arJoseki    = josekiMoves
        , arMcts      = []
        , arRules     = []
        }
    else do
      -- 3. Run MCTS search
      let mctsEngine = MCTSEngine b 1.4 300.0 (aoMaxPlayouts opts) (aoTimeLimitMs opts)
      mctsMoves <- mctsSearch mctsEngine gen

      -- 4. Check resign
      if shouldResign b opts
        then return AgentResult
          { arMove      = -1
          , arPass      = False
          , arResign    = True
          , arReason    = "AI resigns (too far behind)"
          , arPhase     = phase
          , arTactical  = tacticalMoves
          , arStrategic = strategicMoves
          , arJoseki    = josekiMoves
          , arMcts      = mctsMoves
          , arRules     = []
          }
        else
          -- 5. Check pass
          if shouldPass b opts tacticalMoves mctsMoves
          then return AgentResult
            { arMove      = -1
            , arPass      = True
            , arResign    = False
            , arReason    = "AI passes (no good moves or ahead)"
            , arPhase     = phase
            , arTactical  = tacticalMoves
            , arStrategic = strategicMoves
            , arJoseki    = josekiMoves
            , arMcts      = mctsMoves
            , arRules     = []
            }
          else do
            -- 6. Aggregate scores
            let aggregate0 = aggregateMoves phase tacticalMoves strategicMoves josekiMoves mctsMoves

            -- 6b. Apply rule-engine adjustments
            let ruleEngine = newRuleEngine
                candidateIndices = M.keys aggregate0
                ruleResults = evaluateCandidates ruleEngine b candidateIndices moveCount
                aggregate1 = foldl (\m (idx, score, reason) ->
                                      M.adjust (\(sc, rList) -> (sc + score, rList ++ [reason ++ " (" ++ show (round score :: Int) ++ ")"])) idx m)
                                   aggregate0 ruleResults

            -- 7. Select best move
            let bestMctsMove =
                  case mctsMoves of
                    (best:_) | smScore best > 60.0 ->
                       let currentVal = M.findWithDefault (0.0, []) (smIndex best) aggregate1
                       in Just (smIndex best, fst currentVal + 50.0, smReason best)
                    _ -> Nothing

                aggList = M.toList aggregate1
                bestAggMove =
                  case aggList of
                    [] -> (-1, -1e9, "")
                    _  -> foldl (\(bestIdx, bestSc, bestReas) (idx, (score, reasons)) ->
                                   if score > bestSc
                                   then (idx, score, concatWithSemi reasons)
                                   else (bestIdx, bestSc, bestReas))
                                (-1, -1e9, "") aggList

                (selectedMove, selectedReason) =
                  case bestMctsMove of
                    Just (idx, score, reas) | score > snd3 bestAggMove -> (idx, reas)
                    _ -> (fst3 bestAggMove, trd3 bestAggMove)

            -- 8. Fallback: if no good move found, pick a reasonable move
            let sz = boardSize b
                aiColor = boardToMove b
                edgeDist idx =
                  let r = idx `div` sz; c = idx `mod` sz
                  in minimum [r, c, sz - 1 - r, sz - 1 - c]
                isCapturing idx =
                  any (\nb -> stoneAt b nb == Occupied (opp aiColor) &&
                              groupLiberties (groupInfo b nb) == 1) (neighbors b idx)
                legalNonEye idx =
                  stoneAt b idx == Empty &&
                  not (isOwnEye b idx aiColor) &&
                  isLegalMove b idx
                -- Prefer 3rd-line-or-deeper moves; allow edge only if capturing
                interiorMoves = [ i | i <- [0 .. sz*sz - 1], legalNonEye i, edgeDist i >= 2 ]
                capturingEdgeMoves = [ i | i <- [0 .. sz*sz - 1], legalNonEye i, edgeDist i < 2, isCapturing i ]
                anyLegalMoves = [ i | i <- [0 .. sz*sz - 1], legalNonEye i ]
                fallbackMoves =
                  if not (null interiorMoves) then interiorMoves
                  else if not (null capturingEdgeMoves) then capturingEdgeMoves
                  else anyLegalMoves
                (finalMove, finalReason) =
                  if selectedMove >= 0 && isLegalMove b selectedMove
                  then (selectedMove, selectedReason)
                  else case fallbackMoves of
                    (f:_) -> (f, "fallback random move")
                    []    -> (-1, "AI passes (no legal move found)")

            return AgentResult
              { arMove      = finalMove
              , arPass      = finalMove == -1
              , arResign    = False
              , arReason    = finalReason
              , arPhase     = phase
              , arTactical  = tacticalMoves
              , arStrategic = strategicMoves
              , arJoseki    = josekiMoves
              , arMcts      = mctsMoves
              , arRules     = ruleResults
              }

fst3 :: (a, b, c) -> a
fst3 (x, _, _) = x

snd3 :: (a, b, c) -> b
snd3 (_, y, _) = y

trd3 :: (a, b, c) -> c
trd3 (_, _, z) = z

concatWithSemi :: [String] -> String
concatWithSemi [] = ""
concatWithSemi [x] = x
concatWithSemi (x:xs) = x ++ "; " ++ concatWithSemi xs

isLegalMove :: Board -> Int -> Bool
isLegalMove b idx =
  case tryPlay b idx of
    Just _  -> True
    Nothing -> False
