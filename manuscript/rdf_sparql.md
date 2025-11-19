# Implementing a Simple RDF Datastore With Partial SPARQL Support

Other examples in this book use full RDF datastores via their APIs. Here we implement two examples:

- SimpleRDF.hs - A simple in-memory RDF datastore that supports queries using a non-standard pattern matching syntax.
- RDF_simple_SPARQL.hs - Also handles simple SPARQL queries such as shown in the test code for this example:

```haskell
main = do
  putStrLn "--- RDF Store Loaded ---"
  mapM_ print myGraph
  
  let queries = 
        [ ("Query 1: Select ?s ?o where { ?s likes ?o }", 
           "SELECT ?s ?o WHERE { ?s likes ?o }")
        , ("Query 2: Select ?who where { ?who likes <Bob> }", 
           "SELECT ?who WHERE { ?who likes <Bob> }")
        , ("Query 3 (Join): Who likes someone who likes them back?", 
           "SELECT ?a ?b WHERE { ?a likes ?b . ?b likes ?a }")
        ]

  mapM_ runAndPrint queries
```

## In-memory Example Using a Pattern Matching Query Syntax

To demonstrate the fundamentals of a graph database, the following Haskell implementation constructs a minimal in-memory RDF store and a query engine that executes queries defined via an internal data structure rather than parsing raw SPARQL text. We define the core types—nodes representing IRIs, literals, or blank nodes—and organize them into a list of triples to simulate the graph. Instead of a string parser, the code uses a SelectQuery type and TriplePattern objects (the AST) to programmatically model the query logic, while the evaluatePatterns function leverages the List Monad to elegantly handle the combinatorial nature of joining these patterns against the data.

```haskell
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (mapMaybe, fromMaybe)
import Data.List (nub)

import Text.ParserCombinators.ReadP
import Data.Char (isSpace, isAlphaNum)

-- ==========================================
-- 1. RDF Data Types
-- ==========================================

-- A Node can be an IRI (URI), a Literal string, or a Blank Node
data Node
  = IRI String
  | Lit String
  | BNode Int
  deriving (Eq, Ord)

instance Show Node where
  show (IRI s)   = "<" ++ s ++ ">"
  show (Lit s)   = "\"" ++ s ++ "\""
  show (BNode i) = "_:b" ++ show i

-- An RDF Triple: (Subject, Predicate, Object)
type Triple = (Node, Node, Node)

-- The Store is just a list of triples (in a real DB, this would be an indexed Set)
type Graph = [Triple]

-- ==========================================
-- 2. SPARQL Query Types
-- ==========================================

-- A Query Item can be a concrete Node or a Variable ("?x")
data QueryNode
  = QTerm Node
  | QVar String
  deriving (Eq, Show)

-- A Triple Pattern: e.g., { ?s <likes> ?o }
data TriplePattern = 
  TP QueryNode QueryNode QueryNode
  deriving (Show)

-- A simplified representation of a SELECT query
data SelectQuery = Select
  { vars  :: [String]         -- Variables to select (e.g., ["s", "o"])
  , whereClause :: [TriplePattern] -- The WHERE block
  }

-- A Binding maps variable names to concrete RDF Nodes
type Binding = Map String Node

-- ==========================================
-- 3. The Query Engine
-- ==========================================

-- | Checks if a concrete Triple matches a Triple Pattern given a starting context.
-- Returns a new Binding extended with matches if successful, or Nothing if failed.
matchTriple :: Binding -> TriplePattern -> Triple -> Maybe Binding
matchTriple ctx (TP qs qp qo) (s, p, o) = do
  ctx1 <- matchNode ctx qs s
  ctx2 <- matchNode ctx1 qp p
  matchNode ctx2 qo o

-- | Helper to match a single QueryNode against a concrete Node
matchNode :: Binding -> QueryNode -> Node -> Maybe Binding
matchNode ctx (QTerm t) n
  | t == n    = Just ctx  -- Concrete terms must match exactly
  | otherwise = Nothing
matchNode ctx (QVar v) n =
  case Map.lookup v ctx of
    Nothing -> Just (Map.insert v n ctx) -- Bind new variable
    Just val -> if val == n then Just ctx else Nothing -- Check existing binding constraint

-- | Executes a list of patterns against the graph using the List Monad for join logic.
evaluatePatterns :: Graph -> [TriplePattern] -> [Binding]
evaluatePatterns _ [] = [Map.empty] -- Base case: empty pattern results in one empty binding (identity)
evaluatePatterns graph (pat:pats) = do
  -- 1. Take previous results (or start)
  ctx <- evaluatePatterns graph pats
  
  -- 2. Find all triples in the graph that match the current pattern 
  --    consistent with the current context (ctx)
  triple <- graph
  
  -- 3. Attempt to bind the triple to the pattern
  case matchTriple ctx pat triple of
    Just newCtx -> return newCtx
    Nothing     -> []

-- | The main entry point for running a query.
-- It evaluates the WHERE clause and then projects only the requested SELECT variables.
runQuery :: Graph -> SelectQuery -> [[Node]]
runQuery graph query =
  let 
    -- 1. Find all valid bindings for the WHERE clause
    -- We reverse the patterns because the list monad naturally processes right-to-left 
    -- in the recursion above, but we want left-to-right evaluation flow.
    allBindings = evaluatePatterns graph (reverse $ whereClause query)
    
    -- 2. Project specific variables (SELECT ?s ?o)
    project binding = map (\v -> fromMaybe (Lit "NULL") (Map.lookup v binding)) (vars query)
  in
    nub $ map project allBindings

-- ==========================================
-- 4. SPARQL Parser
-- ==========================================

-- | Parses a SPARQL query string into a SelectQuery
parseQuery :: String -> Either String SelectQuery
parseQuery input = 
  case readP_to_S parser input of
    [(q, "")] -> Right q
    [(q, rest)] | all isSpace rest -> Right q
    _ -> Left "Parse error"
  where
    parser :: ReadP SelectQuery
    parser = do
      skipSpaces
      _ <- stringCI "SELECT"
      skipSpaces
      vs <- many1 (skipSpaces >> parseVarName)
      skipSpaces
      _ <- stringCI "WHERE"
      skipSpaces
      _ <- char '{'
      skipSpaces
      pats <- sepBy parseTriplePattern (skipSpaces >> optional (char '.') >> skipSpaces)
      skipSpaces
      _ <- char '}'
      return $ Select vs pats

    stringCI :: String -> ReadP String
    stringCI str = traverse (\c -> satisfy (\x -> toLower x == toLower c)) str
      where toLower x = if 'A' <= x && x <= 'Z' then toEnum (fromEnum x + 32) else x

    parseVarName :: ReadP String
    parseVarName = do
      _ <- char '?'
      munch1 isAlphaNum

    parseTriplePattern :: ReadP TriplePattern
    parseTriplePattern = do
      s <- parseQueryNode
      skipSpaces
      p <- parseQueryNode
      skipSpaces
      o <- parseQueryNode
      return $ TP s p o

    parseQueryNode :: ReadP QueryNode
    parseQueryNode = parseVar <++ parseTerm

    parseVar :: ReadP QueryNode
    parseVar = QVar <$> parseVarName

    parseTerm :: ReadP QueryNode
    parseTerm = QTerm <$> (parseIRI <++ parseLit <++ parseSimpleIRI)

    parseIRI :: ReadP Node
    parseIRI = do
      _ <- char '<'
      content <- munch (/= '>')
      _ <- char '>'
      return $ IRI content

    -- Support for simple words as IRIs (e.g., "likes" instead of "<likes>")
    parseSimpleIRI :: ReadP Node
    parseSimpleIRI = do
      content <- munch1 isAlphaNum
      return $ IRI content

    parseLit :: ReadP Node
    parseLit = do
      _ <- char '"'
      content <- munch (/= '"')
      _ <- char '"'
      return $ Lit content

-- ==========================================
-- 5. Example Data and Usage
-- ==========================================

-- Helpers to make data entry cleaner
iri :: String -> Node
iri = IRI

lit :: String -> Node
lit = Lit

-- The "Social Network" Graph
myGraph :: Graph
myGraph =
  [ (iri "Alice", iri "likes", iri "Bob")
  , (iri "Alice", iri "likes", iri "Pizza")
  , (iri "Bob",   iri "likes", iri "Alice")
  , (iri "Bob",   iri "likes", iri "Pasta")
  , (iri "Charlie", iri "likes", iri "Bob")
  , (iri "Alice", iri "age", lit "25")
  , (iri "Bob",   iri "age", lit "28")
  ]

main :: IO ()
main = do
  putStrLn "--- RDF Store Loaded ---"
  mapM_ print myGraph
  
  let queries = 
        [ ("Query 1: Select ?s ?o where { ?s likes ?o }", 
           "SELECT ?s ?o WHERE { ?s likes ?o }")
        , ("Query 2: Select ?who where { ?who likes <Bob> }", 
           "SELECT ?who WHERE { ?who likes <Bob> }")
        , ("Query 3 (Join): Who likes someone who likes them back?", 
           "SELECT ?a ?b WHERE { ?a likes ?b . ?b likes ?a }")
        ]

  mapM_ runAndPrint queries

runAndPrint :: (String, String) -> IO ()
runAndPrint (desc, qStr) = do
  putStrLn $ "\n--- " ++ desc ++ " ---"
  case parseQuery qStr of
    Left err -> putStrLn $ "Error parsing query: " ++ err
    Right q -> do
      let results = runQuery myGraph q
      let headers = map ("?" ++) (vars q)
      printTable headers results

-- Utility to print results nicely
printTable :: [String] -> [[Node]] -> IO ()
printTable headers rows = do
  putStrLn $ unwords headers
  putStrLn $ replicate (length (unwords headers) + 5) '-'
  mapM_ (putStrLn . unwords . map show) rows
```

The engine relies on a pattern-matching approach where TriplePattern objects are compared against concrete triples in the store to build a Binding map. The matchTriple function acts as the gatekeeper: it checks if a specific triple fits the constraints of the pattern (e.g., matching a specific Subject IRI) and updates the variable bindings (like ?s or ?o) accordingly. Because the queries are constructed as Haskell data types—shown in the main function alongside the commented-out SPARQL strings they represent—the compiler ensures the structure of the query is valid before the program even runs, bypassing the complexity of text parsing entirely.

While this implementation highlights the semantic clarity of using Haskell's monadic structure for query resolution, it represents a naive nested-loop join strategy. The evaluatePatterns function iterates through the entire graph for every pattern step, leading to exponential complexity relative to the number of patterns. In a production-grade triple store, this would be optimized using indexed lookups (such as SPO, POS, or OSP indices) to reduce the search space from linear scans to logarithmic lookups, allowing for efficient handling of millions of triples.

## In-memory Example Using a Simplified SPARQL Query Syntax

To enhance the usability of our RDF engine, we now introduce a parsing layer that allows users to execute queries using standard SPARQL string syntax rather than manually constructing Haskell data types. By utilizing the Text.ParserCombinators.ReadP library, we define a parser that consumes raw strings—handling the SELECT clause, variable extraction, and the WHERE block's triple patterns—and converts them into the SelectQuery AST expected by our engine. This addition bridges the gap between the internal logic and user input, enabling the execution of text-based queries like **SELECT ?a ?b WHERE { ?a likes ?b }** and **SELECT ?a ?b WHERE { ?a likes ?b . ?b likes ?a }** by tokenizing variables, literals, and IRIs, including a helper parseSimpleIRI to allow unbracketed terms for cleaner input.

```haskell
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Main where

import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (mapMaybe, fromMaybe)
import Data.List (nub)

import Text.ParserCombinators.ReadP
import Data.Char (isSpace, isAlphaNum)

-- ==========================================
-- 1. RDF Data Types
-- ==========================================

-- A Node can be an IRI (URI), a Literal string, or a Blank Node
data Node
  = IRI String
  | Lit String
  | BNode Int
  deriving (Eq, Ord)

instance Show Node where
  show (IRI s)   = "<" ++ s ++ ">"
  show (Lit s)   = "\"" ++ s ++ "\""
  show (BNode i) = "_:b" ++ show i

-- An RDF Triple: (Subject, Predicate, Object)
type Triple = (Node, Node, Node)

-- The Store is just a list of triples (in a real DB, this would be an indexed Set)
type Graph = [Triple]

-- ==========================================
-- 2. SPARQL Query Types
-- ==========================================

-- A Query Item can be a concrete Node or a Variable ("?x")
data QueryNode
  = QTerm Node
  | QVar String
  deriving (Eq, Show)

-- A Triple Pattern: e.g., { ?s <likes> ?o }
data TriplePattern = 
  TP QueryNode QueryNode QueryNode
  deriving (Show)

-- A simplified representation of a SELECT query
data SelectQuery = Select
  { vars  :: [String]         -- Variables to select (e.g., ["s", "o"])
  , whereClause :: [TriplePattern] -- The WHERE block
  }

-- A Binding maps variable names to concrete RDF Nodes
type Binding = Map String Node

-- ==========================================
-- 3. The Query Engine
-- ==========================================

-- | Checks if a concrete Triple matches a Triple Pattern given a starting context.
-- Returns a new Binding extended with matches if successful, or Nothing if failed.
matchTriple :: Binding -> TriplePattern -> Triple -> Maybe Binding
matchTriple ctx (TP qs qp qo) (s, p, o) = do
  ctx1 <- matchNode ctx qs s
  ctx2 <- matchNode ctx1 qp p
  matchNode ctx2 qo o

-- | Helper to match a single QueryNode against a concrete Node
matchNode :: Binding -> QueryNode -> Node -> Maybe Binding
matchNode ctx (QTerm t) n
  | t == n    = Just ctx  -- Concrete terms must match exactly
  | otherwise = Nothing
matchNode ctx (QVar v) n =
  case Map.lookup v ctx of
    Nothing -> Just (Map.insert v n ctx) -- Bind new variable
    Just val -> if val == n then Just ctx else Nothing -- Check existing binding constraint

-- | Executes a list of patterns against the graph using the List Monad for join logic.
evaluatePatterns :: Graph -> [TriplePattern] -> [Binding]
evaluatePatterns _ [] = [Map.empty] -- Base case: empty pattern results in one empty binding (identity)
evaluatePatterns graph (pat:pats) = do
  -- 1. Take previous results (or start)
  ctx <- evaluatePatterns graph pats
  
  -- 2. Find all triples in the graph that match the current pattern 
  --    consistent with the current context (ctx)
  triple <- graph
  
  -- 3. Attempt to bind the triple to the pattern
  case matchTriple ctx pat triple of
    Just newCtx -> return newCtx
    Nothing     -> []

-- | The main entry point for running a query.
-- It evaluates the WHERE clause and then projects only the requested SELECT variables.
runQuery :: Graph -> SelectQuery -> [[Node]]
runQuery graph query =
  let 
    -- 1. Find all valid bindings for the WHERE clause
    -- We reverse the patterns because the list monad naturally processes right-to-left 
    -- in the recursion above, but we want left-to-right evaluation flow.
    allBindings = evaluatePatterns graph (reverse $ whereClause query)
    
    -- 2. Project specific variables (SELECT ?s ?o)
    project binding = map (\v -> fromMaybe (Lit "NULL") (Map.lookup v binding)) (vars query)
  in
    nub $ map project allBindings

-- ==========================================
-- 4. SPARQL Parser
-- ==========================================

-- | Parses a SPARQL query string into a SelectQuery
parseQuery :: String -> Either String SelectQuery
parseQuery input = 
  case readP_to_S parser input of
    [(q, "")] -> Right q
    [(q, rest)] | all isSpace rest -> Right q
    _ -> Left "Parse error"
  where
    parser :: ReadP SelectQuery
    parser = do
      skipSpaces
      _ <- stringCI "SELECT"
      skipSpaces
      vs <- many1 (skipSpaces >> parseVarName)
      skipSpaces
      _ <- stringCI "WHERE"
      skipSpaces
      _ <- char '{'
      skipSpaces
      pats <- sepBy parseTriplePattern (skipSpaces >> optional (char '.') >> skipSpaces)
      skipSpaces
      _ <- char '}'
      return $ Select vs pats

    stringCI :: String -> ReadP String
    stringCI str = traverse (\c -> satisfy (\x -> toLower x == toLower c)) str
      where toLower x = if 'A' <= x && x <= 'Z' then toEnum (fromEnum x + 32) else x

    parseVarName :: ReadP String
    parseVarName = do
      _ <- char '?'
      munch1 isAlphaNum

    parseTriplePattern :: ReadP TriplePattern
    parseTriplePattern = do
      s <- parseQueryNode
      skipSpaces
      p <- parseQueryNode
      skipSpaces
      o <- parseQueryNode
      return $ TP s p o

    parseQueryNode :: ReadP QueryNode
    parseQueryNode = parseVar <++ parseTerm

    parseVar :: ReadP QueryNode
    parseVar = QVar <$> parseVarName

    parseTerm :: ReadP QueryNode
    parseTerm = QTerm <$> (parseIRI <++ parseLit <++ parseSimpleIRI)

    parseIRI :: ReadP Node
    parseIRI = do
      _ <- char '<'
      content <- munch (/= '>')
      _ <- char '>'
      return $ IRI content

    -- Support for simple words as IRIs (e.g., "likes" instead of "<likes>")
    parseSimpleIRI :: ReadP Node
    parseSimpleIRI = do
      content <- munch1 isAlphaNum
      return $ IRI content

    parseLit :: ReadP Node
    parseLit = do
      _ <- char '"'
      content <- munch (/= '"')
      _ <- char '"'
      return $ Lit content

-- ==========================================
-- 5. Example Data and Usage
-- ==========================================

-- Helpers to make data entry cleaner
iri :: String -> Node
iri = IRI

lit :: String -> Node
lit = Lit

-- The "Social Network" Graph
myGraph :: Graph
myGraph =
  [ (iri "Alice", iri "likes", iri "Bob")
  , (iri "Alice", iri "likes", iri "Pizza")
  , (iri "Bob",   iri "likes", iri "Alice")
  , (iri "Bob",   iri "likes", iri "Pasta")
  , (iri "Charlie", iri "likes", iri "Bob")
  , (iri "Alice", iri "age", lit "25")
  , (iri "Bob",   iri "age", lit "28")
  ]

main :: IO ()
main = do
  putStrLn "--- RDF Store Loaded ---"
  mapM_ print myGraph
  
  let queries = 
        [ ("Query 1: Select ?s ?o where { ?s likes ?o }", 
           "SELECT ?s ?o WHERE { ?s likes ?o }")
        , ("Query 2: Select ?who where { ?who likes <Bob> }", 
           "SELECT ?who WHERE { ?who likes <Bob> }")
        , ("Query 3 (Join): Who likes someone who likes them back?", 
           "SELECT ?a ?b WHERE { ?a likes ?b . ?b likes ?a }")
        ]

  mapM_ runAndPrint queries

runAndPrint :: (String, String) -> IO ()
runAndPrint (desc, qStr) = do
  putStrLn $ "\n--- " ++ desc ++ " ---"
  case parseQuery qStr of
    Left err -> putStrLn $ "Error parsing query: " ++ err
    Right q -> do
      let results = runQuery myGraph q
      let headers = map ("?" ++) (vars q)
      printTable headers results

-- Utility to print results nicely
printTable :: [String] -> [[Node]] -> IO ()
printTable headers rows = do
  putStrLn $ unwords headers
  putStrLn $ replicate (length (unwords headers) + 5) '-'
  mapM_ (putStrLn . unwords . map show) rows
```

The parseQuery function serves as the new frontend, utilizing monadic parser combinators to decompose the query string. We define a parser that enforces the structural grammar of SPARQL: it expects the **SELECT** keyword followed by variables, and a WHERE clause containing a set of triple patterns enclosed in braces. The use of **sepBy** allows us to parse multiple patterns separated by optional dots, while **stringCI** ensures case-insensitivity for keywords, making the parser robust against minor formatting variations in the input string.

At the granular level, parseTriplePattern constructs the abstract syntax tree by recursively parsing the subject, predicate, and object. The **parseQueryNode** function uses the choice combinator **<++** to distinguish between variables (prefixed with **?**) and concrete terms. To improve readability in this simple implementation, we included parseSimpleIRI, which permits alphanumeric words to be interpreted as IRIs without enclosing angle brackets; this allows users to write natural queries like ?s likes ?o alongside strict SPARQL syntax like **<Alice> <age> "25"**.


## Wrap Up

These examples illustrate the power of Haskell's monadic structures for modeling complex logic like database query execution. By utilizing the List Monad in the core engine, we abstracted away the explicit backtracking and iteration required to join triple patterns. The code treats a query not as a mechanical set of nested loops, but as a sequence of context transformations, where each step filters the universe of possible bindings down to those that satisfy the current constraints. This allows the evaluatePatterns function to remain remarkably concise while handling the non-deterministic nature of graph pattern matching.

The progression from manual data type construction to a text-based parser highlights the critical distinction between a query engine and a query language. The first example demonstrated that the execution logic operates purely on the Abstract Syntax Tree (AST), entirely independent of how that tree is created. The second example bridged the gap to usability by adding a combinator-based parser, effectively treating the SPARQL string syntax merely as a serialization format for the internal logic we had already built. This separation of concerns allows the backend to remain stable even as the frontend syntax evolves or expands.

Finally, while the two implementation in this chapter are functionally correct for small datasets, they reveal the performance challenges inherent in graph databases. The nested-loop join strategy employed here performs a linear scan of the graph for every pattern, resulting in exponential time complexity for complex queries. Production-grade triple stores solve this by replacing list-based storage with indexed structures—such as B-Trees or Hexastores (indexing S-P-O, P-O-S, etc.)—to allow constant-time lookups, ensuring that queries remain performant even as the dataset grows into the billions of triples.
