{-# LANGUAGE BangPatterns #-}
-- | JosekiEngine — opening theory and corner patterns.
module Joseki
  ( generateJosekiMoves
  , evaluateJosekiMove
  ) where

import           Board
import           Tactical (ScoredMove (..))
import qualified Data.Vector.Unboxed as V

-- | A Joseki Pattern definition.
data JosekiPattern = JP
  { jpName   :: !String
  , jpStones :: ![(Int, Int, Int)] -- ^ (dr, dc, colorInt: 1=Black, 2=White)
  , jpSide   :: !Color
  , jpReply  :: !(Int, Int)       -- ^ (dr, dc)
  , jpWeight :: !Double
  } deriving (Show, Eq)

buildPatterns :: [JosekiPattern]
buildPatterns =
  [ -- === 4-4 point (hoshi) joseki ===
    JP "44-kakari-kosumi-respond" [(3, 3, 1), (2, 2, 2)] Black (4, 3) 60.0
  , JP "44-ikken-kakari-extend"   [(3, 3, 1), (2, 3, 2)] Black (3, 4) 65.0
  , JP "44-ikken-kakari-extend2"  [(3, 3, 1), (3, 2, 2)] Black (4, 3) 65.0
  , JP "44-kogeima-kakari-extend" [(3, 3, 1), (2, 4, 2)] Black (3, 4) 55.0
  , JP "44-kakari-extend-tsuke"   [(3, 3, 1), (2, 3, 2), (3, 4, 1)] White (2, 4) 50.0
  , JP "44-kakari-extend-knight"  [(3, 3, 1), (2, 3, 2), (3, 4, 1)] White (2, 2) 45.0
  , JP "44-san-san-invasion"      [(3, 3, 1), (2, 2, 2)] Black (3, 2) 70.0

    -- === 3-4 point (komoku) joseki ===
  , JP "34-kogeima-approach"      [(2, 3, 1), (4, 2, 2)] Black (2, 4) 55.0
  , JP "34-approach-extend"       [(2, 3, 1), (3, 4, 2)] Black (2, 4) 58.0
  , JP "34-approach-extend-tsuke" [(2, 3, 1), (3, 4, 2), (2, 4, 1)] White (3, 5) 50.0
  , JP "34-shimari-knight"        [(2, 3, 1)] Black (4, 4) 40.0
  , JP "34-shimari-large-knight"  [(2, 3, 1)] Black (5, 4) 35.0
  , JP "34-shimari-ikken"         [(2, 3, 1)] Black (4, 3) 38.0

    -- === 3-3 point (san-san) joseki ===
  , JP "33-approach-extend"       [(2, 2, 1), (4, 2, 2)] Black (2, 4) 50.0
  , JP "33-approach-extend2"      [(2, 2, 1), (2, 4, 2)] Black (4, 2) 50.0
  , JP "33-niken-tobi"            [(2, 2, 1)] Black (2, 4) 35.0

    -- === Contact (tsuke) responses ===
  , JP "44-tsuke-hane"            [(3, 3, 1), (3, 2, 2)] Black (4, 2) 60.0
  , JP "44-tsuke-hane-connect"    [(3, 3, 1), (3, 2, 2), (4, 2, 1)] White (3, 1) 55.0
  ]

-- | Check if a pattern matches at a specific corner.
matchPattern :: Board -> JosekiPattern -> Int -> Int -> Int -> Int -> Bool
matchPattern b pat originR originC dr dc =
  all checkStone (jpStones pat)
  where
    sz = boardSize b
    checkStone (sr, sc, colorVal) =
      let r = originR + sr * dr
          c = originC + sc * dc
      in r >= 0 && r < sz && c >= 0 && c < sz &&
         (boardGrid b V.! (r * sz + c)) == colorVal

-- | Convert a relative reply to an absolute board index.
replyToIndex :: Board -> (Int, Int) -> Int -> Int -> Int -> Int -> Int
replyToIndex b (replyR, replyC) originR originC dr dc =
  let sz = boardSize b
      r = originR + replyR * dr
      c = originC + replyC * dc
  in if r >= 0 && r < sz && c >= 0 && c < sz
     then r * sz + c
     else -1

-- | Check if playing at index `idx` would create an empty triangle.
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
        let cornerPts = [ tr * sz + tc, tr * sz + tc + 1, (tr + 1) * sz + tc, (tr + 1) * sz + tc + 1 ]
            friendly = length [ () | ci <- cornerPts, ci == idx || boardGrid b V.! ci == colI ]
            emptyCount = length [ () | ci <- cornerPts, ci /= idx && boardGrid b V.! ci == 0 ]
            enemyCount = length [ () | ci <- cornerPts, boardGrid b V.! ci /= 0 && boardGrid b V.! ci /= colI ]
        in friendly == 3 && emptyCount == 1 && enemyCount == 0
  in any (uncurry check) topLefts

-- | Get the corner transformations: [(originR, originC, dr, dc)]
corners :: Board -> [(Int, Int, Int, Int)]
corners b =
  let s = boardSize b
  in [ (0,     0,      1,  1)  -- top-left
     , (0,     s - 1,  1, -1)  -- top-right
     , (s - 1, 0,     -1,  1)  -- bottom-left
     , (s - 1, s - 1, -1, -1)  -- bottom-right
     ]

-- | Check if corner region has any stones.
cornerRegionHasStone :: Board -> Int -> Int -> Bool
cornerRegionHasStone b r c =
  let sz = boardSize b
  in any (\nr -> any (\nc -> nr >= 0 && nr < sz && nc >= 0 && nc < sz && stoneAt b (nr * sz + nc) /= Empty)
                      [c - 2 .. c + 2])
         [r - 2 .. r + 2]

-- | Generate joseki and fuseki moves.
generateJosekiMoves :: Board -> Int -> [ScoredMove]
generateJosekiMoves b moveCount =
  let color = boardToMove b
      sz = boardSize b
      n = sz * sz
      pats = buildPatterns

      -- 1. Check patterns in corners
      patternMoves =
        [ ScoredMove idx score ("joseki: " ++ jpName pat)
        | pat <- pats
        , (orR, orC, dr, dc) <- corners b
         , let matchesOrig = jpSide pat == color && matchPattern b pat orR orC dr dc
               -- Swapped colors
               swappedPat = pat { jpSide = opp (jpSide pat)
                                , jpStones = map (\(sr, sc, col) -> (sr, sc, if col == 1 then 2 else 1)) (jpStones pat) }
               matchesSwap = jpSide swappedPat == color && matchPattern b swappedPat orR orC dr dc
          , matchesOrig || matchesSwap
          , let replyCoord = if matchesOrig then jpReply pat else jpReply swappedPat
          , let idx = replyToIndex b replyCoord orR orC dr dc
          , idx >= 0
          , stoneAt b idx == Empty
          , let isTriangle = createsEmptyTriangle b idx color
          , let score = if isTriangle then jpWeight pat * 0.3 else jpWeight pat
          ]

      -- 2. Fuseki: if board is nearly empty (<= 4 moves), play star points.
      starPoints =
        if sz == 19 then [(3, 3), (3, 9), (3, 15), (9, 3), (9, 15), (15, 3), (15, 9), (15, 15)]
        else if sz == 13 then [(3, 3), (3, 6), (3, 9), (6, 3), (6, 9), (9, 3), (9, 6), (9, 9)]
        else [(2, 2), (2, 4), (2, 6), (4, 2), (4, 6), (6, 2), (6, 4), (6, 6)]

      fusekiMoves =
        if moveCount <= 4
        then
          [ ScoredMove idx score "fuseki: star point"
          | (r, c) <- starPoints
          , let idx = r * sz + c
          , stoneAt b idx == Empty
          , let minR = minimum [r, sz - 1 - r]
          , let minC = minimum [c, sz - 1 - c]
          , let isCorner = minR <= 3 && minC <= 3
          , let baseScore = if isCorner then 50.0 else 35.0
          , let hasStone = cornerRegionHasStone b r c
          , let score = if hasStone then baseScore - 20.0 else baseScore
          ] ++
          [ ScoredMove idx 35.0 "fuseki: komoku/san-san"
          | (r, c) <- [ (2, 3), (3, 2)
                      , (2, sz - 4), (3, sz - 3)
                      , (sz - 3, 2), (sz - 4, 3)
                      , (sz - 3, sz - 4), (sz - 4, sz - 3)
                      ]
          , r >= 0, r < sz, c >= 0, c < sz
          , let idx = r * sz + c
          , stoneAt b idx == Empty
          ]
        else []

      -- Combine and filter duplicates
      allMoves = patternMoves ++ fusekiMoves
      uniqueMoves = foldl addUnique [] allMoves
        where
          addUnique acc mv =
            if any (\m -> smIndex m == smIndex mv) acc
            then acc
            else mv : acc

  in if fromIntegral moveCount > fromIntegral n * (0.25 :: Double)
     then []
     else uniqueMoves

-- | Evaluate joseki quality of a move.
evaluateJosekiMove :: Board -> Int -> Int -> Double
evaluateJosekiMove b i moveCount =
  let sz = boardSize b
      r = i `div` sz
      c = i `mod` sz
      edgeDist = minimum [r, c, sz - 1 - r, sz - 1 - c]
   in if fromIntegral moveCount < fromIntegral (sz * sz) * (0.2 :: Double)
     then if edgeDist == 2 then 8.0
          else if edgeDist == 3 then 10.0
          else if edgeDist < 2 then -5.0
          else if edgeDist == 4 then -3.0
          else -8.0
     else 0.0
