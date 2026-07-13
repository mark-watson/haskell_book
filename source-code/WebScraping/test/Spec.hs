{-# LANGUAGE OverloadedStrings #-}

-- Integration test: fetch https://example.com/ (the IANA-reserved canonical
-- "example" website), parse the HTML with TagSoup, and verify the expected
-- text and links are extracted. example.com is intentionally stable and
-- minimal, which makes it a good fixture for a live web-scraping smoke test.

module Main (main) where

import Test.Hspec
import Network.HTTP.Simple
import Network.HTTP.Client (HttpException)
import Text.HTML.TagSoup
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.ByteString.Lazy as BL
import Data.Text.Encoding (decodeUtf8)
import Data.Maybe (mapMaybe)
import Control.Exception (try)

main :: IO ()
main = hspec spec

-- Collect visible text from tags and normalize whitespace.
extractTexts :: [Tag String] -> Text
extractTexts =
  T.unwords
  . map (T.strip . T.pack)
  . filter (not . null)
  . mapMaybe maybeTagText

-- Collect `href` values from all <a> tags.
extractLinks :: [Tag String] -> [Text]
extractLinks = map (T.pack . fromAttrib "href") . filter isATag
  where
    isATag (TagOpen "a" _) = True
    isATag _               = False

spec :: Spec
spec = describe "web scraping example.com" $ do
  it "fetches the page and extracts the heading text and the IANA link" $ do
    result <- try $ httpLBS "https://example.com/"
              :: IO (Either HttpException (Response BL.ByteString))
    case result of
      Left err -> expectationFailure ("Network error: " ++ show err)
      Right response -> do
        let body  = T.unpack $ decodeUtf8 $ BL.toStrict $ getResponseBody response
            tags  = parseTags body
            texts = extractTexts tags
            links = extractLinks tags
        "Example Domain" `T.isInfixOf` texts `shouldBe` True
        links `shouldSatisfy` (not . null)
        any (T.isInfixOf "iana.org") links `shouldBe` True
