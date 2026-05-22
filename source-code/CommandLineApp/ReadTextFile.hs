module Main where
  
import System.IO
import Control.Monad
import System.Directory (doesFileExist)

main :: IO ()
main = do
  let filePath = "temp.txt"
  exists <- doesFileExist filePath
  if exists
    then do
      entireFileAsString <- readFile filePath
      print entireFileAsString
      let allWords = words entireFileAsString
      print allWords
    else
      putStrLn $ "Error: file '" ++ filePath ++ "' does not exist."