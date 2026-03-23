{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}

-- | Housing data analysis using the dataframe 1.0.0.0 library.
--
-- This example loads a California housing dataset and demonstrates:
--   * Reading a CSV file
--   * Initial exploration (summarise, describe, take)
--   * Deriving computed columns
--   * Filtering rows
--   * Sorting
--   * Grouping and aggregation
--
-- Reference: https://discourse.haskell.org/t/ann-dataframe-1-0-0-0/13834
--            https://hackage.haskell.org/package/dataframe

module Main where

import qualified DataFrame          as D
import qualified DataFrame.Functions as F
import           DataFrame.Operators          -- re-exports (|>), (.==), (.>=), etc.
import           Data.Text          (Text)

-- ---------------------------------------------------------------------------
-- Template-haskell: inspect the CSV at compile time and generate typed
-- column-reference bindings such as `total_rooms`, `households`, etc.
-- ---------------------------------------------------------------------------
$(F.declareColumnsFromCsvFile "./data/housing.csv")

-- ---------------------------------------------------------------------------
-- Helper
-- ---------------------------------------------------------------------------
separator :: IO ()
separator = putStrLn (replicate 70 '-')

-- ---------------------------------------------------------------------------
-- Main
-- ---------------------------------------------------------------------------
main :: IO ()
main = do
  -- ── 1. Load ──────────────────────────────────────────────────────────────
  df <- D.readCsv "./data/housing.csv"

  putStrLn "\n=== California Housing Dataset ==="
  putStrLn "First 5 rows:"
  print (D.take 5 df)
  separator

  -- ── 2. Summary statistics ─────────────────────────────────────────────────
  putStrLn "\n=== Column Descriptions ==="
  print (D.describeColumns df)
  separator

  putStrLn "\n=== Summary Statistics ==="
  print (D.summarize df)
  separator

  -- ── 3. Derive new columns ─────────────────────────────────────────────────
  -- rooms_per_household, bedrooms_per_room, population_per_household
  let enriched =
        df
          |> D.derive "rooms_per_household"
               (F.toDouble (F.col @Int "total_rooms") / F.toDouble (F.col @Int "households"))
          |> D.derive "population_per_household"
               (F.toDouble (F.col @Int "population") / F.toDouble (F.col @Int "households"))
          |> D.derive "bedrooms_per_room"
               (F.toDouble (F.col @Int "total_bedrooms") / F.toDouble (F.col @Int "total_rooms"))

  putStrLn "\n=== Derived Columns (first 5 rows) ==="
  print (D.take 5 enriched)
  separator

  -- ── 4. Filter: keep high-value coastal properties ────────────────────────
  let expensive =
        enriched
          |> D.filter (F.col @Double "median_house_value") (> 400000)
          |> D.filter (F.col @Text   "ocean_proximity")    (\p -> p `elem` ["NEAR BAY", "NEAR OCEAN", "<1H OCEAN"])

  putStrLn "\n=== Expensive Coastal Properties (value > $400k) ==="
  putStrLn $ "Row count: " <> show (D.nRows expensive)
  print (D.take 5 expensive)
  separator

  -- ── 5. Select relevant columns only ──────────────────────────────────────
  let selected =
        expensive
          |> D.select ["ocean_proximity", "median_income", "median_house_value",
                       "rooms_per_household", "population_per_household"]

  putStrLn "\n=== Selected Columns ==="
  print (D.take 5 selected)
  separator

  -- ── 6. Sort by median house value descending ──────────────────────────────
  let sorted =
        enriched
          |> D.sortBy [D.Desc (F.col @Double "median_house_value")]

  putStrLn "\n=== Top 5 Most Expensive Properties ==="
  print (D.take 5 sorted)
  separator

  -- ── 7. Group by ocean proximity, aggregate ────────────────────────────────
  let byProximity =
        enriched
          |> D.groupBy ["ocean_proximity"]
          |> D.aggregate
               [ F.count @Double (F.col @Double "median_house_value") `F.as` "num_districts"
               , F.mean  @Double (F.col @Double "median_house_value") `F.as` "avg_house_value"
               , F.mean  @Double (F.col @Double "median_income")      `F.as` "avg_income"
               , F.mean  @Double (F.col @Double "rooms_per_household")`F.as` "avg_rooms_per_hh"
               ]
          |> D.sortBy [D.Desc (F.col @Double "avg_house_value")]

  putStrLn "\n=== Average House Value by Ocean Proximity ==="
  print byProximity
  separator

  -- ── 8. Filter + group: inland districts with high income ─────────────────
  let highIncomeInland =
        enriched
          |> D.filter (F.col @Text   "ocean_proximity") (== "INLAND")
          |> D.filter (F.col @Double "median_income")   (>= 4.0)
          |> D.select ["longitude", "latitude", "median_income",
                       "median_house_value", "rooms_per_household"]
          |> D.sortBy [D.Desc (F.col @Double "median_income")]

  putStrLn "\n=== Inland Districts with Median Income >= $40k ==="
  print highIncomeInland
  separator

  -- ── 9. Write enriched dataset to CSV ─────────────────────────────────────
  D.writeCsv "./data/housing_enriched.csv" enriched
  putStrLn "\nEnriched dataset written to ./data/housing_enriched.csv"
