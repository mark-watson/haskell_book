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

Example RDF N3 triples (subject, predicate, object) might look like:

{lang="sparql",linenos=off}
~~~~~~~~
<http://www.markwatson.com>
  <http://dbpedia.org/ontology/owner>
  "Mark Watson" .
~~~~~~~~

Element of triples can be URIs or string constants. Triples are often written all on one line; I split it to three lines to fit the page width. Here the subject is the URI for my web site, the predicate is a URI defining an ownership relationship, and the object is a string literal.

If you want to see details for any property or other URI you see, then "follow your nose" and open the URI in a web browser. For example remove the brackets from the [owner property URI <http://dbpedia.org/ontology/owner>](http://dbpedia.org/ontology/owner) and open it in a web browser. For working with RDF data programmatically, it is convenient using full URI. For humans reading RDF, the N3 notation is better because it supports defining URI standard prefixes for use as abbreviations; for example:

{lang="sparql",linenos=off}
~~~~~~~~
prefix ontology: <http://dbpedia.org/ontology/>

<http://www.markwatson.com>
  ontology:owner
  "Mark Watson" .
~~~~~~~~

If you wanted to find all things that I own (assuming this data was in a public RDF repository, which it isn't) then we might think to match the pattern:


{lang="sparql",linenos=off}
~~~~~~~~
prefix ontology: <http://dbpedia.org/ontology/>

?subject ontology:owner "Mark Watson"
~~~~~~~~

And return all URIs matching the variable **?subject** as the query result. This is the basic idea of making SPARQL queries.

The following SPARQL query will be implemented later in Haskell using the HSparql library:

{lang="sparql",linenos=on}
~~~~~~~~
prefix resource: <http://dbpedia.org/resource/>
prefix dbpprop: <http://dbpedia.org/property/>
prefix foaf: <http://xmlns.com/foaf/0.1/>

SELECT *
WHERE {
    ?s dbpprop:genre resource:Web_browser .
    ?s foaf:name ?name .
} LIMIT 5
~~~~~~~~

In this last SPARQL query example, the triple patterns we are trying to match are inside a *WHERE* clause. Notice that in the two triple patterns, the subject field of each is the variable **?s**. The first pattern matches all DBPedia triples with a predicate <http://dbpedia.org/property/genre> and an object equal to <http://dbpedia.org/resource/Web_browser>. We then find all triples with the same subject but with a predicate equal to <http://xmlns.com/foaf/0.1/name>.

Each result from this query will contain two values for variables **?s** and **?name**: a DBPedia URI for some thing and the name for that thing. Later we will run this query using Haskell code and you can see what the output might look like.

Sometimes when I am using a specific SPARQL query in an application, I don't bother defining prefixes and just use URIs in the query. As an example, suppose I want to return the Wikipedia (or DBPedia) abstract for IBM. I might use a query such as:

{lang="sparql",linenos=on}
~~~~~~~~
select * where {
  <http://dbpedia.org/resource/IBM>
  <http://dbpedia.org/ontology/abstract>
  ?o .
  FILTER langMatches(lang(?o), "EN")
} LIMIT 100
~~~~~~~~

If you try this query using the [web interface for DBPedia SPARQL queries](http://dbpedia.org/sparql/) you get just one result because of the FILTER option that only returns English language results. You could also use FR for French results, GE for German results, etc.
         
## A Haskell HTTP Based SPARQL Client

One approach to query the DBPedia SPARQL endpoint is to build a HTTP GET request, send it to the SPARQL endpoint server, and parse the returned XML response. We will start with this simple approach. You will recognize the SPARQL query from the last section:

{lang="haskell",linenos=on}
~~~~~~~~
{-# LANGUAGE OverloadedStrings #-}

module HttpSparqlClient where

import Network.HTTP.Conduit (simpleHttp)
import Network.HTTP.Base (urlEncode)
import Text.XML.HXT.Core
import Text.HandsomeSoup
import qualified Data.ByteString.Lazy.Char8 as B

buildQuery :: String -> [Char]
buildQuery sparqlString =
  "http://dbpedia.org/sparql/?query=" ++ urlEncode sparqlString
  
main :: IO ()
main = do
  let query = buildQuery "select * where {<http://dbpedia.org/resource/IBM> <http://dbpedia.org/ontology/abstract> ?o . FILTER langMatches(lang(?o), \"EN\")} LIMIT 100"
  res <- simpleHttp query
  let doc = readString []  (B.unpack res)
  putStrLn "\nAbstracts:\n"
  abstracts <- runX $ doc >>> css "binding" >>>
                              (getAttrValue "name" &&& (deep getText))
  print abstracts
~~~~~~~~

The function **buildQuery** defined in lined 11-13 takes any SPARQL query, URL encodes it so it can be passed as part of a URI, and builds a query string for the DBPedia SPARQL endpoint. The returned data is in XML format. In lines 23-24 I am using the **XHT** parsing library to extract the names (values bound to the variable **?o** in the query in line 17). I covered the use of the **HandsomeSoup** parsing library in the chapter *Web Scraping*.

We use **runX** to execute a series of operations on an XML document (the **doc** variable). We first select all elements in **doc** that have the CSS class **binding** using the **css** function. Next we extract the value of the **name** attribute from each selected element using **getAttrValue** and also extract the text inside the element using the function **deep**.
The **&&&** operator is used to combine the two values for the name attribute and the element text into a tuple.

In the **main** function, we use the utility function **simpleHttp** in line 20 to fetch the results as a ByteString and in line 21 we unpack this to a regular Haskell String.

{lang="haskell",linenos=on}
~~~~~~~~
Prelude> :l HttpSparqlClient.hs 
[1 of 1] Compiling HttpSparqlClient ( HttpSparqlClient.hs, interpreted )
Ok, modules loaded: HttpSparqlClient.
*HttpSparqlClient> main

Abstracts:

[("o","International Business Machines Corporation (commonly referred to as IBM) is an American multinational technology and consulting corporation, with corporate headquarters in Armonk, New York.
  ...)]
~~~~~~~~

## Querying Remote SPARQL Endpoints

We will write some code in this section to make the example query to get the names of web browsers from DBPedia. In the last section we made a SPARQL query using fairly low level Haskell libraries. We will be using the high level library *HSparql* to build SPARQL queries and call the DBPedia SPARQL endpoint.

The example in this section can be found in *SparqlClient/TestSparqlClient.hs*. In the **main** function notice how I have commented out printouts of the raw query results. Because Haskell is type safe, extracting the values wrapped in query results requires knowing RDF element return types. I will explain this matching after the program listing:

{lang="haskell",linenos=on}
~~~~~~~~
-- simple experiments with the excellent HSparql library

module Main where

import Database.HSparql.Connection (BindingValue(Bound))

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

main :: IO ()
main = do
  sq1 <- selectQuery "http://dbpedia.org/sparql" companyAbstractSelect
  --putStrLn "\nRaw results of company abstract SPARQL query:\n"
  --print sq1
  putStrLn "\nWeb browser names extracted from the company abstract query results:\n"
  case sq1 of
    Just a -> print $ map (\[Bound (LNode (PlainLL s _))] -> s) a
    Nothing -> putStrLn "nothing"
  sq2 <- selectQuery "http://dbpedia.org/sparql" companyTypeSelect
  --putStrLn "\nRaw results of company type SPARQL query:\n"
  --print sq2
  putStrLn "\nWeb browser names extracted from the company type query results:\n"
  case sq2 of
    Just a -> print $ map (\[Bound (UNode  s)] -> s) a
    Nothing -> putStrLn "nothing"
  sq3 <- selectQuery "http://dbpedia.org/sparql" webBrowserSelect
  --putStrLn "\nRaw results of SPARQL query:\n"
  --print sq3
  putStrLn "\nWeb browser names extracted from the query results:\n"
  case sq3 of
    Just a -> print $ map (\[Bound (LNode (PlainLL s _))] -> s) a
    Nothing -> putStrLn "nothing"
~~~~~~~~


### Haskell Code for SPARQL Queries with HSparql

This provided Haskell code demonstrates the use of the HSparql library to interact with a SPARQL endpoint (specifically, DBpedia) to perform semantic queries on linked data.

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

#### `main` Function

The `main` function serves as the entry point of the program. It performs the following actions:

1. **Query Execution**: It executes each of the defined SPARQL queries against the DBpedia SPARQL endpoint using the `selectQuery` function. This function returns the query results wrapped in a `Maybe` type to handle potential query failures.

2. **Result Processing**: The code then pattern matches on the query results to extract and process the relevant information.  It handles both successful query results (`Just a`) and potential query failures (`Nothing`).

3. **Output**: Finally, the extracted information (primarily names in this case) is printed to the console, providing the user with the desired results of the SPARQL queries.

#### Summary

In summary, this Haskell code showcases a practical example of how to leverage the HSparql library to interact with a SPARQL endpoint (DBpedia) to retrieve and process structured data from the Semantic Web. It demonstrates the construction of SPARQL queries, their execution, and the subsequent handling and presentation of query results. 



**Notes on matching result types of query results:**

You will notice how I have commented out print statements in the last example. When trying new queries you need to print out the results in order to know how to extract the wrapped query results. Let's look at a few examples:

If we print the value for **sq1**:

{linenos=off}
~~~~~~~~
Raw results of company abstract SPARQL query:

Just [[Bound (LNode (PlainLL "Edinburgh University Press ...
~~~~~~~~

we see that inside a **Just** we have a list of lists. Each inner list is a **Bound** wrapping types defined in HSparql. We would unwrap **sq1** using:

{lang="haskell",linenos=on}
~~~~~~~~
  case sq1 of
    Just a -> print $ map (\[Bound (LNode (PlainLL s _))] -> s) a
    Nothing -> putStrLn "nothing"
~~~~~~~~

In a similar way I printed out the values of **sq2** and **sq3** to see the form os **case** statement I would need to unwrap them.

The output from this example with three queries to the DBPedia SPARQL endpoint is:

{linenos=on}
~~~~~~~~
Web browser names extracted from the company abstract query results in sq1:

["Edinburgh University Press \195\168 una casa editrice scientifica di libri accademici e riviste, con sede a Edimburgo, in Scozia.","Edinburgh University Press \195\169 uma editora universit\195\161ria com base em Edinburgh, Esc\195\179cia.","Edinburgh University Press is a scholarly publisher of academic books and journals, based in Edinburgh, Scotland."]

The type of company is extracted from the company type query results in sq2:

["http://dbpedia.org/resource/Publishing"]

Web browser names extracted from the query results in sq3:

["Grail","ViolaWWW","Kirix Strata","SharkWire Online","MacWeb","Camino","eww","TenFourFox","WiseStamp","X-Smiles","Netscape Navigator 2","SimpleTest","AWeb","IBrowse","iCab","ANT Fresco","Netscape Navigator 9.0","HtmlUnit","ZAC Browser","ELinks","ANT Galio","Nintendo DSi Browser","Nintendo DS Browser","Netscape Navigator","NetPositive","OmniWeb","Abaco","Flock","Steel","Kazehakase","GNU IceCat","FreeWRL","UltraBrowser","AMosaic","NetCaptor","NetSurf","Netscape Browser","SlipKnot","ColorZilla","Internet Channel","Obigo Browser","Swiftfox","BumperCar","Swiftweasel","Swiftdove","IEs4Linux","MacWWW","IBM Lotus Symphony","SlimBrowser","cURL","FoxyTunes","Iceweasel","MenuBox","Timberwolf web browser","Classilla","Rockmelt","Galeon","Links","Netscape Navigator","NCSA Mosaic","MidasWWW","w3m","PointerWare","Pogo Browser","Oregano","Avant Browser","Wget","NeoPlanet","Voyager","Amaya","Midori","Sleipnir","Tor","AOL Explorer"]
~~~~~~~~

## Linked Data and Semantic Web Wrap Up

If you enjoyed the material on linked data and DBPedia then please do get a free copy of one of my semantic web books [on my website book page](http://www.markwatson.com/books/) as well as other SPARQL and linked data tutorials on the web.

Structured and semantically labelled data, when it is available, is much easier to process and use effectively than raw text and HTML collected from web sites.

