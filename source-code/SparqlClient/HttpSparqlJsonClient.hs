{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveDataTypeable #-}

module Main where

import Text.JSON.Generic

-- Fetch SPARQL JSON results from DBpedia using HTTP

import Network.HTTP.Conduit (simpleHttp)
import Network.HTTP.Base (urlEncode)
import Text.HandsomeSoup
import qualified Data.ByteString.Lazy.Char8 as B

prefixUrl :: [Char]
prefixUrl = "http://dbpedia.org/sparql/?query="

buildQuery :: String -> [Char]
buildQuery sparqlString = prefixUrl ++ urlEncode sparqlString ++ "&format=json"
  
main :: IO ()
main = do
  let query = buildQuery "select * where {<http://dbpedia.org/resource/IBM> <http://dbpedia.org/ontology/abstract> ?o . FILTER langMatches(lang(?o), \"EN\")} LIMIT 100"
  res <- simpleHttp query
  putStrLn "\nAbstracts:\n"
  B.putStrLn res
