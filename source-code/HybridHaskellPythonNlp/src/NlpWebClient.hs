{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveDataTypeable #-}

-- reference: http://www.serpentine.com/wreq/tutorial.html
module NlpWebClient
  ( nlpClient, NlpResponse
  ) where

import Control.Exception (SomeException, try)
import Control.Lens
import Data.ByteString.Lazy (ByteString)
import Data.ByteString.Lazy.Char8 (unpack)

import Network.URI.Encode as E -- encode is also in Data.Aeson
import Network.Wreq

import Text.JSON.Generic

type LByteString = ByteString

data NlpResponse = NlpResponse {entities::[String], tokens::[String]} deriving (Show, Data, Typeable)

base_url :: String
base_url = "http://127.0.0.1:8008?text="

nlpClient :: [Char] -> IO NlpResponse
nlpClient query = do
  putStrLn $ "\n\n***  Processing " ++ query
  result <- try (get $ base_url ++ (E.encode query) ++ "&no_detail=1") :: IO (Either SomeException (Response LByteString))
  case result of
    Left err -> do
      putStrLn $ "Error connecting to NLP server: " ++ show err
      return $ NlpResponse [] []
    Right r -> do
      let ret = (decodeJSON (unpack (r ^. responseBody))) :: NlpResponse
      return ret
