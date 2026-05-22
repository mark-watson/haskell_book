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
