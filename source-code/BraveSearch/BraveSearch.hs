{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
-- Module: BraveSearch
-- Minimal client for the Brave Search API; exposes `getSearchSuggestions`.
-- Uses OverloadedStrings for convenient Text literals and RecordWildCards for concise pattern binding.

module BraveSearch
  ( getSearchSuggestions
  , SearchResponse(..)
  , QueryInfo(..)
  , WebResults(..)
  , WebResult(..)
  ) where

import Network.HTTP.Simple -- HTTP request/response helpers (parseRequest, setRequestHeader, httpLBS)
import Data.Text.Encoding (encodeUtf8) -- convert Text -> ByteString for query params
import Data.Aeson -- FromJSON and decoding (eitherDecode, (.:), (.:?))
import qualified Data.Text as T -- strict Text type
import Control.Exception (try) -- catch exceptions and return Either
import Network.HTTP.Client (HttpException) -- HTTP error type
import qualified Data.ByteString.Char8 as BS -- UTF-8 ByteString for headers


-- | Top-level response from the Brave Search API, containing the
-- original query information and web search results.
data SearchResponse = SearchResponse
  { query :: QueryInfo
  , web :: WebResults
  } deriving (Show, Eq)

-- | Metadata about the original query as echoed back by the API.
data QueryInfo = QueryInfo
  { original :: T.Text
  } deriving (Show, Eq)

-- | Container wrapping the list of individual web results returned by the API.
data WebResults = WebResults
  { results :: [WebResult]
  } deriving (Show, Eq)

-- | A single web search result. Several fields are optional ('Maybe')
-- because the API may omit them depending on the result type.
data WebResult = WebResult
  { type_ :: T.Text
  , index :: Maybe Int
  , all :: Maybe Bool
  , title :: Maybe T.Text
  , url :: Maybe T.Text
  , description :: Maybe T.Text
  } deriving (Show, Eq)

-- JSON decoders mapping API fields to our Haskell types
instance FromJSON SearchResponse where
  parseJSON = withObject "SearchResponse" $ \v -> SearchResponse
    <$> v .: "query"
    <*> v .: "web"

instance FromJSON QueryInfo where
  parseJSON = withObject "QueryInfo" $ \v -> QueryInfo
    <$> v .: "original"

instance FromJSON WebResults where
  parseJSON = withObject "WebResults" $ \v -> WebResults
    <$> v .: "results"

-- Use (.:) for required fields and (.:?) for optional ones
instance FromJSON WebResult where
  parseJSON = withObject "WebResult" $ \v -> WebResult
    <$> v .: "type"
    <*> v .:? "index"
    <*> v .:? "all"
    <*> v .:? "title"
    <*> v .:? "url"
    <*> v .:? "description"

-- | Perform a Brave Search with the given API key (as raw bytes) and text query.
getSearchSuggestions :: BS.ByteString -> T.Text -> IO (Either T.Text [T.Text])
getSearchSuggestions apiKey query = do
  -- Build base request
  let baseUrl = "https://api.search.brave.com/res/v1/web/search"
  request0 <- parseRequest baseUrl
  -- Add query parameters (URL-encoded) and headers
  let request1 = setRequestQueryString
                   [ ("q", Just $ encodeUtf8 query)
                   , ("country", Just "US")
                   , ("count", Just "5")
                   ]
                   request0
      request  = setRequestHeader "Accept" ["application/json"]
               $ setRequestHeader "X-Subscription-Token" [apiKey]
               $ request1

  -- Run the request and catch exceptions as Either
  result <- try $ httpLBS request

  -- Unwrap the result and handle errors (network, non-200 status, JSON)
  case result of
    Left e -> return . Left $ T.pack $ "Network error: " ++ show (e :: HttpException)
    Right response ->
      let status = getResponseStatusCode response
      in if status /= 200
           then return . Left $ T.pack $ "HTTP error: " ++ show status
           else case eitherDecode (getResponseBody response) of
                  Left err -> return . Left $ T.pack $ "JSON parsing error: " ++ err
                  Right SearchResponse{..} ->
                    let originalQuery = original query
                        webResults    = results web
                        suggestions   = ("Original Query: " <> originalQuery)
                                      : map formatResult webResults
                    in return $ Right suggestions

-- Format a single WebResult into a readable line
formatResult :: WebResult -> T.Text
formatResult WebResult{..} =
  let titleText = maybe "N/A" ("Title: " <>) title
      urlText = maybe "N/A" ("URL: " <>) url
      descText = maybe "N/A" ("Description: " <>) (fmap (T.take 100) description) -- truncate description
  in T.intercalate " | " [titleText, urlText, descText]
