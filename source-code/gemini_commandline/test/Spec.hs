module Main where

import Test.Hspec
import Data.Aeson (eitherDecode, decode, encode)
import qualified Data.ByteString.Lazy.Char8 as LBS
import Gemini

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "Gemini JSON decoding" $ do
    it "decodes a GeminiApiResponse with candidates" $ do
      let json = LBS.pack $ unlines
            [ "{"
            , "  \"candidates\": ["
            , "    {\"content\": {\"parts\": [{\"text\": \"Hello, world!\"}], \"role\": \"model\"},"
            , "     \"finishReason\": \"STOP\"}"
            , "  ]"
            , "}"
            ]
          decoded = eitherDecode json :: Either String GeminiApiResponse
      case decoded of
        Left err -> expectationFailure ("Failed to decode: " ++ err)
        Right resp -> do
          length (candidates resp) `shouldBe` 1
          let r = head (candidates resp)
          map text (parts (content r)) `shouldBe` ["Hello, world!"]

    it "decodes a GeminiApiResponse with promptFeedback" $ do
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
          decoded = eitherDecode json :: Either String GeminiApiResponse
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

    it "decodes response with multiple candidates" $ do
      let json = LBS.pack $ unlines
            [ "{"
            , "  \"candidates\": ["
            , "    {\"content\": {\"parts\": [{\"text\": \"First\"}], \"role\": \"model\"}},"
            , "    {\"content\": {\"parts\": [{\"text\": \"Second\"}], \"role\": \"model\"}}"
            , "  ]"
            , "}"
            ]
          decoded = eitherDecode json :: Either String GeminiApiResponse
      case decoded of
        Left err -> expectationFailure ("Failed to decode: " ++ err)
        Right resp -> length (candidates resp) `shouldBe` 2

  describe "Gemini JSON encoding" $ do
    it "encodes a GeminiApiRequest" $ do
      let req = GeminiApiRequest
            { contents = [RequestContent { reqParts = [RequestPart { reqText = "Hello" }] }]
            , generationConfig = GenerationConfig { temperature = 0.5, maxOutputTokens = 100 }
            }
          json = encode req
      length (LBS.unpack json) `shouldSatisfy` (> 0)

    it "round-trips GenerationConfig through JSON" $ do
      let config = GenerationConfig { temperature = 0.7, maxOutputTokens = 500 }
          encoded = encode config
          decoded = decode encoded :: Maybe GenerationConfig
      decoded `shouldBe` Just config
