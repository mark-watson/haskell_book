-- Common types for the local LLM server (Sushi) that exposes an
-- OpenAI-compatible chat-completions API.
-- (Shared between Main.hs and any future tests.)
{-# LANGUAGE OverloadedStrings #-}

module Sushi
  ( ChatMessage(..)
  , ChatRequest(..)
  , ChatResponse(..)
  , ChatChoice(..)
  , ChatUsage(..)
  , StreamChunk(..)
  , StreamChoice(..)
  , ApiError(..)
  , defaultBaseUrl
  , defaultModel
  , chatCompletionsUrl
  ) where

import Data.Aeson ((.=), (.:), (.:?), (.!=), withObject, object)
import qualified Data.Aeson as Aeson
import qualified Data.Aeson.KeyMap as KeyMap
import Data.Text (Text, unpack)

-- | The local Sushi server. Override the base URL or model with the
-- --base-url / --model flags or the SUSHI_BASE_URL / SUSHI_MODEL env vars.
defaultBaseUrl :: String
defaultBaseUrl = "http://127.0.0.1:12345/v1"

defaultModel :: String
defaultModel = "Qwen3.8-Flash-Next-Sushi-2.6bpw"

-- | Full endpoint for chat completions. Trailing slashes in the base URL are
-- dropped, so "/v1" and "/v1/" both work.
chatCompletionsUrl :: String -> String
chatCompletionsUrl baseUrl = dropTrailingSlashes baseUrl ++ "/chat/completions"
  where
    dropTrailingSlashes = reverse . dropWhile (== '/') . reverse

-- | One chat turn. Role is "system", "user" or "assistant".
-- Used for both request messages and response message/delta objects.
data ChatMessage = ChatMessage
  { msgRole :: Text
  , msgContent :: Text
  } deriving (Show, Eq)

instance Aeson.ToJSON ChatMessage where
  toJSON m = object [ "role" .= msgRole m, "content" .= msgContent m ]

-- A missing role or content decodes as empty, because streaming delta objects
-- frequently omit them.
instance Aeson.FromJSON ChatMessage where
  parseJSON = withObject "ChatMessage" $ \v -> ChatMessage
    <$> v .:? "role" .!= ""
    <*> v .:? "content" .!= ""

-- | Request body for POST /chat/completions. Optional fields are left out
-- when 'Nothing', so the server applies its own defaults.
data ChatRequest = ChatRequest
  { reqModel :: Text
  , reqMessages :: [ChatMessage]
  , reqStream :: Bool
  , reqTemperature :: Maybe Double
  , reqMaxTokens :: Maybe Int
  } deriving (Show, Eq)

instance Aeson.ToJSON ChatRequest where
  toJSON r = object $
    [ "model" .= reqModel r
    , "messages" .= reqMessages r
    , "stream" .= reqStream r
    ]
      ++ maybe [] (\t -> ["temperature" .= t]) (reqTemperature r)
      ++ maybe [] (\n -> ["max_tokens" .= n]) (reqMaxTokens r)

-- | Non-streaming response: an array of choices plus optional token counts.
data ChatResponse = ChatResponse
  { respId :: Maybe Text
  , respModel :: Maybe Text
  , respChoices :: [ChatChoice]
  , respUsage :: Maybe ChatUsage
  } deriving (Show, Eq)

instance Aeson.FromJSON ChatResponse where
  parseJSON = withObject "ChatResponse" $ \v -> ChatResponse
    <$> v .:? "id"
    <*> v .:? "model"
    <*> v .: "choices"
    <*> v .:? "usage"

data ChatChoice = ChatChoice
  { chMessage :: ChatMessage
  , chFinishReason :: Maybe Text
  } deriving (Show, Eq)

instance Aeson.FromJSON ChatChoice where
  parseJSON = withObject "ChatChoice" $ \v -> ChatChoice
    <$> v .: "message"
    <*> v .:? "finish_reason"

-- | Token accounting, when the server reports it.
data ChatUsage = ChatUsage
  { uPromptTokens :: Maybe Int
  , uCompletionTokens :: Maybe Int
  , uTotalTokens :: Maybe Int
  } deriving (Show, Eq)

instance Aeson.FromJSON ChatUsage where
  parseJSON = withObject "ChatUsage" $ \v -> ChatUsage
    <$> v .:? "prompt_tokens"
    <*> v .:? "completion_tokens"
    <*> v .:? "total_tokens"

-- | One "data: {...}" event of a streaming response.
data StreamChunk = StreamChunk
  { scChoices :: [StreamChoice]
  } deriving (Show, Eq)

-- A final chunk may carry an empty choices array (or none at all).
instance Aeson.FromJSON StreamChunk where
  parseJSON = withObject "StreamChunk" $ \v -> StreamChunk
    <$> (v .:? "choices" .!= [])

data StreamChoice = StreamChoice
  { schDelta :: ChatMessage
  , schFinishReason :: Maybe Text
  } deriving (Show, Eq)

instance Aeson.FromJSON StreamChoice where
  parseJSON = withObject "StreamChoice" $ \v -> StreamChoice
    <$> (v .:? "delta" .!= ChatMessage "" "")
    <*> v .:? "finish_reason"

-- | Error payload from the server, e.g. an unknown model id.
-- Handles both shapes: {"error": "message"} and
-- {"error": {"message": "...", "type": "..."}}.
data ApiError = ApiError
  { errMsg :: String
  } deriving (Show, Eq)

instance Aeson.FromJSON ApiError where
  parseJSON = withObject "ApiError" $ \v -> do
    err <- maybe (fail "missing \"error\" field") return (KeyMap.lookup "error" v)
    return (ApiError (errorText err))

-- | The error text is usually a plain string, sometimes a nested object.
errorText :: Aeson.Value -> String
errorText (Aeson.String s) = unpack s
errorText obj@(Aeson.Object o) = case KeyMap.lookup "message" o of
  Just (Aeson.String s) -> unpack s
  _ -> show obj
errorText other = show other
