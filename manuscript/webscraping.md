# Web Scraping

In my past work I usually used the Ruby and Python scripting languages for web scraping but as I use the Haskell language more often for projects both large and small I am now using Haskell for web scraping, data collection, and data cleaning tasks. If you worked through the tutorial chapter on impure Haskell programming then you already know most of what you need to understand this chapter. Here we will walk through a few short examples for common web scraping tasks.

Before we start a tutorial about web scraping I want to point out that much of the information on the web is copyright and the first thing that you should do is to read the terms of service for web sites to insure that your use of web scraped data conforms with the wishes of the persons or organizations who own the content and pay to run scraped web sites.

As we saw in the last chapter on linked data there is a huge amount of structured data available on the web via web services, semantic web/linked data markup, and APIs. That said, you will frequently find text (usually HTML) that is useful on web sites. However, this text is often at least partially unstructured and in a messy and frequently changing format because web pages are meant for human consumption and making them easy to parse and use by software agents is not a priority of web site owners.

**Note:** It takes a while to fetch all of the libraries in the directory *WebScraping* so please do a **stack build** now to get these examples ready to experiment with while you read this chapter.

## Using the Wreq Library

The [*Wreq* library](http://www.serpentine.com/wreq/tutorial.html) is an easy way to fetch data from the web. The example in this section fetches DBPedia (i.e., the semantic web version of Wikipedia) data in JSON and RDF N3 formats, and also fetches the index page from my web site. I will introduce you to the *Lens* library for extracting data from data structures, and we will also use *Lens* in a later chapter when writing a program to play Backjack.

We will be using function **get** in the **Network.Wreq** module that has a type signature:

```haskell{line-numbers: false}
get::String -> IO (Response Data.ByteString.Lazy.Internal.ByteString)
```

We will be using the **OverloadedStrings** language extension to facilitate using both **[Char]** strings and **ByteString** data types. Note: In the GHCi repl you can use **:set -XOverloadedStrings**.

We use function **get** to return JSON data; here is a bit of the JSON data returned from calling **get** using the URI for my web site:

```haskell{line-numbers: false}
Response {responseStatus = Status {statusCode = 200, statusMessage = "OK"},
          responseVersion = HTTP/1.1,
          responseHeaders =
		    [("Date","Sat, 15 Oct 2016 16:00:59 GMT"),
		     ("Content-Type","text/html"),
             ("Transfer-Encoding","chunked"),
             ("Connection","keep-alive")],
          responseBody = "<!DOCTYPE html>\r\n<html>\r\n<head><title>Mark Watson: consultant specializing in artificial intelligence, natural language processing, and machine\r\n    learning</title>\r\n    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\r\n    <meta name=\"msvalidate.01\" content=\"D980F894E94AA6335FB595676DFDD5E6\"/>\r\n    <link href=\"/css/bootstrap.min.css\" rel=\"stylesheet\" type=\"text/css\">\r\n    <link href=\"/css/bootstrap-theme.min.css\" rel=\"stylesheet\" type=\"text/css\">\r\n    <link href=\"/css/mark.css\" rel=\"stylesheet\" type=\"text/css\">\r\n    <link rel=\"manifest\" href=\"/manifest.json\">\r\n    <style type=\"text/css\">
          body {\r\n        padding-top: 60px;\r\n    }</style>\r\n\r\n    <link rel=\"canonical\" href=https://www.markwatson.com/ />\r\n</head>\r\n<body  href=\"http://blog.markwatson.com\">Blog</a></li>\r\n
          <li class=\"\"><a href=\"/books/\">My Books</a>
```

As an example, the *Lens* expression for extracting the response status code is (**r** is the **IO** **Response** data returned from calling **get**):

```haskell{line-numbers: false}
(r ^. responseStatus . statusCode)
```

**responseStatus** digs into the top level response structure and **statusCode** digs further in to fetch the code 200. To get the actual contents of the web page we can use the **responseBody** function:

{```haskell{line-numbers: false}
(r ^. responseBody)
```

Here is the code for the entire example:

```haskell{line-numbers: false}
{-# LANGUAGE OverloadedStrings #-}

-- reference: http://www.serpentine.com/wreq/tutorial.html

module HttpClientExample where

import Network.Wreq
import Control.Lens  -- for ^. ^?
import Data.Maybe (fromJust)

fetchURI uri = do
  putStrLn $ "\n\n***  Fetching " ++ uri
  r <- get uri
  putStrLn $ "status code: " ++ (show (r ^. responseStatus . statusCode))
  putStrLn $ "content type: " ++ (show (r ^? responseHeader "Content-Type"))
  putStrLn $ "respose body: " ++ show (fromJust (r ^? responseBody))
  
main :: IO ()
main = do
  -- JSON from DBPedia
  fetchURI "http://dbpedia.org/data/Sedona_Arizona.json"
  -- N3 RDF from DBPedia
  fetchURI "http://dbpedia.org/data/Sedona_Arizona.n3"
  -- my web site
  fetchURI "http://markwatson.com"
```


This Haskell code utilizes the `wreq` library to perform simple HTTP requests and fetch data from various URIs. Let's analyze the core components:

* **Import Statements**

   * `Network.Wreq`:  The primary library for handling HTTP requests.
   * `Control.Lens`:  Provides convenient lens operators like `^.`, `^?` for accessing data within complex structures.
   * `Data.Maybe`:  Includes the `fromJust` function to safely extract values from `Maybe` types.

* **`fetchURI` Function**

   * This function takes a URI as input.
   * It performs an HTTP GET request to the specified URI.
   * It prints details about the response, including the status code, content type (if available), and the response body.
   * Note: The use of `fromJust` assumes that the `responseBody` is always present in the response. In a real-world scenario, error handling would be essential to deal with potential missing response bodies.

* **`main` Function**

   * The `main` function demonstrates the usage of `fetchURI`.
   * It makes HTTP requests to three different URIs:
      * A JSON resource from DBPedia.
      * An N3 RDF resource from DBPedia.
      * A personal website ([http://markwatson.com](http://markwatson.com)).


This example produces a lot of printout, so I a just showing a small bit here (the text from the body is not shown):

```haskell{line-numbers: false}
*Main> :l HttpClientExample
[1 of 1] Compiling HttpClientExample ( HttpClientExample.hs, interpreted )
Ok, modules loaded: HttpClientExample.
*HttpClientExample> main

***  Fetching http://dbpedia.org/data/Sedona_Arizona.json
status code: 200
content type: Just "application/json"
respose body: "{\n  \"http://en.wikipedia.org/wiki/Sedona_Arizona\" : { \"http://xmlns.com/foaf/0.1/primaryTopic\" : [ { \"type\" : \"uri\", \"value\" : \"http://dbpedia.org/resource/Sedona_Arizona\" } ] } ,\n  \"http://dbpedia.org/resource/Sedona_Arizona\" : { \"http://www.w3.org/2002/07/owl#sameAs\" : [ { \"type\" : \"uri\", \"value\" : \"http://dbpedia.org/resource/Sedona_Arizona\" } ] ,\n    \"http://www.w3.org/2000/01/rdf-schema#label\" : [ { \"type\" : \"literal\", \"value\" : \"Sedona Arizona\" , \"lang\" : \"en\" } ] ,\n    \"http://xmlns.com/foaf/0.1/isPrimaryTopicOf\" : [ { \"type\" : \"uri\", \"value\" : \"http://en.wikipedia.org/wiki/Sedona_Arizona\" } ] ,\n    \"http://www.w3.org/ns/prov#wasDerivedFrom\" : [ { \"type\" : \"uri\", \"value\" : \"http://en.wikipedia.org/wiki/Sedona_Arizona?oldid=345939723\" } ] ,\n    \"http://dbpedia.org/ontology/wikiPageID\" : [ { \"type\" : \"literal\", \"value\" : 11034313 , \"datatype\" : \"http://www.w3.org/2001/XMLSchema#integer\" } ] ,\n    \"http://dbpedia.org/ontology/wikiPageRevisionID\" : [ { \"type\" : \"literal\", \"value\" : 345939723 , \"datatype\" : \"http://www.w3.org/2001/XMLSchema#integer\" } ] ,\n    \"http://dbpedia.org/ontology/wikiPageRedirects\" : [ { \"type\" : \"uri\", \"value\" : \"http://dbpedia.org/resource/Sedona,_Arizona\" } ] }\n}\n"

***  Fetching http://dbpedia.org/data/Sedona_Arizona.n3
status code: 200
content type: Just "text/n3; charset=UTF-8"
respose body: "@prefix foaf:\t<http://xmlns.com/foaf/0.1/> .\n@prefix wikipedia-en:\t<http://en.wikipedia.org/wiki/> .\n@prefix dbr:\t<http://dbpedia.org/resource/> .\nwikipedia-en:Sedona_Arizona\tfoaf:primaryTopic\tdbr:Sedona_Arizona .\n@prefix owl:\t<http://www.w3.org/2002/07/owl#> .\ndbr:Sedona_Arizona\towl:sameAs\tdbr:Sedona_Arizona .\n@prefix rdfs:\t<http://www.w3.org/2000/01/rdf-schema#> .\ndbr:Sedona_Arizona\trdfs:label\t\"Sedona Arizona\"@en ;\n\tfoaf:isPrimaryTopicOf\twikipedia-en:Sedona_Arizona .\n@prefix prov:\t<http://www.w3.org/ns/prov#> .\ndbr:Sedona_Arizona\tprov:wasDerivedFrom\t<http://en.wikipedia.org/wiki/Sedona_Arizona?oldid=345939723> .\n@prefix dbo:\t<http://dbpedia.org/ontology/> .\ndbr:Sedona_Arizona\tdbo:wikiPageID\t11034313 ;\n\tdbo:wikiPageRevisionID\t345939723 ;\n\tdbo:wikiPageRedirects\t<http://dbpedia.org/resource/Sedona,_Arizona> ."

***  Fetching http://markwatson.com
status code: 200
content type: Just "text/html"
respose body: "<!DOCTYPE html>\r\n<html>\r\n<head><title>Mark Watson: consultant specializing in  ...
```

You might want to experiment in the GHCi repl with the **get** function and *Lens*. If so, this will get you started:

```haskell{line-numbers: false}
*Main> :set -XOverloadedStrings
*Main> r <- get "http://dbpedia.org/data/Sedona_Arizona.json"
*Main> :t r
r :: Response ByteString
*Main> (r ^. responseStatus . statusCode)
200
*Main> (r ^? responseHeader "Content-Type")
Just "application/json"
*Main> fromJust (r ^? responseHeader "Content-Type")
"application/json"
*Main> (fromJust (r ^? responseBody))
"{\n  \"http://en.wikipedia.org/wiki/Sedona_Arizona\" : { ... not shown ... \"
```

In the following section we will use the *HandsomeSoup* library for parsing HTML.

## Using the **HandsomeSoup** Library for Parsing HTML

We will now use the [Handsome Soup](https://github.com/egonSchiele/HandsomeSoup) library to parse HTML. Handsome Soup allows us to use CSS style selectors to extract specific elements from the HTML from a web page. The HXT lower level library provides modeling HTML (and XML) as a tree structure and an [*Arrow*](https://wiki.haskell.org/Arrow) style interface for traversing the tree structures and extract data. Arrows are a generalization of monads to manage calculations given a context. I will touch upon just enough material on Arrows for you to understand the examples in this chapter. Handsome Soup also provides a high level utility function **fromUrl** to fetch web pages; the type of **fromUrl** is:

```haskell{line-numbers: false}
fromUrl
  :: String -> IOSArrow b (Data.Tree.NTree.TypeDefs.NTree XNode)
```

We will not work directly with the tree structure of the returned data, we will simply use the accessor functions to extract the data we need. Before looking at the example code listing, let's look at this extraction process (**doc** is the tree structured data returned from calling **fromUrl**):

```haskell{line-numbers: false}
  links <- runX $ doc >>> css "a" ! "href"
```

The **runX** function runs arrow computations for us. **doc** is a tree data structure, **css** allows us to pattern match on specific HTML elements.

Here we are using CSS style selection for all "a" anchor HTML elements and digging into the element to return the element attribute "href" value for each "a" anchor element. In a similar way, we can select all "img" image elements and dig down into the matched elements to fetch the "src" attributes:

```haskell{line-numbers: false}
  imageSrc <- runX $ doc >>> css "img" ! "src"
```

We can get the full body text:

```haskell{line-numbers: false}
  allBodyText <- runX $ doc >>> css "body" //> getText
```

The operator **//>** applied to the function **getText** will get all text in all nested elements inside the *body* element. If we had used the operator **/>** then we would only have fetched the text at the top level of the body element.

Here is the full example source listing:

```haskell{line-numbers: false}
{-# LANGUAGE OverloadedStrings #-}

-- references: https://github.com/egonSchiele/HandsomeSoup
--             http://adit.io/posts/2012-04-14-working_with_HTML_in_haskell.html

module Main where

import Text.XML.HXT.Core
import Text.HandsomeSoup


main :: IO ()
main = do
  let doc = fromUrl "http://markwatson.com/"
  putStrLn "\n\n ** LINKS:\n"
  links <- runX $ doc >>> css "a" ! "href"
  mapM_ putStrLn links
  h2 <- runX $ doc >>> css "h2" ! "href"
  putStrLn "\n\n ** ALL H2 ELEMENTS::\n"
  mapM_ putStrLn h2
  imageSrc <- runX $ doc >>> css "img" ! "src"
  putStrLn "\n\n ** ALL IMG ELEMENTS:\n"
  mapM_ putStrLn imageSrc
  allBodyText <- runX $ doc >>> css "body" //> getText
  putStrLn "\n\n ** TEXT FROM BODY ELEMENT:\n"
  mapM_ putStrLn allBodyText
  pText <- runX $ doc >>> css "p" //> getText -- //> gets all contained text
                                              -- />  gets only directly
                                              --     contained text
  putStrLn "\n\n ** ALL P ELEMENTS:\n"
  mapM_ putStrLn pText
```


This Haskell code utilizes the `HandsomeSoup` and `HXT` libraries to parse and extract specific elements from an HTML document fetched from the URL "[http://markwatson.com/](http://markwatson.com/)". Here's a breakdown of its functionality:

1. **Import Libraries:** 
   - `Text.XML.HXT.Core`: Provides core functions for HTML/XML parsing and transformation.
   - `Text.HandsomeSoup`: Offers convenient CSS selector-based operations on parsed HTML.

2. **`main` Function:**
   - `fromUrl`: Fetches the HTML content from the specified URL.
   - `runX`: Executes HXT transformations and returns the results.
   - `css "a" ! "href"`: Extracts the values of the "href" attributes from all anchor (`<a>`) elements.
   - `css "h2" ! "href"`: Extracts the values of the "href" attributes from all `<h2>` elements (likely to be an empty list since `<h2>` elements don't typically have "href" attributes).
   - `css "img" ! "src"`: Extracts the values of the "src" attributes from all image (`<img>`) elements.
   - `css "body" //> getText`: Extracts all text content within the `<body>` element.
   - `css "p" //> getText`: Extracts all text content within all `<p>` (paragraph) elements.
   - `mapM_ putStrLn`: Prints each extracted element on a separate line.


**Key Points:**

- This code demonstrates web scraping using `HandsomeSoup` for CSS selector-based extraction.
- HXT transformations facilitate navigating and extracting data from the parsed HTML structure.
- The actual output content will depend on the current structure of the "[http://markwatson.com/](http://markwatson.com/)" website.

This example prints out several hundred lines; here is the first bit of output:

```haskell{line-numbers: false}
*Main> :l HandsomeSoupTest.hs 
[1 of 1] Compiling HandsomeSoupTest ( HandsomeSoupTest.hs, interpreted )
Ok, modules loaded: HandsomeSoupTest.
*HandsomeSoupTest> main
 ** LINKS:
/
/consulting/
http://blog.markwatson.com
/books/
/opensource/
/fun/
https://github.com/mark-watson
https://plus.google.com/117612439870300277560
https://twitter.com/mark_l_watson
https://www.wikidata.org/wiki/Q18670263
http://markwatson.com/index.rdf
http://markwatson.com/index.ttl

 ** ALL IMG ELEMENTS:
/pictures/Markws.jpg

 ** TEXT FROM BODY ELEMENT:
   ...
```

I find HandsomeSoup to be very convenient for picking apart HTML data fetched from web pages. Writing a good spider for any given web site is a process of understanding how the HTML for the web site is structured and what information you need to collect. I strongly suggest that you work with the web page to be spider open in a web browser with "show source code" in another browser tab. Then open an interactive GHCi repl and experiment using the HandsomeSoup APIs to get the data you need.

## Web Scraping Wrap Up

There are many Haskell library options for web scraping and cleaning data. In this chapter I showed you just what I use in my projects.

The material in this chapter and the chapters on text processing and linked data should be sufficient to get you started using online data sources in your applications.