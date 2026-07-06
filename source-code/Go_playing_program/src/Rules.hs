{-# LANGUAGE BangPatterns #-}
-- | Rules — Special situation rule evaluation framework.
module Rules
  ( Rule (..)
  , RuleEngine (..)
  , newRuleEngine
  , evaluateMove
  , evaluateCandidates
  ) where

import           Board
import           Data.List   (nub, foldl')
import qualified Data.IntSet as IS
import qualified Data.Vector.Unboxed as V

-- | A heuristic rule. Returns a score delta.
data Rule = Rule
  { ruleName     :: !String
  , ruleWeight   :: !Double
  , ruleEvaluate :: !(Board -> Int -> Int -> Color -> Double)
  }

newtype RuleEngine = RuleEngine { reRules :: [Rule] }

newRuleEngine :: RuleEngine
newRuleEngine = RuleEngine buildStandardRules

evaluateMove :: RuleEngine -> Board -> Int -> Int -> Double
evaluateMove eng b i moveCount =
  let aiColor = boardToMove b
  in foldl' (\acc rule -> acc + ruleEvaluate rule b i moveCount aiColor * ruleWeight rule) 0.0 (reRules eng)

evaluateCandidates :: RuleEngine -> Board -> [Int] -> Int -> [(Int, Double, String)]
evaluateCandidates eng b candidates moveCount =
  [ (i, score, "rule-heuristics")
  | i <- candidates
  , let score = evaluateMove eng b i moveCount
  , abs score > 0.01
  ]

-- ─── Rule 1: Four-point response early in the game ─────────────────────────
-- Normalized corner matching for joseki continuation.
fourPointResponseRule :: Rule
fourPointResponseRule = Rule "4-point-response" 1.2 eval
  where
    eval b i moveCount _aiColor =
      let sz = boardSize b
      in if fromIntegral moveCount > fromIntegral sz * fromIntegral sz * (0.2 :: Double)
         then 0.0
         else
           let cornerOffsets =
                 if sz >= 13 then [(3, 3), (3, sz - 4), (sz - 4, 3), (sz - 4, sz - 4)]
                 else if sz == 9 then [(2, 2), (2, 6), (6, 2), (6, 6)]
                 else []
               canonPoint = if sz >= 13 then 3 else 2
               r = i `div` sz
               c = i `mod` sz

               checkCorner (cr, cc) =
                 let cornerIdx = cr * sz + cc
                     cornerColor = stoneAt b cornerIdx
                 in case cornerColor of
                   Empty -> 0.0
                   Occupied _ ->
                     let rowSign = if cr <= sz `div` 2 then 1 else -1
                         colSign = if cc <= sz `div` 2 then 1 else -1
                         toCanon pr pc = ( canonPoint + (pr - cr) * rowSign
                                         , canonPoint + (pc - cc) * colSign )
                         (canonMR, canonMC) = toCanon r c

                         -- Walk outward from the corner stone to find nearby stones
                         regionMax = 6
                         candidates =
                           [ (idx, dist)
                           | dr <- [-regionMax .. regionMax]
                           , dc <- [-regionMax .. regionMax]
                           , let nr = cr + dr
                           , let nc = cc + dc
                           , nr >= 0, nr < sz, nc >= 0, nc < sz
                           , let idx = nr * sz + nc
                           , idx /= cornerIdx
                           , stoneAt b idx /= Empty
                           , let dist = abs dr + abs dc
                           ]
                         sortedCands = map fst $ sortByDist candidates
                         moveSeq = toCanon cr cc : map (\idx -> toCanon (idx `div` sz) (idx `mod` sz)) (take 6 sortedCands)

                         -- Simple check if matches embedded SGF joseki:
                         -- (B[dd] -> W[cd]; B[ed]; W[ec]; B[fc]) etc.
                         -- Canonical coordinates: dd=(3,3), cd=(2,3) or (3,2), ed=(4,3) or (3,4)
                         -- Let's just check if (canonMR, canonMC) is a valid joseki continuation.
                         -- If corner is occupied, and we approach, we want to play the response.
                         -- Let's map coordinates: (3,3) hoshi. Approaches are (2,3), (3,2), (2,4), (4,2).
                         -- Responses are (3,4), (4,3), (2,2), etc.
                         isJosekiContinuation =
                            case moveSeq of
                             [(3,3)] -> (canonMR, canonMC) `elem` [(2,3), (3,2), (2,4), (4,2), (2,2)]
                             [(3,3), (2,3)] -> (canonMR, canonMC) `elem` [(3,4), (2,2), (2,4)]
                             [(3,3), (3,2)] -> (canonMR, canonMC) `elem` [(4,3), (2,2), (4,2)]
                             [(3,3), (2,2)] -> (canonMR, canonMC) `elem` [(3,2), (2,3)]
                             _ -> False
                     in if isJosekiContinuation then 0.8 else 0.0

           in foldl' (\acc co -> acc + checkCorner co) 0.0 cornerOffsets

    sortByDist :: [(Int, Int)] -> [(Int, Int)]
    sortByDist [] = []
    sortByDist (x:xs) = sortByDist [y | y <- xs, snd y < snd x] ++ [x] ++ sortByDist [y | y <- xs, snd y >= snd x]

-- ─── Rule 2: Avoid dense placement of own stones ───────────────────────────
avoidDensePlacementRule :: Rule
avoidDensePlacementRule = Rule "avoid-dense-placement" 1.0 eval
  where
    eval b i moveCount aiColor =
      let sz = boardSize b
          r0 = i `div` sz
          c0 = i `mod` sz
          radius = 3

          countStones !fCount !eCount !adjF !adjFDanger dr dc
            | dr > radius = (fCount, eCount, adjF, adjFDanger)
            | dc > radius = countStones fCount eCount adjF adjFDanger (dr + 1) (-radius)
            | dr == 0 && dc == 0 = countStones fCount eCount adjF adjFDanger dr (dc + 1)
            | otherwise =
                let nr = r0 + dr
                    nc = c0 + dc
                in if nr >= 0 && nr < sz && nc >= 0 && nc < sz
                   then
                     let idx = nr * sz + nc
                         dist = fromIntegral (abs dr + abs dc) :: Float
                      in case stoneAt b idx of
                        Occupied col | col == aiColor ->
                          let adjF' = if dist == 1 then adjF + 1 else adjF
                              adjFDanger' = if dist == 1 && libertyCount b idx <= 2 then True else adjFDanger
                          in countStones (fCount + 1.0 / dist) eCount adjF' adjFDanger' dr (dc + 1)
                                     | otherwise ->
                          countStones fCount (eCount + 1.0 / dist) adjF adjFDanger dr (dc + 1)
                        Empty -> countStones fCount eCount adjF adjFDanger dr (dc + 1)
                   else countStones fCount eCount adjF adjFDanger dr (dc + 1)

          (friendlyCount, enemyCount, adjacentFriendly, adjacentFriendlyInDanger) =
            countStones 0.0 0.0 (0 :: Int) False (-radius) (-radius)

      in if friendlyCount < 1.0
         then 0.0
         else
           let noEnemy = enemyCount < 0.3
               total = sz * sz
               phaseFactor = if moveCount > round (fromIntegral total * 0.3 :: Double) then 1.5 else 1.0 :: Double

               penalty0 =
                 if adjacentFriendly >= 1 && not adjacentFriendlyInDanger && noEnemy
                 then 18 + (if adjacentFriendly >= 2 then 10 else 0) + (if adjacentFriendly >= 3 then 8 else 0)
                 else 0 :: Int

               penalty1 =
                 if friendlyCount >= 4.0 then 15
                 else if friendlyCount >= 3.0 then 10
                 else if friendlyCount >= 2.0 then 6
                 else 0 :: Int

               penalty2 =
                 if adjacentFriendly >= 3 then 8
                 else if adjacentFriendly >= 2 && enemyCount < 0.5 then 5
                 else 0 :: Int

               pSum = penalty0 + penalty1 + penalty2
               pSum' = if noEnemy && pSum > 0 then fromIntegral pSum * 1.6 else fromIntegral pSum :: Double
               finalPenalty = round (pSum' * phaseFactor) :: Int
           in -fromIntegral finalPenalty

-- ─── Rule 3: Avoid the edge of the board unless capturing ──────────────────
avoidEdgeUnlessCaptureRule :: Rule
avoidEdgeUnlessCaptureRule = Rule "avoid-edge-unless-capture" 3.0 eval
  where
    eval b i _moveCount aiColor =
      let sz = boardSize b
          r = i `div` sz
          c = i `mod` sz
          edgeDist = minimum [r, c, sz - 1 - r, sz - 1 - c]
      in if edgeDist >= 2
         then 0.0
         else
           let enemy = opp aiColor
               nbs = neighbors b i
               capturesSomething = any (\nb -> stoneAt b nb == Occupied enemy && libertyCount b nb <= 1) nbs
               savesSomething = any (\nb -> stoneAt b nb == Occupied aiColor && libertyCount b nb <= 1 &&
                                            case tryPlay (b { boardToMove = aiColor }) i of
                                              Just trial -> libertyCount trial i >= 2
                                              Nothing -> False) nbs
           in if capturesSomething || savesSomething
              then 0.0
              else
                let penalty = if edgeDist == 0 then -30.0 else -10.0
                    noStones = all (\nb -> stoneAt b nb == Empty) (neighborsRange b i 4)
                    penalty' = if noStones then penalty - 8.0 else penalty
                in penalty'

    neighborsRange b i radius =
      let sz = boardSize b
          r0 = i `div` sz
          c0 = i `mod` sz
      in [ nr * sz + nc
         | dr <- [-radius .. radius]
         , dc <- [-radius .. radius]
         , dr /= 0 || dc /= 0
         , let nr = r0 + dr
         , let nc = c0 + dc
         , nr >= 0, nr < sz, nc >= 0, nc < sz
         ]

-- ─── Rule 3b: Prefer third/fourth line in the opening ───────────────────────
openingLinePreferenceRule :: Rule
openingLinePreferenceRule = Rule "opening-line-preference" 1.0 eval
  where
    eval b i moveCount _aiColor =
      let sz = boardSize b
          r = i `div` sz
          c = i `mod` sz
          edgeDist = minimum [r, c, sz - 1 - r, sz - 1 - c]
      in if moveCount >= 20 || edgeDist == 2 || edgeDist == 3 || edgeDist < 2
         then 0.0
         else -fromIntegral ((edgeDist - 3) * 5)

-- ─── Rule 4: Ladder avoidance and breaking ─────────────────────────────────
ladderAvoidanceRule :: Rule
ladderAvoidanceRule = Rule "ladder-avoidance" 1.0 eval
  where
    eval b i _moveCount aiColor =
      let enemy = opp aiColor
          sz = boardSize b
          n = sz * sz

          -- 1. Avoid moving own group into a working ladder
          trialPenalty =
            case tryPlay (b { boardToMove = aiColor }) i of
              Nothing -> 0.0
              Just trial ->
                let info = groupInfo trial i
                in if groupLiberties info == 2 && ladderWorks trial i enemy (60 :: Int)
                   then -12.0
                   else 0.0

          -- 2 & 3. Detect existing danger and escape/break
          dangerPoints =
            let go idx visited acc
                  | idx >= n = acc
                  | stoneAt b idx == Occupied aiColor && not (IS.member idx visited) =
                      let info = groupInfo b idx
                          stones = groupStones info
                          visited' = foldr IS.insert visited stones
                          libs = groupLiberties info
                       in if (libs == 1 || libs == 2) && ladderWorks b idx enemy (60 :: Int)
                         then
                           let scoreChange =
                                 if libs == 2
                                 -- Early escape
                                 then case tryPlay (b { boardToMove = aiColor }) i of
                                   Nothing -> 0.0
                                   Just escapeTrial ->
                                     let escInfo = groupInfo escapeTrial idx
                                     in if groupLiberties escInfo >= 3 then 6.0
                                         else if groupLiberties escInfo >= 2 && not (ladderWorks escapeTrial idx enemy (60 :: Int)) then 4.0
                                        else 0.0
                                 -- Late break
                                 else
                                   let forcedLib = findForcedLiberty b stones
                                   in if i == forcedLib then 0.0
                                      else
                                        let bPath = simulateLadderPath b idx enemy (60 :: Int)
                                        in if IS.member i bPath then 6.0
                                           else case tryPlay (b { boardToMove = aiColor }) i of
                                             Nothing -> 0.0
                                             Just breakTrial ->
                                               let breakInfo = groupInfo breakTrial idx
                                                in if groupLiberties breakInfo >= 2 && not (ladderWorks breakTrial idx enemy (60 :: Int))
                                                  then 6.0
                                                  else 0.0
                           in go (idx + 1) visited' (scoreChange + acc)
                         else go (idx + 1) visited' acc
                  | otherwise = go (idx + 1) visited acc
            in go 0 IS.empty 0.0

      in trialPenalty + dangerPoints

    findForcedLiberty b stones =
      let search [] = -1
          search (s:ss) =
            case filter (\nb -> stoneAt b nb == Empty) (neighbors b s) of
              (lib:_) -> lib
              []      -> search ss
      in search stones

    simulateLadderPath b groupSeed attackerColor maxDepth =
      let defColor = opp attackerColor
          sz = boardSize b
          go !trial !seed !depth !pts
            | depth >= maxDepth = pts
            | otherwise =
                let info = groupInfo trial seed
                    libs = groupLiberties info
                in case libs of
                  0 -> pts
                  _ | libs >= 3 -> pts
                    | libs == 1 ->
                        let lib = findForcedLiberty trial (groupStones info)
                        in if lib < 0 then pts
                           else case tryPlay (trial { boardToMove = defColor }) lib of
                             Nothing -> pts
                             Just trial' ->
                               let info' = groupInfo trial' seed
                               in if groupLiberties info' == 0 || groupLiberties info' >= 3
                                  then IS.insert lib pts
                                  else goAttacker trial' seed (depth + 1) (IS.insert lib pts)
                    | otherwise -> goAttacker trial seed depth pts

          goAttacker !trial !seed !depth !pts =
            let info = groupInfo trial seed
                libs = groupLiberties info
            in case libs of
              0 -> pts
              _ | libs >= 3 -> pts
                | libs == 1 ->
                    let lib = findForcedLiberty trial (groupStones info)
                    in if lib < 0 then pts
                       else case tryPlay (trial { boardToMove = attackerColor }) lib of
                         Nothing -> pts
                         Just _trial' -> IS.insert lib pts
                | otherwise -> -- 2 libs: pick one towards nearest edge
                    let searchLibs = nub [ nb | s <- groupStones info, nb <- neighbors trial s, stoneAt trial nb == Empty ]
                        edgeDist p = let r = p `div` sz; c = p `mod` sz in minimum [r, c, sz - 1 - r, sz - 1 - c]
                        bestLib = case searchLibs of
                          [] -> -1
                          _  -> snd $ minimum [ (edgeDist p, p) | p <- searchLibs ]
                    in if bestLib < 0 then pts
                       else case tryPlay (trial { boardToMove = attackerColor }) bestLib of
                         Nothing -> pts
                         Just trial' -> go trial' seed (depth + 1) (IS.insert bestLib pts)

      in go b groupSeed 0 IS.empty

    ladderWorks b groupSeed attackerColor maxDepth =
      let defColor = opp attackerColor
          go !trial !seed !depth
            | depth >= maxDepth = False
            | otherwise =
                let info = groupInfo trial seed
                    libs = groupLiberties info
                in case libs of
                  0 -> True
                  _ | libs >= 3 -> False
                    | libs == 1 ->
                        let lib = findForcedLiberty trial (groupStones info)
                        in if lib < 0 then True
                           else case tryPlay (trial { boardToMove = defColor }) lib of
                             Nothing -> True
                             Just trial' ->
                               let info' = groupInfo trial' seed
                               in if groupLiberties info' == 0 then True
                                  else if groupLiberties info' >= 3 then False
                                  else goAttacker trial' seed (depth + 1)
                    | otherwise -> goAttacker trial seed depth

          goAttacker !trial !seed !depth =
            let info = groupInfo trial seed
                libs = groupLiberties info
            in case libs of
              0 -> True
              _ | libs >= 3 -> False
                | libs == 1 ->
                    let lib = findForcedLiberty trial (groupStones info)
                    in if lib < 0 then True
                       else case tryPlay (trial { boardToMove = attackerColor }) lib of
                         Nothing -> False
                         Just trial' -> groupLiberties (groupInfo trial' seed) == 0 || go trial' seed (depth + 1)
                | otherwise -> -- 2 libs: try both
                    let searchLibs = nub [ nb | s <- groupStones info, nb <- neighbors trial s, stoneAt trial nb == Empty ]
                        tryAtari lib =
                          case tryPlay (trial { boardToMove = attackerColor }) lib of
                            Nothing -> False
                            Just trial' ->
                              groupLiberties (groupInfo trial' seed) < 3 && go trial' seed (depth + 1)
                    in any tryAtari searchLibs
      in go b groupSeed 0

-- ─── Rule 5: Avoid self-atari unless capturing ──────────────────────────────
avoidSelfAtariRule :: Rule
avoidSelfAtariRule = Rule "avoid-self-atari" 3.0 eval
  where
    eval b i _moveCount aiColor =
      let enemy = opp aiColor
      in case tryPlay (b { boardToMove = aiColor }) i of
        Nothing -> 0.0
        Just trial ->
          let info = groupInfo trial i
          in if groupLiberties info >= 2
             then 0.0
             else
               let beforeEnemy = length [ () | idx <- [0 .. boardSize b * boardSize b - 1], stoneAt b idx == Occupied enemy ]
                   afterEnemy  = length [ () | idx <- [0 .. boardSize b * boardSize b - 1], stoneAt trial idx == Occupied enemy ]
               in if afterEnemy < beforeEnemy
                  then 0.0 -- captured
                  else
                    let grpSize = length (groupStones info)
                    in -fromIntegral (30 + grpSize * 20)

-- ─── Rule 6: Local 7×7 context ───────────────────────────────────────────────
local7x7ContextRule :: Rule
local7x7ContextRule = Rule "local-7x7-context" 1.0 eval
  where
    eval b i _moveCount aiColor =
      let probe = if boardToMove b /= aiColor
                  then b { boardToMove = aiColor }
                  else b
          sz = boardSize probe
          r0 = i `div` sz
          c0 = i `mod` sz
          enemy = opp aiColor

          countStones dr dc !comp !player
            | dr > 3 = (comp, player)
            | dc > 3 = countStones (dr + 1) (-3) comp player
            | dr == 0 && dc == 0 = countStones dr (dc + 1) comp player
            | otherwise =
                let nr = r0 + dr
                    nc = c0 + dc
                in if nr >= 0 && nr < sz && nc >= 0 && nc < sz
                   then
                     let idx = nr * sz + nc
                     in case stoneAt probe idx of
                       Occupied col | col == aiColor -> countStones dr (dc + 1) (comp + 1) player
                                    | col == enemy   -> countStones dr (dc + 1) comp (player + 1)
                       _ -> countStones dr (dc + 1) comp player
                   else countStones dr (dc + 1) comp player

          (computerCount, playerCount) = countStones (-3) (-3) (0 :: Int) (0 :: Int)
      in if playerCount == 0
         then -40.0
         else
           let surplus = computerCount - playerCount
           in if surplus >= 3
              then -fromIntegral (surplus - 2) * 5.0
              else 0.0

-- ─── Rule 7: Double atari ───────────────────────────────────────────────────
doubleAtariRule :: Rule
doubleAtariRule = Rule "double-atari" 1.0 eval
  where
    eval b i _moveCount aiColor =
      let enemy = opp aiColor
      in case tryPlay (b { boardToMove = aiColor }) i of
        Nothing -> 0.0
        Just trial ->
          let nbs = neighbors trial i
              findAtaris [] _ !count = count
              findAtaris (nb:ns) visited !count
                | stoneAt trial nb == Occupied enemy && not (IS.member nb visited) =
                    let info = groupInfo trial nb
                        visited' = foldr IS.insert visited (groupStones info)
                        count' = if groupLiberties info == 1 then count + 1 else count
                    in findAtaris ns visited' count'
                | otherwise = findAtaris ns visited count
              atariGroups = findAtaris nbs IS.empty (0 :: Int)
          in if atariGroups >= 2
             then 50.0 + fromIntegral (atariGroups - 2) * 15.0
             else 0.0

-- ─── Rule 8: Avoid connecting to isolated own stone in the opening ──────────
avoidConnectingIsolatedStoneRule :: Rule
avoidConnectingIsolatedStoneRule = Rule "avoid-connect-isolated" 1.0 eval
  where
    eval b i moveCount aiColor =
      if moveCount >= 30
      then 0.0
      else
        let nbs = neighbors b i
            checkIsolated nb =
              stoneAt b nb == Occupied aiColor &&
              all (\nnb -> nnb == i || stoneAt b nnb == Empty) (neighbors b nb)
            isolatedTouches = length (filter checkIsolated nbs)
        in if isolatedTouches == 0
           then 0.0
           else -fromIntegral (10 + isolatedTouches * 5)

-- ─── Rule 9: Respond to contact on a weak computer stone ───────────────────
respondToContactOnWeakStoneRule :: Rule
respondToContactOnWeakStoneRule = Rule "respond-contact-weak-stone" 1.0 eval
  where
    eval b i _moveCount aiColor =
      case boardLastMove b of
        Nothing -> 0.0
        Just lastMove ->
          let enemy = opp aiColor
          in if stoneAt b lastMove /= Occupied enemy
             then 0.0
             else
               let sz = boardSize b
                   weakStones =
                     [ nb
                     | nb <- neighbors b lastMove
                     , stoneAt b nb == Occupied aiColor
                     , let info = groupInfo b nb
                     , length (groupStones info) <= 2 || groupLiberties info <= 3
                     ]
               in if null weakStones
                  then 0.0
                  else
                    let iR = i `div` sz
                        iC = i `mod` sz
                        evalWs ws =
                          let wsR = ws `div` sz
                              wsC = ws `mod` sz
                              dr = iR - wsR
                              dc = iC - wsC
                              manhattan = abs dr + abs dc
                              chebyshev = max (abs dr) (abs dc)
                              isDirect = manhattan == 1
                              isJump = manhattan == 2 && chebyshev == 2 && (dr == 0 || dc == 0) &&
                                       let midR = wsR + signum dr
                                           midC = wsC + signum dc
                                       in stoneAt b (midR * sz + midC) == Empty
                              isDiag = manhattan == 2 && chebyshev == 1
                              weight = if isDirect then 0.5 else if isJump then 1.5 else if isDiag then 1.2 else 0.0
                          in if weight > 0
                             then
                               let openness = length (filter (\nb -> stoneAt b nb == Empty) (neighbors b i))
                                   baseBonus = (if openness >= 5 then 18 else if openness >= 3 then 12 else 6) :: Int
                                in fromIntegral (round ((fromIntegral baseBonus :: Double) * weight) :: Int)
                             else 0.0
                    in sum (map evalWs weakStones)

-- ─── Rule 10: Tactical survival fighting ────────────────────────────────────
tacticalSurvivalRule :: Rule
tacticalSurvivalRule = Rule "tactical-survival" 1.0 eval
  where
    eval b i _moveCount aiColor =
      let enemy = opp aiColor
          sz = boardSize b
          n = sz * sz

          -- Find weak groups helper
          findWeakGroups col maxLibs =
            let go idx visited acc
                  | idx >= n = acc
                  | stoneAt b idx == Occupied col && not (IS.member idx visited) =
                      let info = groupInfo b idx
                          visited' = foldr IS.insert visited (groupStones info)
                      in if groupLiberties info <= maxLibs
                         then go (idx + 1) visited' (info : acc)
                         else go (idx + 1) visited' acc
                  | otherwise = go (idx + 1) visited acc
            in go 0 IS.empty []

          weakOwn = findWeakGroups aiColor 3
          isAdj gs = any (\s -> s `elem` neighbors b i) gs
          connectsToOther gs =
            any (\nb -> stoneAt b nb == Occupied aiColor && nb `notElem` gs) (neighbors b i)

          isOpenDirection =
            let r = i `div` sz
                c = i `mod` sz
                pts = [ (nr * sz + nc, stoneAt b (nr * sz + nc) == Empty)
                      | dr <- [-2 .. 2]
                      , dc <- [-2 .. 2]
                      , dr /= 0 || dc /= 0
                      , let nr = r + dr
                      , let nc = c + dc
                      , nr >= 0, nr < sz, nc >= 0, nc < sz
                      ]
                total = length pts
                empty = length (filter snd pts)
            in total > 0 && fromIntegral empty / fromIntegral total >= (0.6 :: Double)

          defScore = sum
            [ fromIntegral (bonus * urgency)
            | info <- weakOwn
            , isAdj (groupStones info)
            , let urgency = if groupLiberties info <= 1 then 3 else if groupLiberties info == 2 then 2 else 1 :: Int
            , let bonus = if connectsToOther (groupStones info) then 15 else if isOpenDirection then 12 else 4 :: Int
            ]

          -- Offence check
          weakEnemy = findWeakGroups enemy 3
          candidateSafe =
            case tryPlay (b { boardToMove = aiColor }) i of
              Nothing -> False
              Just trial ->
                let info = groupInfo trial i
                in not (length (groupStones info) == 1 && groupLiberties info <= 3)

          offScore =
            if not candidateSafe || null weakEnemy
            then 0.0
            else sum
              [ fromIntegral (8 * urgency)
              | info <- weakEnemy
              , let enemyStones = groupStones info
              , let libs = nub [ nb | s <- enemyStones, nb <- neighbors b s, stoneAt b nb == Empty ]
              , i `elem` libs
              , case tryPlay (b { boardToMove = aiColor }) i of
                  Nothing -> False
                  Just trial ->
                    let newInfo = groupInfo trial (head enemyStones)
                    in groupLiberties newInfo < groupLiberties info
              , let urgency = if groupLiberties info <= 1 then 3 else if groupLiberties info == 2 then 2 else 1 :: Int
              ]

      in defScore + offScore

-- ─── Rule 11: Corner strategy ───────────────────────────────────────────────
cornerStrategyRule :: Rule
cornerStrategyRule = Rule "corner-strategy" 1.5 eval
  where
    eval b i moveCount aiColor =
      let sz = boardSize b
          n = sz * sz
          enemy = opp aiColor
          r = i `div` sz
          c = i `mod` sz
          extent = if sz >= 17 then 7 else if sz >= 11 then 5 else 4
          star = if sz >= 17 then 3 else if sz >= 11 then 3 else 2

          corners =
            [ (star, star, 0, 0, 1, 1)
            , (star, sz - 1 - star, 0, sz - 1, 1, -1)
            , (sz - 1 - star, star, sz - 1, 0, -1, 1)
            , (sz - 1 - star, sz - 1 - star, sz - 1, sz - 1, -1, -1)
            ]

          inCorner (_, _, orR, orC, _dr, _dc) =
            abs (r - orR) < extent && abs (c - orC) < extent

          stonesInCorner (_, _, orR, orC, dr, dc) col =
            [ pr * sz + pc
            | ddr <- [0 .. extent - 1]
            , ddc <- [0 .. extent - 1]
            , let pr = orR + ddr * dr
            , let pc = orC + ddc * dc
            , pr >= 0, pr < sz, pc >= 0, pc < sz
            , stoneAt b (pr * sz + pc) == Occupied col
            ]

          -- 1. Claim empty corners
          claimScore =
            case filter inCorner corners of
              (corner@(starR, starC, orR, orC, _dr, _dc) : _) ->
                if fromIntegral moveCount < fromIntegral n * (0.3 :: Double) && null (stonesInCorner corner aiColor)
                then
                  let distToStar = abs (r - starR) + abs (c - starC)
                      starEmpty = stoneAt b (starR * sz + starC) == Empty
                      s0 = if distToStar == 0 then 45.0
                           else if distToStar <= 1 then 15.0 + (if starEmpty then -10.0 else 0)
                           else if distToStar <= 2 then 8.0 + (if starEmpty then -8.0 else 0)
                           else if distToStar <= 3 then 4.0
                           else 0.0
                      distFromOrigin = abs (r - orR) + abs (c - orC)
                      maxUsefulDist = extent - 1
                      s1 = if distFromOrigin > maxUsefulDist + 2
                           then -fromIntegral (distFromOrigin - maxUsefulDist - 2) * 6.0
                           else 0.0
                  in s0 + s1
                else 0.0
              [] -> 0.0

          -- 2. Side extension
          sideScore =
            if fromIntegral moveCount >= fromIntegral n * (0.4 :: Double) || any inCorner corners
            then 0.0
            else
              let checkExtend corner@(starR, starC, _orR, _orC, dr, dc) =
                    let own = stonesInCorner corner aiColor
                        enemyStones = stonesInCorner corner enemy
                    in if null own then 0.0
                       else
                         let checkHoriz =
                               if abs (r - starR) <= 1
                               then
                                 let along = (c - starC) * dc
                                 in if along >= 3 && along <= sz `div` 2
                                    then
                                      let blocked = any (\es -> let esR = es `div` sz; esC = es `mod` sz
                                                                in abs (esR - starR) <= 1 &&
                                                                   let eAlong = (esC - starC) * dc
                                                                   in eAlong > 0 && eAlong < along) enemyStones
                                      in if not blocked then 20.0 else 0.0
                                    else 0.0
                               else 0.0
                             checkVert =
                               if abs (c - starC) <= 1
                               then
                                 let along = (r - starR) * dr
                                 in if along >= 3 && along <= sz `div` 2
                                    then
                                      let blocked = any (\es -> let esR = es `div` sz; esC = es `mod` sz
                                                                in abs (esC - starC) <= 1 &&
                                                                   let eAlong = (esR - starR) * dr
                                                                   in eAlong > 0 && eAlong < along) enemyStones
                                      in if not blocked then 20.0 else 0.0
                                    else 0.0
                               else 0.0
                         in max checkHoriz checkVert
              in maximum (0.0 : map checkExtend corners)

          -- 3. Block approach
          blockScore =
            case boardLastMove b of
              Nothing -> 0.0
              Just lastMove ->
                if stoneAt b lastMove /= Occupied enemy
                then 0.0
                else
                  let lastR = lastMove `div` sz
                      lastC = lastMove `mod` sz
                      checkBlock corner@(starR, starC, orR, orC, _dr, _dc) =
                        let own = stonesInCorner corner aiColor
                        in if null own || not (abs (lastR - orR) < extent + 2 && abs (lastC - orC) < extent + 2) ||
                              not (inCorner corner) || stoneAt b (starR * sz + starC) == Occupied aiColor
                           then 0.0
                           else
                             let candDist = abs (r - starR) + abs (c - starC)
                                 approachDist = abs (lastR - starR) + abs (lastC - starC)
                             in if candDist < approachDist && candDist <= 4 then 28.0 else 0.0
                  in maximum (0.0 : map checkBlock corners)

          -- 4. Kill invasion
          killScore =
            case filter inCorner corners of
              (corner : _) ->
                let own = stonesInCorner corner aiColor
                    enemyStones = stonesInCorner corner enemy
                in if null own || null enemyStones || length own < length enemyStones
                   then 0.0
                   else
                     case tryPlay (b { boardToMove = aiColor }) i of
                       Nothing -> 0.0
                       Just safetyTrial ->
                         let candInfo = groupInfo safetyTrial i
                         in if length (groupStones candInfo) == 1 && groupLiberties candInfo <= 3
                            then 0.0
                            else
                              let goInvasions [] _ !sc = sc
                                  goInvasions (es:ess) visited !sc
                                    | IS.member es visited = goInvasions ess visited sc
                                    | otherwise =
                                        let info = groupInfo b es
                                            visited' = foldr IS.insert visited (groupStones info)
                                        in if groupLiberties info > 5
                                           then goInvasions ess visited' sc
                                           else
                                             let libs = nub [ nb | s <- groupStones info, nb <- neighbors b s, stoneAt b nb == Empty ]
                                             in if i `elem` libs
                                                then
                                                  case tryPlay (b { boardToMove = aiColor }) i of
                                                    Just trial ->
                                                      let newInfo = groupInfo trial es
                                                      in if groupLiberties newInfo < groupLiberties info
                                                         then
                                                            let urgency = if groupLiberties info <= 1 then 3 else if groupLiberties info == 2 then 2 else 1 :: Int
                                                           in goInvasions ess visited' (sc + fromIntegral (14 * urgency))
                                                         else goInvasions ess visited' sc
                                                else goInvasions ess visited' sc
                              in goInvasions enemyStones IS.empty 0.0
              [] -> 0.0

      in claimScore + sideScore + blockScore + killScore

-- ─── Rule 12: Play lightly when attached to ─────────────────────────────────
playLightlyWhenAttachedRule :: Rule
playLightlyWhenAttachedRule = Rule "play-lightly-when-attached" 1.0 eval
  where
    eval b i _moveCount aiColor =
      case boardLastMove b of
        Nothing -> 0.0
        Just lastMove ->
          let enemy = opp aiColor
          in if stoneAt b lastMove /= Occupied enemy
             then 0.0
             else
               let sz = boardSize b
                   attachedStones = [ nb | nb <- neighbors b lastMove, stoneAt b nb == Occupied aiColor ]
               in if null attachedStones
                  then 0.0
                  else
                    let attachedGroups =
                          let go [] _ acc = acc
                              go (s:ss) visited acc
                                | IS.member s visited = go ss visited acc
                                | otherwise =
                                    let info = groupInfo b s
                                        visited' = foldr IS.insert visited (groupStones info)
                                    in go ss visited' (info : acc)
                          in go attachedStones IS.empty []

                        candTouchesEnemy = any (\nb -> stoneAt b nb == Occupied enemy) (neighbors b i)
                        iR = i `div` sz
                        iC = i `mod` sz

                        evalGroup group =
                          let groupSet = IS.fromList (groupStones group)
                              isDirect = any (\nb -> IS.member nb groupSet) (neighbors b i)
                              isDiagonal = any (\s -> let sR = s `div` sz; sC = s `mod` sz
                                                      in abs (sR - iR) == 1 && abs (sC - iC) == 1) (groupStones group)
                              isBoth = isDirect && isDiagonal

                              jumpInfo =
                                let checkJump s =
                                      let sR = s `div` sz
                                          sC = s `mod` sz
                                      in if sR == iR && abs (sC - iC) == 2 && stoneAt b (sR * sz + (sC + iC) `div` 2) == Empty
                                         then Just (sR * sz + (sC + iC) `div` 2)
                                         else if sC == iC && abs (sR - iR) == 2 && stoneAt b ((sR + iR) `div` 2 * sz + sC) == Empty
                                         then Just ((sR + iR) `div` 2 * sz + sC)
                                         else Nothing
                                in case filter (not . null) (map (\s -> case checkJump s of Just j -> [j]; Nothing -> []) (groupStones group)) of
                                  (j:_) -> Just (head j)
                                  []    -> Nothing

                              penalty =
                                if isDirect && not (null jumpInfo) && (not isDiagonal || isBoth) && groupLiberties group > 1
                                then -14.0 + (if isBoth then -10.0 else 0.0)
                                else 0.0

                              jumpBonus =
                                case jumpInfo of
                                  Just midIdx ->
                                    if not candTouchesEnemy
                                    then case tryPlay (b { boardToMove = aiColor }) i of
                                      Nothing -> -4.0
                                      Just trial ->
                                        case tryPlay (trial { boardToMove = enemy }) midIdx of
                                          Nothing -> 16.0
                                          Just trial' -> if groupLiberties (groupInfo trial' midIdx) <= 2 then 16.0 else -4.0
                                    else 0.0
                                  Nothing -> 0.0

                              diagBonus =
                                if isDiagonal && not isDirect && not candTouchesEnemy
                                then 10.0
                                else 0.0
                          in penalty + jumpBonus + diagBonus
                    in sum (map evalGroup attachedGroups)

-- ─── Rule 13: Prefer sides/corners over center ──────────────────────────────
preferSidesOverCenterRule :: Rule
preferSidesOverCenterRule = Rule "prefer-sides-over-center" 1.0 eval
  where
    eval b i _moveCount aiColor =
      let sz = boardSize b
          total = sz * sz
          filled = length [ () | idx <- [0 .. total - 1], stoneAt b idx /= Empty ]
      in if filled > total `div` 2
         then 0.0
         else
           let r = i `div` sz
               c = i `mod` sz
               edgeDist = minimum [r, c, sz - 1 - r, sz - 1 - c]
               centralThreshold = if sz >= 17 then 5 else if sz >= 11 then 4 else 3
           in if edgeDist < centralThreshold
              then 0.0
              else
                let hasOpenCorner = unclaimedCorner b aiColor
                    hasOpenSide = openSideStretch b sz
                in if not hasOpenCorner && not hasOpenSide
                   then 0.0
                   else
                     let maxEdgeDist = (sz - 1) `div` 2
                         centrality = fromIntegral (edgeDist - centralThreshold + 1) / fromIntegral (max 1 (maxEdgeDist - centralThreshold + 1))
                         basePenalty = 10.0 + centrality * 15.0
                         penalty = if hasOpenCorner then basePenalty + 10.0 else basePenalty
                     in -penalty

    unclaimedCorner b aiColor =
      let sz = boardSize b
          extent = if sz >= 17 then 7 else if sz >= 11 then 5 else 4
          corners = [ (0, 0, 1, 1), (0, sz-1, 1, -1), (sz-1, 0, -1, 1), (sz-1, sz-1, -1, -1) ]
          check (orR, orC, dr, dc) =
            let pts = [ (orR + ddr * dr) * sz + (orC + ddc * dc)
                      | ddr <- [0 .. extent - 1]
                      , ddc <- [0 .. extent - 1]
                      ]
            in not (any (\p -> stoneAt b p == Occupied aiColor) pts)
      in any check corners

    openSideStretch b sz =
      let cornerExtent = if sz >= 17 then 7 else if sz >= 11 then 5 else 4
          checkStretch pts =
            let checkGap [] count = count >= 4
                checkGap (p:ps) count =
                  if stoneAt b p == Empty
                  then checkGap ps (count + 1)
                  else count >= 4 || checkGap ps 0
            in checkGap pts (0 :: Int)
          -- Check 3rd & 4th line
          lineNums = [2, 3]
          varyingCols line =
            [ [ line * sz + col | col <- [cornerExtent .. sz - 1 - cornerExtent] ]
            , [ (sz - 1 - line) * sz + col | col <- [cornerExtent .. sz - 1 - cornerExtent] ]
            ]
          varyingRows line =
            [ [ row * sz + line | row <- [cornerExtent .. sz - 1 - cornerExtent] ]
            , [ row * sz + (sz - 1 - line) | row <- [cornerExtent .. sz - 1 - cornerExtent] ]
            ]
          allStretches = concat [ varyingCols l ++ varyingRows l | l <- lineNums ]
      in any checkStretch allStretches

-- ─── Rule 14: Avoid empty triangles & prefer light shape ─────────────────────
emptyTriangleRule :: Rule
emptyTriangleRule = Rule "empty-triangle-light-shape" 1.0 eval
  where
    eval b i _moveCount aiColor =
      let enemy = opp aiColor
      in if hasTacticalJustification b i aiColor enemy
         then 0.0
         else
           let sz = boardSize b
               r = i `div` sz
               c = i `mod` sz
               colI = if aiColor == Black then 1 else 2

               -- 1. Empty triangle count
               topLefts = [ (r - 1, c - 1), (r - 1, c), (r, c - 1), (r, c) ]
               checkTriangle tr tc =
                 if tr >= 0 && tr + 1 < sz && tc >= 0 && tc + 1 < sz
                 then
                   let corners = [ tr * sz + tc, tr * sz + tc + 1, (tr + 1) * sz + tc, (tr + 1) * sz + tc + 1 ]
                       friendly = length [ () | ci <- corners, ci == i || boardGrid b V.! ci == colI ]
                       emptyCount = length [ () | ci <- corners, ci /= i && boardGrid b V.! ci == 0 ]
                       enemyCount = length [ () | ci <- corners, boardGrid b V.! ci /= 0 && boardGrid b V.! ci /= colI ]
                   in if friendly == 3 && emptyCount == 1 && enemyCount == 0 then 1 else 0
                 else 0
               emptyTriangles = sum (map (uncurry checkTriangle) topLefts) :: Int
               penalty0 = fromIntegral emptyTriangles * 35.0

               -- 2. Heavy-shape penalty
               nbs = neighbors b i
               adjFriendly = length (filter (\nb -> stoneAt b nb == Occupied aiColor) nbs)
               adjEnemy = length (filter (\nb -> stoneAt b nb == Occupied enemy) nbs)
               penalty1 = if adjFriendly >= 2 && adjEnemy == 0 then 15.0 else 0.0

               -- 3. Continuous-line penalty
               penalty2 = if adjEnemy == 0
                          then
                            let dirs = [(0, 1), (1, 0)]
                                countLine (dr, dc) =
                                  let walk steps sign =
                                        let nr = r + steps * dr * sign
                                            nc = c + steps * dc * sign
                                        in if nr >= 0 && nr < sz && nc >= 0 && nc < sz &&
                                              boardGrid b V.! (nr * sz + nc) == colI
                                            then 1 + walk (steps + 1) sign
                                            else (0 :: Int)
                                      lineLen = 1 + walk 1 1 + walk 1 (-1)
                                  in if lineLen >= 3 then 8.0 + fromIntegral (lineLen - 3) * 6.0 else 0.0
                            in maximum (0.0 : map countLine dirs)
                          else 0.0

           in -(penalty0 + penalty1 + penalty2)

    hasTacticalJustification b i aiColor enemy =
      let nbs = neighbors b i
      in any (\nb -> stoneAt b nb == Occupied enemy) nbs ||
         any (\nb -> stoneAt b nb == Occupied aiColor && libertyCount b nb <= 1) nbs ||
         case tryPlay (b { boardToMove = aiColor }) i of
           Nothing -> False
           Just trial ->
             let beforeEnemy = length [ () | idx <- [0 .. boardSize b * boardSize b - 1], stoneAt b idx == Occupied enemy ]
                 afterEnemy  = length [ () | idx <- [0 .. boardSize b * boardSize b - 1], stoneAt trial idx == Occupied enemy ]
             in afterEnemy < beforeEnemy

-- ─── Rule 15: Prefer light connections over direct contact ──────────────────
lightConnectionRule :: Rule
lightConnectionRule = Rule "light-connection" 1.0 eval
  where
    eval b i _moveCount aiColor =
      let enemy = opp aiColor
      in if hasTacticalJustification b i aiColor enemy
         then 0.0
         else
           let nbs = neighbors b i
               sz = boardSize b
               r = i `div` sz
               c = i `mod` sz

               -- Direct connection penalty
               evalDirect nb =
                 if stoneAt b nb == Occupied aiColor
                 then
                   let info = groupInfo b nb
                       touchesEnemy = any (\nnb -> stoneAt b nnb == Occupied enemy) (neighbors b nb)
                   in if groupLiberties info <= 2 || touchesEnemy
                      then 0.0
                      else -14.0 - (if groupLiberties info >= 5 then 6.0 else 0.0)
                 else 0.0
               directPenalty = sum (map evalDirect nbs)

               -- Light connection bonus
               lightBonus =
                 let go dr dc !bonus
                       | dr > 2 = bonus
                       | dc > 2 = go (dr + 1) (-2) bonus
                       | dr == 0 && dc == 0 = go dr (dc + 1) bonus
                       | otherwise =
                           let nr = r + dr
                               nc = c + dc
                           in if nr >= 0 && nr < sz && nc >= 0 && nc < sz
                              then
                                let idx = nr * sz + nc
                                in if stoneAt b idx == Occupied aiColor
                                   then
                                     let info = groupInfo b idx
                                         touchesEnemy = any (\nnb -> stoneAt b nnb == Occupied enemy) (neighbors b idx)
                                     in if groupLiberties info <= 2 || touchesEnemy
                                        then go dr (dc + 1) bonus
                                        else
                                          let manhattan = abs dr + abs dc
                                              chebyshev = max (abs dr) (abs dc)
                                              addVal = if manhattan == 2 && chebyshev == 2 && (dr == 0 || dc == 0) &&
                                                          stoneAt b ((r + signum dr) * sz + (c + signum dc)) == Empty
                                                       then 12.0
                                                       else if manhattan == 3 && chebyshev == 2 then 8.0
                                                       else if manhattan == 2 && chebyshev == 1 then 6.0
                                                       else 0.0
                                          in go dr (dc + 1) (bonus + addVal)
                                   else go dr (dc + 1) bonus
                              else go dr (dc + 1) bonus
                 in min 20.0 (go (-2) (-2) 0.0)

           in directPenalty + lightBonus

    hasTacticalJustification b i aiColor enemy =
      let nbs = neighbors b i
      in any (\nb -> stoneAt b nb == Occupied enemy) nbs ||
         any (\nb -> stoneAt b nb == Occupied aiColor && libertyCount b nb <= 1) nbs ||
         case tryPlay (b { boardToMove = aiColor }) i of
           Nothing -> False
           Just trial ->
             let beforeEnemy = length [ () | idx <- [0 .. boardSize b * boardSize b - 1], stoneAt b idx == Occupied enemy ]
                 afterEnemy  = length [ () | idx <- [0 .. boardSize b * boardSize b - 1], stoneAt trial idx == Occupied enemy ]
             in afterEnemy < beforeEnemy

-- ─── Rule 16: Avoid creating weak isolated stones ───────────────────────────
avoidWeakNewStoneRule :: Rule
avoidWeakNewStoneRule = Rule "avoid-weak-new-stone" 1.5 eval
  where
    eval b i _moveCount aiColor =
      let enemy = opp aiColor
      in case tryPlay (b { boardToMove = aiColor }) i of
        Nothing -> 0.0
        Just trial ->
          let info = groupInfo trial i
          in if length (groupStones info) > 1 || groupLiberties info > 3
             then 0.0
             else
               let adjEnemy = length (filter (\nb -> stoneAt b nb == Occupied enemy) (neighbors b i))
               in if adjEnemy < 2
                  then 0.0
                  else
                    let beforeEnemy = length [ () | idx <- [0 .. boardSize b * boardSize b - 1], stoneAt b idx == Occupied enemy ]
                        afterEnemy  = length [ () | idx <- [0 .. boardSize b * boardSize b - 1], stoneAt trial idx == Occupied enemy ]
                    in if afterEnemy < beforeEnemy
                       then 0.0
                       else
                         let libertyFactor = if groupLiberties info <= 2 then 10 else 6
                             penalty = libertyFactor * adjEnemy
                         in -fromIntegral penalty

-- ─── Rule 17: Hane / extend response to contact moves ───────────────────────
contactResponseRule :: Rule
contactResponseRule = Rule "contact-response" 2.0 eval
  where
    eval b i _moveCount aiColor =
      case boardLastMove b of
        Nothing -> 0.0
        Just lastMove ->
          let enemy = opp aiColor
          in if stoneAt b lastMove /= Occupied enemy
             then 0.0
             else
               let sz = boardSize b
                   contactedStones =
                     [ nb | nb <- neighbors b lastMove, stoneAt b nb == Occupied aiColor ]
               in if null contactedStones
                  then 0.0
                  else
                    let iR = i `div` sz
                        iC = i `mod` sz
                        myNbs = neighbors b i

                        touchesEnemy = lastMove `elem` myNbs

                        touchesOwn =
                          any (\cs -> cs `elem` myNbs) contactedStones

                        isDiagToOwn =
                          any (\cs ->
                                 let csR = cs `div` sz
                                     csC = cs `mod` sz
                                 in abs (iR - csR) == 1 && abs (iC - csC) == 1)
                              contactedStones

                        isHane = isDiagToOwn && touchesEnemy
                        isExtend = touchesOwn && not touchesEnemy

                        haneAtari =
                          isHane &&
                          case tryPlay (b { boardToMove = aiColor }) i of
                            Nothing -> False
                            Just trial -> groupLiberties (groupInfo trial lastMove) <= 1

                    in if isHane
                       then if haneAtari then 30.0 else 20.0
                       else if isExtend
                       then 12.0
                       else 0.0

-- ─── Rule 18: Never leave own group in atari (non-capturing) ────────────────
avoidLeavingGroupInAtariRule :: Rule
avoidLeavingGroupInAtariRule = Rule "avoid-leaving-atari" 2.5 eval
  where
    eval b i _moveCount aiColor =
      let enemy = opp aiColor
          sz = boardSize b
          n = sz * sz
      in case tryPlay (b { boardToMove = aiColor }) i of
        Nothing -> 0.0
        Just trial ->
          let afterEnemy = length [ () | idx <- [0 .. n - 1], stoneAt trial idx == Occupied enemy ]
              beforeEnemy = length [ () | idx <- [0 .. n - 1], stoneAt b idx == Occupied enemy ]
              captured = afterEnemy < beforeEnemy
          in if captured
             then 0.0
             else
               let playedInfo = groupInfo trial i
                   playedGrp = IS.fromList (groupStones playedInfo)
                   findAtariGroups idx visited acc
                     | idx >= n = acc
                     | stoneAt trial idx == Occupied aiColor && not (IS.member idx visited) =
                         let info = groupInfo trial idx
                             stones = groupStones info
                             visited' = foldr IS.insert visited stones
                         in if groupLiberties info == 1 && not (IS.member idx playedGrp)
                            then findAtariGroups (idx + 1) visited' (info : acc)
                            else findAtariGroups (idx + 1) visited' acc
                     | otherwise = findAtariGroups (idx + 1) visited acc
                   atariGroups = findAtariGroups 0 IS.empty []
               in if null atariGroups
                  then 0.0
                  else
                    let totalStones = sum (map (length . groupStones) atariGroups)
                    in -fromIntegral (25 + totalStones * 15)

-- ─── Rule 19: Cutting moves to separate enemy stones ────────────────────────
cuttingRule :: Rule
cuttingRule = Rule "cutting" 2.0 eval
  where
    eval b i _moveCount aiColor =
      let enemy = opp aiColor
      in case tryPlay (b { boardToMove = aiColor }) i of
        Nothing -> 0.0
        Just trial ->
          let playedInfo = groupInfo trial i
              playedLibs = groupLiberties playedInfo
          in if playedLibs < 2
             then 0.0
             else
               let nbs = neighbors b i
                   enemyNbs = [ nb | nb <- nbs, stoneAt b nb == Occupied enemy ]
               in if length enemyNbs < 2
                  then 0.0
                  else
                    let enemyGroups = map (groupInfo b) enemyNbs
                        distinctGroups =
                          let collect [] acc = acc
                              collect (g:gs) acc =
                                let gSet = IS.fromList (groupStones g)
                                in if any (\es -> not (IS.null (IS.intersection gSet es))) acc
                                   then collect gs acc
                                   else collect gs (gSet : acc)
                          in collect enemyGroups []
                        groupCount = length distinctGroups
                    in if groupCount < 2
                       then 0.0
                       else
                         let totalEnemyStones = sum (map IS.size distinctGroups)
                             libsAfter = groupLiberties (groupInfo trial i)
                             safetyBonus = if libsAfter >= 4 then 1.5
                                           else if libsAfter >= 3 then 1.2
                                           else 1.0
                             baseScore = 30 + (groupCount - 1) * 15 + totalEnemyStones * 4
                         in fromIntegral baseScore * safetyBonus

-- ─── Rule registry ──────────────────────────────────────────────────────────
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
