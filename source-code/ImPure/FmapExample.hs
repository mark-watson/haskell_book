module Main where

import System.Directory (doesFileExist)

-- Reads a file and splits on whitespace, returning the list of words.
fileToWords :: FilePath -> IO [String]
fileToWords fileName = do
  fileText <- readFile fileName
  return $ words fileText

main :: IO ()
main = do
  let fileName = "text1.txt"
  exists <- doesFileExist fileName
  if exists
    then do
      words1 <- fileToWords fileName
      print $ reverse words1
      words2 <- fmap reverse $ fileToWords fileName
      print words2
    else putStrLn $ "Error: file '" ++ fileName ++ "' not found."

