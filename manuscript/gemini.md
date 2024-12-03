# Command Line Utility To Use the Google Gemini APIs

This example is similar to the example in the last chapter but here we build not a web application but a command line application to use the Google Gemini LLM APIs.

The directory **haskell_tutorial_cookbook_examples/gemini_commandline** contains the code for this example.

Before we look at the code let’s run the example:

```text{line-numbers: false}
$ gemini "what is the square of pi?"
Response:

The square of pi (π) is π multiplied by itself: π².  Since π is approximately 3.14159, π² is approximately 9.8696.
```

The executable file **gemini** is on my path because I copied the executable file to my personal bin directory:

```text{line-numbers: false}
$ cabal build
$ find . -name gemini
  ... output not shown
$ cp ./dist-newstyle/build/aarch64-osx/ghc-9.4.8/gemini-0.1.0.0/x/gemini/build/gemini/gemini ~/bin
```

If you don’t want to permanently install this example on your laptop, then just run it with cabal:

```text{line-numbers: false}
$ cabal run gemini "what is 11 + 23?"
Response:

11 + 23 = 34
```

Here is a listing of the source file **Main.hs** (explanation after the code). This code is a Haskell program that interacts with Google's Gemini AI model through its API. The program is structured to send prompts to Gemini and receive generated responses, implementing a command line interface for this interaction.

```haskell{line-numbers: false}
import Control.Monad.IO.Class (liftIO)
import System.Environment (getArgs, getEnv)
import qualified Data.Aeson as Aeson
import Data.Aeson (FromJSON, ToJSON)
import GHC.Generics
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Client (newManager, httpLbs, parseRequest, Request(..), RequestBody(..), responseBody, responseStatus)
import Network.HTTP.Types.Status (statusCode)
import qualified Data.Text as T
import Data.Text.Encoding (encodeUtf8)
import qualified Data.Vector as V

data GeminiRequest = GeminiRequest
  { prompt :: String
  } deriving (Show, Generic, ToJSON)

data GeminiResponse = GeminiResponse
  { candidates :: [Candidate]  -- Changed from choices to candidates
  } deriving (Show, Generic, FromJSON)

data Candidate = Candidate
  { content :: Content
  } deriving (Show, Generic, FromJSON)

data Content = Content
  { parts :: [Part]
  } deriving (Show, Generic, FromJSON)

data Part = Part
  { text :: String
  } deriving (Show, Generic, FromJSON, ToJSON)

data PromptFeedback = PromptFeedback
  { blockReason :: Maybe String
  , safetyRatings :: Maybe [SafetyRating]
  } deriving (Show, Generic, FromJSON, ToJSON)

data SafetyRating = SafetyRating
  { category :: String
  , probability :: String
  } deriving (Show, Generic, FromJSON, ToJSON)

main :: IO ()
main = do
  args <- getArgs
  case args of
    [] -> putStrLn "Error: Please provide a prompt as a command line argument."
    (arg:_) -> do  --  Extract the argument directly
      apiKey <- getEnv "GOOGLE_API_KEY"

      manager <- newManager tlsManagerSettings

      initialRequest <- parseRequest "https://generativelanguage.googleapis.com/v1/models/gemini-1.5-pro:generateContent"

      let geminiRequestBody = Aeson.object [
            ("contents", Aeson.Array $ V.singleton $ Aeson.object [
                ("parts", Aeson.Array $ V.singleton $ Aeson.object [
                    ("text", Aeson.String $ T.pack  arg)
                    ])
            ]),
            ("generationConfig", Aeson.object [
                ("temperature", Aeson.Number 0.1),
                ("maxOutputTokens", Aeson.Number 800)
                ])
            ]
            
      let request = initialRequest
            { requestHeaders =
                [ ("Content-Type", "application/json")
                , ("x-goog-api-key", encodeUtf8 $ T.pack apiKey)
                ]
            , method = "POST"
            , requestBody = RequestBodyLBS $ Aeson.encode geminiRequestBody
            }

      response <- httpLbs request manager
      
      let responseStatus' = responseStatus response

      if statusCode responseStatus' == 200
        then do
        let maybeGeminiResponse =
           Aeson.decode (responseBody response) :: Maybe GeminiResponse
        case maybeGeminiResponse of
          Just geminiResponse -> do
            case candidates geminiResponse of
              (candidate:_) -> do
                case parts (content candidate) of
                  (part:_) -> do  -- Changed text_ to _ since it's unused
                    liftIO $ putStrLn $ "Response:\n\n" ++ text part
                  [] -> do
                    liftIO $ putStrLn "Error: No parts in content"
              [] -> do
                liftIO $ putStrLn "Error: No candidates in response"
          Nothing -> do
             liftIO $ putStrLn "Error: Failed to parse response"
        else do
        putStrLn $ "Error: " ++ show responseStatus'
```

The first section of the code defines several data types using Haskell's deriving mechanism for automatic JSON serialization/deserialization. These types (GeminiRequest, GeminiResponse, Candidate, Content, Part, PromptFeedback, and SafetyRating) mirror the JSON structure expected by the Gemini API. This demonstrates Haskell's strong type system being used to ensure type-safe handling of API data structures.

The main function implements the program's core logic: it retrieves a prompt from command-line arguments and an API key from environment variables, constructs an HTTP request to the Gemini API with proper headers and JSON body, and handles the response. The code uses monadic composition to handle the asynchronous nature of HTTP requests and includes error handling for various failure cases, such as missing arguments, API errors, or malformed responses. The response processing extracts the generated text from the nested data structure and prints it to the console. The code also includes configuration for the AI model's parameters like temperature and maximum output tokens.


