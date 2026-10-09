-- Simple command-line client for a local LLM server (Sushi) that exposes an
-- OpenAI-compatible API.
--
-- Default endpoint: http://127.0.0.1:12345/v1
-- Default model:    Qwen3.8-Flash-Next-Sushi-2.6bpw
--
-- Usage: cabal run llm-sushi-local -- "<prompt>" [model]
--    or: runghc Main.hs "<prompt>" [model]
-- Pass --stream to print tokens as they arrive. See --help for all options.
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main (main) where

-- Core utilities
import Control.Exception (try, evaluate, SomeException)
import Control.Monad (unless, when)
import Data.IORef
  ( IORef, newIORef, readIORef, writeIORef, modifyIORef' )
import Data.List (dropWhileEnd)
import Data.Maybe (mapMaybe)
import System.Console.GetOpt
  ( ArgDescr(NoArg, ReqArg)
  , ArgOrder(Permute)
  , OptDescr(Option)
  , getOpt
  , usageInfo
  )
import System.Environment (getArgs, lookupEnv)
import System.Exit (exitFailure)
import System.IO (hFlush, hPutStrLn, stderr, stdout)

-- JSON support
import qualified Data.Aeson as Aeson
import Data.Text (Text, pack, unpack)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO

-- HTTP client
import Network.HTTP.Client
  ( BodyReader
  , HttpException
  , Manager
  , Request(..)
  , RequestBody(RequestBodyLBS)
  , Response(..)
  , brConsume
  , brRead
  , defaultManagerSettings
  , httpLbs
  , newManager
  , parseRequest
  , responseBody
  , responseStatus
  , withResponse
  )
import Network.HTTP.Types.Status (statusIsSuccessful, statusCode, statusMessage)
import qualified Data.ByteString.Lazy as LBS
import qualified Data.ByteString.Lazy.Char8 as LBS8
import qualified Data.ByteString.Char8 as BS

-- Local types
import Sushi

-- -----------------------------------------------------------------------------
-- Command line options
-- -----------------------------------------------------------------------------

data Flag
  = OptStream
  | OptBaseUrl String
  | OptModel String
  | OptTemperature String
  | OptMaxTokens String
  | OptHelp
  deriving (Show, Eq)

options :: [OptDescr Flag]
options =
  [ Option ['s'] ["stream"] (NoArg OptStream)
      "print tokens as they arrive (server-sent events)"
  , Option [] ["base-url"] (ReqArg OptBaseUrl "URL")
      ("API base url (default " ++ defaultBaseUrl ++ "; env SUSHI_BASE_URL)")
  , Option ['m'] ["model"] (ReqArg OptModel "MODEL")
      ("model id (default " ++ defaultModel ++ "; env SUSHI_MODEL)")
  , Option ['t'] ["temperature"] (ReqArg OptTemperature "N")
      "sampling temperature, e.g. 0.7"
  , Option [] ["max-tokens"] (ReqArg OptMaxTokens "N")
      "maximum number of generated tokens"
  , Option ['h'] ["help"] (NoArg OptHelp)
      "show this help"
  ]

usage :: String
usage = usageInfo header options
  where
    header = unlines
      [ "Usage: llm-sushi-local [OPTIONS] <prompt> [model]"
      , ""
      , "Send a prompt to a local OpenAI-compatible LLM server and print the reply."
      , ""
      , "  llm-sushi-local \"how much is 4 + 11 + 13?\""
      , "  llm-sushi-local --stream \"write a haiku about Haskell\""
      , "  llm-sushi-local --max-tokens 40 --temperature 0.2 \"explain lazy evaluation\""
      , ""
      , "Options:"
      ]

-- -----------------------------------------------------------------------------
-- HTTP request building
-- -----------------------------------------------------------------------------

-- The local Sushi server ignores this header, but OpenAI-compatible servers
-- generally require an Authorization header on every request.
authHeaderValue :: BS.ByteString
authHeaderValue = "Bearer not-needed"

-- | Build a POST request to /chat/completions.
-- 'checkResponse' is neutralized so that an HTTP error can be reported
-- together with the server's own error message instead of throwing.
buildRequest :: String -> ChatRequest -> IO Request
buildRequest baseUrl req = do
  initialRequest <- parseRequest (chatCompletionsUrl baseUrl)
  return initialRequest
    { method = "POST"
    , requestHeaders =
        [ ("Content-Type", "application/json")
        , ("Accept", acceptFor (reqStream req))
        , ("Authorization", authHeaderValue)
        ]
    , requestBody = RequestBodyLBS $ Aeson.encode req
    , checkResponse = \_ _ -> return ()
    }

-- The server honours the "stream" flag in the JSON body, so the same Accept
-- header works for both modes.
acceptFor :: Bool -> BS.ByteString
acceptFor True = "text/event-stream"
acceptFor False = "application/json"

-- | Format an HTTP status as "404 Not Found".
showStatus :: Response body -> String
showStatus response =
  let status = responseStatus response
  in show (statusCode status) ++ " " ++ BS.unpack (statusMessage status)

-- | Recover the server's error text from a failed response body.
errorFromBody :: LBS.ByteString -> String
errorFromBody body = case Aeson.decode body :: Maybe ApiError of
  Just apiErr -> errMsg apiErr
  Nothing     -> take 500 (LBS8.unpack body)

-- | Parse a JSON body without letting a malformed document throw: aeson's
-- 'decode' is lazy in its result, so forcing it here converts a partial parse
-- failure into a normal error message.
decodeSafely
  :: forall a. Aeson.FromJSON a
  => String -> LBS.ByteString -> IO (Either String a)
decodeSafely what body = do
  decoded <- try (evaluate (Aeson.decode body :: Maybe a))
    :: IO (Either SomeException (Maybe a))
  return $ case decoded of
    Left _ex -> Left parseFailure
    Right (Just v) -> Right v
    Right Nothing -> Left parseFailure
  where
    parseFailure = "Failed to parse " ++ what ++ " JSON. Body: "
      ++ take 500 (LBS8.unpack body)

connectError :: String -> HttpException -> String
connectError baseUrl ex =
  "Could not connect to the local LLM server at "
    ++ chatCompletionsUrl baseUrl ++ ": " ++ show ex

-- -----------------------------------------------------------------------------
-- Non-streaming call
-- -----------------------------------------------------------------------------

callOnce
  :: Manager
  -> String
  -> ChatRequest
  -> IO (Either String ChatResponse)
callOnce manager baseUrl req = do
  request <- buildRequest baseUrl req
  eitherResponse <- try (httpLbs request manager)
    :: IO (Either HttpException (Response LBS.ByteString))
  case eitherResponse of
    Left ex -> return (Left (connectError baseUrl ex))
    Right response -> do
      let status = responseStatus response
          body = responseBody response
      if statusIsSuccessful status
        then decodeSafely "response" body
        else return (Left (httpError response body))

httpError :: Response body -> LBS.ByteString -> String
httpError response body =
  "Error: HTTP " ++ showStatus response ++ ": " ++ errorFromBody body

-- -----------------------------------------------------------------------------
-- Streaming call
-- -----------------------------------------------------------------------------

-- State of one streaming response.
data StreamState = StreamState
  { ssDeltas :: IORef [Text]       -- ^ text deltas seen so far (newest first)
  , ssError :: IORef (Maybe String)
  , ssDone :: IORef Bool           -- ^ set when "data: [DONE]" arrives
  }

-- | Call /chat/completions with streaming enabled. Prints each text delta as
-- it arrives and returns the full assistant message.
callStreaming
  :: Manager
  -> String
  -> ChatRequest
  -> IO (Either String Text)
callStreaming manager baseUrl req = do
  request <- buildRequest baseUrl req
  state <- StreamState <$> newIORef [] <*> newIORef Nothing <*> newIORef False
  eitherResult <- try
    (withResponse request manager (manage state) :: IO ())
    :: IO (Either HttpException ())
  case eitherResult of
    Left ex -> return (Left (connectError baseUrl ex))
    Right () -> do
      mErr <- readIORef (ssError state)
      case mErr of
        Just err -> return (Left err)
        Nothing -> do
          deltas <- readIORef (ssDeltas state)
          return (Right (mconcat (reverse deltas)))
  where
    manage state response
      | statusIsSuccessful (responseStatus response) =
          readSse state (responseBody response)
      | otherwise = do
          chunks <- brConsume (responseBody response)
          writeIORef (ssError state)
            (Just (httpError response (LBS.fromChunks chunks)))

-- | Read the SSE response body incrementally: each chunk from the connection
-- is split into complete lines and processed immediately, so output appears
-- as the model generates it.
readSse :: StreamState -> BodyReader -> IO ()
readSse state bodyReader = go ""
  where
    go pending = do
      done <- readIORef (ssDone state)
      unless done $ do
        chunk <- brRead bodyReader
        if BS.null chunk
          then processLines state [pending]
          else do
            let text = pending ++ BS.unpack chunk
                ls = lines text
            -- The last element is only complete if the chunk ended with a
            -- newline; keep the remainder for the next chunk.
            let (completeLines, newPending) = case reverse ls of
                  (lastL:others)
                    | endsWithNewline chunk -> (reverse (lastL : others), "")
                    | otherwise -> (reverse others, lastL)
                  [] -> ([], "")
            processLines state completeLines
            go newPending

    endsWithNewline chunk = case BS.uncons chunk of
      Just (_, _) -> BS.last chunk == '\n'
      Nothing     -> True

-- | Process complete SSE lines. "data:" lines carry JSON chunks; the stream
-- ends with "data: [DONE]". Blank lines and other SSE fields are ignored.
processLines :: StreamState -> [String] -> IO ()
processLines state = mapM_ processLine
  where
    processLine rawLine = do
      let line = trimSpace rawLine
      when (not (null line) && dataPrefix `isPrefixOfStr` line) $ do
        let payload = dropWhile (== ' ') (drop (length dataPrefix) line)
        if payload == "[DONE]"
          then writeIORef (ssDone state) True
          else case Aeson.decode (LBS8.pack payload) :: Maybe StreamChunk of
            Nothing -> when (apiErrorIn payload) $
              writeIORef (ssError state) (Just (apiErrorText payload))
            Just chunk -> do
              let delta = mconcat (map (schDeltaText . schDelta) (scChoices chunk))
              unless (Text.null delta) $ do
                TextIO.putStr delta
                hFlush stdout
                modifyIORef' (ssDeltas state) (delta :)

    dataPrefix = "data:"
    isPrefixOfStr prefix s = take (length prefix) s == prefix
    schDeltaText = msgContent

-- | A streaming error arrives as a JSON object with an "error" field.
apiErrorIn :: String -> Bool
apiErrorIn payload = case Aeson.decode (LBS8.pack payload) :: Maybe ApiError of
  Just _ -> True
  Nothing -> False

apiErrorText :: String -> String
apiErrorText payload = case Aeson.decode (LBS8.pack payload) :: Maybe ApiError of
  Just apiErr -> errMsg apiErr
  Nothing -> payload

-- | Trim leading and trailing whitespace from an SSE line.
trimSpace :: String -> String
trimSpace = dropWhileEnd isSpaceChar . dropWhile isSpaceChar
  where
    isSpaceChar :: Char -> Bool
    isSpaceChar c = c `elem` (" \t\r\n" :: String)

-- -----------------------------------------------------------------------------
-- Config resolution
-- -----------------------------------------------------------------------------

-- | First flag value matching a projection.
flagValue :: [Flag] -> (Flag -> Maybe String) -> Maybe String
flagValue flags project = case mapMaybe project flags of
  (v:_) -> Just v
  []    -> Nothing

-- | First non-empty value wins: flags, then environment, then defaults.
resolve :: [Maybe String] -> String
resolve xs = case [v | Just v <- xs, not (null v)] of
  (v:_) -> v
  []    -> ""

-- -----------------------------------------------------------------------------
-- main
-- -----------------------------------------------------------------------------

main :: IO ()
main = do
  rawArgs <- getArgs
  case getOpt Permute options rawArgs of
    (flags, positional, errs) -> do
      mapM_ (hPutStrLn stderr) errs
      if OptHelp `elem` flags
        then putStrLn usage
        else if not (null errs)
          then do
            hPutStrLn stderr usage
            exitFailure
          else run flags positional

run :: [Flag] -> [String] -> IO ()
run flags positional = do
  envBaseUrl <- lookupEnv "SUSHI_BASE_URL"
  envModel <- lookupEnv "SUSHI_MODEL"

  let -- Positional arguments follow the Ollama example: <prompt> [model]
      promptArg = case positional of
        (p:_) -> Just p
        []    -> Nothing
      positionalModel = case positional of
        (_:m:_) -> Just m
        _       -> Nothing
      baseUrl = resolve
        [ flagValue flags (\f -> case f of OptBaseUrl u -> Just u; _ -> Nothing)
        , envBaseUrl
        , Just defaultBaseUrl
        ]
      model = resolve
        [ positionalModel
        , flagValue flags (\f -> case f of OptModel m -> Just m; _ -> Nothing)
        , envModel
        , Just defaultModel
        ]
      stream = OptStream `elem` flags

  temperature <- numberOption "temperature" flags
  maxTokens <- numberOption "max-tokens" flags

  case promptArg of
    Nothing -> do
      putStrLn "No prompt given."
      putStrLn usage
      exitFailure
    Just prompt -> do
      manager <- newManager defaultManagerSettings
      let chatRequestBody = ChatRequest
            { reqModel = pack model
            , reqMessages = [ChatMessage "user" (pack prompt)]
            , reqStream = stream
            , reqTemperature = temperature
            , reqMaxTokens = maxTokens
            }

      putStrLn $ "Sending prompt '" ++ shorten 60 prompt ++ "' to model '"
        ++ model ++ "' at " ++ chatCompletionsUrl baseUrl
        ++ (if stream then " (streaming)" else "") ++ "..."
      putStrLn ""

      if stream
        then do
          result <- callStreaming manager baseUrl chatRequestBody
          case result of
            Right _text -> putStrLn "\n\n--- End of stream ---"
            Left err    -> putStrLn ("API Error: " ++ err)
        else do
          result <- callOnce manager baseUrl chatRequestBody
          case result of
            Right chatResponse -> do
              case respChoices chatResponse of
                (choice:_) -> do
                  putStrLn "--- Response ---"
                  TextIO.putStrLn (msgContent (chMessage choice))
                  case chFinishReason choice of
                    Just reason -> putStrLn ("\nDone reason: " ++ unpack reason)
                    Nothing     -> return ()
                [] -> putStrLn "API Error: no choices in response."
              printUsage chatResponse
            Left err -> putStrLn ("API Error: " ++ err)

-- | Read a numeric flag (--temperature / --max-tokens). 'Nothing' when the
-- flag is absent; a malformed value warns and is ignored.
numberOption :: Read a => String -> [Flag] -> IO (Maybe a)
numberOption label flags = case flagValue flags (valueFor label) of
  Nothing -> return Nothing
  Just text -> case reads text of
    [(v, rest)] | all (`elem` (" \t\r\n" :: String)) rest -> return (Just v)
    _ -> do
      hPutStrLn stderr ("Warning: ignoring invalid " ++ label ++ " '" ++ text ++ "'")
      return Nothing
  where
    valueFor "temperature" (OptTemperature v) = Just v
    valueFor "max-tokens" (OptMaxTokens v) = Just v
    valueFor _ _ = Nothing

shorten :: Int -> String -> String
shorten n s
  | length s <= n = s
  | otherwise     = take n s ++ "..."

printUsage :: ChatResponse -> IO ()
printUsage chatResponse = case respUsage chatResponse of
  Nothing -> return ()
  Just usage' -> do
    let showInt label maybeValue = case maybeValue of
          Nothing -> return ()
          Just v  -> putStrLn ("  " ++ label ++ ": " ++ show v)
    putStrLn "\nUsage:"
    showInt "prompt tokens" (uPromptTokens usage')
    showInt "completion tokens" (uCompletionTokens usage')
    showInt "total tokens" (uTotalTokens usage')
