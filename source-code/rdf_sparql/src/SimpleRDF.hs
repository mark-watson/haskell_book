-- In-memory RDF store and SPARQL query engine
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module SimpleRDF
  ( Node(..)
  , formatNode
  , Triple
  , Graph
  , QueryNode(..)
  , TriplePattern(..)
  , SelectQuery(..)
  , Binding
  , matchTriple
  , matchNode
  , evaluatePatterns
  , runQuery
  ) where

import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Data.Maybe (fromMaybe)
import Data.List (nub)

-- | A Node can be an IRI (URI), a Literal string, or a Blank Node.
data Node
  = IRI String
  | Lit String
  | BNode Int
  deriving (Show, Eq, Ord)

-- | Format an RDF Node for display using standard N-Triples notation.
formatNode :: Node -> String
formatNode (IRI s)   = "<" ++ s ++ ">"
formatNode (Lit s)   = "\"" ++ s ++ "\""
formatNode (BNode i) = "_:b" ++ show i

-- An RDF Triple: (Subject, Predicate, Object)
type Triple = (Node, Node, Node)

-- The Store is just a list of triples
type Graph = [Triple]

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
  { vars  :: [String]
  , whereClause :: [TriplePattern]
  }

-- A Binding maps variable names to concrete RDF Nodes
type Binding = Map String Node

-- | Checks if a concrete Triple matches a Triple Pattern given a starting context.
matchTriple :: Binding -> TriplePattern -> Triple -> Maybe Binding
matchTriple ctx (TP qs qp qo) (s, p, o) = do
  ctx1 <- matchNode ctx qs s
  ctx2 <- matchNode ctx1 qp p
  matchNode ctx2 qo o

-- | Helper to match a single QueryNode against a concrete Node
matchNode :: Binding -> QueryNode -> Node -> Maybe Binding
matchNode ctx (QTerm t) n
  | t == n    = Just ctx
  | otherwise = Nothing
matchNode ctx (QVar v) n =
  case Map.lookup v ctx of
    Nothing -> Just (Map.insert v n ctx)
    Just val -> if val == n then Just ctx else Nothing

-- | Executes a list of patterns against the graph using the List Monad for join logic.
evaluatePatterns :: Graph -> [TriplePattern] -> [Binding]
evaluatePatterns _ [] = [Map.empty]
evaluatePatterns graph (pat:pats) = do
  ctx <- evaluatePatterns graph pats
  triple <- graph
  case matchTriple ctx pat triple of
    Just newCtx -> return newCtx
    Nothing     -> []

-- | The main entry point for running a query.
runQuery :: Graph -> SelectQuery -> [[Node]]
runQuery graph query =
  let
    allBindings = evaluatePatterns graph (reverse $ whereClause query)
    project binding = map (\v -> fromMaybe (Lit "NULL") (Map.lookup v binding)) (vars query)
  in
    nub $ map project allBindings
