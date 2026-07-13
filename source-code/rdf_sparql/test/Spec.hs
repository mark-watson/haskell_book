module Main where

import Test.Hspec
import qualified Data.Map.Strict as Map
import SimpleRDF

main :: IO ()
main = hspec spec

iri :: String -> Node
iri = IRI

lit :: String -> Node
lit = Lit

testGraph :: Graph
testGraph =
  [ (iri "Alice", iri "likes", iri "Bob")
  , (iri "Alice", iri "likes", iri "Pizza")
  , (iri "Bob",   iri "likes", iri "Alice")
  , (iri "Bob",   iri "likes", iri "Pasta")
  , (iri "Charlie", iri "likes", iri "Bob")
  , (iri "Alice", iri "age", lit "25")
  , (iri "Bob",   iri "age", lit "28")
  ]

spec :: Spec
spec = do
  describe "formatNode" $ do
    it "formats an IRI with angle brackets" $
      formatNode (IRI "http://example.org") `shouldBe` "<http://example.org>"
    it "formats a Literal with quotes" $
      formatNode (Lit "hello") `shouldBe` "\"hello\""
    it "formats a BNode with _:b prefix" $
      formatNode (BNode 42) `shouldBe` "_:b42"

  describe "matchNode" $ do
    it "matches a QTerm when nodes are equal" $
      matchNode Map.empty (QTerm (iri "likes")) (iri "likes") `shouldBe` Just Map.empty
    it "fails to match a QTerm when nodes differ" $
      matchNode Map.empty (QTerm (iri "likes")) (iri "hates") `shouldBe` Nothing
    it "binds a QVar to a concrete node" $
      matchNode Map.empty (QVar "x") (iri "Alice") `shouldBe` Just (Map.singleton "x" (iri "Alice"))
    it "accepts QVar when existing binding matches" $
      matchNode (Map.singleton "x" (iri "Alice")) (QVar "x") (iri "Alice") `shouldBe` Just (Map.singleton "x" (iri "Alice"))
    it "rejects QVar when existing binding differs" $
      matchNode (Map.singleton "x" (iri "Alice")) (QVar "x") (iri "Bob") `shouldBe` Nothing

  describe "matchTriple" $ do
    it "matches a concrete triple pattern against a matching triple" $
      matchTriple Map.empty (TP (QTerm (iri "Alice")) (QTerm (iri "likes")) (QTerm (iri "Bob")))
                  (iri "Alice", iri "likes", iri "Bob") `shouldBe` Just Map.empty
    it "binds variables in a triple pattern" $ do
      let result = matchTriple Map.empty (TP (QVar "s") (QTerm (iri "likes")) (QVar "o"))
                               (iri "Alice", iri "likes", iri "Bob")
      case result of
        Nothing -> expectationFailure "Expected match"
        Just bindings -> do
          Map.lookup "s" bindings `shouldBe` Just (iri "Alice")
          Map.lookup "o" bindings `shouldBe` Just (iri "Bob")

  describe "evaluatePatterns" $ do
    it "returns one empty binding for an empty pattern list" $
      evaluatePatterns testGraph [] `shouldBe` [Map.empty]
    it "finds all subjects that like someone" $ do
      let pats = [TP (QVar "s") (QTerm (iri "likes")) (QVar "o")]
          results = evaluatePatterns testGraph (reverse pats)
      length results `shouldBe` 5

  describe "runQuery" $ do
    it "selects all subject-object pairs for 'likes'" $ do
      let q = Select { vars = ["s", "o"]
                     , whereClause = [TP (QVar "s") (QTerm (iri "likes")) (QVar "o")] }
          results = runQuery testGraph q
      length results `shouldBe` 5
      [iri "Alice", iri "Bob"] `elem` results `shouldBe` True
      [iri "Bob", iri "Alice"] `elem` results `shouldBe` True

    it "selects who likes Bob" $ do
      let q = Select { vars = ["who"]
                     , whereClause = [TP (QVar "who") (QTerm (iri "likes")) (QTerm (iri "Bob"))] }
          results = runQuery testGraph q
      length results `shouldBe` 2
      [iri "Alice"] `elem` results `shouldBe` True
      [iri "Charlie"] `elem` results `shouldBe` True

    it "selects ages" $ do
      let q = Select { vars = ["who", "age"]
                     , whereClause = [TP (QVar "who") (QTerm (iri "age")) (QVar "age")] }
          results = runQuery testGraph q
      length results `shouldBe` 2
      [iri "Alice", lit "25"] `elem` results `shouldBe` True
      [iri "Bob", lit "28"] `elem` results `shouldBe` True

    it "handles join queries (mutual likes)" $ do
      let q = Select { vars = ["a", "b"]
                     , whereClause = [ TP (QVar "a") (QTerm (iri "likes")) (QVar "b")
                                     , TP (QVar "b") (QTerm (iri "likes")) (QVar "a") ] }
          results = runQuery testGraph q
      length results `shouldBe` 2
      [iri "Alice", iri "Bob"] `elem` results `shouldBe` True
      [iri "Bob", iri "Alice"] `elem` results `shouldBe` True

    it "returns empty list for no matches" $ do
      let q = Select { vars = ["x"]
                     , whereClause = [TP (QVar "x") (QTerm (iri "hates")) (QVar "y")] }
          results = runQuery testGraph q
      results `shouldBe` []
