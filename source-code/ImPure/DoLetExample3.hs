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

example3 :: IO String
example3 =  putStrLn "Enter an integer number:" >>  getLine

example4 :: String -> IO ()
example4 mv =
  case readMaybe mv :: Maybe Int of
    Nothing -> putStrLn "Error: invalid integer."
    Just n  -> do
      let number = n + 2
      putStrLn $ "Number plus 2 = " ++ (show number)

main :: IO ()
main = example3 >>= example4
