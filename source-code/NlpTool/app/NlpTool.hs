module Main where

-- Copyright 2014 by Mark Watson. All rights reserved.
-- The software and data in this project can be used under the terms of the GPL version 3 license or APache 2 license.

-- experiments with creating a command line tool for categorization and entity detection

import System.IO
import Text.JSON (showJSON, encode)

import NlpUtils

import Categorize
import Entities
import Summarize

main = do
  putStrLn "Enter text (or \"exit\"/\"quit\" to stop):"
  s <- getLine
  if s `elem` ["exit", "quit"]
    then putStrLn "Goodbye."
    else do
      let cats = bestCategories (splitWords s);
          bestCat = if not (null cats) then fst (head cats) else "";
          summaryText = summarizeS s;
          spwkc = splitWordsKeepCase s;
          people = encode $ showJSON $ peopleNames spwkc;
          countries = encode $ showJSON $ countryNames spwkc;
          companies = encode $ showJSON $ companyNames spwkc;
          result = encode $ showJSON [bestCat, summaryText];
          result2 = encode $ showJSON [people, countries, companies] in
        do
          putStr "category:\t"
          putStrLn bestCat
          putStr "summary:\t"
          putStrLn summaryText
          putStr "people:\t"
          putStrLn people
          putStr "companies:\t"
          putStrLn companies
          putStr "countries:\t"
          putStrLn countries
      main
