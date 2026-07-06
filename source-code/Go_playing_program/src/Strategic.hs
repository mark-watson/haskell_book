{-# LANGUAGE BangPatterns #-}
-- | StrategicEngine — whole-board strategy: influence, territory, group safety,
-- strategic move generation (extensions, invasions, moyo reduction, connections).
module Strategic
  ( StrategicEngine (..)
  , newStrategicEngine
  , generateStrategicMoves
  , estimateScore
  , evaluateStrategicMove
  ) where

import           Board
import           Tactical (ScoredMove (..))
import qualified Data.Vector.Unboxed as V
import qualified Data.IntSet as IS
import           Data.List   (foldl')

-- | The Strategic Engine state.
data StrategicEngine = StrategicEngine
  { seBoard     :: !Board
  , seInfluence :: !(V.Vector Float) -- ^ Flat influence map. Row-major. Black positive, White negative.
  , seTerritory :: !(V.Vector Int)   -- ^ Flat territory map. Row-major. -1 white, 0 neutral, 1 black.
  } deriving (Show)

-- | Construct a new StrategicEngine by computing influence and territory maps.
newStrategicEngine :: Board -> StrategicEngine
newStrategicEngine b =
  let inf = computeInfluence b
      ter = computeTerritory b inf
  in StrategicEngine b inf ter

-- | Compute influence map: each stone radiates influence that decays with distance.
-- Black = positive, White = negative.
computeInfluence :: Board -> V.Vector Float
computeInfluence b =
  let sz = boardSize b
      n = sz * sz
      radius = if sz <= 9 then 4 else if sz <= 13 then 5 else 6
      decay = 0.5 :: Float
      baseStrength = 4.0 :: Float

      -- Calculate influence contribution from a single stone.
      stoneInfluence idx color =
        let r = idx `div` sz
            c = idx `mod` sz
            sign = if color == Black then 1.0 else -1.0
            updates =
              [ (nr * sz + nc, val)
              | dr <- [-radius .. radius]
              , dc <- [-radius .. radius]
              , let nr = r + dr
              , let nc = c + dc
              , nr >= 0, nr < sz, nc >= 0, nc < sz
              , let dist = abs dr + abs dc
              , dist <= radius
              , let val = if dist == 0
                          then sign * baseStrength * 3
                          else sign * baseStrength * (decay ** fromIntegral dist)
              ]
        in updates

      -- Accumulate influence of all stones.
      allUpdates =
        [ up
        | idx <- [0 .. n - 1]
        , Occupied col <- [stoneAt b idx]
        , up <- stoneInfluence idx col
        ]

      initVec = V.replicate n 0.0
  in V.accum (+) initVec allUpdates

-- | Compute territory: empty regions dominated by one color's influence.
computeTerritory :: Board -> V.Vector Float -> V.Vector Int
computeTerritory b inf =
  let sz = boardSize b
      n = sz * sz
      grid = boardGrid b

      -- Flood fill empty region.
      floodEmpty start visited =
        let go []     !vis !reg !tb !tw !bi !wi = (reg, vis, tb, tw, bi, wi)
            go (x:xs) !vis !reg !tb !tw !bi !wi =
              let nbs = neighbors b x
                  infVal = inf V.! x
                  bi' = bi + if infVal > 0 then infVal else 0
                  wi' = wi + if infVal < 0 then -infVal else 0
                  (xs', vis', tb', tw') = foldr step (xs, vis, tb, tw) nbs
              in go xs' vis' (x : reg) tb' tw' bi' wi'

            step nb (!stk, !vs, !tb, !tw)
              | grid V.! nb == 0 =
                  if IS.member nb vs
                  then (stk, vs, tb, tw)
                  else (nb : stk, IS.insert nb vs, tb, tw)
              | grid V.! nb == 1 = (stk, vs, True, tw)
              | grid V.! nb == 2 = (stk, vs, tb, True)
              | otherwise = (stk, vs, tb, tw)

            startVis = IS.insert start visited
        in go [start] startVis [] False False 0.0 0.0

      getTerritoryUpdates idx !visited !updates
        | idx >= n = updates
        | grid V.! idx /= 0 || IS.member idx visited = getTerritoryUpdates (idx + 1) visited updates
        | otherwise =
            let (region, visited', tb, tw, bi, wi) = floodEmpty idx visited
                owner = case (tb, tw) of
                  (True, False) | bi > wi -> 1
                  (False, True) | wi > bi -> -1
                  (False, False) ->
                    if bi > wi * 1.5 then 1
                    else if wi > bi * 1.5 then -1
                    else 0
                  _ -> 0
                newUpdates = map (\p -> (p, owner)) region
            in getTerritoryUpdates (idx + 1) visited' (newUpdates ++ updates)

      initTerr = V.replicate n 0
      ups = getTerritoryUpdates 0 IS.empty []
  in initTerr V.// ups

-- | Estimate overall score from Black's perspective.
estimateScore :: StrategicEngine -> Double
estimateScore se =
  let b = seBoard se
      sz = boardSize b
      n = sz * sz
      score = foldl' count 0 [0 .. n - 1]
        where
          count !acc i =
            let st = stoneAt b i
                terr = seTerritory se V.! i
                stoneVal = case st of
                  Occupied Black -> 1
                  Occupied White -> -1
                  Empty          -> 0
                terrVal = if st == Empty then terr else 0
            in acc + stoneVal + terrVal
  in fromIntegral score - 6.5

-- | Check if playing at index `i` would create an empty triangle.
createsEmptyTriangle :: Board -> Int -> Color -> Bool
createsEmptyTriangle b idx color =
  let sz = boardSize b
      r = idx `div` sz
      c = idx `mod` sz
      colI = if color == Black then 1 else 2

      -- Check all four 2x2 boxes containing (r, c)
      topLefts = [ (r - 1, c - 1), (r - 1, c), (r, c - 1), (r, c) ]
      check tr tc =
        tr >= 0 && tr + 1 < sz && tc >= 0 && tc + 1 < sz &&
        let corners = [ tr * sz + tc, tr * sz + tc + 1, (tr + 1) * sz + tc, (tr + 1) * sz + tc + 1 ]
            friendly = length [ () | ci <- corners, ci == idx || boardGrid b V.! ci == colI ]
            emptyCount = length [ () | ci <- corners, ci /= idx && boardGrid b V.! ci == 0 ]
            enemyCount = length [ () | ci <- corners, boardGrid b V.! ci /= 0 && boardGrid b V.! ci /= colI ]
        in friendly == 3 && emptyCount == 1 && enemyCount == 0
  in any (uncurry check) topLefts

-- | Count empty corners of a board.
countEmptyCorners :: Board -> Int
countEmptyCorners b =
  let sz = boardSize b
      extent = if sz >= 17 then 7 else if sz >= 11 then 5 else 4
      corners = [ (0, 0, 1, 1), (0, sz-1, 1, -1), (sz-1, 0, -1, 1), (sz-1, sz-1, -1, -1) ]
      cornerEmpty (orG, ocG, dr, dc) =
        let pts = [ (orG + ddr * dr) * sz + (ocG + ddc * dc)
                  | ddr <- [0 .. extent - 1]
                  , ddc <- [0 .. extent - 1]
                  ]
        in all (\p -> stoneAt b p == Empty) pts
  in length (filter cornerEmpty corners)

-- | Generate strategic moves.
generateStrategicMoves :: StrategicEngine -> [ScoredMove]
generateStrategicMoves se =
  let b = seBoard se
      color = boardToMove b
      sz = boardSize b
      n = sz * sz
      sign = if color == Black then 1.0 else -1.0
      infMap = seInfluence se

      -- 1. Extend into own territory/influence.
      extends =
        [ ScoredMove i (max 0 (15 + fromIntegral (round (inf * 3) :: Int) - shapePenalty))
                       (if shapePenalty > 10 then "extend influence (light)" else "extend influence")
        | i <- [0 .. n - 1]
        , stoneAt b i == Empty
        , let inf = infMap V.! i * sign
        , inf > 1.5
        , any (\nb -> stoneAt b nb == Occupied color) (neighbors b i)
        , let shapePenalty =
                (if createsEmptyTriangle b i color then 15 else 0) +
                (if any (\nb -> stoneAt b nb == Occupied color && groupLiberties (groupInfo b nb) >= 3) (neighbors b i)
                 then 8
                 else 0)
        ]

      -- 2. Reduce opponent's moyo.
      reductions =
         [ ScoredMove i (12 + realToFrac (enemyInf * 2)) "reduce enemy moyo"
        | i <- [0 .. n - 1]
        , stoneAt b i == Empty
        , let enemyInf = -infMap V.! i * sign
        , enemyInf > 2.0 && enemyInf < 6.0
        , not (any (\nb -> stoneAt b nb == Occupied (opp color)) (neighbors b i))
        ]

      -- 3. Approach enemy stones.
      stoneCount = length [ () | idx <- [0 .. n - 1], stoneAt b idx /= Empty ]
      isOpening = stoneCount < round (fromIntegral n * 0.15 :: Double)
      emptyCorners = countEmptyCorners b
      openingDampener = if isOpening && emptyCorners >= 2 then (0.5 :: Double) else 1.0

      approaches =
        let go idx visited acc
              | idx >= n = acc
              | stoneAt b idx == Occupied (opp color) && not (IS.member idx visited) =
                  let info = groupInfo b idx
                      stones = groupStones info
                      visited' = foldr IS.insert visited stones
                      r = idx `div` sz
                      c = idx `mod` sz
                      mvs =
                        [ ScoredMove ni (fromIntegral (round (rawScore * openingDampener) :: Int)) "approach enemy group"
                        | dr <- [-3 .. 3]
                        , dc <- [-3 .. 3]
                        , let nr = r + dr
                        , let nc = c + dc
                        , nr >= 0, nr < sz, nc >= 0, nc < sz
                        , let ni = nr * sz + nc
                        , stoneAt b ni == Empty
                        , let dist = abs dr + abs dc
                        , dist >= 2 && dist <= 3
                        , let candEdgeDist = minimum [nr, nc, sz - 1 - nr, sz - 1 - nc]
                        , let enemyEdgeDist = minimum [r, c, sz - 1 - r, sz - 1 - c]
                        , let edgeDiff = candEdgeDist - enemyEdgeDist
                        , let edgeBonus = if edgeDiff < 0 then -edgeDiff * 4 else 0
                        , let edgePenalty = if edgeDiff > 0 then if isOpening then edgeDiff * 8 else edgeDiff * 3 else 0
                        , let safetyPenalty =
                                case tryPlay (b { boardToMove = color }) ni of
                                  Nothing -> (0 :: Int)
                                  Just trial ->
                                    let candInfo = groupInfo trial ni
                                    in if length (groupStones candInfo) == 1 && groupLiberties candInfo <= 3
                                       then if length (filter (\nb -> stoneAt b nb == Occupied (opp color)) (neighbors b ni)) >= 2
                                            then 15
                                            else 0
                                       else 0
                        , let rawScore = 10.0 + fromIntegral (3 - dist) * 3.0 + fromIntegral edgeBonus - fromIntegral edgePenalty - fromIntegral safetyPenalty
                        ]
                  in go (idx + 1) visited' (mvs ++ acc)
              | otherwise = go (idx + 1) visited acc
        in go 0 IS.empty []

      -- Remove duplicates from approaches
      uniqueApproaches = nubBy (\a y -> smIndex a == smIndex y) approaches
        where nubBy _ [] = []
              nubBy eq (x:xs) = x : nubBy eq (filter (not . eq x) xs)

      -- 4. Connect friendly groups.
      friendlyGroups =
        let go idx visited acc
              | idx >= n = acc
              | stoneAt b idx == Occupied color && not (IS.member idx visited) =
                  let info = groupInfo b idx
                      stones = groupStones info
                      visited' = foldr IS.insert visited stones
                  in go (idx + 1) visited' (stones : acc)
              | otherwise = go (idx + 1) visited acc
        in go 0 IS.empty []

      connections =
        [ ScoredMove bestPoint (fromIntegral (20 + (5 - bestDist) * 4)) "connect friendly groups"
        | (idxA, grpA) <- zip [(0 :: Int)..] friendlyGroups
        , (idxB, grpB) <- zip [0..] friendlyGroups
        , idxB > idxA
        , let connectionsForPairs =
                [ (dist, mi)
                | sa <- grpA
                , let ra = sa `div` sz
                , let ca = sa `mod` sz
                , sb <- grpB
                , let rb = sb `div` sz
                , let cb = sb `mod` sz
                , let dist = abs (ra - rb) + abs (ca - cb)
                , dist <= 4
                , let mr = (ra + rb) `div` 2
                , let mc = (ca + cb) `div` 2
                , let mi0 = mr * sz + mc
                , let mi = if stoneAt b mi0 == Empty
                           then mi0
                           else case filter (\nb -> stoneAt b nb == Empty) (neighbors b mi0) of
                                  (nbOpt:_) -> nbOpt
                                  []        -> -1
                , mi >= 0
                ]
        , not (null connectionsForPairs)
        , let (bestDist, bestPoint) = minimum connectionsForPairs
        ]

      -- 5. Big points.
      bigPoints =
        [ ScoredMove i (fromIntegral ((10 + if edgeDist == 3 then 4 else 2) :: Int)) "big point"
        | i <- [0 .. n - 1]
        , stoneAt b i == Empty
        , abs (infMap V.! i) < 0.5
        , let r = i `div` sz
        , let c = i `mod` sz
        , let edgeDist = minimum [r, c, sz - 1 - r, sz - 1 - c]
        , edgeDist == 2 || edgeDist == 3
        ]

      -- Combine all list and filter out non-empty moves or duplicates
      allMoves = extends ++ reductions ++ uniqueApproaches ++ connections ++ bigPoints
      uniqueAllMoves = foldl' addUnique [] allMoves
        where
          addUnique acc mv =
            if any (\m -> smIndex m == smIndex mv) acc
            then acc
            else mv : acc

  in uniqueAllMoves

-- | Evaluate a single candidate strategically.
evaluateStrategicMove :: StrategicEngine -> Int -> Double
evaluateStrategicMove se i =
  let b = seBoard se
      color = boardToMove b
      sign = if color == Black then 1.0 else -1.0
      sz = boardSize b
      inf = seInfluence se V.! i * sign

      -- Gain in own/enemy influence
      score0 = if inf > 0 then inf * 2.0 else 0.0
      enemyInf = -seInfluence se V.! i * sign
      score1 = if enemyInf > 1 then enemyInf * 1.5 else 0.0

      -- Edge distance penalty/bonus
      r = i `div` sz
      c = i `mod` sz
      edgeDist = minimum [r, c, sz - 1 - r, sz - 1 - c]
      stoneCount = length [ () | idx <- [0 .. sz*sz - 1], stoneAt b idx /= Empty ]
      isOpening = stoneCount < round (fromIntegral (sz*sz) * 0.15 :: Double)

      penalty = if isOpening
                then (if edgeDist < 2 then fromIntegral (2 - edgeDist) * 5.0 else 0.0) +
                     (if edgeDist >= 4 then fromIntegral (edgeDist - 3) * 3.0 else 0.0)
                else 0.0

      bonus = if edgeDist == 2 then 3.0
              else if edgeDist == 3 then 5.0
              else 0.0
  in realToFrac (score0 + score1) - penalty + bonus
