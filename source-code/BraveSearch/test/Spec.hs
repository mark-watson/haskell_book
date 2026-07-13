module Main where

import Test.Hspec
import Data.Aeson (eitherDecode)
import qualified Data.ByteString.Lazy.Char8 as LBS
import qualified Data.Text as T
import BraveSearch

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "BraveSearch JSON decoding" $ do
    it "decodes a complete SearchResponse" $ do
      let json = LBS.pack $ unlines
            [ "{\"query\": {\"original\": \"haskell programming\"}"
            , ", \"web\": {\"results\": ["
            , "    {\"type\": \"search_result\", \"title\": \"Haskell.org\", \"url\": \"https://haskell.org\", \"description\": \"The Haskell programming language\"}"
            , "  , {\"type\": \"news_result\", \"title\": \"Haskell News\", \"url\": \"https://example.com\"}"
            , "]}}"
            ]
          decoded = eitherDecode json :: Either String SearchResponse
      case decoded of
        Left err -> expectationFailure ("Failed to decode: " ++ err)
        Right sr -> do
          original (query sr) `shouldBe` T.pack "haskell programming"
          length (results (web sr)) `shouldBe` 2
          title (head (results (web sr))) `shouldBe` Just (T.pack "Haskell.org")

    it "decodes a SearchResponse with empty results" $ do
      let decoded = eitherDecode (LBS.pack "{\"query\": {\"original\": \"xyzzy\"}, \"web\": {\"results\": []}}")
                  :: Either String SearchResponse
      case decoded of
        Left err -> expectationFailure ("Failed to decode: " ++ err)
        Right sr -> do
          original (query sr) `shouldBe` T.pack "xyzzy"
          results (web sr) `shouldBe` []

    it "decodes a WebResult with all optional fields present" $ do
      let json = "{\"type\":\"search_result\",\"index\":1,\"all\":false,\"title\":\"Test\",\"url\":\"http://x.com\",\"description\":\"Desc\"}"
          decoded = eitherDecode (LBS.pack json) :: Either String WebResult
      case decoded of
        Left err -> expectationFailure ("Failed to decode: " ++ err)
        Right wr -> do
          type_ wr `shouldBe` T.pack "search_result"
          index wr `shouldBe` Just 1
          BraveSearch.all wr `shouldBe` Just False
          title wr `shouldBe` Just (T.pack "Test")
          url wr `shouldBe` Just (T.pack "http://x.com")
          description wr `shouldBe` Just (T.pack "Desc")

    it "decodes a WebResult with missing optional fields as Nothing" $ do
      let decoded = eitherDecode (LBS.pack "{\"type\":\"search_result\"}") :: Either String WebResult
      case decoded of
        Left err -> expectationFailure ("Failed to decode: " ++ err)
        Right wr -> do
          type_ wr `shouldBe` T.pack "search_result"
          index wr `shouldBe` Nothing
          title wr `shouldBe` Nothing
          url wr `shouldBe` Nothing
          description wr `shouldBe` Nothing

    it "returns parse error for malformed JSON" $ do
      let decoded = eitherDecode (LBS.pack "not json") :: Either String SearchResponse
      case decoded of
        Right _ -> expectationFailure "Should have failed"
        Left _ -> return ()
