{-# LANGUAGE OverloadedStrings #-}
-- Allows string literals like "foo" to be used as `Text`
module Main where

import BraveSearch (getSearchSuggestions)
import qualified Data.ByteString.Char8 as BS
import System.Environment (lookupEnv)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO

-- Entry point: runs an interactive search
main :: IO ()
main = do
  -- Read API key from environment; fail with a descriptive message if unset
  maybeKey <- lookupEnv "BRAVE_SEARCH_API_KEY"
  case maybeKey of
    Nothing -> TIO.putStrLn "Error: BRAVE_SEARCH_API_KEY environment variable is not set. Please set it to your Brave Search API key."
    Just apiKeyRaw -> do
      let apiKey = BS.pack apiKeyRaw

      -- Prompt the user for a search query
      TIO.putStrLn "Enter a search query:"
      query <- TIO.getLine

      -- Call the function to get search suggestions
      result <- getSearchSuggestions apiKey query

      -- Handle `Either`: Left is an error, Right is a list of suggestion lines
      case result of
        Left err -> TIO.putStrLn $ "Error: " <> err
        Right suggestions -> do
          TIO.putStrLn "Search suggestions:"
          mapM_ (TIO.putStrLn . ("- " <>)) suggestions -- print each suggestion
