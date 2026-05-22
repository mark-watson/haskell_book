module Main where

import Control.Monad.State

-- | Increment state using do-notation.
-- 'get' retrieves the current state value.
-- 'put' replaces the state with a new value.
-- Returns the old state value before incrementing.
incrementState :: State Int Int
incrementState = do
  n <- get
  put (n + 1)
  return n

-- | Same state monad without using a 'do' expression.
-- Uses (>>=) to chain 'get' and (>>) to chain 'put' (since put returns ()
-- and its result is unused, >> is correct here instead of >>=).
incrementState2 :: State Int Int
incrementState2 = get >>= \a ->
                  put (a + 1) >>
                  return a

-- | Transform both the return value and the state.
bumpVals :: (Int, Int) -> (Int, Int)
bumpVals (a,b) = (a+1, b+2)

-- | Demonstrates running state computations:
-- 'runState'  returns a pair (result, finalState).
-- 'evalState' returns only the result (discards final state).
-- 'execState' returns only the final state (discards result).
main :: IO ()
main = do
  print $ runState incrementState 1  -- (1,2) == (return value, final state)
  print $ runState incrementState2 1 -- (1,2) == (return value, final state)
  print $ runState (mapState bumpVals incrementState) 1 -- (2,4)
  print $ evalState incrementState 1  -- 1 == return value
  print $ execState incrementState 1  -- 2 == final state
