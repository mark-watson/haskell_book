{-# LANGUAGE BangPatterns #-}
-- | Board — Lightweight board representation for Go.
-- Independent simulation board optimised for fast clone + play (for MCTS).
-- Mirrors the rules from the TypeScript SimBoard: captures, suicide, ko.
module Board
  ( -- * Types
    Color (..)
  , Stone (..)
  , Board (..)
  , GroupInfo (..)
  , Move (..)
    -- * Construction
  , emptyBoard
  , cloneBoard
    -- * Queries
  , boardIdx
  , rowOf
  , colOf
  , atRC
  , neighbors
  , groupInfo
  , libertyCount
  , legalMoves
  , areaScore
  , isOwnEye
    -- * Moves
  , tryPlay
  , passMove
    -- * Utilities
  , opp
  , stoneAt
  , boardSize
  , gridList
  ) where

import           Data.Bits          (xor)
import qualified Data.IntSet        as IS
import qualified Data.Vector.Unboxed as V
import           Data.Word          (Word32)

-- | Stone colours.  EMPTY is encoded as 0 in the grid vector.
data Color = Black | White
  deriving (Eq, Ord, Show, Enum)

-- | What occupies a board intersection.
data Stone = Empty | Occupied !Color
  deriving (Eq, Ord, Show)



intToStone :: Int -> Stone
intToStone 1 = Occupied Black
intToStone 2 = Occupied White
intToStone _ = Empty

-- | A move on the board (row, col) or Pass.
data Move = Play !Int !Int | Pass
  deriving (Eq, Show)

-- | The opponent colour.
opp :: Color -> Color
opp Black = White
opp White = Black

-- | Info about a group of connected same-colour stones.
data GroupInfo = GroupInfo
  { groupStones    :: ![Int]   -- ^ Flat indices of stones in the group
  , groupLiberties :: !Int     -- ^ Number of distinct liberties
  } deriving (Show)

-- | The board state.
data Board = Board
  { boardGrid     :: !(V.Vector Int)    -- ^ Flat grid, row-major.  0=empty, 1=black, 2=white
  , boardSz       :: !Int               -- ^ Board edge length (9, 13, or 19)
  , boardToMove   :: !Color             -- ^ Whose turn it is
  , boardPrevHash :: !Word32            -- ^ Hash of the position before last move (ko)
  , boardLastMove :: !(Maybe Int)       -- ^ Flat index of last move, Nothing for pass/start
  , boardCaptures :: !(Int, Int)        -- ^ (Black's captures, White's captures)
  } deriving (Eq, Show)

-- | Short-hand for board edge length.
boardSize :: Board -> Int
boardSize = boardSz

-- | Create an empty board of the given size.
emptyBoard :: Int -> Board
emptyBoard sz = Board
  { boardGrid     = V.replicate (sz * sz) 0
  , boardSz       = sz
  , boardToMove   = Black
  , boardPrevHash = 0
  , boardLastMove = Nothing
  , boardCaptures = (0, 0)
  }

-- | Clone a board (the Vector is already immutable, so this is cheap).
cloneBoard :: Board -> Board
cloneBoard b = b  -- immutable data — identity clone

-- | Convert (row, col) to flat index.
boardIdx :: Board -> Int -> Int -> Int
boardIdx b r c = r * boardSz b + c

-- | Row of a flat index.
rowOf :: Board -> Int -> Int
rowOf b i = i `div` boardSz b

-- | Column of a flat index.
colOf :: Board -> Int -> Int
colOf b i = i `mod` boardSz b

-- | Stone at (row, col).
atRC :: Board -> Int -> Int -> Stone
atRC b r c = intToStone (boardGrid b V.! boardIdx b r c)

-- | Stone at flat index.
stoneAt :: Board -> Int -> Stone
stoneAt b i
  | i < 0 || i >= V.length (boardGrid b) = error $ "stoneAt: index " ++ show i ++ " out of bounds (board size " ++ show (boardSz b) ++ ")"
  | otherwise = intToStone (boardGrid b V.! i)

-- | Get the list representation of the grid (for iteration).
gridList :: Board -> [Int]
gridList b = V.toList (boardGrid b)

-- | Orthogonal neighbours of a flat index.
neighbors :: Board -> Int -> [Int]
neighbors b i =
  let s = boardSz b
      r = i `div` s
      c = i `mod` s
  in  [i - s | r > 0]
   ++ [i + s | r < s - 1]
   ++ [i - 1 | c > 0]
   ++ [i + 1 | c < s - 1]

-- | Flood-fill group from a seed index.
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

-- | Liberty count for the group containing the stone at the given index.
libertyCount :: Board -> Int -> Int
libertyCount b i = groupLiberties (groupInfo b i)

-- | Compute a simple hash of a grid (for ko detection).
hashGrid :: V.Vector Int -> Word32
hashGrid = V.foldl' (\h v -> (h * 33) `xor` fromIntegral v) 5381

-- | Try to play a stone at flat index.  Returns Nothing if illegal,
-- or Just the new board if legal.
tryPlay :: Board -> Int -> Maybe Board
tryPlay b i
  | i < 0 || i >= boardSz b * boardSz b = error $ "tryPlay: index " ++ show i ++ " out of bounds (board size " ++ show (boardSz b) ++ ")"
  | boardGrid b V.! i /= 0 = Nothing  -- occupied
  | otherwise = do
      let color    = colorToInt (boardToMove b)
          enemy    = colorToInt (opp (boardToMove b))
          sz       = boardSz b

          -- Place the stone.
          trial0   = boardGrid b V.// [(i, color)]

          -- Remove enemy groups with 0 liberties adjacent to the played stone.
          nbs      = neighbors b i
          (trial1, removed) = removeDeadGroups trial0 sz enemy nbs

          -- Check own group liberties (suicide check).
          ownLibs  = countGroupLibs trial1 sz color i

      -- Suicide: own group has 0 liberties after removing enemy dead groups.
      if ownLibs == 0
        then Nothing
        else do
          -- Ko check: resulting position must not equal the previous position hash.
          let newHash = hashGrid trial1
          if boardPrevHash b /= 0 && newHash == boardPrevHash b
            then Nothing  -- ko
            else
              let (bc, wc) = boardCaptures b
                  captures' = case boardToMove b of
                    Black -> (bc + removed, wc)
                    White -> (bc, wc + removed)
                  -- The prevHash for the next position is the hash of the
                  -- position *before* this move (i.e. the current grid).
                  prevH = hashGrid (boardGrid b)
              in  Just Board
                    { boardGrid     = trial1
                    , boardSz       = sz
                    , boardToMove   = opp (boardToMove b)
                    , boardPrevHash = prevH
                    , boardLastMove = Just i
                    , boardCaptures = captures'
                    }

-- | Pass the turn.
passMove :: Board -> Board
passMove b = b
  { boardToMove   = opp (boardToMove b)
  , boardLastMove = Nothing
  , boardPrevHash = 0  -- passing breaks the ko chain
  }

-- | Get all legal moves (empty points).
legalMoves :: Board -> [Int]
legalMoves b = [ i | i <- [0 .. V.length (boardGrid b) - 1]
                   , boardGrid b V.! i == 0
               ]

-- | Score using simple area scoring (Chinese-like).
-- Returns score from Black's perspective (positive = Black ahead).
areaScore :: Board -> Double
areaScore b =
  let sz = boardSz b
      n  = sz * sz
      grid = boardGrid b

      -- Count stones.
      (blackStones, whiteStones) = V.foldl' countSt (0, 0) grid

      -- Count territory by flood-filling empty regions.
      territory = computeTerritory b n

  in  fromIntegral (blackStones + fst territory)
    - fromIntegral (whiteStones + snd territory)

  where
    countSt (!bs, !ws) v
      | v == 1    = (bs + 1, ws)
      | v == 2    = (bs, ws + 1)
      | otherwise = (bs, ws)

-- | Compute territory: (black territory count, white territory count).
computeTerritory :: Board -> Int -> (Int, Int)
computeTerritory b n = go 0 IS.empty 0 0
  where
    go i visited bt wt
      | i >= n = (bt, wt)
      | boardGrid b V.! i /= 0 || IS.member i visited = go (i+1) visited bt wt
      | otherwise =
          let (region, visited', touchesBlack, touchesWhite) =
                floodEmpty b [i] (IS.insert i visited) [] False False
              count = length region
          in  case (touchesBlack, touchesWhite) of
                (True, False) -> go (i+1) visited' (bt + count) wt
                (False, True) -> go (i+1) visited' bt (wt + count)
                _             -> go (i+1) visited' bt wt

    floodEmpty _ []     vis reg tb tw = (reg, vis, tb, tw)
    floodEmpty bd (x:xs) vis reg tb tw =
      let nbs = neighbors bd x
          (xs', vis', tb', tw') = foldr (stepEmpty bd) (xs, vis, tb, tw) nbs
      in  floodEmpty bd xs' vis' (x : reg) tb' tw'

    stepEmpty bd nb (!stk, !vs, !tb, !tw)
      | v == 0    = if IS.member nb vs
                    then (stk, vs, tb, tw)
                    else (nb : stk, IS.insert nb vs, tb, tw)
      | v == 1    = (stk, vs, True, tw)
      | v == 2    = (stk, vs, tb, True)
      | otherwise = (stk, vs, tb, tw)
      where v = boardGrid bd V.! nb

-- | Check if a point is an eye for the given colour.
isOwnEye :: Board -> Int -> Color -> Bool
isOwnEye b i color =
  let sz   = boardSz b
      colI = colorToInt color
      r    = i `div` sz
      c    = i `mod` sz
      nbs  = neighbors b i
      -- All orthogonal neighbours must be same colour.
      allFriendly = all (\nb -> boardGrid b V.! nb == colI) nbs
      -- Diagonal check.
      diags = [ (r + dr, c + dc) | dr <- [-1, 1], dc <- [-1, 1]
              , let nr = r + dr; nc = c + dc
              , nr >= 0, nr < sz, nc >= 0, nc < sz
              ]
      diagCount   = length diags
      diagFriends = length [ () | (dr, dc) <- diags
                           , boardGrid b V.! (dr * sz + dc) == colI
                           ]
  in  allFriendly &&
      if diagCount < 4
        then diagFriends == diagCount
        else diagFriends >= 3

-- ─── Internal helpers ───────────────────────────────────────────────────────

colorToInt :: Color -> Int
colorToInt Black = 1
colorToInt White = 2

-- | Remove all dead enemy groups adjacent to the given indices.
-- Returns (updated grid, number of stones removed).
removeDeadGroups :: V.Vector Int -> Int -> Int -> [Int] -> (V.Vector Int, Int)
removeDeadGroups grid0 sz enemyColor indices =
  foldl step (grid0, 0) indices
  where
    step (grid, removed) nb
      | grid V.! nb /= enemyColor = (grid, removed)
      | otherwise =
          let grp = floodGroup grid sz enemyColor nb
              libs = countLibsOf grid sz grp
          in  if libs == 0
              then let grid' = foldl (\g idx -> g V.// [(idx, 0)]) grid grp
                   in  (grid', removed + length grp)
              else (grid, removed)

-- | Flood-fill a group in a grid.
floodGroup :: V.Vector Int -> Int -> Int -> Int -> [Int]
floodGroup grid sz color seed = go [seed] IS.empty []
  where
    go []     _    acc = acc
    go (x:xs) seen acc
      | IS.member x seen = go xs seen acc
      | grid V.! x /= color = go xs seen acc
      | otherwise =
          let seen' = IS.insert x seen
              nbs   = neighborsRaw sz x
              xs'   = nbs ++ xs
          in  go xs' seen' (x : acc)

-- | Count liberties of a set of stones in a grid.
countLibsOf :: V.Vector Int -> Int -> [Int] -> Int
countLibsOf grid sz stones =
  IS.size $ foldl step IS.empty stones
  where
    step libSet s =
      foldl (\ls nb -> if grid V.! nb == 0
                       then IS.insert nb ls
                       else ls)
            libSet (neighborsRaw sz s)

-- | Count group liberties of the stone at index i in a given grid.
countGroupLibs :: V.Vector Int -> Int -> Int -> Int -> Int
countGroupLibs grid sz color seed =
  let grp = floodGroup grid sz color seed
  in  countLibsOf grid sz grp

-- | Raw neighbor computation from size and index (no Board needed).
neighborsRaw :: Int -> Int -> [Int]
neighborsRaw sz i =
  let r = i `div` sz
      c = i `mod` sz
  in  [i - sz | r > 0]
   ++ [i + sz | r < sz - 1]
   ++ [i - 1 | c > 0]
   ++ [i + 1 | c < sz - 1]
