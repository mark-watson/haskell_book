# Web Scraping

*Note: the code for this example replaced November 9, 2024.*

In my past work I usually used the Ruby and Python scripting languages for web scraping but as I use the Haskell language more often for projects both large and small I am now using Haskell for web scraping, data collection, and data cleaning tasks. If you worked through the tutorial chapter on impure Haskell programming then you already know most of what you need to understand this chapter. Here we will walk through a few short examples for common web scraping tasks.

Before we start a tutorial about web scraping I want to point out that much of the information on the web is copyright and the first thing that you should do is to read the terms of service for web sites to insure that your use of web scraped data conforms with the wishes of the persons or organizations who own the content and pay to run scraped web sites.

As we saw in the last chapter on linked data there is a huge amount of structured data available on the web via web services, semantic web/linked data markup, and APIs. That said, you will frequently find text (usually HTML) that is useful on web sites. However, this text is often at least partially unstructured and in a messy and frequently changing format because web pages are meant for human consumption and making them easy to parse and use by software agents is not a priority of web site owners.
Here is t
he code for the entire example in directory **haskell_tutorial_cookbook_examples/WebScraping** (code description follows the listing):

```haskell{line-numbers: false}
-- Simple web scraper: fetch a page, parse HTML with TagSoup, print headers, text, and links
-- OverloadedStrings lets string literals be `Text` or `ByteString` without explicit packing
{-# LANGUAGE OverloadedStrings #-}

-- HTTP client for making requests
import Network.HTTP.Simple
-- TagSoup: tolerant HTML parser that turns HTML into a list of tags
import Text.HTML.TagSoup
-- Text types and IO helpers
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
-- Lazy ByteString helpers for response body
import qualified Data.ByteString.Lazy.Char8 as BL8
-- mapMaybe: map and drop Nothings
import Data.Maybe (mapMaybe)

main :: IO ()
main = do
    -- Fetch the HTML content
    response <- httpLBS "https://markwatson.com/"  -- GET request; returns `Response ByteString`
    let body = BL8.unpack $ getResponseBody response  -- convert lazy ByteString to String
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
```

This Haskell program retrieves and processes the content of the webpage at https://markwatson.com/. It utilizes the http-conduit library to perform an HTTP GET request, fetching the HTML content of the specified URL. The response body, initially in a lazy ByteString format, is converted to a String using BL8.unpack to facilitate subsequent parsing operations.

For parsing the HTML content, the program employs the TagSoup library, which is adept at handling both well-formed and malformed HTML. The parseTags function processes the HTML String into a list of Tag String elements, representing the structure of the HTML document. This parsed representation enables efficient extraction of specific components, such as headers, text content, and hyperlinks.

The program defines two functions, **extractTexts** and **extractLinks**, to extract text content and hyperlinks, respectively. The **extractTexts** function filters the parsed tags to identify text nodes, removes any empty strings, converts them to Text, strips leading and trailing whitespace, and concatenates them into a single Text value. The **extractLinks** function filters for anchor tags, extracts their href attributes, and converts these URLs to Text.

In the main function, after fetching and parsing the HTML content, the program retrieves and prints the HTTP response headers using **getResponseHeaders**. It then calls **extractTexts** to obtain and display the textual content of the webpage, followed by **extractLinks** to list all hyperlinks present in the HTML. This structured approach allows for a clear and organized extraction of information from the specified webpage.

Here is some example output (shortened for brevity):

```
 $ cabal run TagSoupTest
Headers:
("Date","Sat, 09 Nov 2024 18:12:46 GMT")
("Content-Type","text/html; charset=utf-8")
("Transfer-Encoding","chunked")
("Connection","keep-alive")
("Last-Modified","Mon, 04 Nov 2024 22:52:48 GMT")
("Access-Control-Allow-Origin","*")

Text Content:
     Mark Watson: AI Practitioner and Author of 20+ AI Books | Mark Watson                 window.dataLayer = window.dataLayer || [];
       function gtag(){dataLayer.push(arguments);}
       gtag('js', new Date());
       gtag('config', 'G-MJNL6DY9ZQ');            Read My Blog on Blogspot      Read My Blog on Substack      Consulting      Fun stuff      My Books      Open Source     Privacy Policy       Mark Watson AI Practitioner and Consultant Specializing in Large Language Models, LangChain/Llama-Index Integrations, Deep Learning, and the Semantic Web   I am the author of 20+ books on Artificial Intelligence, Python, Common Lisp, Deep Learning, Haskell, Clojure, Java, Ruby, Hy language, and the Semantic Web. I have 55 US Patents.         My customer list includes: Google, Capital One, Babylist, Olive AI, CompassLabs, Mind AI, Disney, SAIC, Americast, PacBell, CastTV, Lutris Technology, Arctan Group, Sitescout.com, Embed.ly, and Webmind Corporation.

Links:
https://mark-watson.blogspot.com/
https://marklwatson.substack.com
#consulting
#fun
#books
#opensource
https://markwatson.com/privacy.html
```


## Web Scraping Wrap Up

There are many Haskell library options for web scraping and cleaning data. In this chapter I showed you just what I use in my projects.

The material in this chapter and the chapters on text processing and linked data should be sufficient to get you started using online data sources in your applications.