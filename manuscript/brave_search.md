# Using the Brave Search API

You need to sign up for a free or paid for account on the [Brave search page](https://brave.com/search/api/) and set an environment variable to your assigned API key:

```{line-numbers: false}
export BRAVE_SEARCH_API_KEY = BSAgQ-Nc5.....
```

The Brave Search API allows you to access Brave Search results directly within your applications or services. It provides developers with the ability to harness the privacy-focused and independent search capabilities of Brave, returning results for web searches, news, videos, and more. To obtain an API key, simply create an account on the Brave Search API website and subscribe to either the Free or one of the paid plans. The Brave Search API offers flexible pricing tiers, including a free option for testing and development, making it accessible to a wide range of users and projects. Currently you can call the API 2000 times a month on the free tier.

The library developed in this chapter is implemented in a single file **BraveSearch.hs**:

```haskell
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module BraveSearch
  ( getSearchSuggestions
  ) where

import Network.HTTP.Simple
import Data.Aeson
import qualified Data.Text as T
import Control.Exception (try)
import Network.HTTP.Client (HttpException)
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as LBS

data SearchResponse = SearchResponse
  { query :: QueryInfo
  , web :: WebResults
  } deriving (Show)

data QueryInfo = QueryInfo
  { original :: T.Text
  } deriving (Show)

data WebResults = WebResults
  { results :: [WebResult]
  } deriving (Show)

data WebResult = WebResult
  { type_ :: T.Text
  , index :: Maybe Int
  , all :: Maybe Bool
  , title :: Maybe T.Text
  , url :: Maybe T.Text
  , description :: Maybe T.Text
  } deriving (Show)

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

instance FromJSON WebResult where
  parseJSON = withObject "WebResult" $ \v -> WebResult
    <$> v .: "type"
    <*> v .:? "index"
    <*> v .:? "all"
    <*> v .:? "title"
    <*> v .:? "url"
    <*> v .:? "description"

getSearchSuggestions :: String -> String -> IO (Either String [T.Text])
getSearchSuggestions apiKey query = do
  let url = "https://api.search.brave.com/res/v1/web/search?q=" ++
            query ++ "&country=US&count=5"
  
  request <- parseRequest url
  let requestWithHeaders = setRequestHeader "Accept" ["application/json"]
                         $ setRequestHeader "X-Subscription-Token" [BS.pack apiKey]
                         $ request
  
  result <- try $ httpLBS requestWithHeaders
  
  case result of
    Left e -> return $ Left $ "Network error: " ++ show (e :: HttpException)
    Right response -> do
      let statusCode = getResponseStatusCode response
      if statusCode /= 200
        then return $ Left $ "HTTP error: " ++ show statusCode
        else do
          let body = getResponseBody response
          case eitherDecode body of
            Left err -> return $ Left $ "JSON parsing error: " ++ err
            Right searchResponse@SearchResponse{..} -> do
              let originalQuery = original query
                  webResults = results web
              let suggestions = "Original Query: " <>
                  originalQuery : map formatResult webResults
              return $ Right suggestions

formatResult :: WebResult -> T.Text
formatResult WebResult{..} =
  let titleText = maybe "N/A" ("Title: " <>) title
      urlText = maybe "N/A" ("URL: " <>) url
      descText = maybe "N/A" ("Description: " <>) (fmap (T.take 100) description)
  in T.intercalate " | " [titleText, urlText, descText]
```

### Haskell Code Description for Brave Search Suggestions

This Haskell code implements a function, `getSearchSuggestions`, that fetches search suggestions from the Brave Search API.

#### Functionality:

* **`getSearchSuggestions`:** 
    * Takes an API key and a search query as input.
    * Constructs a URL to send a request to the Brave Search API, specifying the query, country, and result count.
    * Sets up the HTTP request with necessary headers, including the API key.
    * Makes the request and handles potential network errors.
    * Checks the response status code. If it's 200 (OK), proceeds to parse the JSON response.
    * Extracts search results and formats them, including the original query.
    * Returns either an error message (if something went wrong) or a list of formatted search suggestions.

#### Key Features:

* **Data Types:**
    * Defines data types to model the JSON structure of the Brave Search API response, including `SearchResponse`, `QueryInfo`, `WebResults`, and `WebResult`.
* **JSON Parsing:**
    * Uses the `aeson` library to parse the JSON response into the defined data types.
* **Error Handling:**
    * Employs `try` from the `Control.Exception` module to gracefully handle potential network errors during the HTTP request.
* **HTTP Request:**
    * Utilizes the `Network.HTTP.Simple` library to make the HTTP request to the Brave Search API.
* **Formatting:**
    * The `formatResult` function formats each search result into a user-friendly string, including the title, URL, and a shortened description.

#### Libraries Used:

* `Network.HTTP.Simple` - For making HTTP requests.
* `Data.Aeson` - For JSON parsing and encoding.
* `Data.Text` - For efficient text handling.
* `Control.Exception` - For error handling.
* `Network.HTTP.Client` - For additional HTTP functionalities.
* `Data.ByteString.Char8` and `Data.ByteString.Lazy.Char8` - For working with byte strings.

#### Language Extensions:

* `OverloadedStrings` - Allows the use of string literals as `Text` values.
* `RecordWildCards` - Enables convenient access to record fields using wildcards.

#### Overall:

This code provides a basic but functional way to interact with the Brave Search API to retrieve and format search suggestions. It demonstrates good practices in Haskell programming, including data modeling, error handling, and the use of relevant libraries.


Here is an example **Main.hs** file to use this library:

```haskell
{-# LANGUAGE OverloadedStrings #-}

module Main where

import BraveSearch (getSearchSuggestions)
import System.Environment (getEnv)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO

main :: IO ()
main = do
  -- Get the API key from the environment variable
  apiKey <- getEnv "BRAVE_SEARCH_API_KEY"
  
  -- Prompt the user for a search query
  TIO.putStrLn "Enter a search query:"
  query <- TIO.getLine
  
  -- Call the function to get search suggestions
  result <- getSearchSuggestions apiKey (T.unpack query)
  
  case result of
    Left err -> TIO.putStrLn $ "Error: " <> T.pack err
    Right suggestions -> do
      TIO.putStrLn "Search suggestions:"
      mapM_ (TIO.putStrLn . ("- " <>)) suggestions
```


**Test Code Explanation**

The code interacts with the `BraveSearch` module to demonstrate how to fetch and display search suggestions from the Brave Search API.

**Code Breakdown**

1. **Imports**

   - It imports:
     - `BraveSearch` to use the `getSearchSuggestions` function.
     - `System.Environment` to get the API key from an environment variable.
     - `Data.Text` and `Data.Text.IO` for working with text input and output.

2. **`main` Function**

   1. **Get API Key**
      - It uses `getEnv "BRAVE_SEARCH_API_KEY"` to retrieve the Brave Search API key from an environment variable named `BRAVE_SEARCH_API_KEY`. This assumes you have set this environment variable in your system before running the code.

   2. **Prompt for Query**
      - It prints the message "Enter a search query:" to the console, prompting the user to input a search term.
      - It reads the user's input using `TIO.getLine` and stores it in the `query` variable.

   3. **Fetch Search Suggestions**
      - It calls the `getSearchSuggestions` function from the `BraveSearch` module, passing the API key and the user's query (converted from `Text` to `String` using `T.unpack`).
      - It stores the result of this call in the `result` variable.

   4. **Handle Result**
      - It uses a `case` expression to handle the two possible outcomes of the `getSearchSuggestions` call:

        - `Left err`: 
           - If there was an error (e.g., network issue, HTTP error, JSON parsing error), it prints the error message prefixed with "Error: ".

        - `Right suggestions`:
           - If the call was successful and returned a list of search suggestions:
             - Prints "Search suggestions:" to the console.
             - Uses `mapM_` to iterate over the `suggestions` list and print each suggestion in the following format:  `- suggestion text` 


This test code provides a basic example of how to use the `getSearchSuggestions` function from the `BraveSearch` module. 

Here is the output:

```{line-numbers: false}
$ cabal run     
Enter a search query:
find a consultant for AI and common lisp, and the semantic web
Search suggestions:
- Original Query: find a consultant for AI and common lisp, and the semantic web
- Title: Mark Watson: AI Practitioner and Lisp Hacker | URL: https://markwatson.com/ | Description: I am the author of 20+ books on Artificial Intelligence, <strong>Common</strong> <strong>Lisp</stron
- Title: Lisp (programming language) - Wikipedia | URL: https://en.wikipedia.org/wiki/Lisp_(programming_language) | Description: Scheme is a statically scoped and properly tail-recursive dialect of <strong>the</strong> <strong>Li
- Title: The Lisp approach to AI (Part 1). If you are a programmer that reads… | by Sebastian Valencia | AI Society | Medium | URL: https://medium.com/ai-society/the-lisp-approach-to-ai-part-1-a48c7385a913 | Description: If you are a programmer that reads about the history and random facts of this lovely craft
```