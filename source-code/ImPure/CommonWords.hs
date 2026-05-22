module Main where

import Data.Set (Set, fromList, toList, intersection)
import Data.Char (toLower)

-- Reads a file, lowercases its contents, splits on whitespace, and returns a Set of unique words.
fileToWords :: FilePath -> IO (Set String)
fileToWords fileName = do
  fileText <- readFile fileName
  return $ (fromList . words) (map toLower fileText)
  
-- | Style 1: do-notation. The most readable form; each step is explicit.
-- Reads both files and returns the list of words they share (set intersection).
commonWords :: FilePath -> FilePath -> IO [String]
commonWords file1 file2 = do  
  words1 <- fileToWords file1
  words2 <- fileToWords file2
  return $  toList $ intersection words1 words2

-- | Style 2: explicit monadic bind (>>=) with lambdas.
-- Equivalent to do-notation above, but shows the underlying >>= plumbing.
-- Same as `commonWords` but uses explicit monadic bind (>>=) with lambdas.
commonWords2 :: FilePath -> FilePath -> IO [String]
commonWords2 file1 file2 =
  fileToWords file1 >>= \f1 ->
  fileToWords file2 >>= \f2 ->
  return $  toList $ intersection f1 f2
                                                            
-- | Style 3: applicative style with (<$>) and (<*>).
-- Most concise; combines the two IO actions without naming intermediates.
-- Same result using applicative style with (<$>) and (<*>).
commonWords3 :: FilePath -> FilePath -> IO [String]
commonWords3 file1 file2 =
  (\f1 f2 -> toList $ intersection f1 f2)
    <$> fileToWords file1
    <*> fileToWords file2
    
main :: IO ()
main = do
  cw <- commonWords "text1.txt" "text2.txt"
  print cw
  cw2 <- commonWords2 "text1.txt" "text2.txt"
  print cw2
  cw3 <- commonWords3 "text1.txt" "text2.txt"
  print cw3
  
