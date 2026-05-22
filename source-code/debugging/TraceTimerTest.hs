-- | Demonstration of Debug.Trace for debugging Haskell programs.
--
-- Note: trace output order depends on lazy evaluation demand, not textual
-- code order. Trace messages appear on stderr when the traced expression is
-- actually evaluated, which may differ from the order they appear in source.
-- This makes trace useful for understanding evaluation order, but unreliable
-- for logging in the traditional sense.
module Main where

import Debug.Trace  (trace, traceShow) -- for debugging only!

anyCalculationWillDo :: Int -> [Int]
anyCalculationWillDo n =
  trace
      ("+++ anyCalculationWillDo: " ++ show n) $
      anyCalculationWillDo' n

anyCalculationWillDo' :: Int -> [Int]
anyCalculationWillDo' n =
  take n $ trace ("   -- sieve n:" ++ (show n)) $ sieve [2..]
            where
              sieve (x:xs) =
                  traceShow ("     -- inside sieve recursion") $
                            x:sieve [y | y <- xs, rem y x > 0]

main :: IO ()
main = do
  print $ anyCalculationWillDo 5
