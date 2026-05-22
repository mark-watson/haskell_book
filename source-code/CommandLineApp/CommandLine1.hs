module Main where

import System.IO
import Data.Char (toUpper)

main :: IO ()
main = do
  putStrLn "Enter a line of text for test 1 (or \"exit\"/\"quit\" to stop):"
  s <- getLine
  if s == "exit" || s == "quit"
    then putStrLn "Goodbye!"
    else do
      putStrLn $ "As upper case:\t" ++ (map toUpper s)
      main
