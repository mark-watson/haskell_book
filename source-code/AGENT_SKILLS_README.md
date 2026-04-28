---
name: haskell-dev
description: Haskell language tutorial, idioms, and API reference for all examples in Mark Watson's Haskell book "Haskell Tutorial and Cookbook". Use this skill for writing Haskell code that accesses LLMs (Gemini, OpenAI, Ollama), SPARQL queries, NLP, web scraping, databases, and more.
---

# Notes for Using AGENT Skills with Haskell Book Examples

This document helps readers set up coding agent skills so that AI assistants can reference the Haskell APIs and patterns from this book when generating code.

## Source code for Gemini, OpenAI, Ollama, SPARQL queries, NLP, web scraping, database example code

```bash
git clone https://github.com/mark-watson/haskell_book.git
```

All the Haskell examples are in the `source-code/` directory. Look in ~/GITHUB/haskell_book/source-code/ for code to reuse.

---

## Haskell Language Tutorial and Idioms

Haskell is a statically-typed, purely functional programming language with lazy evaluation. It provides strong type inference, algebraic data types, and powerful abstraction via type classes and monads.

### Core Syntax

```haskell
-- Printing
main :: IO ()
main = putStrLn "Hello from Haskell!"

-- Variable binding (let and where)
result = let x = 42
             name = "Mark"
         in x + length name

-- Arithmetic (prefix and infix)
sum3 = 1 + 2 + 3       -- => 6
prod  = 2 * (3 + 4)    -- => 14
```

### Imports

```haskell
-- Import a module
import Data.List
import Data.Map (Map)

-- Import specific names from a module
import System.Environment (getArgs, getEnv)
import Data.Text (Text, pack, unpack)

-- Qualified import
import qualified Data.Aeson as Aeson
import qualified Data.ByteString.Lazy as LBS

-- Import with hiding
import Prelude hiding (null)
```

### Functions

```haskell
-- Define a function with type signature
greet :: String -> String
greet name = "Hello, " ++ name ++ "!"

-- Multiple arguments
add :: Int -> Int -> Int
add x y = x + y

-- Pattern matching
factorial :: Integer -> Integer
factorial 0 = 1
factorial n = n * factorial (n - 1)

-- Guards
classify :: Int -> String
classify x
  | x < 0    = "negative"
  | x == 0   = "zero"
  | otherwise = "positive"

-- Anonymous functions (lambdas)
filter (\x -> x > 3) [1, 2, 3, 4, 5]  -- => [4, 5]

-- Where clause
bmi :: Double -> Double -> String
bmi weight height = classify bmiValue
  where
    bmiValue = weight / height ^ 2
    classify b
      | b < 18.5  = "underweight"
      | b < 25.0  = "normal"
      | otherwise  = "overweight"
```

### Control Flow

```haskell
-- if-then-else (always requires both branches; it's an expression)
result = if x == 1
           then "one"
           else "not one"

-- case expression
describe :: Int -> String
describe x = case x of
  0 -> "zero"
  1 -> "one"
  _ -> "something else"

-- Guards (preferred for multiple conditions)
sign :: Int -> String
sign x
  | x < 0    = "negative"
  | x == 0   = "zero"
  | otherwise = "positive"
```

### Data Types

```haskell
-- Algebraic data types
data Color = Red | Green | Blue deriving (Show, Eq)

data Shape = Circle Double
           | Rectangle Double Double
           deriving (Show)

-- Record syntax
data Person = Person
  { personName :: String
  , personAge  :: Int
  } deriving (Show)

-- Newtypes (zero-cost wrapper)
newtype ApiKey = ApiKey String
```

### Lists and Tuples

```haskell
-- Lists (homogeneous)
fruits :: [String]
fruits = ["apple", "banana", "cherry"]

head fruits               -- => "apple"
take 2 fruits             -- => ["apple", "banana"]
fruits ++ ["date"]        -- => ["apple", "banana", "cherry", "date"]

-- List comprehensions
squares = [x * x | x <- [1..5]]                  -- => [1, 4, 9, 16, 25]
evens   = [x | x <- [1..10], even x]             -- => [2, 4, 6, 8, 10]

-- Tuples (heterogeneous, fixed size)
point :: (Double, Double)
point = (1.0, 2.0)
fst point                 -- => 1.0
snd point                 -- => 2.0

-- Maps (from Data.Map)
import qualified Data.Map as Map
config = Map.fromList [("host", "localhost"), ("port", "8080")]
Map.lookup "host" config  -- => Just "localhost"
```

### String Handling

```haskell
-- String is [Char] — simple but slow for large data
greeting = "Hello, " ++ "world!"

-- Data.Text — strict, efficient Unicode text (preferred)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
name = T.pack "world"
TIO.putStrLn (T.append "Hello, " name)

-- String interpolation (no built-in; use concatenation or printf)
import Text.Printf (printf)
printf "Result: %d\n" (1 + 2 :: Int)
```

### Exception Handling

```haskell
import Control.Exception (try, SomeException, handle, catch, IOException)

-- try: wraps result in Either
main = do
  result <- try (readFile "missing.txt") :: IO (Either IOException String)
  case result of
    Left err  -> putStrLn ("Error: " ++ show err)
    Right txt -> putStrLn txt

-- handle: provides a default on failure
lookupEnv :: String -> IO (Maybe String)
lookupEnv name = handle (\(_ :: SomeException) -> return Nothing) $
  Just <$> getEnv name
```

### Type Classes

```haskell
-- Defining a type class
class Describable a where
  describe :: a -> String

-- Instance for a specific type
instance Describable Color where
  describe Red   = "This is red"
  describe Green = "This is green"
  describe Blue  = "This is blue"

-- Common built-in classes: Show, Read, Eq, Ord, Num, Functor, Monad
```

### Monads and IO

```haskell
-- IO actions (side effects are explicit in the type)
main :: IO ()
main = do
  putStrLn "What is your name?"
  name <- getLine
  putStrLn ("Hello, " ++ name ++ "!")

-- Maybe monad (short-circuits on Nothing)
safeDivide :: Double -> Double -> Maybe Double
safeDivide _ 0 = Nothing
safeDivide x y = Just (x / y)

-- Either monad (short-circuits on Left with error info)
parseAge :: String -> Either String Int
parseAge s = case reads s of
  [(n, "")] | n >= 0    -> Right n
  _                     -> Left ("Invalid age: " ++ s)
```

### Common GHC Language Extensions

```haskell
{-# LANGUAGE OverloadedStrings   #-}   -- String literals become Text/ByteString
{-# LANGUAGE DeriveGeneric       #-}   -- Auto-derive Generic for Aeson etc.
{-# LANGUAGE ScopedTypeVariables #-}   -- Explicit type annotations in patterns
{-# LANGUAGE RecordWildCards     #-}   -- Unpack record fields into scope
{-# LANGUAGE DuplicateRecordFields #-} -- Allow same field name in different types
{-# LANGUAGE OverloadedRecordDot #-}   -- Use dot syntax: response.text
```

### JSON with Aeson

```haskell
{-# LANGUAGE DeriveGeneric #-}
import Data.Aeson (FromJSON, ToJSON, eitherDecode, encode)
import GHC.Generics (Generic)

data User = User
  { name :: String
  , age  :: Int
  } deriving (Show, Generic)

instance FromJSON User
instance ToJSON User

-- Encode: encode (User "Alice" 30)  =>  "{\"name\":\"Alice\",\"age\":30}"
-- Decode: eitherDecode "{...}" :: Either String User
```

### HTTP Requests

```haskell
import Network.HTTP.Client (newManager, httpLbs, parseRequest, Request(..), RequestBody(..), responseBody)
import Network.HTTP.Client.TLS (tlsManagerSettings)
import qualified Data.Aeson as Aeson

-- GET request
doGet :: IO ()
doGet = do
  manager <- newManager tlsManagerSettings
  request <- parseRequest "https://api.example.com/data"
  response <- httpLbs request manager
  print (responseBody response)

-- POST request with JSON body
doPost :: IO ()
doPost = do
  manager <- newManager tlsManagerSettings
  initialReq <- parseRequest "https://api.example.com/endpoint"
  let request = initialReq
        { method = "POST"
        , requestHeaders = [("Content-Type", "application/json")]
        , requestBody = RequestBodyLBS (Aeson.encode someValue)
        }
  response <- httpLbs request manager
  print (responseBody response)
```

---

# Haskell Book APIs — Quick Reference

Knowledge of public APIs and usage patterns for the Haskell examples in Mark Watson's book *Haskell Tutorial and Cookbook*.

## Project Setup

Most examples use **Stack** or **Cabal** for building. Each example directory has its own `.cabal` file and usually a `stack.yaml`:

```bash
cd source-code/<example_name>

# Using Stack
stack build
stack exec <executable-name>

# Using Cabal
cabal build
cabal run <executable-name>

# Interactive REPL
stack ghci
# or
cabal repl
```

---

## gemini_commandline

**Directory:** `gemini_commandline/`
**Deps:** `aeson`, `http-client`, `http-client-tls`, `http-types`, `text`
**Env var:** `GOOGLE_API_KEY`
**Model:** `gemini-2.5-flash`

### API

- `completion :: String -> Manager -> String -> IO (Either String String)` — Send a prompt to the Gemini API. Returns `Right responseText` or `Left errorMessage`.
- `extractEntities :: String -> String -> String -> Manager -> String -> IO (Either String [String])` — Generic entity extraction using a Gemini prompt pattern. Returns list of extracted entities.
- `findPlaces :: String -> Manager -> String -> IO (Either String [String])` — Extract place names from text.
- `findPeople :: String -> Manager -> String -> IO (Either String [String])` — Extract person names from text.
- `findCompanyNames :: String -> Manager -> String -> IO (Either String [String])` — Extract company names from text.

### Example

```haskell
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Client (newManager)

main :: IO ()
main = do
  apiKey <- getEnv "GOOGLE_API_KEY"
  manager <- newManager tlsManagerSettings
  result <- completion apiKey manager "What is the square of pi?"
  case result of
    Right text -> putStrLn text
    Left err   -> putStrLn ("Error: " ++ err)
```

### Build & Run

```bash
cabal run gemini -- "what is the square of pi?"
```

---

## webchat

**Directory:** `webchat/`
**Deps:** `aeson`, `http-client`, `http-client-tls`, `scotty`, `text`
**Env var:** `GOOGLE_API_KEY`
**Model:** `gemini-2.5-flash`

### Description

A web-based chat interface for the Google Gemini API, serving a browser UI on `http://localhost:3000`. Web counterpart to `gemini_commandline`.

### Build & Run

```bash
cabal run
# Open http://localhost:3000
```

---

## ollama_commandline

**Directory:** `ollama_commandline/`
**Deps:** `aeson`, `http-client`, `http-types`
**Server:** Requires Ollama running locally on port 11434
**Models:** `llama3.2:latest` (default, configurable)

### API

- `callOllama :: Manager -> String -> String -> IO (Either String OllamaResponse)` — Call Ollama's local `/api/generate` endpoint. Returns `Right OllamaResponse` or `Left errorMessage`.

### Data Types

```haskell
data OllamaRequest = OllamaRequest
  { model  :: String
  , prompt :: String
  , stream :: Bool
  }

data OllamaResponse = OllamaResponse
  { model       :: String
  , created_at  :: String
  , response    :: String
  , done        :: Bool
  , done_reason :: Maybe String
  }
```

### Build & Run

```bash
cabal run ollama-client -- "What is Haskell?" llama3.2:latest
```

---

## OpenAiApiClient

**Directory:** `OpenAiApiClient/`
**Deps:** `openai-hs`, `http-client`, `http-client-tls`
**Env var:** `OPENAI_API_KEY`

### Description

Calls the OpenAI Chat Completion API from Haskell using the `openai-hs` library. Sends a prompt and prints the response text.

### Build & Run

```bash
stack build
stack exec GenText
```

---

## BraveSearch

**Directory:** `BraveSearch/`
**Deps:** `http-conduit`, `aeson`, `text`, `bytestring`
**Env var:** `BRAVE_SEARCH_API_KEY`

### API

- `getSearchSuggestions :: BS.ByteString -> T.Text -> IO (Either T.Text [T.Text])` — Perform a Brave web search. Returns formatted results with title, URL, and description.

### Example

```haskell
import BraveSearch (getSearchSuggestions)
import qualified Data.ByteString.Char8 as BS
import qualified Data.Text as T

main :: IO ()
main = do
  apiKey <- BS.pack <$> getEnv "BRAVE_SEARCH_API_KEY"
  result <- getSearchSuggestions apiKey (T.pack "Haskell programming")
  case result of
    Right suggestions -> mapM_ (T.putStrLn) suggestions
    Left err          -> T.putStrLn err
```

---

## SparqlClient

**Directory:** `SparqlClient/`
**Deps:** `HTTP`, `rdf4h`, `text`, `aeson`

### Scripts

| File | Description |
|------|-------------|
| `HttpSparqlClient.hs` | Queries a SPARQL endpoint over HTTP |
| `HttpSparqlJsonClient.hs` | SPARQL query with JSON response parsing |
| `RobsExample.hs` | RDF4H library example (demo URI no longer valid) |
| `TestSparqlClient.hs` | Test harness for the SPARQL client |

### Example

```bash
stack ghci
:l HttpSparqlClient
main
```

---

## rdf_sparql

**Directory:** `rdf_sparql/`
**Deps:** `base`, `containers`

### Description

In-memory RDF store and basic SPARQL query engine. Demonstrates List Monad for graph pattern matching and join operations.

### Key Types

```haskell
data Node = IRI String | Literal String | BlankNode String
data Triple = Triple Node Node Node
type Graph = [Triple]
```

### Build & Run

```bash
cabal run simple-rdf
cabal run simple-rdf-with-sparql
```

---

## NlpTool

**Directory:** `NlpTool/`
**Deps:** `text`, `containers`, `split`

### Description

NLP toolkit providing text categorization, summarization, and entity extraction. Includes generated lexicon data files with `Data.Map` lookups for city names linked to DBpedia URIs.

### Key Modules

| Module | Description |
|--------|-------------|
| `Summarize.hs` | Text summarization |
| `Entities.hs` | Named entity extraction |
| `Categorize.hs` | Text categorization |
| `WebApp.hs` | Optional web interface |

### Build & Run

```bash
stack build --fast --exec NlpTool-exe
```

---

## knowledge_graph_creator_pure

**Directory:** `knowledge_graph_creator_pure/`
**Deps:** NLP libraries, `text`, `split`

### Description

Extracts entities and relationships from natural text to build knowledge graphs. Uses part-of-speech tagging and entity recognition. Optionally integrates with a Python coreference resolution server.

### Build & Run

```bash
stack build --fast --exec KGCreator-exe
stack build --fast --exec "KGCreator-exe test_data outtest"
```

---

## WebScraping

**Directory:** `WebScraping/`
**Deps:** `tagsoup`, `HTTP`

### Scripts

| File | Description |
|------|-------------|
| `TagSoupTest.hs` | Web scraping with TagSoup HTML parser |
| `HandsomeSoupTest.hs` | Alternative scraping with HandsomeSoup (CSS selectors) |

### Build & Run

```bash
stack build --exec TagSoupTest
```

---

## Database-sqlite

**Directory:** `Database-sqlite/`
**Deps:** `HDBC`, `HDBC-sqlite3`

### Description

Demonstrates connecting to and querying a SQLite database from Haskell. Lightweight file-based database — no server required.

### Prerequisites

```bash
sqlite3 test.db "CREATE TABLE test (id INTEGER PRIMARY KEY, str TEXT);"
```

### Build & Run

```bash
stack build --exec TestSqLite1
```

---

## Database-postgres

**Directory:** `Database-postgres/`
**Deps:** `postgresql-simple`

### Description

Demonstrates connecting to and querying a PostgreSQL database. Works with a simple e-commerce schema (customers, products, links).

### Build & Run

```bash
stack build --exec TestPostgres1
```

---

## TextProcessing

**Directory:** `TextProcessing/`
**Deps:** `aeson`, `csv`, `text`

### Scripts

| File | Description |
|------|-------------|
| `CleanText.hs` | Text cleaning utilities |
| `TestAESON.hs` | JSON processing with Aeson |
| `TestCSV.hs` | CSV file processing |
| `TestTextJSON.hs` | Text-based JSON handling |

---

## dataframe_example

**Directory:** `dataframe_example/`
**Deps:** `dataframe`

### Description

Data analysis in Haskell using the `dataframe` library with a California housing dataset. Demonstrates: load CSV, explore, derive columns, filter, select, sort, group & aggregate, and write CSV.

### Key API

```haskell
D.readCsv  :: FilePath -> IO DataFrame
D.writeCsv :: FilePath -> DataFrame -> IO ()
D.take     :: Int -> DataFrame -> DataFrame
D.derive   :: Text -> Expr a -> DataFrame -> DataFrame
D.filter   :: Expr a -> (a -> Bool) -> DataFrame -> DataFrame
D.groupBy  :: [Text] -> DataFrame -> GroupedDataFrame
D.aggregate :: [NamedExpr] -> GroupedDataFrame -> DataFrame
```

### Build & Run

```bash
cabal run dataframe_example
```

---

## Blackjack

**Directory:** `Blackjack/`
**Deps:** `random`

### Description

Command-line Blackjack game demonstrating functional state management without a State Monad. Functions take a `Table` and return a modified `Table` (Game Loop pattern).

### Build & Run

```bash
stack build --exec Blackjack
# or
cabal run Blackjack
```

---

## Pure / ImPure

**Directory:** `Pure/`, `ImPure/`

### Description

Pure Haskell functions and impure (IO) examples. Covers guards, pattern matching, list processing, and IO operations.

### Run

```bash
cd Pure
stack ghci
:l Guards.hs
main
```

---

## Other Examples

| Directory | Description |
|-----------|-------------|
| `ClientServer/` | TCP client-server networking |
| `CommandLineApp/` | CLI application patterns, game loops, file I/O |
| `FastTag/` | Part-of-speech tagger |
| `StateMonad/` | State Monad examples |
| `Timers/` | Timer and timing utilities |
| `debugging/` | Debugging techniques |
| `HybridHaskellPythonNlp/` | Haskell-Python interop for NLP |
| `HybridHaskellPythonCorefAnaphoraResolution/` | Haskell-Python coreference resolution |

---

## General Notes

- Most examples use **Stack** (`stack build`, `stack exec`, `stack ghci`) or **Cabal** (`cabal build`, `cabal run`, `cabal repl`) for building.
- Each example directory contains its own `.cabal` file and usually a `stack.yaml`.
- Haskell HTTP clients use `http-client` + `http-client-tls` for HTTPS and `Network.HTTP` for simpler HTTP.
- JSON serialization/deserialization uses `aeson` (`Data.Aeson`) with `DeriveGeneric` for automatic instances.
- Environment variables are read with `System.Environment.getEnv` or a safe wrapper returning `Maybe String`.
- Required env vars: `GOOGLE_API_KEY`, `OPENAI_API_KEY`, `BRAVE_SEARCH_API_KEY` (depending on the example).
- Common LANGUAGE pragmas: `OverloadedStrings`, `DeriveGeneric`, `ScopedTypeVariables`, `RecordWildCards`.
- Haskell uses **camelCase** for functions and variables, **PascalCase** for types and constructors.
- The book is freely readable online at: https://leanpub.com/haskell-cookbook/read
