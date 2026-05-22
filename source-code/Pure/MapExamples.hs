module MapExamples where

import qualified Data.Map as M -- from library containers
import Data.Maybe (fromMaybe)


aTestMap :: M.Map String Int
aTestMap = M.fromList [("height", 120), ("weight", 15)]

getNumericValue :: Ord k => k -> M.Map k Int -> Int
getNumericValue key aMap = fromMaybe (-1) (M.lookup key aMap)

main :: IO ()
main = do
  print $ getNumericValue "height" aTestMap
  print $ getNumericValue "age" aTestMap

