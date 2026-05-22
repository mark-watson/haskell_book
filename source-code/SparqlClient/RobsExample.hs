{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- Updated example: fetches RDF/XML data from a live DBpedia resource
-- and prints a sample of its triples.
--
-- The original data.semanticweb.org URL is no longer available (domain went offline).
-- We now fetch DBpedia's RDF description of the "Semantic_Web" article instead.
--
-- Note: rdf4h's parseURL only supports plain HTTP, so we fetch with
-- http-client-tls and then hand the body to parseString.

module Main where

import Data.RDF
import qualified Data.Text as T
import Network.HTTP.Client
import Network.HTTP.Client.TLS (tlsManagerSettings)
import qualified Data.ByteString.Lazy.Char8 as B

-- | Fetch URL body using TLS-capable http-client.
fetchURL :: String -> IO B.ByteString
fetchURL url = do
  manager <- newManager tlsManagerSettings
  req0    <- parseRequest url
  let req = req0 { requestHeaders = [("User-Agent", "HaskellRdfClient/1.0 (educational example)")] }
  resp    <- httpLbs req manager
  return (responseBody resp)

-- | Convert any RDF Node to a human-readable Text string.
nodeText :: Node -> T.Text
nodeText (UNode t)              = t
nodeText (BNode t)              = T.concat ["_:", t]
nodeText (BNodeGen i)           = T.pack ("_:gen" ++ show i)
nodeText (LNode (PlainL t))     = t
nodeText (LNode (PlainLL t l))  = T.concat [t, "@", l]
nodeText (LNode (TypedL t dt))  = T.concat [t, "^^", dt]

-- | Format a triple as "subject | predicate | object".
showTriple :: Triple -> T.Text
showTriple (Triple s p o) =
  T.intercalate " | " [nodeText s, nodeText p, nodeText o]

main :: IO ()
main = do
  let rdfUrl = "https://dbpedia.org/data/Semantic_Web.rdf"
  putStrLn $ "Fetching RDF from: " ++ rdfUrl
  body <- fetchURL rdfUrl
  -- XmlParser takes: Maybe BaseUrl, Maybe Text (document-URI hint)
  let bodyText = T.pack (B.unpack body)
      result   = parseString (XmlParser Nothing Nothing)
                              bodyText :: Either ParseFailure (RDF TList)
  case result of
    Left (ParseFailure err) ->
      putStrLn $ "Parse error: " ++ err
    Right rdfGraph -> do
      let ts = take 20 (map showTriple (triplesOf rdfGraph))
      putStrLn $ "\nFirst " ++ show (length ts) ++ " triples (subject | predicate | object):\n"
      mapM_ (putStrLn . T.unpack) ts
