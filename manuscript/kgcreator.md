# Knowledge Graph Creator

The large project described here processes raw text inputs and generates data for knowledge graphs in formats for both the Neo4J graph database and in RDF format for semantic web and linked data applications.

This application works by identifying entities in text. Example entity types are people, companies, country names, city names, broadcast network names, political party names, and university names. We saw earlier code for detecting entities in the chapter on natural language processing (NLP) and we will reuse this code. We will discuss later three strategies for reusing code from different projects.

The following figure shows part of a Neo4J Knowledge Graph created with the example code. This graph has shortened labels in displayed nodes but Neo4J offers a web browser-based console that lets you interactively explore Knowledge Graphs. We don't cover setting up Neo4J here so please use the [Neo4J documentation](https://neo4j.com/docs/operations-manual/current/introduction/). As an introduction to RDF data, the semantic web, and linked data you can get free copies of my two books [Practical Semantic Web and Linked Data Applications, Common Lisp Edition](http://markwatson.com/opencontentdata/book_lisp.pdf) and [Practical Semantic Web and Linked Data Applications, Java, Scala, Clojure, and JRuby Edition](http://markwatson.com/opencontentdata/book_java.pdf).

{width=60%}
![Part of a Knowledge Graph shown in Neo4J web application console](neo4j.png)

There are two versions of this project that deal with generating duplicate data in  two ways:

- As either Neo4J Cypher data or RDF triples data are created, store generated data in a SQLite embedded database. Check this database before writing new output data.
- Ignore the problem of generating duplicate data and filter out duplicates in the outer processing pipeline that uses the Knowledge Graph Creator as one processing step.

For my own work I choose the second method since filtering duplicates is as easy as a few Makefile targets (the following listing is in the file **Makefile** in the directory
**haskell_book/source-code/knowledge_graph_creator_pure**):


```bash{line-numbers: false}
all: gendata rdf cypher

gendata:
	stack build --fast --exec Dev-exe

rdf:
	echo "Removing duplicate RDF statements"
	awk '!visited[$$0]++' out.n3 > output.n3
	rm -f out.n3

cypher:
	echo "Removing duplicate Cypher statements"
	awk '!visited[$$0]++' out.cypher > output.cypher
	rm -f out.cypher
```

The Haskell KGCreator application we develop here writes output files *out.n3* (N3 is a RDF data format) and *out.cypher* (Cypher is the import output format and query language for the Neo4J open source and commercial graph database). The **awk** commands remove duplicate lines and write de-duplicated data to *output.n3* and *output.cypher*.

We will use this second approach but the next section provides sufficient information and a link to alternative code in case you are interested in using SQLite to prevent duplicate data generation.

### Notes for Using SQLite to Avoid Duplicates (Optional Material)

We saw two methods of avoiding duplicates in  generated data in the last section. If you want to use the first method for avoiding generating duplicate data, I leave it as an exercise but here are some notes to get you started: you can then modify the example code by using the utility function **Blackboard.h** in the directory **knowledge_graph_creator_pure/src/fileutils** and implement the logic seen below for checking new generated data to see if it is in the SQLite database. This first method as it also is a good example for wrapping the embedded SQLite library in an IO Monad and is left as an exercise, otherwise skip this section.

Before you write either an RDF statement or a Neo4J Cypher data import statement, check to see if the statement has already been written using something like:

```haskell{line-numbers: false}
  check <- blackboard_check_key new_data_uri
  if check
     ....
```

and after writing a RDF statement or a Neo4J Cypher data import statement, write it to the temporary SQLite database using something like:

```haskell{line-numbers: false}
  blackboard_write newStatementString
```

For the rest of the chapter we will use the approach of not keeping track of generated data in SQLite and instead remove duplicates during post-processing using the standard **awk** command line utility.

This section is optional. In the rest of this chapter we use the example code in **knowledge_graph_creator_pure**.

## Code Layout For the KGCreator Project and strategies for sharing Haskell code between projects

We will reuse the code for finding entities that we studied in an earlier chapter. There are several ways to reuse code from multiple local Haskell projects:

- In a project's cabal file, use relative paths to the source code for other projects. This is my preferred way to work but has the drawback that the stack command *sdist* to make a distribution tarball will not work with relative paths. If this is a problem for you then create relative symbolic file links to the source directories in other projects.
- In your project's stack.yaml file, add the other project's name and path as a *extra-deps*.
- In library projects, define a *packages* definition and install the library globally on your system.

I almost always use the first method on my projects with dependencies on other local projects I work on and this is also the approach we use here. The relevant lines in the file KGCreator.cabal are:

```haskell{line-numbers: true}
library
  exposed-modules:
      CorefWebClient
      NlpWebClient
      ClassificationWebClient
      DirUtils
      FileUtils
      BlackBoard
      GenTriples
      GenNeo4jCypher
      Apis
      Categorize
      NlpUtils
      Summarize
      Entities
  other-modules:
      Paths_KGCreator
      BroadcastNetworkNamesDbPedia
      Category1Gram
      Category2Gram
      CityNamesDbpedia
      CompanyNamesDbpedia
      CountryNamesDbpedia
      PeopleDbPedia
      PoliticalPartyNamesDbPedia
      Sentence
      Stemmer
      TradeUnionNamesDbPedia
      UniversityNamesDbPedia

  hs-source-dirs:
      src
      src/webclients
      src/fileutils
      src/sw
      src/toplevel
      ../NlpTool/src/nlp
      ../NlpTool/src/nlp/data
```

This is a standard looking *cabal* file except for lines 37 and 38 where the source paths reference the example code for the **NlpTool** application developed in a previous chapter. The exposed module **BlackBoard** (line 8) is not used but I leave it in the *cabal* file in case you want to experiment with recording generated data in SQLite to avoid data duplication. You are likely to also want to use **BlackBoard** if you modify this example to continuously process incoming data in a production system. This is left as an exercise.

Before going into too much detail on the implementation let's look at the layout of the project code:

{lang="bash",linenos=on}
~~~~~~~~
src/fileutils:
BlackBoard.hs	DirUtils.hs	FileUtils.hs

../NlpTool/src/nlp:
Categorize.hs	Entities.hs	NlpUtils.hs	Sentence.hs	Stemmer.hs	Summarize.hs	data

../NlpTool/src/nlp/data:
BroadcastNetworkNamesDbPedia.hs	CompanyNamesDbpedia.hs		TradeUnionNamesDbPedia.hs
Category1Gram.hs		CountryNamesDbpedia.hs		UniversityNamesDbPedia.hs
Category2Gram.hs		PeopleDbPedia.hs
CityNamesDbpedia.hs		PoliticalPartyNamesDbPedia.hs

src/sw:
GenNeo4jCypher.hs	GenTriples.hs

src/toplevel:
Apis.hs
~~~~~~~~

As mentioned before, we are using the Haskell source fies in a relative path **../NlpTool/src/...** and the local **src** directory. We discuss this code in the next few sections.

## The Main Event: Detecting Entities in Text

A primary task in KGCreator is to identify entities (people, places, etc.) in text and then we will create RDF and Neo4J Cypher data statements using these entities, knowledge of the origin of text data and general relationships between entities.

We will use the top level code that we developed earlier that is located in the directory **../NlpTool/src/nlp** (please see the chapter **Natural Language Processing Tools** for more detail):

- Categorize.hs - categorizes text into categories like news, religion, business, politics, science, etc.
- Entities.hs - identifies entities like people, companies, places, new broadcast networks, labor unions, etc. in text
- Summarize.hs - creates an extractive summary of text

The KGCreator Haskell application looks in a specified directory for text files to process. For each file with a **.txt** extension there should be a matching file with the extension **.meta** that contains a single line: the URI of the web location where the corresponding text was found. The reason we need this is that we want to create graph knowledge data from information found in text sources and the original location of the data is important to preserve. In other words, we want to know where the data elements in our knowledge graph came from.

We have not looked at an example of using command line arguments yet so let's go into some detail on how we do this.
Previously when we have defined an output target executable in our **.cabal** file,
in this case *KGCreator-exe*, we could use stack to build the executable and run it with:

{lang="bash",linenos=off}
~~~~~~~~
stack build --fast --exec KGCreator-exe"
~~~~~~~~

Now, we have an executable that requires two arguments: a source input directory and the file root for generated RDF and Cypher output files. We can pass command line arguments using this notation:

{lang="bash",linenos=off}
~~~~~~~~
stack build --fast --exec "KGCreator-exe test_data outtest"
~~~~~~~~

The two command line arguments are:

- **test_data** which is the file path of a local directory containing the input files
- **outtest** which is the root file name for generated Neo4J Cypher and RDF output files

If you are using KGCreator in production, then you will want to copy the compiled and linked executable file **KGCreator-exe** to somewhere on your *PATH* like */usr/local/bin*.

The following listing shows the file **app/Main.hs**, the main program for this example that handles command line arguments and calls two top level functions in **src/toplevel/Apis.hs**:

```haskell{line-numbers: true}
module Main where

import System.Environment (getArgs)
import Apis (processFilesToRdf, processFilesToNeo4j)

main :: IO ()
main = do
  args <- getArgs
  case args of
    [] -> error "must supply an input directory containing text and meta files"
    [_] -> error "in addition to an input directory, also specify a root file name for the generated RDF and Cypher files"
    [inputDir, outputFileRoot] -> do
        processFilesToRdf   inputDir $ outputFileRoot ++ ".n3"
        processFilesToNeo4j inputDir $ outputFileRoot ++ ".cypher"
    _ -> error "too many arguments"
```

Here we use **getArgs** in line8 to fetch a list of command line arguments and verify that at least two arguments have been provided. Then we call the functions **processFilesToRdf** and **processFilesToNeo4j** and the functions they call in the next three sections.

## Utility Code for Generating RDF

The code for generating RDF and for generating Neo4J Cypher data is similar. We start with the code to generate RDF triples. Before we look at the code, let's start with a few lines of generated RDF:

```{line-numbers: false}
<http://dbpedia.org/resource/The_Wall_Street_Journal> 
  <http://knowledgebooks.com/schema/aboutCompanyName> 
  "Wall Street Journal" .
<https://newsshop.com/june/z902.html>
  <http://knowledgebooks.com/schema/containsCountryDbPediaLink>
  <http://dbpedia.org/resource/Canada> .
```

The next listing shows the file **src/sw/GenTriples.hs** that finds entities like broadcast network names, city names, company names, people's names, political party names, and university names in text and generates RDF triple data. If you need to add more entity types for your own applications, then use the following steps:

- Look at the format of entity data for the **NlpTool** example and add names for the new entity type you  are adding.
- Add a utility function to find instances of the new entity type to **NlpTools**. For example, if you are adding a new entity type "park names", then copy the code for **companyNames** to **parkNames**, modify as necessary, and export **parkNames**.
- In the following code, add new code for the new entity helper function after lines 10, 97, 151, and 261. Use the code for **companyNames** as an example.

The map *category_to_uri_map** created in lines 36 to 84 maps a topic name to a linked Data URI that describes the topic. For example, we would not refer to an information source as being about the topic "economics", but would instead refer to a linked data URI like **<http://knowledgebooks.com/schema/topic/economics>**. The utility function **uri_from_categor** takes a text description of a topic like "economy" and converts it to an appropriate URI using the map *category_to_uri_map**.

The utility function **textToTriple** takes a file path to a text input file and a path to  meta file path, calculates the text string representing the generated triples for the input text file, and returns the result wrapped in an IO monad.

```haskell{line-numbers: true}
module GenTriples
  ( textToTriples
  , category_to_uri_map
  ) where

import Categorize (bestCategories)
import Entities
  ( broadcastNetworkNames
  , cityNames
  , companyNames
  , countryNames
  , peopleNames
  , politicalPartyNames
  , tradeUnionNames
  , universityNames
  )
import FileUtils
  ( MyMeta
  , filePathToString
  , filePathToWordTokens
  , readMetaFile
  , uri
  )
import Summarize (summarize, summarizeS)

import qualified Data.Map as M
import Data.Maybe (fromMaybe)

generate_triple :: [Char] -> [Char] -> [Char] -> [Char]
generate_triple s p o = s ++ "  " ++ p ++ "  " ++ o ++ " .\n"

make_literal :: [Char] -> [Char]
make_literal s = "\"" ++ s ++ "\""

category_to_uri_map :: M.Map [Char] [Char]
category_to_uri_map =
  M.fromList
    [ ("news_weather", "<http://knowledgebooks.com/schema/topic/weather>")
    , ("news_war", "<http://knowledgebooks.com/schema/topic/war>")
    , ("economics", "<http://knowledgebooks.com/schema/topic/economics>")
    , ("news_economy", "<http://knowledgebooks.com/schema/topic/economics>")
    , ("news_politics", "<http://knowledgebooks.com/schema/topic/politics>")
    , ("religion", "<http://knowledgebooks.com/schema/topic/religion>")
    , ( "religion_buddhism"
      , "<http://knowledgebooks.com/schema/topic/religion/buddhism>")
    , ( "religion_islam"
      , "<http://knowledgebooks.com/schema/topic/religion/islam>")
    , ( "religion_christianity"
      , "<http://knowledgebooks.com/schema/topic/religion/christianity>")
    , ( "religion_hinduism"
      , "<http://knowledgebooks.com/schema/topic/religion/hinduism>")
    , ( "religion_judaism"
      , "<http://knowledgebooks.com/schema/topic/religion/judaism>")
    , ("chemistry", "<http://knowledgebooks.com/schema/topic/chemistry>")
    , ("computers", "<http://knowledgebooks.com/schema/topic/computers>")
    , ("computers_ai", "<http://knowledgebooks.com/schema/topic/computers/ai>")
    , ( "computers_ai_datamining"
      , "<http://knowledgebooks.com/schema/topic/computers/ai/datamining>")
    , ( "computers_ai_learning"
      , "<http://knowledgebooks.com/schema/topic/computers/ai/learning>")
    , ( "computers_ai_nlp"
      , "<http://knowledgebooks.com/schema/topic/computers/ai/nlp>")
    , ( "computers_ai_search"
      , "<http://knowledgebooks.com/schema/topic/computers/ai/search>")
    , ( "computers_ai_textmining"
      , "<http://knowledgebooks.com/schema/topic/computers/ai/textmining>")
    , ( "computers/programming"
      , "<http://knowledgebooks.com/schema/topic/computers/programming>")
    , ( "computers_microsoft"
      , "<http://knowledgebooks.com/schema/topic/computers/microsoft>")
    , ( "computers/programming/ruby"
      , "<http://knowledgebooks.com/schema/topic/computers/programming/ruby>")
    , ( "computers/programming/lisp"
      , "<http://knowledgebooks.com/schema/topic/computers/programming/lisp>")
    , ("health", "<http://knowledgebooks.com/schema/topic/health>")
    , ( "health_exercise"
      , "<http://knowledgebooks.com/schema/topic/health/exercise>")
    , ( "health_nutrition"
      , "<http://knowledgebooks.com/schema/topic/health/nutrition>")
    , ("mathematics", "<http://knowledgebooks.com/schema/topic/mathematics>")
    , ("news_music", "<http://knowledgebooks.com/schema/topic/music>")
    , ("news_physics", "<http://knowledgebooks.com/schema/topic/physics>")
    , ("news_sports", "<http://knowledgebooks.com/schema/topic/sports>")
    ]

uri_from_category :: [Char] -> [Char]
uri_from_category key =
  fromMaybe ("\"" ++ key ++ "\"") $ M.lookup key category_to_uri_map

textToTriples :: FilePath -> [Char] -> IO [Char]
textToTriples file_path meta_file_path = do
  word_tokens <- filePathToWordTokens file_path
  contents <- filePathToString file_path
  putStrLn $ "** contents:\n" ++ contents ++ "\n"
  meta_data <- readMetaFile meta_file_path
  let people = peopleNames word_tokens
  let companies = companyNames word_tokens
  let countries = countryNames word_tokens
  let cities = cityNames word_tokens
  let broadcast_networks = broadcastNetworkNames word_tokens
  let political_parties = politicalPartyNames word_tokens
  let trade_unions = tradeUnionNames word_tokens
  let universities = universityNames word_tokens
  let a_summary = summarizeS contents
  let the_categories = bestCategories word_tokens
  let filtered_categories =
        map (uri_from_category . fst) $
        filter (\(name, value) -> value > 0.3) the_categories
  putStrLn "\nfiltered_categories:"
  print filtered_categories
  --putStrLn "a_summary:"
  --print a_summary
  --print $ summarize contents

  let summary_triples =
        generate_triple
          (uri meta_data)
          "<http://knowledgebooks.com/schema/summaryOf>" $
        "\"" ++ a_summary ++ "\""
  let category_triples =
        concat
          [ generate_triple
            (uri meta_data)
            "<http://knowledgebooks.com/schema/news/category/>"
            cat
          | cat <- filtered_categories
          ]
  let people_triples1 =
        concat
          [ generate_triple
            (uri meta_data)
            "<http://knowledgebooks.com/schema/containsPersonDbPediaLink>"
            (snd pair)
          | pair <- people
          ]
  let people_triples2 =
        concat
          [ generate_triple
            (snd pair)
            "<http://knowledgebooks.com/schema/aboutPersonName>"
            (make_literal (fst pair))
          | pair <- people
          ]
  let company_triples1 =
        concat
          [ generate_triple
            (uri meta_data)
            "<http://knowledgebooks.com/schema/containsCompanyDbPediaLink>"
            (snd pair)
          | pair <- companies
          ]
  let company_triples2 =
        concat
          [ generate_triple
            (snd pair)
            "<http://knowledgebooks.com/schema/aboutCompanyName>"
            (make_literal (fst pair))
          | pair <- companies
          ]
  let country_triples1 =
        concat
          [ generate_triple
            (uri meta_data)
            "<http://knowledgebooks.com/schema/containsCountryDbPediaLink>"
            (snd pair)
          | pair <- countries
          ]
  let country_triples2 =
        concat
          [ generate_triple
            (snd pair)
            "<http://knowledgebooks.com/schema/aboutCountryName>"
            (make_literal (fst pair))
          | pair <- countries
          ]
  let city_triples1 =
        concat
          [ generate_triple
            (uri meta_data)
            "<http://knowledgebooks.com/schema/containsCityDbPediaLink>"
            (snd pair)
          | pair <- cities
          ]
  let city_triples2 =
        concat
          [ generate_triple
            (snd pair)
            "<http://knowledgebooks.com/schema/aboutCityName>"
            (make_literal (fst pair))
          | pair <- cities
          ]
  let bnetworks_triples1 =
        concat
          [ generate_triple
            (uri meta_data)
            "<http://knowledgebooks.com/schema/containsBroadCastDbPediaLink>"
            (snd pair)
          | pair <- broadcast_networks
          ]
  let bnetworks_triples2 =
        concat
          [ generate_triple
            (snd pair)
            "<http://knowledgebooks.com/schema/aboutBroadCastName>"
            (make_literal (fst pair))
          | pair <- broadcast_networks
          ]
  let pparties_triples1 =
        concat
          [ generate_triple
            (uri meta_data)
            "<http://knowledgebooks.com/schema/containsPoliticalPartyDbPediaLink>"
            (snd pair)
          | pair <- political_parties
          ]
  let pparties_triples2 =
        concat
          [ generate_triple
            (snd pair)
            "<http://knowledgebooks.com/schema/aboutPoliticalPartyName>"
            (make_literal (fst pair))
          | pair <- political_parties
          ]
  let unions_triples1 =
        concat
          [ generate_triple
            (uri meta_data)
            "<http://knowledgebooks.com/schema/containsTradeUnionDbPediaLink>"
            (snd pair)
          | pair <- trade_unions
          ]
  let unions_triples2 =
        concat
          [ generate_triple
            (snd pair)
            "<http://knowledgebooks.com/schema/aboutTradeUnionName>"
            (make_literal (fst pair))
          | pair <- trade_unions
          ]
  let universities_triples1 =
        concat
          [ generate_triple
            (uri meta_data)
            "<http://knowledgebooks.com/schema/containsUniversityDbPediaLink>"
            (snd pair)
          | pair <- universities
          ]
  let universities_triples2 =
        concat
          [ generate_triple
            (snd pair)
            "<http://knowledgebooks.com/schema/aboutTradeUnionName>"
            (make_literal (fst pair))
          | pair <- universities
          ]
  return $
    concat
      [ people_triples1
      , people_triples2
      , company_triples1
      , company_triples2
      , country_triples1
      , country_triples2
      , city_triples1
      , city_triples2
      , bnetworks_triples1
      , bnetworks_triples2
      , pparties_triples1
      , pparties_triples2
      , unions_triples1
      , unions_triples2
      , universities_triples1
      , universities_triples2
      , category_triples
      , summary_triples
      ]
```

The code in this file could be shortened but having repetitive code for each entity type hopefully makes it easier for you to understand how it works:

This code processes text from a given file and generates RDF triples (subject-predicate-object statements) based on the extracted information. 

**Key Functionality**

1. **`category_to_uri_map`**: A map defining the correspondence between categories and their URIs.
2. **`uri_from_category`**:  Retrieves the URI associated with a category, or returns the category itself in quotes if not found in the map.
3. **`textToTriples`**: 
    * Takes file paths for the text and metadata files.
    * Extracts various entities (people, companies, countries, etc.) and categories from the text.
    * Generates RDF triples representing:
        * Summary of the text
        * Categories associated with the text
        * Links between the text's URI and identified entities (people, companies, etc.)
        * Additional information about each identified entity (e.g., name)
    * Returns a concatenated string of all generated triples.

**Pattern**

The code repeatedly follows this pattern for different entity types:

1. Identify entities of a certain type (e.g., `peopleNames`).
2. Generate triples linking the text's URI to the entity's URI.
3. Generate triples providing additional information about the entity itself.

**Purpose**

This code is designed for knowledge extraction and representation. It aims to transform unstructured text into structured RDF data, making it suitable for semantic web applications or knowledge graphs. 

**Note:**

* The code relies on external modules (`Categorize`, `Entities`, `FileUtils`, `Summarize`) for specific functionalities like categorization, entity recognition, file handling, and summarization.
* The quality of the generated triples will depend on the accuracy of these external modules. 


## Utility Code for Generating Cypher Input Data for Neo4J

Now we will generate Neo4J Cypher data. In order to keep the implementation simple, both the RDF and Cypher generation code starts with raw text and performs the NLP analysis to find entities. This example could be refactored to perform the NLP analysis just one time but in practice you will likely be working with either RDF or NEO4J and so you will probably extract just the code you need from this example (i.e., either the RDF or Cypher generation code).

 Before we look at the code, let's start with a few lines of generated Neo4J Cypher import data:

{linenos=off}
~~~~~~~~
CREATE (newsshop_com_june_z902_html_news)-[:ContainsCompanyDbPediaLink]->(Wall_Street_Journal)
CREATE (Canada:Entity {name:"Canada", uri:"<http://dbpedia.org/resource/Canada>"})
CREATE (newsshop_com_june_z902_html_news)-[:ContainsCountryDbPediaLink]->(Canada)
CREATE (summary_of_abcnews_go_com_US_violent_long_lasting_tornadoes_threaten_oklahoma_texas_storyid63146361:Summary {name:"summary_of_abcnews_go_com_US_violent_long_lasting_tornadoes_threaten_oklahoma_texas_storyid63146361", uri:"<https://abcnews.go.com/US/violent-long-lasting-tornadoes-threaten-oklahoma-texas/story?id=63146361>", summary:"Part of the system that delivered severe weather to the central U.S. over the weekend is moving into the Northeast today, producing strong to severe storms -- damaging winds, hail or isolated tornadoes can't be ruled out. Severe weather is forecast to continue on Tuesday, with the western storm moving east into the Midwest and parts of the mid-Mississippi Valley."})
~~~~~~~~

The following listing shows the file **src/sw/GenNeo4jCypher.hs**. This code is very similar to the code for generating RDF in the last section. The same notes for adding your own new entity notes in the last section are also relevant here.

Notice that we import in line 29 the map **category_to_uri_map** that was defined in the last section. The function **neo4j_category_node_defs** defined in lines 35 to 43 creates category graph nodes for each category in the map **category_to_uri_map**.  These nodes will be referenced by graph nodes created in the functions **create_neo4j_node**, **create_neo4j_lin**, **create_summary_node**, and **create_entity_node**. The top level function is **textToCypher** that is similar to the function **textToTriples** in the last section.

```haskell{line-numbers: true}
{-# LANGUAGE OverloadedStrings #-}

module GenNeo4jCypher
  ( textToCypher
  , neo4j_category_node_defs
  ) where

import Categorize (bestCategories)
import Data.List (isInfixOf)
import Data.Char (toLower)
import Data.String.Utils (replace)
import Entities
  ( broadcastNetworkNames
  , cityNames
  , companyNames
  , countryNames
  , peopleNames
  , politicalPartyNames
  , tradeUnionNames
  , universityNames
  )
import FileUtils
  ( MyMeta
  , filePathToString
  , filePathToWordTokens
  , readMetaFile
  , uri
  )
import GenTriples (category_to_uri_map)
import Summarize (summarize, summarizeS)

import qualified Data.Map as M
import Data.Maybe (fromMaybe)
import Database.SQLite.Simple

-- for debug:
import Data.Typeable (typeOf)

neo4j_category_node_defs :: [Char]
neo4j_category_node_defs =
  replace
    "/"
    "_"
    $ concat
    [ "CREATE (" ++ c ++ ":CategoryType {name:\"" ++ c ++ "\"})\n"
    | c <- M.keys category_to_uri_map
    ]

uri_from_category :: p -> p
uri_from_category s = s -- might want the full version from GenTriples

repl :: Char -> Char
repl '-' = '_'
repl '/' = '_'
repl '.' = '_'
repl c = c

filterChars :: [Char] -> [Char]
filterChars = filter (\c -> c /= '?' && c /= '=' && c /= '<' && c /= '>')

create_neo4j_node :: [Char] -> ([Char], [Char])
create_neo4j_node uri =
  let name =
        (map repl (filterChars
                    (replace "https://" "" (replace "http://" "" uri)))) ++
                    "_" ++
                    (map toLower node_type)
      node_type =
        if isInfixOf "dbpedia" uri
          then "DbPedia"
          else "News"
      new_node =
        "CREATE (" ++
        name ++ ":" ++
        node_type ++ " {name:\"" ++ (replace " " "_" name) ++
        "\", uri:\"" ++ uri ++ "\"})\n"
   in (name, new_node)

create_neo4j_link :: [Char] -> [Char] -> [Char] -> [Char]
create_neo4j_link node1 linkName node2 =
  "CREATE (" ++ node1 ++ ")-[:" ++ linkName ++ "]->(" ++ node2 ++ ")\n"

create_summary_node :: [Char] -> [Char] -> [Char]
create_summary_node uri summary =
  let name =
        "summary_of_" ++
        (map repl $
         filterChars (replace "https://" "" (replace "http://" "" uri)))
      s1 = "CREATE (" ++ name ++ ":Summary {name:\"" ++ name ++ "\", uri:\""
      s2 = uri ++ "\", summary:\"" ++ summary ++ "\"})\n"
   in s1 ++ s2

create_entity_node :: ([Char], [Char]) -> [Char]
create_entity_node entity_pair = 
  "CREATE (" ++ (replace " " "_" (fst entity_pair)) ++ 
  ":Entity {name:\"" ++ (fst entity_pair) ++ "\", uri:\"" ++
  (snd entity_pair) ++ "\"})\n"

create_contains_entity :: [Char] -> [Char] -> ([Char], [Char]) -> [Char]
create_contains_entity relation_name source_uri entity_pair =
  let new_person_node = create_entity_node entity_pair
      new_link = create_neo4j_link source_uri
                   relation_name
                   (replace " " "_" (fst entity_pair))
  in
    (new_person_node ++ new_link)

entity_node_helper :: [Char] -> [Char] -> [([Char], [Char])] -> [Char]
entity_node_helper relation_name node_name entity_list =
  concat [create_contains_entity
           relation_name node_name entity | entity <- entity_list]

textToCypher :: FilePath -> [Char] -> IO [Char]
textToCypher file_path meta_file_path = do
  let prelude_nodes = neo4j_category_node_defs
  putStrLn "+++++++++++++++++ prelude node defs:"
  print prelude_nodes
  word_tokens <- filePathToWordTokens file_path
  contents <- filePathToString file_path
  putStrLn $ "** contents:\n" ++ contents ++ "\n"
  meta_data <- readMetaFile meta_file_path
  putStrLn "++ meta_data:"
  print meta_data
  let people = peopleNames word_tokens
  let companies = companyNames word_tokens
  putStrLn "^^^^ companies:"
  print companies
  let countries = countryNames word_tokens
  let cities = cityNames word_tokens
  let broadcast_networks = broadcastNetworkNames word_tokens
  let political_parties = politicalPartyNames word_tokens
  let trade_unions = tradeUnionNames word_tokens
  let universities = universityNames word_tokens
  let a_summary = summarizeS contents
  let the_categories = bestCategories word_tokens
  let filtered_categories =
        map (uri_from_category . fst) $
        filter (\(name, value) -> value > 0.3) the_categories
  putStrLn "\nfiltered_categories:"
  print filtered_categories
  let (node1_name, node1) = create_neo4j_node (uri meta_data)
  let summary1 = create_summary_node (uri meta_data) a_summary
  let category1 =
        concat
          [ create_neo4j_link node1_name "Category" cat
          | cat <- filtered_categories
          ]
  let pp = entity_node_helper "ContainsPersonDbPediaLink" node1_name people
  let cmpny = entity_node_helper "ContainsCompanyDbPediaLink" node1_name companies
  let cntry = entity_node_helper "ContainsCountryDbPediaLink" node1_name countries
  let citys = entity_node_helper "ContainsCityDbPediaLink" node1_name cities
  let bnet = entity_node_helper "ContainsBroadcastNetworkDbPediaLink"
                                node1_name broadcast_networks
  let ppart = entity_node_helper "ContainsPoliticalPartyDbPediaLink"
                                node1_name political_parties
  let tunion = entity_node_helper "ContainsTradeUnionDbPediaLink"
                                  node1_name trade_unions
  let uni = entity_node_helper "ContainsUniversityDbPediaLink"
                               node1_name universities
  return $ concat [node1, summary1, category1, pp, cmpny, cntry, citys, bnet,
                   ppart, tunion, uni]
```

This code generates Cypher queries to create nodes and relationships in a Neo4j graph database based on extracted information from text.

**Core Functionality:**

- `neo4j_category_node_defs`: Defines Cypher statements to create nodes for predefined categories.
- `uri_from_category`: Placeholder, potentially for full URI mapping (not used in this code).
- `create_neo4j_node`: Creates a Cypher statement to create a node representing either a DbPedia entity or a News article, based on the URI.
- `create_neo4j_link`:  Creates a Cypher statement to create a relationship between two nodes.
- `create_summary_node`: Creates a Cypher statement to create a node representing a summary of the text.
- `create_entity_node`: Creates a Cypher statement to create a node representing an entity.
- `create_contains_entity`: Creates Cypher statements to create an entity node and link it to a source node with a specified relationship.
- `entity_node_helper`: Generates Cypher statements for creating entity nodes and relationships for a list of entities.
- `textToCypher`:
    - Processes text from a file and its metadata.
    - Extracts various entities and categories from the text.
    - Generates Cypher statements to:
        - Create nodes for the text itself, its summary, and identified categories.
        - Create nodes and relationships for entities (people, companies, etc.) mentioned in the text.
    - Returns a concatenated string of all generated Cypher statements.

**Purpose:**

This code is designed to transform text into a structured representation within a Neo4j graph database. This allows for querying and analyzing relationships between entities and categories extracted from the text. 


Because the top level function is **textToCypher** returns a string wrapped in a monad, it is possible to add "debug"" print statements in **textToCypher**. I left many such debug statements in the example code to help you understand the data that is being operated on. I leave it as an exercise to remove these print statements if you use this code in your own projects and no longer need to see the debug output.


## Top Level API Code for Handling Knowledge Graph Data Generation

So far we have looked at processing command line arguments and processing individual input files. Now we look at higher level utility APIs for processing an entire directory of input files. The following listing shows the file API.hs that contains the two top level helper functions we saw in **app/Main.hs**.

The functions **processFilesToRdf** and **processFilesToNeo4j** both have the function type signature **FilePath->FilePath->IO()** and are very similar except for calling different helper functions to generate RDF triples or Cypher input graph data:

```haskell{line-numbers: true}
module Apis
  ( processFilesToRdf
  , processFilesToNeo4j
  ) where

import FileUtils
import GenNeo4jCypher
import GenTriples (textToTriples)

import qualified Database.SQLite.Simple as SQL

import Control.Monad (mapM)
import Data.String.Utils (replace)
import System.Directory (getDirectoryContents)

import Data.Typeable (typeOf)

processFilesToRdf :: FilePath -> FilePath -> IO ()
processFilesToRdf dirPath outputRdfFilePath = do
  files <- getDirectoryContents dirPath :: IO [FilePath]
  let filtered_files = filter isTextFile files
  let full_paths = [dirPath ++ "/" ++ fn | fn <- filtered_files]
  putStrLn "full_paths:"
  print full_paths
  let r =
        [textToTriples fp1 (replace ".txt" ".meta" fp1)
        |
        fp1 <- full_paths] :: [IO [Char]]
  tripleL <-
    mapM (\fp -> textToTriples fp (replace ".txt" ".meta" fp)) full_paths
  let tripleS = concat tripleL
  putStrLn tripleS
  writeFile outputRdfFilePath tripleS

processFilesToNeo4j :: FilePath -> FilePath -> IO ()
processFilesToNeo4j dirPath outputRdfFilePath = do
  files <- getDirectoryContents dirPath :: IO [FilePath]
  let filtered_files = filter isTextFile files
  let full_paths = [dirPath ++ "/" ++ fn | fn <- filtered_files]
  putStrLn "full_paths:"
  print full_paths
  let prelude_node_defs = neo4j_category_node_defs
  putStrLn
    ("+++++  type of prelude_node_defs is: " ++
     (show (typeOf prelude_node_defs)))
  print prelude_node_defs
  cypher_dataL <-
    mapM (\fp -> textToCypher fp (replace ".txt" ".meta" fp)) full_paths
  let cypher_dataS = concat cypher_dataL
  putStrLn cypher_dataS
  writeFile outputRdfFilePath $ prelude_node_defs ++ cypher_dataS
```

Since both of these functions return IO monads, I could add "debug" print statements that should be helpful in understanding the data being operated on.

The code defines two functions for processing text files in a directory:

* **`processFilesToRdf`**: Processes text files and their corresponding metadata files (with `.meta` extension) in a given directory. It converts the content into RDF triples using `textToTriples` and writes the concatenated triples to an output RDF file.

* **`processFilesToNeo4j`**:  Processes text files and metadata files to generate Cypher statements for Neo4j. It uses `textToCypher` to create Cypher data from file content, combines it with predefined Neo4j category node definitions, and writes the result to an output file.

### Key Points

* **File Handling:**  It utilizes `getDirectoryContents` for file listing, `filter` for selecting text files, and `writeFile` for output.

* **Data Transformation:** `textToTriples` and `textToCypher` are functions that convert text content into RDF triples and Cypher statements, respectively.

* **Metadata Handling:**  It expects metadata files with the same base name as the text files but with a `.meta` extension.

* **Output:** The generated RDF triples or Cypher statements are written to specified output files.

* **`neo4j_category_node_defs`:** A variable holding predefined Cypher node definitions for Neo4j categories.

This code relies on external modules like `FileUtils`, `GenNeo4jCypher`, `GenTriples`, and `Database.SQLite.Simple` for specific functionalities.



## Wrap Up for Automating the Creation of Knowledge Graphs

The code in this chapter will provide you with a good start for creating both test knowledge graphs and for generating data for production. In practice, generated data should be reviewed before use and additional data manually generated as needed. It is good practice to document required manual changes because this documentation can be used in the requirements for updating the code in this chapter to more closely match your knowledge graph requirements.
