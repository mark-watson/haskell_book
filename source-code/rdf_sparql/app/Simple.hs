-- Simple RDF demo: load a social network graph and run SPARQL queries
{-# LANGUAGE OverloadedStrings #-}

module Main where

import SimpleRDF
import qualified Data.Text.IO as TIO

-- Helpers
iri :: String -> Node
iri = IRI

lit :: String -> Node
lit = Lit

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

  putStrLn "\n--- Query 1: Select ?s ?o where { ?s likes ?o } ---"
  let q1 = Select
        { vars = ["s", "o"]
        , whereClause =
            [ TP (QVar "s") (QTerm (iri "likes")) (QVar "o")
            ]
        }
  printTable ["?s", "?o"] (runQuery myGraph q1)

  putStrLn "\n--- Query 2: Select ?who where { ?who likes <Bob> } ---"
  let q2 = Select
        { vars = ["who"]
        , whereClause =
            [ TP (QVar "who") (QTerm (iri "likes")) (QTerm (iri "Bob"))
            ]
        }
  printTable ["?who"] (runQuery myGraph q2)

  putStrLn "\n--- Query 3 (Join): Who likes someone who likes them back? ---"
  let q3 = Select
        { vars = ["a", "b"]
        , whereClause =
            [ TP (QVar "a") (QTerm (iri "likes")) (QVar "b")
            , TP (QVar "b") (QTerm (iri "likes")) (QVar "a")
            ]
        }
  printTable ["?a", "?b"] (runQuery myGraph q3)

printTable :: [String] -> [[Node]] -> IO ()
printTable headers rows = do
  putStrLn $ unwords headers
  putStrLn $ replicate (length (unwords headers) + 5) '-'
  mapM_ (putStrLn . unwords . map formatNode) rows
