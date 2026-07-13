-- Common types for the Ollama API client (shared between Main and tests)
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}

module Ollama
  ( OllamaRequest(..)
  , OllamaResponse(..)
  , OllamaError(..)
  ) where

import Data.Aeson (FromJSON, ToJSON)
import qualified Data.Aeson as Aeson
import GHC.Generics (Generic)

-- Use unique field names; aeson options map them to correct JSON keys
data OllamaRequest = OllamaRequest
  { reqModel :: String
  , reqPrompt :: String
  , reqStream :: Bool
  } deriving (Show, Eq, Generic)

instance ToJSON OllamaRequest where
  toJSON r = Aeson.object
    [ "model" Aeson..= reqModel r
    , "prompt" Aeson..= reqPrompt r
    , "stream" Aeson..= reqStream r
    ]

data OllamaResponse = OllamaResponse
  { respModel :: String
  , respCreatedAt :: String
  , respResponse :: String
  , respDone :: Bool
  , respDoneReason :: Maybe String
  } deriving (Show, Eq, Generic)

instance FromJSON OllamaResponse where
  parseJSON = Aeson.withObject "OllamaResponse" $ \v -> OllamaResponse
    <$> v Aeson..: "model"
    <*> v Aeson..: "created_at"
    <*> v Aeson..: "response"
    <*> v Aeson..: "done"
    <*> v Aeson..:? "done_reason"

data OllamaError = OllamaError
  { errMsg :: String
  } deriving (Show, Eq, Generic)

instance FromJSON OllamaError where
  parseJSON = Aeson.withObject "OllamaError" $ \v -> OllamaError
    <$> v Aeson..: "error"
