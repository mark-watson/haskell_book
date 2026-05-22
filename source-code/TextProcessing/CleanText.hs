--  {-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.List.Split (splitOn)
import Data.List (intercalate)
import Data.Char as C
import Data.List.Utils (replace)

noiseCharacters :: [Char]
noiseCharacters = ['[', ']', '{', '}', '\n', '\t', '&', '^', 
                   '@', '%', '$', '#']

substituteNoiseCharacters :: [Char] -> [Char]
substituteNoiseCharacters =
  map (\x -> if elem x noiseCharacters then ' ' else x)

cleanText :: String -> String
cleanText s = 
  intercalate
   " " $
   filter
     (\x -> length x > 0) $
     splitOn " " $ substituteNoiseCharacters $
       (replace "." " . "
        (replace "," " , " 
         (replace ";" " ; " s)))

stopWords :: [String]
stopWords = ["a", "the", "that", "of", "an", "and"]

toLower' :: String -> String
toLower' = map C.toLower

removeStopWords :: String -> [Char]
removeStopWords s =
  intercalate
     " " $
    filter
      (\x -> notElem (toLower' x) stopWords) $
      words s

main :: IO ()
main = do
  let ct = cleanText "The[]@] cat, and all the dogs, escaped&^. They were caught."
  print ct
  let nn = removeStopWords ct
  print nn
