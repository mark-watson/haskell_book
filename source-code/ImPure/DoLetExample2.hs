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

example1 :: IO ()
example1 = do
  number <- readInt
  let result = number + 2
  putStrLn $ "Number plus 2 = " ++ (show result)

example2 :: IO ()
example2 = do
  number <- readInt
  let result = number + 2 in
    putStrLn $ "Number plus 2 = " ++ (show result)

main :: IO ()
main = example1 >> example2 >> example1