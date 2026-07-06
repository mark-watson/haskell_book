{-# LANGUAGE BangPatterns #-}
-- | TacticalEngine — handles local combat: atari, ladders, captures, saves.
-- Produces scored candidate moves for urgent tactical situations.
module Tactical
  ( ScoredMove (..)
  , generateTacticalMoves
  , evaluateTacticalMove
  ) where

import           Board
import           Data.List   (nub)
import qualified Data.IntSet as IS

-- | A scored candidate move.
data ScoredMove = ScoredMove
  { smIndex  :: !Int
  , smScore  :: !Double
  , smReason :: !String
  } deriving (Show, Eq)

-- | Find all groups of the given color that are in atari (1 liberty).
findAtariGroups :: Board -> Color -> [[Int]]
findAtariGroups b color =
  let sz = boardSize b
      n = sz * sz
      go idx visited acc
        | idx >= n = acc
        | stoneAt b idx == Occupied color && not (IS.member idx visited) =
            let info = groupInfo b idx
                stones = groupStones info
                visited' = foldr IS.insert visited stones
            in if groupLiberties info == 1
               then go (idx + 1) visited' (stones : acc)
               else go (idx + 1) visited' acc
        | otherwise = go (idx + 1) visited acc
  in go 0 IS.empty []

-- | Find the single liberty of an atari group.
findLiberty :: Board -> [Int] -> Int
findLiberty b stones =
  let search [] = -1
      search (s:ss) =
        case filter (\nb -> stoneAt b nb == Empty) (neighbors b s) of
          (lib:_) -> lib
          []      -> search ss
  in search stones

-- | Check if a group can be captured via ladder.
-- attackerColor is the color doing the capturing; the group is opp(attacker).
-- Returns true if the ladder works (group will be captured).
ladderWorks :: Board -> Int -> Color -> Int -> Bool
ladderWorks board groupSeed attackerColor maxDepth =
  go board groupSeed 0
  where
    defColor = opp attackerColor
    go !b !seed !depth
      | depth >= maxDepth = False
      | otherwise =
          let info = groupInfo b seed
              libs = groupLiberties info
          in case libs of
            0 -> True  -- captured
            _ | libs >= 3 -> False -- escaped
              | libs == 2 -> False -- escaped (can't ladder with 2 libs)
              | otherwise -> -- libs == 1: attacker extends the ladder by playing the liberty
                  let lib = findLiberty b (groupStones info)
                  in if lib < 0
                     then True
                     else
                       -- Attacker plays the liberty
                       case tryPlay (b { boardToMove = attackerColor }) lib of
                         Nothing -> False -- can't play, group escapes
                         Just b' ->
                           -- Defender tries to escape: play the new liberty of own group
                           let defInfo = groupInfo b' seed
                               defLibs = groupLiberties defInfo
                           in case defLibs of
                             0 -> True
                             _ | defLibs >= 2 -> False
                               | otherwise ->
                                   let defLib = findLiberty b' (groupStones defInfo)
                                   in if defLib < 0
                                      then True
                                      else
                                        case tryPlay (b' { boardToMove = defColor }) defLib of
                                          Nothing -> True
                                          Just b'' -> go b'' seed (depth + 2)

-- | Generate tactically urgent moves.
generateTacticalMoves :: Board -> Int -> [ScoredMove]
generateTacticalMoves b maxLadderDepth =
  let color = boardToMove b
      enemy = opp color
      sz = boardSize b
      n = sz * sz

      -- 1. Capture: enemy groups in atari — play their liberty to capture.
      enemyAtari = findAtariGroups b enemy
      captures =
        [ ScoredMove lib (100 + fromIntegral size * 30) ("capture " ++ show size ++ " stone(s) in atari")
        | group <- enemyAtari
        , let lib = findLiberty b group
        , lib >= 0
        , let size = length group
        ]

      -- 2. Save: own groups in atari — try to extend/add liberties.
      ownAtari = findAtariGroups b color
      saves =
        [ move
        | group <- ownAtari
        , let lib = findLiberty b group
        , lib >= 0
        , let size = length group
        , move <-
            case tryPlay (b { boardToMove = color }) lib of
              Nothing -> []
              Just trial ->
                let newInfo = groupInfo trial lib
                in if groupLiberties newInfo >= 2
                   then [ScoredMove lib (90 + fromIntegral size * 25) ("save " ++ show size ++ " stone(s) from atari")]
                   else
                     if not (ladderWorks trial lib enemy maxLadderDepth)
                     then [ScoredMove lib (40 + fromIntegral size * 10) ("extend " ++ show size ++ " stone(s) (ladder escapes)")]
                     else []
        ]

      -- Counter-atari moves to save ourselves.
      counterSaves =
        [ ScoredMove enemyLib (85 + fromIntegral enemySize * 20) "counter-atari: capture to save group"
        | group <- ownAtari
        , s <- group
        , nb <- neighbors b s
        , stoneAt b nb == Occupied enemy
        , let enemyInfo = groupInfo b nb
        , groupLiberties enemyInfo == 1
        , let enemyLib = findLiberty b (groupStones enemyInfo)
        , enemyLib >= 0
        , let enemySize = length (groupStones enemyInfo)
        ]

      -- 3. Atari: put enemy groups with 2 liberties into atari.
      ataris =
        let goAtari idx visited acc
              | idx >= n = acc
              | stoneAt b idx == Occupied enemy && not (IS.member idx visited) =
                  let info = groupInfo b idx
                      stones = groupStones info
                      visited' = foldr IS.insert visited stones
                  in if groupLiberties info == 2
                     then
                       let libs = nub [ nb | s <- stones, nb <- neighbors b s, stoneAt b nb == Empty ]
                           mvs = [ ScoredMove lib score (if ladder then "atari + ladder on " ++ show size ++ " stones" else "atari on " ++ show size ++ " stones")
                                 | lib <- libs
                                 , let trial = b { boardToMove = color }
                                 , Just trial' <- [tryPlay trial lib]
                                 , let enemyInfo2 = groupInfo trial' (head stones)
                                 , groupLiberties enemyInfo2 == 1
                                 , let ownInfo = groupInfo trial' lib
                                 , groupLiberties ownInfo >= 2
                                 , let ladder = ladderWorks trial' (head stones) color maxLadderDepth
                                 , let size = length stones
                                 , let score = if ladder then 60 + fromIntegral size * 15 else 30 + fromIntegral size * 5
                                 ]
                       in goAtari (idx + 1) visited' (mvs ++ acc)
                     else goAtari (idx + 1) visited' acc
              | otherwise = goAtari (idx + 1) visited acc
        in goAtari 0 IS.empty []

      -- 4. Prevent atari: if own group has 2 liberties and enemy could atari, play a liberty to gain liberties.
      prevAtaris =
        let goPrev idx visited acc
              | idx >= n = acc
              | stoneAt b idx == Occupied color && not (IS.member idx visited) =
                  let info = groupInfo b idx
                      stones = groupStones info
                      visited' = foldr IS.insert visited stones
                  in if groupLiberties info == 2 && length stones >= 2
                     then
                       let libs = nub [ nb | s <- stones, nb <- neighbors b s, stoneAt b nb == Empty ]
                           mvs = [ ScoredMove lib (25 + fromIntegral (length stones) * 5) ("reinforce " ++ show (length stones) ++ "-stone group")
                                 | lib <- libs
                                 , let trial = b { boardToMove = color }
                                 , Just trial' <- [tryPlay trial lib]
                                 , let newInfo = groupInfo trial' lib
                                 , groupLiberties newInfo >= 3
                                 ]
                       in goPrev (idx + 1) visited' (mvs ++ acc)
                     else goPrev (idx + 1) visited' acc
              | otherwise = goPrev (idx + 1) visited acc
        in goPrev 0 IS.empty []

  in captures ++ saves ++ counterSaves ++ ataris ++ prevAtaris

-- | Evaluate a candidate move tactically — returns a bonus score.
evaluateTacticalMove :: Board -> Int -> Double
evaluateTacticalMove b i =
  let color = boardToMove b
      enemy = opp color
      nbs = neighbors b i

      -- Bonus for capturing.
      captureBonus = sum
        [ 50 + fromIntegral (length (groupStones info)) * 20
        | nb <- nbs
        , stoneAt b nb == Occupied enemy
        , let info = groupInfo b nb
        , groupLiberties info == 1
        ]

      -- Bonus for atari.
      atariBonus = sum
        [ 15 + fromIntegral (length (groupStones info)) * 5
        | nb <- nbs
        , stoneAt b nb == Occupied enemy
        , let info = groupInfo b nb
        , groupLiberties info == 2
        ]

      -- Bonus for saving own group from atari.
      saveBonus = sum
        [ 40 + fromIntegral (length (groupStones info)) * 15
        | nb <- nbs
        , stoneAt b nb == Occupied color
        , let info = groupInfo b nb
        , groupLiberties info == 1
        , let trial = b { boardToMove = color }
        , Just trial' <- [tryPlay trial i]
        , groupLiberties (groupInfo trial' i) >= 2
        ]

  in captureBonus + atariBonus + saveBonus
