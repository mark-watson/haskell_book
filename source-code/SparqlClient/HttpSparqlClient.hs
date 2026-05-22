{-# LANGUAGE OverloadedStrings #-}

module Main where

import Network.HTTP.Client
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Base (urlEncode)
import Network.HTTP.Types.Status (statusCode)
import Text.XML.HXT.Core
import Text.HandsomeSoup
import qualified Data.ByteString.Lazy.Char8 as B

prefixUrl :: String
prefixUrl = "https://dbpedia.org/sparql?format=xml&query="

buildQuery :: String -> String
buildQuery sparqlString = prefixUrl ++ urlEncode sparqlString

main :: IO ()
main = do
  let url = buildQuery "select ?label where {<http://dbpedia.org/resource/IBM> <http://www.w3.org/2000/01/rdf-schema#label> ?label . FILTER langMatches(lang(?label), \"EN\")}"
  manager <- newManager tlsManagerSettings
  initialReq <- parseRequest url
  let req = initialReq
              { requestHeaders =
                  [ ("User-Agent", "HaskellSparqlClient/1.0 (educational example)")
                  , ("Accept",     "application/sparql-results+xml")
                  ]
              }
  response <- httpLbs req manager
  let status = statusCode (responseStatus response)
  if status /= 200
    then putStrLn $ "HTTP error: " ++ show status
    else do
      let body = responseBody response
      let doc  = readString [] (B.unpack body)
      putStrLn "\nIBM rdfs:labels:\n"
      labels <- runX $ doc >>> css "binding" >>> (getAttrValue "name" &&& (deep getText))
      if null labels
        then putStrLn "(no results — check the SPARQL endpoint or query)"
        else mapM_ print labels
