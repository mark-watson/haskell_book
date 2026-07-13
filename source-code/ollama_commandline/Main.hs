-- Simple command-line client for Ollama's local API
-- Usage: run as `Main "<prompt>" [model]` or `runghc Main.hs "<prompt>" [model]`. Default model: `qwen3:1.7b`
{-# LANGUAGE DeriveGeneric #-}

-- Core utilities
import System.Environment (getArgs)
import Control.Exception (try)

-- JSON support
import qualified Data.Aeson as Aeson

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

import Ollama

-- Call Ollama's local API and decode the JSON response
callOllama :: Manager -> String -> String -> IO (Either String OllamaResponse)
callOllama manager modelName userPrompt = do
  -- Build the POST request to /api/generate
  initialRequest <- parseRequest "http://localhost:11434/api/generate"

  let ollamaRequestBody = OllamaRequest
        { reqModel = modelName
        , reqPrompt = userPrompt
        , reqStream = False
        }

  let request = initialRequest
        { requestHeaders = [("Content-Type", "application/json")]
        , method = "POST"
        , requestBody = RequestBodyLBS $ Aeson.encode ollamaRequestBody
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
          let maybeOllamaResponse = Aeson.decode body :: Maybe OllamaResponse
          case maybeOllamaResponse of
            Just ollamaResponse -> return $ Right ollamaResponse
            Nothing -> return $ Left $ "Error: Failed to parse JSON response. Body: " ++ show body
        else do
          let errorMsg = case Aeson.decode body :: Maybe OllamaError of
                Just ollamaErr -> errMsg ollamaErr
                Nothing        -> LBS8.unpack body
          return $ Left $ "Error: HTTP " ++ show status ++ ": " ++ errorMsg

main :: IO ()
main = do
  args <- getArgs
  case args of
    [] -> putStrLn "Usage: <program_name> <prompt> [model_name]"
    (promptArg:modelArgs) -> do
      let modelName = case modelArgs of
                        (m:_) -> m
                        []    -> "qwen3:1.7b"

      manager <- newManager defaultManagerSettings

      putStrLn $ "Sending prompt '" ++ promptArg ++ "' to model '" ++ modelName ++ "'..."

      result <- callOllama manager modelName promptArg

      case result of
        Right ollamaResponse -> do
          putStrLn "\n--- Response ---"
          putStrLn (respResponse ollamaResponse)
          case respDoneReason ollamaResponse of
            Just reason -> putStrLn $ "\nDone reason: " ++ reason
            Nothing     -> return ()
        Left err -> do
          putStrLn $ "API Error: " ++ err
