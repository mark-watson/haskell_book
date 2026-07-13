{-# LANGUAGE OverloadedStrings #-}
module Main where

import Test.Hspec
import qualified DataFrame as D
import qualified DataFrame.Functions as F
import DataFrame.Operators
import Data.Text (Text)
import Control.Exception (try, IOException)

main :: IO ()
main = hspec spec

dataFile :: FilePath
dataFile = "./data/housing.csv"

loadData :: IO D.DataFrame
loadData = do
  result <- try (D.readCsv dataFile) :: IO (Either IOException D.DataFrame)
  case result of
    Left err -> expectationFailure ("Failed to load CSV: " ++ show err) >> undefined
    Right df -> pure df

spec :: Spec
spec = do
  describe "DataFrame basics" $ do
    it "loads CSV successfully" $ do
      df <- loadData
      D.nRows df `shouldSatisfy` (> 0)

    it "has expected columns" $ do
      df <- loadData
      let cols = D.columnNames df
      cols `shouldSatisfy` (\c -> "longitude" `elem` c)
      cols `shouldSatisfy` (\c -> "ocean_proximity" `elem` c)
      cols `shouldSatisfy` (\c -> "median_house_value" `elem` c)

  describe "take" $ do
    it "returns the requested number of rows" $ do
      df <- loadData
      D.nRows (D.take 5 df) `shouldBe` 5

    it "returns all rows when asked for more than available" $ do
      df <- loadData
      let n = D.nRows df
      D.nRows (D.take (n + 100) df) `shouldBe` n

  describe "filter" $ do
    it "reduces row count" $ do
      df <- loadData
      let filtered = df |> D.filter (F.col @Double "median_house_value") (> 400000)
      D.nRows filtered `shouldSatisfy` (< D.nRows df)

    it "keeps only matching rows" $ do
      df <- loadData
      let filtered = df |> D.filter (F.col @Text "ocean_proximity") (== "INLAND")
      D.nRows filtered `shouldSatisfy` (> 0)

  describe "derive" $ do
    it "adds a new derived column" $ do
      df <- loadData
      let enriched = df
            |> D.derive "rooms_per_household"
                 (F.toDouble (F.col @Int "total_rooms") / F.toDouble (F.col @Int "households"))
      let cols = D.columnNames enriched
      cols `shouldSatisfy` (\c -> "rooms_per_household" `elem` c)

    it "does not change row count" $ do
      df <- loadData
      let enriched = df
            |> D.derive "test_col" (F.toDouble (F.col @Int "population") * 2.0)
      D.nRows enriched `shouldBe` D.nRows df

  describe "select" $ do
    it "reduces to requested columns" $ do
      df <- loadData
      let selected = df |> D.select ["longitude", "latitude"]
      length (D.columnNames selected) `shouldBe` 2

    it "preserves row count" $ do
      df <- loadData
      let selected = df |> D.select ["median_income", "median_house_value"]
      D.nRows selected `shouldBe` D.nRows df

  describe "sortBy" $ do
    it "can sort by a column" $ do
      df <- loadData
      let sorted = df |> D.sortBy [D.Desc (F.col @Double "median_house_value")]
      D.nRows sorted `shouldBe` D.nRows df

  describe "groupBy and aggregate" $ do
    it "reduces rows when grouping" $ do
      df <- loadData
      let grouped = df
            |> D.groupBy ["ocean_proximity"]
            |> D.aggregate
                 [ F.count @Double (F.col @Double "median_house_value") `F.as` "num_districts"
                 , F.mean   @Double (F.col @Double "median_house_value") `F.as` "avg_house_value"
                 ]
      D.nRows grouped `shouldSatisfy` (< D.nRows df)
      let cols = D.columnNames grouped
      cols `shouldSatisfy` (\c -> "num_districts" `elem` c)
      cols `shouldSatisfy` (\c -> "avg_house_value" `elem` c)

  describe "pipeline" $ do
    it "filter, select, sort can be chained" $ do
      df <- loadData
      let result = df
            |> D.filter (F.col @Double "median_income") (>= 3.0)
            |> D.select ["median_income", "median_house_value", "ocean_proximity"]
            |> D.sortBy [D.Desc (F.col @Double "median_income")]
      D.nRows result `shouldSatisfy` (> 0)
      D.nRows result `shouldSatisfy` (< D.nRows df)
