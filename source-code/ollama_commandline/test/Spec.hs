module Main where

import Test.Hspec
import Data.Aeson (eitherDecode, encode)
import qualified Data.ByteString.Lazy.Char8 as LBS
import Data.List (isInfixOf)
import Ollama

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "Ollama JSON decoding" $ do
    it "decodes a complete OllamaResponse" $ do
      let json = LBS.pack $ unlines
            [ "{"
            , "  \"model\": \"llama3\","
            , "  \"created_at\": \"2024-01-01T00:00:00Z\","
            , "  \"response\": \"Hello!\","
            , "  \"done\": true"
            , "}"
            ]
          decoded = eitherDecode json :: Either String OllamaResponse
      case decoded of
        Left err -> expectationFailure ("Failed to decode: " ++ err)
        Right r -> do
          respModel r `shouldBe` "llama3"
          respCreatedAt r `shouldBe` "2024-01-01T00:00:00Z"
          respResponse r `shouldBe` "Hello!"
          respDone r `shouldBe` True
          respDoneReason r `shouldBe` Nothing

    it "decodes an OllamaResponse with done_reason" $ do
      let json = "{\"model\":\"x\",\"created_at\":\"\",\"response\":\"\",\"done\":true,\"done_reason\":\"stop\"}"
          decoded = eitherDecode (LBS.pack json) :: Either String OllamaResponse
      case decoded of
        Left err -> expectationFailure ("Failed to decode: " ++ err)
        Right r -> respDoneReason r `shouldBe` Just "stop"

    it "decodes an OllamaError" $ do
      let json = "{\"error\":\"model not found\"}"
          decoded = eitherDecode (LBS.pack json) :: Either String OllamaError
      case decoded of
        Left err -> expectationFailure ("Failed to decode: " ++ err)
        Right e -> errMsg e `shouldBe` "model not found"

  describe "Ollama JSON encoding" $ do
    it "encodes an OllamaRequest with correct field names" $ do
      let req = OllamaRequest
            { reqModel = "qwen3"
            , reqPrompt = "Hi"
            , reqStream = False
            }
          json = LBS.unpack (encode req)
      "\"model\"" `isInfixOf` json `shouldBe` True
      "\"prompt\"" `isInfixOf` json `shouldBe` True
      "\"stream\"" `isInfixOf` json `shouldBe` True

    it "encodes a request containing user text" $ do
      let req = OllamaRequest { reqModel = "m", reqPrompt = "Hello", reqStream = True }
          json = LBS.unpack (encode req)
      "Hello" `isInfixOf` json `shouldBe` True
