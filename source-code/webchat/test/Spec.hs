module Main where

import Test.Hspec
import Data.Aeson (eitherDecode, decode, encode)
import qualified Data.ByteString.Lazy.Char8 as LBS
import Gemini

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "GeminiRequest JSON" $ do
    it "round-trips through JSON" $ do
      let req = GeminiRequest { prompt = "Hello, Gemini!" }
          decoded = decode (encode req) :: Maybe GeminiRequest
      decoded `shouldBe` Just req

    it "decodes a GeminiRequest from JSON" $ do
      let json = LBS.pack "{\"prompt\": \"What is Haskell?\"}"
          decoded = eitherDecode json :: Either String GeminiRequest
      case decoded of
        Left err -> expectationFailure ("Failed to decode: " ++ err)
        Right r  -> prompt r `shouldBe` "What is Haskell?"

  describe "GeminiResponse JSON decoding" $ do
    it "decodes a response with a single candidate" $ do
      let json = LBS.pack $ unlines
            [ "{"
            , "  \"candidates\": ["
            , "    {\"content\": {\"parts\": [{\"text\": \"Hello, world!\"}], \"role\": \"model\"},"
            , "     \"finishReason\": \"STOP\", \"index\": 0}"
            , "  ]"
            , "}"
            ]
          decoded = eitherDecode json :: Either String GeminiResponse
      case decoded of
        Left err -> expectationFailure ("Failed to decode: " ++ err)
        Right resp -> case candidates resp of
          [c] -> do
            finishReason c `shouldBe` Just "STOP"
            index c `shouldBe` Just 0
            map text (parts (content c)) `shouldBe` ["Hello, world!"]
            role (content c) `shouldBe` Just "model"
          _ -> expectationFailure "Expected exactly one candidate"

    it "decodes a response with multiple candidates" $ do
      let json = LBS.pack $ unlines
            [ "{"
            , "  \"candidates\": ["
            , "    {\"content\": {\"parts\": [{\"text\": \"First\"}], \"role\": \"model\"}},"
            , "    {\"content\": {\"parts\": [{\"text\": \"Second\"}], \"role\": \"model\"}}"
            , "  ]"
            , "}"
            ]
          decoded = eitherDecode json :: Either String GeminiResponse
      case decoded of
        Left err -> expectationFailure ("Failed to decode: " ++ err)
        Right resp -> do
          length (candidates resp) `shouldBe` 2
          [ text p | c <- candidates resp, (p:_) <- [parts (content c)] ]
            `shouldBe` ["First", "Second"]

    it "decodes a response with promptFeedback" $ do
      let json = LBS.pack $ unlines
            [ "{"
            , "  \"candidates\": [],"
            , "  \"promptFeedback\": {"
            , "    \"blockReason\": \"SAFETY\","
            , "    \"safetyRatings\": ["
            , "      {\"category\": \"HARM_CATEGORY_SEXUALLY_EXPLICIT\", \"probability\": \"NEGLIGIBLE\"}"
            , "    ]"
            , "  }"
            , "}"
            ]
          decoded = eitherDecode json :: Either String GeminiResponse
      case decoded of
        Left err -> expectationFailure ("Failed to decode: " ++ err)
        Right resp -> do
          candidates resp `shouldBe` []
          case promptFeedback resp of
            Nothing -> expectationFailure "Expected promptFeedback"
            Just pf -> do
              blockReason pf `shouldBe` Just "SAFETY"
              case safetyRatings pf of
                Just [sr] -> do
                  category sr `shouldBe` "HARM_CATEGORY_SEXUALLY_EXPLICIT"
                  probability sr `shouldBe` "NEGLIGIBLE"
                _ -> expectationFailure "Expected one safety rating"

  describe "Part JSON" $ do
    it "round-trips a Part" $ do
      let p = Part { text = "some text" }
          decoded = decode (encode p) :: Maybe Part
      decoded `shouldBe` Just p
