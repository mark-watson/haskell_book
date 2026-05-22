{-# LANGUAGE OverloadedStrings #-}
import OpenAI.Client

import Network.HTTP.Client
import Network.HTTP.Client.TLS
import System.Environment (lookupEnv)
import System.Exit (exitFailure)
import qualified Data.Text as T
import Data.Maybe (fromMaybe)
import Data.Text (splitOn)

-- | This module uses the @openai-hs@ library (and its dependency @openai-servant@)
-- to call the OpenAI chat-completion API.  You must set the @OPENAI_API_KEY@
-- environment variable to a valid API key before running, e.g.:
--
-- > export OPENAI_API_KEY=sk-...

-- | Sends a chat prompt and returns the assistant's text as String.
-- Requires a shared 'Manager' (created once in 'main') to avoid
-- opening a new TLS connection on every call.
completionRequestToString :: Manager -> T.Text -> String -> IO String
completionRequestToString manager apiKey prompt = do
    -- Build a client; the last argument (4) retries on transient network errors
    let client = makeOpenAIClient apiKey manager 4
    -- Describe the chat request to send
    let request = ChatCompletionRequest
                 { chcrModel = ModelId "gpt-5-mini"  -- model to use
                 , chcrMessages =
                    [ ChatMessage
                        { chmContent = Just (T.pack prompt)  -- user prompt
                        , chmRole = "user"
                        , chmFunctionCall = Nothing
                        , chmName = Nothing
                        }
                    ]
                 , chcrFunctions = Nothing
                 , chcrTemperature = Nothing
                 , chcrTopP = Nothing
                 , chcrN = Nothing
                 , chcrStream = Nothing
                 , chcrStop = Nothing
                 , chcrMaxTokens = Nothing
                 , chcrPresencePenalty = Nothing
                 , chcrFrequencyPenalty = Nothing
                 , chcrLogitBias = Nothing
                 , chcrUser = Nothing
                 }
    -- Perform the API call
    result <- completeChat client request
    -- Unpack the result and extract the text content from the first choice
    case result of
        Left failure -> return (show failure)
        Right success ->
            case chrChoices success of
                (ChatChoice {chchMessage = ChatMessage {chmContent = content}} : _) ->
                    return $ fromMaybe "No content" $ T.unpack <$> content
                _ -> return "No choices returned"

-- | Extracts place names from @text@ (comma-separated) using the chat model.
findPlaces :: Manager -> T.Text -> String -> IO [String]
findPlaces manager apiKey text = do
    let prompt = "Extract only the place names separated by commas from the following text:\n\n" ++ text
    response <- completionRequestToString manager apiKey prompt
    let places = filter (not . null) $ map T.unpack $ splitOn "," (T.pack response)
    return $ map (T.unpack . T.strip . T.pack) places

-- | Extracts person names from @text@ (comma-separated) using the chat model.
findPeople :: Manager -> T.Text -> String -> IO [String]
findPeople manager apiKey text = do
    let prompt = "Extract only the person names separated by commas from the following text:\n\n" ++ text
    response <- completionRequestToString manager apiKey prompt
    let people = filter (not . null) $ map T.unpack $ splitOn "," (T.pack response)
    return $ map (T.unpack . T.strip . T.pack) people

-- Demo: generate text, then extract places and people
main :: IO ()
main = do
    -- Look up the API key; exit with a friendly message if missing
    maybeKey <- lookupEnv "OPENAI_API_KEY"
    apiKey <- case maybeKey of
      Nothing -> do
        putStrLn "Error: OPENAI_API_KEY environment variable not set."
        putStrLn "Please set it with: export OPENAI_API_KEY=sk-..."
        exitFailure
      Just k  -> return (T.pack k)

    -- Create a single HTTPS manager shared across all requests
    manager <- newManager tlsManagerSettings

    -- Generic text generation
    response <- completionRequestToString manager apiKey "Write a hello world program in Haskell"
    putStrLn response

    -- Extract place names
    places <- findPlaces manager apiKey "I visited London, Paris, and New York last year."
    print places

    -- Extract person names
    people <- findPeople manager apiKey "John Smith met with Sarah Johnson and Michael Brown at the conference."
    print people