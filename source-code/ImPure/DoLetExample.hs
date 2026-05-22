module Main where

import Text.Read (readMaybe)

-- | Safely read an Int from stdin, re-prompting on invalid input.
readInt :: IO Int
readInt = do
  putStrLn "Enter an integer number:"
  s <- getLine
  case readMaybe s :: Maybe Int of
    Nothing -> do
      putStrLn "Error: invalid integer, please try again."
      readInt
    Just n  -> return n

-- Prompts for an Int, binds with `let` inside a do-block, and prints the value plus 2.
example1 :: IO ()
example1 = do  -- good style
  number <- readInt
  let result = number + 2
  putStrLn $ "Number plus 2 = " ++ (show result)

-- Shows `let ... in` inside a do-block (discouraged); the binding only scopes the next expression.
example2 :: IO ()
example2 = do  -- avoid using "in" inside a do statement
  number <- readInt
  let result = number + 2 in
    putStrLn $ "Number plus 2 = " ++ (show result)

-- Uses a nested do with `let ... in`; still better to use `let` without `in` for multi-statement blocks.
example3 :: IO ()
example3 = do  -- avoid using "in" inside a do statement
  number <- readInt
  let result = number + 2 in
    do
      putStrLn "Result is:"
      putStrLn $ "Number plus 2 = " ++ (show result)

main :: IO ()
main = do
  example1
  example2
  example3