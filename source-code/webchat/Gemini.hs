{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE OverloadedStrings #-}

module Gemini
  ( GeminiRequest(..)
  , GeminiResponse(..)
  , Candidate(..)
  , Content2(..)
  , Part(..)
  , PromptFeedback(..)
  , SafetyRating(..)
  ) where

import Data.Aeson (FromJSON, ToJSON)
import GHC.Generics (Generic)

data GeminiRequest = GeminiRequest
  { prompt :: String
  } deriving (Show, Eq, Generic, FromJSON, ToJSON)

data GeminiResponse = GeminiResponse
  { candidates :: [Candidate]
  , promptFeedback :: Maybe PromptFeedback
  } deriving (Show, Eq, Generic, FromJSON, ToJSON)

data Candidate = Candidate
  { content :: Content2
  , finishReason :: Maybe String
  , index :: Maybe Int
  } deriving (Show, Eq, Generic, FromJSON, ToJSON)

data Content2 = Content2
  { parts :: [Part]
  , role :: Maybe String
  } deriving (Show, Eq, Generic, FromJSON, ToJSON)

data Part = Part
  { text :: String
  } deriving (Show, Eq, Generic, FromJSON, ToJSON)

data PromptFeedback = PromptFeedback
  { blockReason :: Maybe String
  , safetyRatings :: Maybe [SafetyRating]
  } deriving (Show, Eq, Generic, FromJSON, ToJSON)

data SafetyRating = SafetyRating
  { category :: String
  , probability :: String
  } deriving (Show, Eq, Generic, FromJSON, ToJSON)
