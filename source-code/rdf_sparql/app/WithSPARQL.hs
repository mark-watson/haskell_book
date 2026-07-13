-- RDF store with SPARQL parser demo
{-# LANGUAGE OverloadedStrings #-}

module Main where

import SimpleRDF
import Text.ParserCombinators.ReadP
import Data.Char (isSpace, isAlphaNum, toLower)
import Data.Maybe (fromMaybe)
import Data.List (nub)

-- SPARQL Parser (simplified grammar)

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

printTable :: [String] -> [[Node]] -> IO ()
printTable headers rows = do
  putStrLn $ unwords headers
  putStrLn $ replicate (length (unwords headers) + 5) '-'
  mapM_ (putStrLn . unwords . map formatNode) rows
