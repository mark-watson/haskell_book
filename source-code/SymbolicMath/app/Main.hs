module Main where

import qualified SymbolicMath.Types           as T
import qualified SymbolicMath.Differentiation as D
import qualified SymbolicMath.Integration     as I

main :: IO ()
main = do
  T.runSmokeTest
  D.runSmokeTest
  I.runSmokeTest
