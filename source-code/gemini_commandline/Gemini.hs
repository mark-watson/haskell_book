-- Common types for Gemini API client (shared between Main and tests)
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE OverloadedStrings #-}

module Gemini
  ( RequestPart(..)
  , RequestContent(..)
  , GenerationConfig(..)
  , GeminiApiRequest(..)
  , ResponsePart(..)
  , ResponseContent(..)
  , Candidate(..)
  , SafetyRating(..)
  , PromptFeedback(..)
  , GeminiApiResponse(..)
  ) where

import Data.Aeson (FromJSON, ToJSON(..), (.=), object)
import GHC.Generics (Generic)
import Data.Text (Text)

data RequestPart = RequestPart
  { reqText :: Text
  } deriving (Show, Eq, Generic)

instance ToJSON RequestPart where
  toJSON (RequestPart t) = object ["text" .= t]

data RequestContent = RequestContent
  { reqParts :: [RequestPart]
  } deriving (Show, Eq, Generic)

instance ToJSON RequestContent where
  toJSON (RequestContent p) = object ["parts" .= p]

data GenerationConfig = GenerationConfig
  { temperature     :: Double
  , maxOutputTokens :: Int
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

data GeminiApiRequest = GeminiApiRequest
  { contents         :: [RequestContent]
  , generationConfig :: GenerationConfig
  } deriving (Show, Eq, Generic, ToJSON)

data ResponsePart = ResponsePart
  { text :: String
  } deriving (Show, Eq, Generic, FromJSON)

data ResponseContent = ResponseContent
  { parts :: [ResponsePart]
  } deriving (Show, Eq, Generic, FromJSON)

data Candidate = Candidate
  { content :: ResponseContent
  } deriving (Show, Eq, Generic, FromJSON)

data SafetyRating = SafetyRating
  { category    :: String
  , probability :: String
  } deriving (Show, Eq, Generic, FromJSON)

data PromptFeedback = PromptFeedback
  { blockReason   :: Maybe String
  , safetyRatings :: Maybe [SafetyRating]
  } deriving (Show, Eq, Generic, FromJSON)

data GeminiApiResponse = GeminiApiResponse
  { candidates     :: [Candidate]
  , promptFeedback :: Maybe PromptFeedback
  } deriving (Show, Eq, Generic, FromJSON)
