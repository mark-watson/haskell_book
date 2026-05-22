module Main where

import Data.Time.Clock.POSIX -- for getPOSIXTime
import System.TimeIt         -- for timeIt
import System.Timeout        -- for timeout

-- | Compute the first n primes using a simple sieve.
anyCalculationWillDo :: Int -> [Integer]
anyCalculationWillDo n =
  take n $ sieve [2..]
            where
              sieve (x:xs) =
                x:sieve [y | y <- xs, rem y x > 0]

-- | Note: 'timeout' works via asynchronous exceptions. The computation is
-- run in a separate thread, and if it doesn't complete within the given
-- number of microseconds, an exception is thrown to cancel it.
-- Because Haskell uses lazy evaluation, the actual computation may not
-- begin until the result is demanded (e.g., by 'print'), so the timeout
-- measures wall-clock time from the point of demand, not from binding.
main :: IO ()
main = do
  startingTime <- getPOSIXTime
  print startingTime
  print $ last $ take 20000001 [0..]
  endingTime <- getPOSIXTime
  print endingTime
  print (endingTime - startingTime)

  timeIt $ print $ last $ anyCalculationWillDo 2000
  let somePrimes = anyCalculationWillDo 3333 in
    timeIt $ print $ last somePrimes

  -- 100000 microseconds (0.1 second) timeout tests:
  res1 <- timeout 100000 $ print "simple print statement did not timeout"
  case res1 of
    Nothing -> putStrLn "Calculation timed out!"
    Just _  -> putStrLn "Calculation finished in time."

  res2 <- timeout 100000 $ print $ last $ anyCalculationWillDo 4
  case res2 of
    Nothing -> putStrLn "Calculation timed out!"
    Just _  -> putStrLn "Calculation finished in time."

  res3 <- timeout 100000 $ print $ last $ anyCalculationWillDo 40
  case res3 of
    Nothing -> putStrLn "Calculation timed out!"
    Just _  -> putStrLn "Calculation finished in time."

  res4 <- timeout 100000 $ print $ last $ anyCalculationWillDo 400
  case res4 of
    Nothing -> putStrLn "Calculation timed out!"
    Just _  -> putStrLn "Calculation finished in time."

  res5 <- timeout 100000 $ print $ last $ anyCalculationWillDo 4000
  case res5 of
    Nothing -> putStrLn "Calculation timed out!"
    Just _  -> putStrLn "Calculation finished in time."

  res6 <- timeout 100000 $ print $ last $ anyCalculationWillDo 40000
  case res6 of
    Nothing -> putStrLn "Calculation timed out!"
    Just _  -> putStrLn "Calculation finished in time."

  print $ anyCalculationWillDo 5
