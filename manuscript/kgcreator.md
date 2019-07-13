# Knowledge Graph Creator

The large project described here processes raw text inputs and generates data for knowledge graphs in formats for both the Neo4J graph database and in RDF format for semantic web and linked data applications.

This application works by identifying entities in text. Example entity types are people, companies, country names, city names, broadcast network names, political party names, and university names. We saw earlier code for detecting entities in the chapter on natural language processing (NLP) and we will reuse this code. We will discuss later three strategies for reusing code from different projects.

There are two versions of this project that deal with generating duplicate data in  two ways:

- As either Neo4J Cypher import data or RDF triples are created, store generated data in a SQLite embedded database. Check this database before writing new output data.
- Ignore the problem of generating duplicate data and filter out duplicates in the outer processing pipeline that uses the Knowledge Graph Creator as one processing step.

For my own work I choose the second method since filtering duplicates is as easy as a few Makefile targets (the following listing is in the file **Makefile** in the directory
**haskell_tutorial_cookbook_examples/knowledge_graph_creator_pure**):

{lang="bash",linenos=off}
~~~~~~~~
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
~~~~~~~~

Because it makes a better example for this book because the implementation is simpler.

### Notes for Using SQLite to Avoid Duplicates

If you want to use the first method you can start with the utility function **Blackboard.h** in the directory **knowledge_graph_creator_pure/src/fileutils**. first method as it also is a good example for wrapping the embedded SQLite library in an IO Monad.

Before you write either an RDF statement or a Neo4J Cypher data import statement, check to see if the statement has already been written using something like:

{lang="haskell",linenos=off}
~~~~~~~
  check <- blackboard_check_key (fst entity_pair)
  if check
     ....
~~~~~~~

and after writing a RDF statement or a Neo4J Cypher data import statement, write it to the temportary SQLite database using something like:

{lang="haskell",linenos=off}
~~~~~~~
  blackboard_write newStatementString
~~~~~~~

## Code Layout For the KGCreator Project and strategies for sharing Haskell code between projects

There are several ways to reuse code from multiple local Haskell projects:

- In a project's cabal file, use relative paths to the source code for other projects. This is my preferred way to work but has the drawback that the stack command *sdist* to make a distribution tarball will not work with relative paths. If this is a problem for you then creak relative symbolic file links to the source directories in other projects.
- In yur project's stack.yaml file, add the other project's name and path as a *extra-deps*.
- In library projects, define a *packages* definition and install the library globally on your system.

I almost always use the first method on my projects with dependencies on other local projects I work on and this is also the approach we use here. The relavent lines in the file KGCreator.cabal are:

{lang="haskell",linenos=on}
~~~~~~~~
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
~~~~~~~~

TBD: discuss relevant lines


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

TBD describe code

## The Main Event: Detecting Entities in Text

A primary task in KGCreator is to identify entities (people, places, etc.) in text and then we will create RDF and Neo4J Cypher data statements using these entities, knowledge of the origin of text data and general relationships between entities.

We will use the top level code that we developer earlier that is located in the directory **src/nlp** (please see the chapter **Natural Language Processing Tools** for more detail):

- Categorize.hs - categorizes text into categories like news, religion, business, politics, science, etc.
- Entities.hs - identifies entities like people, companies, places, new broadcast networks, labor unions, etc. in text
- Summarize.hs - creates an extractive summary of text

The KGCreator Haskell application looks in a specified directory for text files to process. For each file with a **.txt** extension there should be a matching file with the extension **.meta** that contains a single line: the URI of the web location where the corresponding text was found. The reason we need this is that we want to create graph knowledge bases of information found in text sources and the original location of the data is important to preserve.

We have not looked at an example of using command line arguments yet so let's go into some detail.
Previously when we have defined an output target executable in our **.cabal** file,
in this case *KGCreator-exe*, we can use stack to build the executable and run it with:

{lang="bash",linenos=off}
~~~~~~~~
stack build --fast --exec KGCreator-exe"
~~~~~~~~

Now, we have an executabel that requires two arguments: a source inoput directory and the file root for generated RDF and Cypher output files. We can pass command line arguments using this notation:

{lang="bash",linenos=off}
~~~~~~~~
stack build --fast --exec "KGCreator-exe test_data outtest"
~~~~~~~~

TBD



{lang="haskell",linenos=on}
~~~~~~~~
module Main where

import System.Environment (getArgs)
import Apis (processFilesToRdf, processFilesToNeo4j)

main :: IO ()
main
  --  TBD: add command line argument processing
 = do
  args <- getArgs
  case args of
    [] -> error "must supply an input directory containing text and meta files"
    [_] -> error "in addition to an input directory, also specify a root file name for the generated RDF and Cypher files"
    [inputDir, outputFileRoot] -> do
        processFilesToRdf   inputDir $ outputFileRoot ++ ".n3"
        processFilesToNeo4j inputDir $ outputFileRoot ++ ".cypher"
    _ -> error "too many arguments"
~~~~~~~~

## Top Level Code for Generating RDF


{lang="haskell",linenos=on}
~~~~~~~~
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
~~~~~~~~

## Top Level Code for Generating Cypher Input Data for Neo4J




{lang="haskell",linenos=on}
~~~~~~~~
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
~~~~~~~~


## Top Level API Code for Handling Knowledge Graph Data Generation


API.hs:

{lang="haskell",linenos=on}
~~~~~~~~
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
~~~~~~~~


