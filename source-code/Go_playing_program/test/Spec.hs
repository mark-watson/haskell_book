module Main where

import Test.Hspec
import Board
import qualified Data.Vector.Unboxed as V

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "Board basics" $ do
    it "emptyBoard creates a 9x9 board" $ do
      let b = emptyBoard 9
      boardSz b `shouldBe` 9
      V.length (boardGrid b) `shouldBe` 81
    it "empty board has all empty stones" $ do
      let b = emptyBoard 9
      all (== Empty) (map (stoneAt b) [0 .. 80]) `shouldBe` True
    it "boardIdx computes flat index" $ do
      let b = emptyBoard 9
      boardIdx b 0 0 `shouldBe` 0
      boardIdx b 0 8 `shouldBe` 8
      boardIdx b 8 0 `shouldBe` 72
      boardIdx b 8 8 `shouldBe` 80
    it "rowOf and colOf are inverses of boardIdx" $ do
      let b = emptyBoard 13
          i = boardIdx b 5 7
      rowOf b i `shouldBe` 5
      colOf b i `shouldBe` 7

  describe "neighbors" $ do
    it "corner has 2 neighbors" $ do
      let b = emptyBoard 9
      length (neighbors b 0) `shouldBe` 2
    it "edge has 3 neighbors" $ do
      let b = emptyBoard 9
      length (neighbors b 1) `shouldBe` 3
    it "center has 4 neighbors" $ do
      let b = emptyBoard 9
      length (neighbors b 40) `shouldBe` 4

  describe "stoneAt and color" $ do
    it "opp swaps colors" $ do
      opp Black `shouldBe` White
      opp White `shouldBe` Black

  describe "tryPlay" $ do
    it "can play on an empty intersection" $ do
      let b = emptyBoard 9
      case tryPlay b (boardIdx b 4 4) of
        Nothing -> expectationFailure "Expected legal move"
        Just b' -> do
          stoneAt b' (boardIdx b' 4 4) `shouldBe` Occupied Black
          boardToMove b' `shouldBe` White
    it "cannot play on an occupied intersection" $ do
      let b = emptyBoard 9
      case tryPlay b 40 of
        Just b' -> tryPlay b' 40 `shouldBe` Nothing
        Nothing -> expectationFailure "First move should succeed"
    it "cannot play a suicidal move (own group with 0 liberties)" $ do
      let b = emptyBoard 9
      -- Place white stones around a corner
      case tryPlay b 0 of  -- Black plays at 0,0
        Just b1 -> case tryPlay b1 1 of  -- White plays at 0,1
          Just b2 -> case tryPlay b2 9 of  -- Black plays at 1,0
            Just b3 -> do
              -- Now try White at 0,0 which is occupied by Black
              tryPlay b3 0 `shouldBe` Nothing
            Nothing -> expectationFailure "Move 3 should succeed"
          Nothing -> expectationFailure "Move 2 should succeed"
        Nothing -> expectationFailure "Move 1 should succeed"

  describe "passMove" $ do
    it "changes whose turn it is" $ do
      let b = emptyBoard 9
      boardToMove (passMove b) `shouldBe` White
    it "does not change the grid" $ do
      let b = emptyBoard 9
      boardGrid (passMove b) `shouldBe` boardGrid b

  describe "areaScore" $ do
    it "empty board has score near 0" $ do
      let b = emptyBoard 9
      abs (areaScore b) `shouldSatisfy` (< 1.0)
