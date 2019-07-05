# Knowledge Graph Creator

The large project described here processes raw text inputs and generates data for knowledge graphs in formats for both the Neo4J graph database and in RDF format for semantic web and linked data applications.

This application works by identifying entities in text. Example entity types are people, companies, country names, city names, broadcast network names, political party names, and university names. We saw earlier code for detecting entities in the chapter on natural language processing (NLP) and we will reuse this code.

There are two versions of this project that deal with generating duplicate data in  two ways:

- As either Neo4J Cypher import data or RDF triples are created, store generated data in a SQLite embedded database. Check this database before writing new output data.
- Ignore the problem of generating duplicate data and filter out duplicates in the outer processing pipeline that uses the Knowledge Graph Creator as one processing step.

For my own work I choose the second method since filtering duplicates is as easy as a few Makefile targets (the following listing is in the file **Makefile** in the directory
**haskell_tutorial_cookbook_examples/knowledge_graph_creator_pure**):

{lang="bash",linenos=off}
````````
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
````````

Because it makes a better example for this book because the implementation is simpler.

### Notes for Using SQLite to Avoid Duplicates

If you want to use the first method you can start with the utility function **Blackboard.h** in the directory **knowledge_graph_creator_pure/src/fileutils**. first method as it also is a good example for wrapping the embedded SQLite library in an IO Monad.

Before you write either an RDF statement or a Neo4J Cypher data import statement, check to see if the statement has already been written using something like:

{lang="haskell",linenos=off}
~~~~~~~
  check <- blackboard_check_key (fst entity_pair)
  if check
     ....

and after writing a RDF statement or a Neo4J Cypher data import statement, write it to the temportary SQLite database using something like:

{lang="haskell",linenos=off}
~~~~~~~
  blackboard_write newStatementString
~~~~~~~

## Code Layout For the KGCreator Project

Before going into too much detail on the implementation let's look at the layout of the project code:

{lang="bash",linenos=off}
````````
knowledge_graph_creator_pure $ ls -R src
fileutils	nlp		sw		toplevel	webclients

src/fileutils:
BlackBoard.hs	DirUtils.hs	FileUtils.hs

src/nlp:
Categorize.hs	Entities.hs	NlpUtils.hs	Sentence.hs	Stemmer.hs	Summarize.hs	data

src/nlp/data:
BroadcastNetworkNamesDbPedia.hs	CompanyNamesDbpedia.hs		TradeUnionNamesDbPedia.hs
Category1Gram.hs		CountryNamesDbpedia.hs		UniversityNamesDbPedia.hs
Category2Gram.hs		PeopleDbPedia.hs
CityNamesDbpedia.hs		PoliticalPartyNamesDbPedia.hs

src/sw:
GenNeo4jCypher.hs	GenTriples.hs

src/toplevel:
Apis.hs
````````

TBD describe code

## The Main Event: Detecting Entities in Text

A primary task in KGCreator is to identify entities (people, places, etc.) in text and then we will create RDF and Neo4J Cypher data statements using these entities, knowledge of the origin of text data and general relationships between entities.

We will use the top level code that we developer earlier that is located in the directory **src/nlp** (please see the chapter **Natural Language Processing Tools** for more detail):

- Categorize.hs - categorizes text into categories like news, religion, business, politics, science, etc.
- Entities.hs - identifies entities like people, companies, places, new broadcast networks, labor unions, etc. in text
- NlpUtils.hs - general utilities
- Sentence.hs - segments raw text into individual sentences
- Stemmer.hs - performs stemming on text
- Summarize.hs - creates an extractive summary of text

TBD


