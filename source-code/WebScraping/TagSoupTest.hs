-- Simple web scraper: fetch a page, parse HTML with TagSoup, print headers, text, and links
-- OverloadedStrings lets string literals be `Text` or `ByteString` without explicit packing
{-# LANGUAGE OverloadedStrings #-}

-- HTTP client for making requests
import Network.HTTP.Simple
import Network.HTTP.Client (HttpException)
-- TagSoup: tolerant HTML parser that turns HTML into a list of tags
import Text.HTML.TagSoup
-- Text types and IO helpers
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
-- ByteString helpers for proper UTF-8 decoding
import qualified Data.ByteString.Lazy as BL
import Data.Text.Encoding (decodeUtf8)
-- mapMaybe: map and drop Nothings
import Data.Maybe (mapMaybe)
-- Exception handling for network errors
import Control.Exception (try)

main :: IO ()
main = do
    -- Fetch the HTML content, catching network exceptions
    result <- try $ httpLBS "https://markwatson.com/" :: IO (Either HttpException (Response BL.ByteString))
    case result of
      Left err -> putStrLn $ "Network error: " ++ show err
      Right response -> do
        -- Properly decode the response body from UTF-8
        let body = T.unpack $ decodeUtf8 $ BL.toStrict $ getResponseBody response
            tags = parseTags body                          -- turn HTML into `[Tag String]`

        -- Extract and print headers
        let headers = getResponseHeaders response  -- list of (header-name, value)
        putStrLn "Headers:"
        mapM_ print headers  -- `mapM_` runs `print` over the list in IO

        -- Extract and print all text content
        let texts = extractTexts tags  -- collapse visible text nodes into a single `Text`
        putStrLn "\nText Content:"
        TIO.putStrLn texts  -- use Text IO to print

        -- Extract and print all links
        let links = extractLinks tags  -- grab `href` attributes from <a> tags
        putStrLn "\nLinks:"
        mapM_ TIO.putStrLn links  -- print each link line-by-line

-- Collect visible text from tags and normalize whitespace
extractTexts :: [Tag String] -> Text
extractTexts =
  T.unwords                               -- join words with single spaces
  . map (T.strip . T.pack)                -- trim and convert `String` -> `Text`
  . filter (not . null)                   -- drop empty pieces
  . mapMaybe maybeTagText                 -- keep only text nodes, discard tags

-- Collect `href` values from all <a> tags
extractLinks :: [Tag String] -> [Text]
extractLinks = map (T.pack . fromAttrib "href") . filter isATag
  where
    isATag (TagOpen "a" _) = True   -- match opening <a ...> tag
    isATag _               = False