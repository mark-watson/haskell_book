# Using the Brave Search API

You need to sign up for a free or paid for account on the [Brave search page](https://brave.com/search/api/) and set an environment variable to your assigned API key:

<pre>
export BRAVE_SEARCH_API_KEY = BSAgQ-Nc5.....
</pre>

Library **BraveSearch.hs**:

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
  let url = "https://api.search.brave.com/res/v1/web/search?q=" ++ query ++ "&country=US&count=5"
  
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
              let suggestions = "Original Query: " <> originalQuery : map formatResult webResults
              return $ Right suggestions

formatResult :: WebResult -> T.Text
formatResult WebResult{..} =
  let titleText = maybe "N/A" ("Title: " <>) title
      urlText = maybe "N/A" ("URL: " <>) url
      descText = maybe "N/A" ("Description: " <>) (fmap (T.take 100) description)
  in T.intercalate " | " [titleText, urlText, descText]
```

The code defines a module named **BraveSearch** which provides a function **getSearchSuggestions**.  This function takes an API key and a search query as input. It then makes a request to the Brave Search API to fetch search suggestions related to the given query. Finally, it parses the API response and returns the suggestions as a list of formatted text strings.

The code imports necessary modules for HTTP requests, JSON parsing, text manipulation, exception handling, and working with ByteStrings.

Several data types are defined to represent the structure of the JSON response received from the Brave Search API:
- SearchResponse: The top-level structure of the response.
- QueryInfo: Contains information about the original search query.
- WebResults: Contains a list of web search results.
- WebResult: Represents a single web search result with its title, URL, description, etc.

The **FromJSON** instances define how to parse JSON data into the corresponding Haskell data types using the **aeson** library.

The **getSearchSuggestions** function

- Construct API URL: creates the URL for the Brave Search API request by appending the query and other parameters.
- Prepare HTTP Request: creates an HTTP request to the constructed URL. It sets the necessary headers:
-- “Accept": "application/json" to indicate that it expects a JSON response.
-- “X-Subscription-Token": apiKey to provide the API key for authentication.
- Make HTTP Request and Handle Errors: tries to make the HTTP request and handle potential network errors. If there's a network error, it returns a Left value with an error message. If the request is successful, it checks the HTTP status code. If the status code is not 200 (OK), it returns a Left value with an HTTP error message. If the status code is 200, it proceeds to parse the response body.
- Parse JSON Response: uses eitherDecode to parse the JSON response body.
-- If there's a JSON parsing error, it returns a Left value with an error message.
-- If parsing is successful, it extracts the original query and web results from the response.
- Format Results: it formats each web result using the formatResult function. It prepends the original query to the list of formatted results.
- Return Results: returns a Right value containing the list of formatted suggestions if everything is successful.Otherwise, it returns a Left value containing the error message.
- formatResult Function: this function takes a WebResult and formats it into a text string by combining its title, URL, and a shortened description (if available).

In summary this code enables you to fetch search suggestions from the Brave Search API by providing an API key and a search query. It handles network errors, HTTP errors, and JSON parsing errors gracefully. Finally, it presents the search suggestions in a user-friendly formatted text.

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

<pre>
$ cabal run     
Enter a search query:
find a consultant for AI and common lisp, and the semantic web
Search suggestions:
- Original Query: find a consultant for AI and common lisp, and the semantic web
- Title: Mark Watson: AI Practitioner and Lisp Hacker | URL: https://markwatson.com/ | Description: I am the author of 20+ books on Artificial Intelligence, <strong>Common</strong> <strong>Lisp</stron
- Title: Lisp (programming language) - Wikipedia | URL: https://en.wikipedia.org/wiki/Lisp_(programming_language) | Description: Scheme is a statically scoped and properly tail-recursive dialect of <strong>the</strong> <strong>Li
- Title: The Lisp approach to AI (Part 1). If you are a programmer that reads… | by Sebastian Valencia | AI Society | Medium | URL: https://medium.com/ai-society/the-lisp-approach-to-ai-part-1-a48c7385a913 | Description: If you are a programmer that reads about the history and random facts of this lovely craft
</pre>