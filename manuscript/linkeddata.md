# Linked Data and the Semantic Web

I am going to show you how to query semantic web data sources on the web and provide examples for how you might use this data in applications. I have written two previous books on the semantic web, one covering Common Lisp and the other covering JVM languages Java, Scala, Clojure, and Ruby. You can read these recent eBooks online for free on [my Leanpub author’s page](https://leanpub.com/u/markwatson). If you enjoy the light introduction in this chapter then please do read my other eBooks that cover in more detail semantic web material on RDF, RDFS, and SPARQL.

I like to think of the semantic web and linked data resources as:

- A source of structured data on the web. These resources are called SPARQL endpoints.
- Data is represented by data triples: subject, predicate, and object. The subject of one triple can be the object of another triple. Predicates are relationships; a few examples: "owns", "is part of", "author of", etc.
- Data that is accessed via the SPARQL query language.
- A source of data that may or may not be available. SPARQL endpoints are typically available for free use and they are sometimes unavailable. Although not covered here, I sometimes work around this problem by adding a caching layer to SPARQL queries (access key being a SPARQL query string, the value being the query results). This caching speeds up development and running unit tests, and sometimes saves a customer demo when a required SPARQL endpoint goes offline at an inconvenient time.

DBPedia is the semantic web version of [Wikipedia](http://wiki.dbpedia.org/). The many millions of data triples that make up DBPedia are mostly derived from the structured "info boxes" on Wikipedia pages.

As you are learning SPARQL use the [DBPedia SPARQL endpoint](http://dbpedia.org/sparql) to practice. As a practitioner who uses linked data, for any new project I start by identifying SPARQL endpoints for possibly useful data. I then interactively experiment with SPARQL queries to extract the data I need. Only when I am satisfied with the choice of SPARQL endpoints and SPARQL queries do I write any code to automatically fetch linked data for my application.

**Pro** **tip:** I mentioned SPARQL query caching. I sometimes cache query results in a local database, saving the returned RDF data indexed by the SPARQL query. You can also store the cache timestamp and refresh the cache every few weeks as needed. In addition to making development and unit testing faster, your applications will be more resilient.

In the last chapter "Natural Language Processing Tools" we resolved entities in natural language text to DBPedia (semantic web SPAQL endpoint for Wikipedia) URIs. Here we will use some of these URIs to demonstrate fetching real world knowledge that you might want to use in applications.


## The SPARQL Query Language

![SPARQL Client Architecture](FIG_SparqlClient.jpg)

Example RDF N3 triples (subject, predicate, object) might look like:

```sparql{line-numbers: false}
<http://www.markwatson.com>
  <http://dbpedia.org/ontology/owner>
  "Mark Watson" .
```

Element of triples can be URIs or string constants. Triples are often written all on one line; I split it to three lines to fit the page width. Here the subject is the URI for my web site, the predicate is a URI defining an ownership relationship, and the object is a string literal.

If you want to see details for any property or other URI you see, then "follow your nose" and open the URI in a web browser. For example remove the brackets from the [owner property URI <http://dbpedia.org/ontology/owner>](http://dbpedia.org/ontology/owner) and open it in a web browser. For working with RDF data programmatically, it is convenient using full URI. For humans reading RDF, the N3 notation is better because it supports defining URI standard prefixes for use as abbreviations; for example:

```sparql{line-numbers: false}
prefix ontology: <http://dbpedia.org/ontology/>

<http://www.markwatson.com>
  ontology:owner
  "Mark Watson" .
```

If you wanted to find all things that I own (assuming this data was in a public RDF repository, which it isn't) then we might think to match the pattern:


```sparql{line-numbers: false}
prefix ontology: <http://dbpedia.org/ontology/>

?subject ontology:owner "Mark Watson"
```

And return all URIs matching the variable **?subject** as the query result. This is the basic idea of making SPARQL queries.

The following SPARQL query will be implemented later in Haskell using the HSparql library:

```sparql{line-numbers: false}
prefix resource: <http://dbpedia.org/resource/>
prefix dbpprop: <http://dbpedia.org/property/>
prefix foaf: <http://xmlns.com/foaf/0.1/>

SELECT *
WHERE {
    ?s dbpprop:genre resource:Web_browser .
    ?s foaf:name ?name .
} LIMIT 5
```

In this last SPARQL query example, the triple patterns we are trying to match are inside a *WHERE* clause. Notice that in the two triple patterns, the subject field of each is the variable **?s**. The first pattern matches all DBPedia triples with a predicate <http://dbpedia.org/property/genre> and an object equal to <http://dbpedia.org/resource/Web_browser>. We then find all triples with the same subject but with a predicate equal to <http://xmlns.com/foaf/0.1/name>.

Each result from this query will contain two values for variables **?s** and **?name**: a DBPedia URI for some thing and the name for that thing. Later we will run this query using Haskell code and you can see what the output might look like.

Sometimes when I am using a specific SPARQL query in an application, I don't bother defining prefixes and just use URIs in the query. As an example, suppose I want to return the Wikipedia (or DBPedia) abstract for IBM. I might use a query such as:

```sparql{line-numbers: false}
select * where {
  <http://dbpedia.org/resource/IBM>
  <http://dbpedia.org/ontology/abstract>
  ?o .
  FILTER langMatches(lang(?o), "EN")
} LIMIT 100
```

If you try this query using the [web interface for DBPedia SPARQL queries](http://dbpedia.org/sparql/) you get just one result because of the FILTER option that only returns English language results. You could also use FR for French results, GE for German results, etc.
         
## A Haskell HTTP Based SPARQL Client

One approach to query the DBPedia SPARQL endpoint is to build a HTTP GET request, send it to the SPARQL endpoint server, and parse the returned XML response. We will start with this simple approach:

```haskell{line-numbers: true}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Network.HTTP.Client
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Base (urlEncode)
import Network.HTTP.Types.Status (statusCode)
import Text.XML.HXT.Core
import Text.HandsomeSoup
import qualified Data.ByteString.Lazy.Char8 as B

prefixUrl :: String
prefixUrl = "https://dbpedia.org/sparql?format=xml&query="

buildQuery :: String -> String
buildQuery sparqlString = prefixUrl ++ urlEncode sparqlString

main :: IO ()
main = do
  let url = buildQuery "select ?label where {<http://dbpedia.org/resource/IBM> <http://www.w3.org/2000/01/rdf-schema#label> ?label . FILTER langMatches(lang(?label), \"EN\")}"
  manager <- newManager tlsManagerSettings
  initialReq <- parseRequest url
  let req = initialReq
              { requestHeaders =
                  [ ("User-Agent", "HaskellSparqlClient/1.0 (educational example)")
                  , ("Accept",     "application/sparql-results+xml")
                  ]
              }
  response <- httpLbs req manager
  let status = statusCode (responseStatus response)
  if status /= 200
    then putStrLn $ "HTTP error: " ++ show status
    else do
      let body = responseBody response
      let doc  = readString [] (B.unpack body)
      putStrLn "\nIBM rdfs:labels:\n"
      labels <- runX $ doc >>> css "binding" >>> (getAttrValue "name" &&& (deep getText))
      if null labels
        then putStrLn "(no results — check the SPARQL endpoint or query)"
        else mapM_ print labels
```

The constant **prefixUrl** on line 14 specifies the DBPedia SPARQL endpoint URL with an XML format parameter. The function **buildQuery** on line 17 takes any SPARQL query, URL encodes it, and appends it to the endpoint URL. In **main**, we create an HTTP manager with TLS settings (line 22), build a request with custom headers for a User-Agent and to request XML results (lines 24-29), and then execute the request (line 30). We check the HTTP status code and, if successful, parse the XML response. On lines 37-38 I use the **HXT** parsing library with the **HandsomeSoup** CSS selector to extract bindings. I covered the use of the **HandsomeSoup** parsing library in the chapter *Web Scraping*.

We use **runX** to execute a series of operations on an XML document (the **doc** variable). We first select all elements in **doc** that have the CSS class **binding** using the **css** function. Next we extract the value of the **name** attribute from each selected element using **getAttrValue** and also extract the text inside the element using the function **deep**.
The **&&&** operator is used to combine the two values for the name attribute and the element text into a tuple.

## Querying Remote SPARQL Endpoints

We will write some code in this section to make the example query to get the names of web browsers from DBPedia. In the last section we made a SPARQL query using fairly low level Haskell libraries. We will be using the high level library *HSparql* to build SPARQL queries and call the DBPedia SPARQL endpoint.

The example in this section can be found in *SparqlClient/TestSparqlClient.hs*. Because Haskell is type safe, extracting the values wrapped in query results requires knowing RDF element return types. The code defines an **extractBinding** helper function that pattern-matches on the various RDF node types to extract a display string:

```haskell{line-numbers: true}
-- simple experiments with the excellent HSparql library
--
-- HSparql DSL mapping to raw SPARQL:
--   prefix "name" (iriRef url) => PREFIX name: <url>
--   var                        => a fresh ?varN variable
--   triple s p o               => s p o  (in the WHERE clause)
--   resource .:. "Foo"         => name:Foo  (prefixed IRI)
--   SelectQuery { queryVars }  => SELECT ?var1 ?var2 ...

{-# LANGUAGE OverloadedStrings #-}

module Main where

import Database.HSparql.Connection (BindingValue(..))

import Data.RDF hiding (triple)
import Database.HSparql.QueryGenerator
import Database.HSparql.Connection (selectQuery)
    
webBrowserSelect :: Query SelectQuery
webBrowserSelect = do
    resource <- prefix "dbprop" (iriRef "http://dbpedia.org/resource/")
    dbpprop  <- prefix "dbpedia" (iriRef "http://dbpedia.org/property/")
    foaf     <- prefix "foaf" (iriRef "http://xmlns.com/foaf/0.1/")
    x    <- var
    name <- var
    triple x (dbpprop .:. "genre") (resource .:. "Web_browser")
    triple x (foaf .:. "name") name

    return SelectQuery { queryVars = [name] }

companyAbstractSelect :: Query SelectQuery
companyAbstractSelect = do
    resource <- prefix "dbprop" (iriRef "http://dbpedia.org/resource/")
    ontology <- prefix "ontology" (iriRef "http://dbpedia.org/ontology/")
    o <- var
    triple (resource .:. "Edinburgh_University_Press") (ontology .:. "abstract") o
    return SelectQuery { queryVars = [o] }

companyTypeSelect :: Query SelectQuery
companyTypeSelect = do
    resource <- prefix "dbprop" (iriRef "http://dbpedia.org/resource/")
    ontology <- prefix "ontology" (iriRef "http://dbpedia.org/ontology/")
    o <- var
    triple (resource .:. "Edinburgh_University_Press") (ontology .:. "type") o
    return SelectQuery { queryVars = [o] }

-- | Extract a display string from a single binding row.
-- Handles the main RDF node types: language-tagged literals, plain literals,
-- typed literals, URI nodes, and blank nodes.
extractBinding :: [BindingValue] -> String
extractBinding [Bound (LNode (PlainLL s _))] = show s  -- language-tagged literal
extractBinding [Bound (LNode (PlainL s))]    = show s  -- plain literal
extractBinding [Bound (LNode (TypedL s _))]  = show s  -- typed literal
extractBinding [Bound (UNode s)]             = show s  -- URI node
extractBinding [Bound (BNode s)]             = "_:" ++ show s  -- blank node
extractBinding [Bound (BNodeGen i)]          = "_:b" ++ show i -- generated blank node
extractBinding [Unbound]                     = "(unbound)"
extractBinding _                             = "(unexpected binding shape)"

main :: IO ()
main = do
  -- companyAbstractSelect => SELECT ?o WHERE { dbprop:Edinburgh_University_Press ontology:abstract ?o }
  sq1 <- selectQuery "http://dbpedia.org/sparql" companyAbstractSelect
  putStrLn "\nAbstracts extracted from the company abstract query results:\n"
  case sq1 of
    Just a  -> mapM_ (putStrLn . extractBinding) a
    Nothing -> putStrLn "No results returned."

  -- companyTypeSelect => SELECT ?o WHERE { dbprop:Edinburgh_University_Press ontology:type ?o }
  sq2 <- selectQuery "http://dbpedia.org/sparql" companyTypeSelect
  putStrLn "\nTypes extracted from the company type query results:\n"
  case sq2 of
    Just a  -> mapM_ (putStrLn . extractBinding) a
    Nothing -> putStrLn "No results returned."

  -- webBrowserSelect => SELECT ?name WHERE { ?x dbpedia:genre dbprop:Web_browser . ?x foaf:name ?name }
  sq3 <- selectQuery "http://dbpedia.org/sparql" webBrowserSelect
  putStrLn "\nWeb browser names extracted from the query results:\n"
  case sq3 of
    Just a  -> mapM_ (putStrLn . extractBinding) a
    Nothing -> putStrLn "No results returned."
```

### Haskell Code for SPARQL Queries with HSparql

This provided Haskell code demonstrates the use of the HSparql library to interact with a SPARQL endpoint (specifically, DBpedia) to perform semantic queries on linked data.

The comment block at the top of the file (lines 3-8) documents how the HSparql DSL maps to raw SPARQL syntax, which is helpful when learning the library.

#### SPARQL Query Definitions

It begins by defining three SPARQL queries, each constructed using the `Query` monad provided by HSparql. These queries are:

* **`webBrowserSelect`**: 
   * This query aims to retrieve the names of entities categorized as web browsers. 
   * It utilizes prefixes to simplify the representation of URIs within the query. 
   * It selects entities (`x`) that have a "genre" property linking them to the concept of a "Web_browser" and then retrieves their "name."

* **`companyAbstractSelect`**: 
    * This query targets information about the "Edinburgh University Press." 
    * It seeks to retrieve the "abstract" associated with this entity, which provides a concise summary or description.

* **`companyTypeSelect`**:
    * Similar to the previous query, this one focuses on the "Edinburgh University Press" but retrieves its "type," which indicates the category or class it belongs to within the DBpedia ontology.

#### The `extractBinding` Helper

The **extractBinding** function (lines 51-59) pattern-matches on the various RDF node types returned by HSparql to extract a display string. It handles language-tagged literals, plain literals, typed literals, URI nodes, blank nodes, unbound values, and unexpected shapes. This is more robust than inline pattern matching and handles all the cases you might encounter when querying different SPARQL endpoints.

#### `main` Function

The `main` function serves as the entry point of the program. It performs the following actions:

1. **Query Execution**: It executes each of the defined SPARQL queries against the DBpedia SPARQL endpoint using the `selectQuery` function. This function returns the query results wrapped in a `Maybe` type to handle potential query failures.

2. **Result Processing**: The code uses `mapM_` with `extractBinding` to process and print each binding row. It handles both successful query results (`Just a`) and potential query failures (`Nothing`).

3. **Output**: The extracted information is printed to the console, with each result on its own line.

#### Summary

In summary, this Haskell code showcases a practical example of how to leverage the HSparql library to interact with a SPARQL endpoint (DBpedia) to retrieve and process structured data from the Semantic Web. It demonstrates the construction of SPARQL queries, their execution, and the subsequent handling and presentation of query results.

The output from this example with three queries to the DBPedia SPARQL endpoint will show abstracts for Edinburgh University Press, its type(s), and names of web browsers, each printed on its own line.

## Linked Data and Semantic Web Wrap Up

If you enjoyed the material on linked data and DBPedia then please do get a free copy of one of my semantic web books [on my website book page](http://www.markwatson.com/books/) as well as other SPARQL and linked data tutorials on the web.

Structured and semantically labelled data, when it is available, is much easier to process and use effectively than raw text and HTML collected from web sites.

