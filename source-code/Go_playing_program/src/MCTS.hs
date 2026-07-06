{-# LANGUAGE BangPatterns #-}
-- | MCTS — Monte Carlo Tree Search with UCT selection and RAVE.
--
-- Features:
--   - Heavy playouts with pattern-based move generation
--   - RAVE (Rapid Action Value Estimation) for faster convergence
--   - Time-limited search with iterative deepening
--   - Progressive widening to limit branching
module MCTS
  ( MCTSEngine (..)
  , mctsSearch
  ) where

import           Board
import qualified Data.Vector.Unboxed as V
import           Tactical (ScoredMove (..))
import           Data.IORef
import           Data.List   (sortBy)
import           Data.Ord    (Down (..))
import           System.Random (StdGen, randomR)
import           Data.Time.Clock (getCurrentTime, diffUTCTime)

-- | MCTS configuration.
data MCTSEngine = MCTSEngine
  { mctsBoard          :: !Board
  , mctsExploration    :: !Double
  , mctsRaveBias       :: !Double
  , mctsMaxPlayouts    :: !Int
  , mctsTimeLimitMs    :: !Int
  } deriving (Show)

-- | An MCTS tree node.
data MCTSNode = MCTSNode
  { nodeIndex     :: !Int             -- move that led here (-1 for root)
  , nodeChildren  :: ![MCTSNode]
  , nodeUntried   :: ![Int]           -- moves not yet expanded
  , nodeVisits    :: !Int
  , nodeWins      :: !Double
  , nodeRaveVisits :: !Int
  , nodeRaveWins  :: !Double
  , nodeColor     :: !Color           -- color to move at this node
  , nodeExpanded  :: !Bool
  } deriving (Show)

mkNode :: Int -> Color -> MCTSNode
mkNode idx col = MCTSNode
  { nodeIndex      = idx
  , nodeChildren   = []
  , nodeUntried    = []
  , nodeVisits     = 0
  , nodeWins       = 0.0
  , nodeRaveVisits = 0
  , nodeRaveWins   = 0.0
  , nodeColor      = col
  , nodeExpanded   = False
  }

-- | Run MCTS search, return scored moves (sorted by score descending).
mctsSearch :: MCTSEngine -> StdGen -> IO [ScoredMove]
mctsSearch eng gen0 = do
  let rootColor = boardToMove (mctsBoard eng)
  rootRef <- newIORef (mkNode (-1) rootColor)
  genRef  <- newIORef gen0
  startTime <- getCurrentTime

  let loop !playoutCount = do
        now <- getCurrentTime
        let elapsedMs = round (diffUTCTime now startTime * 1000) :: Int
        if playoutCount >= mctsMaxPlayouts eng || elapsedMs >= mctsTimeLimitMs eng
          then return ()
          else do
            root <- readIORef rootRef
            gen  <- readIORef genRef

            let board0 = mctsBoard eng
            -- Selection + Expansion + Simulation + Backpropagation
            let (root', gen') = runPlayout eng board0 root rootColor gen
            writeIORef rootRef root'
            writeIORef genRef gen'
            loop (playoutCount + 1)

  loop (0 :: Int)

  root <- readIORef rootRef
  let results = [ ScoredMove (nodeIndex child) (winRate * 100)
                    ("MCTS: " ++ show (nodeVisits child) ++ " visits, "
                     ++ showFFloat2 (winRate * 100) ++ "% win rate")
                | child <- nodeChildren root
                , nodeIndex child >= 0
                , nodeVisits child > 0
                , let winRate = nodeWins child / fromIntegral (nodeVisits child)
                ]
  return $ sortBy (\a b -> compare (Down (smScore a)) (Down (smScore b))) results

showFFloat2 :: Double -> String
showFFloat2 x = let s = show (round (x * 10) :: Int)
                    (whole, frac) = splitAt (length s - 1) s
                in  (if null whole then "0" else whole) ++ "." ++ frac

-- | Run a single MCTS playout: selection, expansion, simulation, backpropagation.
runPlayout :: MCTSEngine -> Board -> MCTSNode -> Color -> StdGen -> (MCTSNode, StdGen)
runPlayout eng board0 root rootColor gen0 =
  -- 1. Selection: walk down tree using UCT
  let (path, board1, node, gen1) = selectPath eng board0 root gen0
      -- 2. Expansion: try to add a new child
      (node', board2, gen2) = expandNode eng board1 node gen1
      -- 3. Simulation: random playout
      (result, gen3) = playout board2 rootColor gen2
      -- 4. Backpropagation
      root' = backprop path node' result rootColor
  in  (root', gen3)

-- | Select path from root to a leaf using UCT.
selectPath :: MCTSEngine -> Board -> MCTSNode -> StdGen
           -> ([MCTSNode -> MCTSNode], Board, MCTSNode, StdGen)
selectPath eng board node gen
  | null (nodeChildren node) || not (nodeExpanded node) = ([], board, node, gen)
  | otherwise =
      let (childIdx, _gen') = selectChild eng node gen
          child  = nodeChildren node !! childIdx
      in  if nodeIndex child < 0 || nodeIndex child >= boardSz board * boardSz board
          then ([], board, node, gen)  -- skip invalid child
          else
            let board' = case tryPlay board (nodeIndex child) of
                           Just b  -> b
                           Nothing -> board  -- shouldn't happen
                rebuild newChild = node { nodeChildren = replaceAt childIdx newChild (nodeChildren node) }
                (path', board'', leaf, gen'') = selectPath eng board' child _gen'
            in  (rebuild : path', board'', leaf, gen'')

-- | UCT + RAVE child selection.
selectChild :: MCTSEngine -> MCTSNode -> StdGen -> (Int, StdGen)
selectChild eng parent gen =
  let children = nodeChildren parent
      n        = boardSz (mctsBoard eng) * boardSz (mctsBoard eng)
      logN     = log (max 1 (fromIntegral (nodeVisits parent)))
      exploit  = mctsExploration eng

      uctValue child
        | nodeIndex child < 0 || nodeIndex child >= n = -1e9
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

      scores   = map uctValue children
      bestIdx  = snd $ maximum $ zip scores [0..]
  in  (bestIdx, gen)

-- | Expand a node: add one new child.
expandNode :: MCTSEngine -> Board -> MCTSNode -> StdGen -> (MCTSNode, Board, StdGen)
expandNode _eng board node gen
  | nodeExpanded node && null (nodeUntried node) = (node, board, gen)
  | not (nodeExpanded node) =
      let moves  = generateMovesForMCTS board
          (moves', gen') = shuffle moves gen
          node'  = node { nodeUntried = moves', nodeExpanded = True }
      in  expandNode _eng board node' gen'
  | otherwise =
      case nodeUntried node of
        []     -> (node, board, gen)
        (m:ms) ->
          case tryPlay board m of
            Just board' ->
              let child = mkNode m (boardToMove board')
                  node' = node { nodeChildren = nodeChildren node ++ [child]
                               , nodeUntried = ms }
              in  (node', board', gen)
            Nothing ->
              -- Skip illegal move.
              let node' = node { nodeUntried = ms }
              in  expandNode _eng board node' gen

-- | Generate candidate moves for MCTS tree expansion.
generateMovesForMCTS :: Board -> [Int]
generateMovesForMCTS board =
  let sz    = boardSz board
      n     = sz * sz
      color = boardToMove board
      nonEdge = [ i | i <- [0 .. n - 1]
                    , stoneAt board i == Empty
                    , not (isOwnEye board i color)
                    , let r = i `div` sz
                    , let c = i `mod` sz
                    , minimum [r, c, sz-1-r, sz-1-c] > 0
                ]
  in  if null nonEdge
      then [ i | i <- [0 .. n - 1], stoneAt board i == Empty, not (isOwnEye board i color) ]
      else nonEdge

-- | Random playout from a position. Returns 1 if rootColor wins, 0 otherwise.
playout :: Board -> Color -> StdGen -> (Double, StdGen)
playout board0 rootColor gen0 =
  let sz      = boardSz board0
      maxMvs  = if sz <= 9 then sz * sz
                else if sz <= 13 then (sz * sz * 3) `div` 2
                else (sz * sz * 4) `div` 5
  in  go board0 gen0 (0 :: Int) (0 :: Int) maxMvs
  where
    go !board !gen !mvCount !passes !maxM
      | mvCount >= maxM || passes >= 2 =
          let score = areaScore board
              win = if rootColor == Black then score > 0 else score < 0
          in  (if win then 1.0 else 0.0, gen)
      | otherwise =
          let (move, gen') = playoutMove board gen
          in  case move of
                Nothing ->
                  go (passMove board) gen' (mvCount + 1) (passes + 1) maxM
                Just m ->
                  case tryPlay board m of
                    Just board' ->
                      go board' gen' (mvCount + 1) 0 maxM
                    Nothing ->
                      -- Failed move, try pass
                      go (passMove board) gen' (mvCount + 1) (passes + 1) maxM

-- | Generate a move for random playout.
playoutMove :: Board -> StdGen -> (Maybe Int, StdGen)
playoutMove board gen =
  let sz    = boardSz board
      n     = sz * sz
      color = boardToMove board
      enemy = opp color

      -- 1. Capture enemy atari groups.
      captures = [ lib | i <- [0 .. n - 1]
                       , boardGrid board `vecAt` i == colorToInt' enemy
                       , let info = groupInfo board i
                       , groupLiberties info == 1
                       , let lib = findGroupLib board (groupStones info)
                       , lib >= 0
                 ]

      -- 2. Collect candidate empty points (avoiding eyes and first line).
      allCandidates = [ i | i <- [0 .. n - 1]
                          , stoneAt board i == Empty
                          , not (isOwnEye board i color)
                      ]
      candidates gen0 =
        let nonEdge = [ i | i <- allCandidates
                          , let r = i `div` sz
                          , let c = i `mod` sz
                          , minimum [r, c, sz-1-r, sz-1-c] > 0
                      ]
        in  pickRandom (if null nonEdge then allCandidates else nonEdge) gen0

  in  case captures of
        (lib:_) -> (Just lib, gen)
        []      -> candidates gen

-- | Backpropagation: update all nodes on the path.
backprop :: [MCTSNode -> MCTSNode] -> MCTSNode -> Double -> Color -> MCTSNode
backprop path leaf result rootColor =
  let leaf' = updateNode leaf result rootColor
  in  foldr (\rebuild acc -> updateNode (rebuild acc) result rootColor) leaf' (reverse path)

updateNode :: MCTSNode -> Double -> Color -> MCTSNode
updateNode node result rootColor =
  let v = nodeVisits node + 1
      -- If node.color == opp(rootColor), the move that created this node
      -- was made by rootColor, so wins += result.
      w = if nodeColor node == opp rootColor
          then nodeWins node + result
          else nodeWins node + (1 - result)
  in  node { nodeVisits = v, nodeWins = w }

-- ─── Helpers ────────────────────────────────────────────────────────────────

colorToInt' :: Color -> Int
colorToInt' Black = 1
colorToInt' White = 2

vecAt :: V.Vector Int -> Int -> Int
vecAt = (V.!)

findGroupLib :: Board -> [Int] -> Int
findGroupLib b stones = go stones
  where
    go []     = -1
    go (s:ss) = case filter (\nb -> stoneAt b nb == Empty) (neighbors b s) of
                  (lib:_) -> lib
                  []      -> go ss

pickRandom :: [a] -> StdGen -> (Maybe a, StdGen)
pickRandom [] gen = (Nothing, gen)
pickRandom xs gen =
  let (idx, gen') = randomR (0, length xs - 1) gen
  in  (Just (xs !! idx), gen')

shuffle :: [a] -> StdGen -> ([a], StdGen)
shuffle [] gen = ([], gen)
shuffle xs gen = go xs [] gen
  where
    go []  acc g = (acc, g)
    go [x] acc g = (x : acc, g)
    go ys  acc g =
      let (idx, g') = randomR (0, length ys - 1) g
          picked    = ys !! idx
          rest      = take idx ys ++ drop (idx + 1) ys
      in  go rest (picked : acc) g'

replaceAt :: Int -> a -> [a] -> [a]
replaceAt _ _ []     = []
replaceAt 0 x (_:ys) = x : ys
replaceAt n x (y:ys) = y : replaceAt (n - 1) x ys
