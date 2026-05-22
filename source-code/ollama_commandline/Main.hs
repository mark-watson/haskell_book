-- Simple command-line client for Ollama's local API
-- Usage: run as `Main "<prompt>" [model]` or `runghc Main.hs "<prompt>" [model]`. Default model: `qwen3:1.7b`
-- LANGUAGE pragmas enable features used below
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE DeriveGeneric #-}

-- Core utilities
import System.Environment (getArgs)
import Control.Exception (try)

-- JSON support
import qualified Data.Aeson as Aeson
import Data.Aeson (FromJSON, ToJSON)
import GHC.Generics (Generic)

-- HTTP client
import Network.HTTP.Client
  ( newManager
  , httpLbs
  , parseRequest
  , Request(..)
  , RequestBody(..)
  , Response(..)
  , responseBody
  , responseStatus
  , defaultManagerSettings
  , Manager
  , HttpException
  )
import Network.HTTP.Types.Status (statusIsSuccessful)
import qualified Data.ByteString.Lazy as LBS
import qualified Data.ByteString.Lazy.Char8 as LBS8

-- Types that mirror Ollama's request and response JSON
data OllamaRequest = OllamaRequest
  { model :: String        -- name/tag of the model to use
  , prompt :: String       -- user input sent to the model
  , stream :: Bool         -- stream tokens or return a single final string
  } deriving (Show, Generic, ToJSON)

data OllamaResponse = OllamaResponse
  { model :: String
  , created_at :: String
  , response :: String     -- the generated text from the model
  , done :: Bool
  , done_reason :: Maybe String -- may be missing; use Maybe
  } deriving (Show, Generic, FromJSON)

-- | An error message returned by Ollama when a request fails (e.g. missing model).
data OllamaError = OllamaError
  { error :: String
  } deriving (Show, Generic, FromJSON)

-- Call Ollama's local API and decode the JSON response
callOllama :: Manager -> String -> String -> IO (Either String OllamaResponse)
callOllama manager modelName userPrompt = do
  -- Build the POST request to /api/generate
  initialRequest <- parseRequest "http://localhost:11434/api/generate"

  let ollamaRequestBody = OllamaRequest
        { model = modelName
        , prompt = userPrompt
        , stream = False     -- single complete response
        }

  let request = initialRequest
        { requestHeaders = [("Content-Type", "application/json")]
        , method = "POST"
        , requestBody = RequestBodyLBS $ Aeson.encode ollamaRequestBody -- encode as JSON
        }

  -- Send the request; catch network/connection errors
  eitherResponse <- try (httpLbs request manager) :: IO (Either HttpException (Response LBS.ByteString))
  case eitherResponse of
    Left _ex ->
      return $ Left "Could not connect to Ollama. Please ensure the Ollama service is running on port 11434."
    Right httpResponse -> do
      let status = responseStatus httpResponse
          body = responseBody httpResponse

      if statusIsSuccessful status
        then do
          -- Try to decode the JSON body into our Haskell type
          let maybeOllamaResponse = Aeson.decode body :: Maybe OllamaResponse
          case maybeOllamaResponse of
            Just ollamaResponse -> return $ Right ollamaResponse
            Nothing -> return $ Left $ "Error: Failed to parse JSON response. Body: " ++ show body
        else do
          -- Non-2xx HTTP status: try to extract a structured error message
          let errorMsg = case Aeson.decode body :: Maybe OllamaError of
                Just ollamaErr -> Main.error ollamaErr
                Nothing        -> LBS8.unpack body
          return $ Left $ "Error: HTTP " ++ show status ++ ": " ++ errorMsg

main :: IO ()
main = do
  -- Read command-line args: prompt and optional model name
  args <- getArgs
  case args of
    [] -> putStrLn "Usage: <program_name> <prompt> [model_name]"
    (promptArg:modelArgs) -> do
      -- Choose model: use user-provided or default
      let modelName = case modelArgs of
                        (m:_) -> m
                        []    -> "qwen3:1.7b"

      -- Create an HTTP connection manager
      manager <- newManager defaultManagerSettings

      putStrLn $ "Sending prompt '" ++ promptArg ++ "' to model '" ++ modelName ++ "'..."

      -- Make the API call
      result <- callOllama manager modelName promptArg

      -- Handle success or error
      case result of
        Right ollamaResponse -> do
          putStrLn "\n--- Response ---"
          putStrLn ollamaResponse.response
          -- Print reason if present
          case ollamaResponse.done_reason of
            Just reason -> putStrLn $ "\nDone reason: " ++ reason
            Nothing     -> return ()
        Left err -> do
          putStrLn $ "API Error: " ++ err
