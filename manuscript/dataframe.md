# Data Analysis in Haskell with DataFrame

Haskell's mathematical purity allows for highly performant and expressive data manipulation algorithms. In this chapter, we will explore the `dataframe` library (version 1.0.0.0), a powerful tool for tabular data analysis, akin to Pandas in Python but built on Haskell's robust type system. 

We will walk through an example project that analyzes a California housing dataset. We will cover how to read and write CSV files, compute summary statistics, derive new columns, and perform complex filtering, sorting, and aggregations.

## Setup and Boilerplate

Before working directly with tabular data, we initialize our project with the required extensions and imports. We make use of `OverloadedStrings` for cleaner string literals and `ScopedTypeVariables` for explicit type applications on column references.

```haskell
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Main where

import qualified DataFrame          as D
import qualified DataFrame.Functions as F
import           DataFrame.Operators          -- re-exports (|>), (.==), (.>=), etc.
import           Data.Text          (Text)
import           Control.Exception  (IOException, try)
import           System.Exit        (exitFailure)
```

All column references in this example use string-based `F.col @T "name"` syntax. The dataframe library also supports a Template Haskell splice (`F.declareColumnsFromCsvFile`) that generates typed column-reference bindings at compile time; if you want that extra compile-time column safety, add `{-# LANGUAGE TemplateHaskell #-}` and uncomment the splice.

![DataFrame Analysis Pipeline Architecture](FIG_dataframe_example.jpg)

## Loading Data and Summary Statistics

To get started, we read the CSV into a DataFrame layout. The `dataframe` library affords commands similar to familiar database and analysis tools. We wrap the load in `try`/`catch` so we get a clear error message if the CSV is missing:

```haskell
main :: IO ()
main = do
  -- Wrap in try/catch so we get a clear error message if the CSV is missing.
  result <- try (D.readCsv "./data/housing.csv") :: IO (Either IOException D.DataFrame)
  df <- case result of
    Left err -> do
      putStrLn $ "ERROR: Could not load CSV file: " <> show err
      putStrLn "Make sure you are running from the dataframe_example project root."
      exitFailure
    Right v  -> pure v

  putStrLn "\n=== California Housing Dataset ==="
  putStrLn "First 5 rows:"
  print (D.take 5 df)
```

Once the dataframe is loaded, initial exploration is crucial. To quickly get a grasp of your data's distribution and missing values, use summary capabilities:

```haskell
  putStrLn "\n=== Column Descriptions ==="
  print (D.describeColumns df)

  putStrLn "\n=== Summary Statistics ==="
  print (D.summarize df)
```

## Deriving New Columns

Often, your analysis requires data metrics not present in the original dataset. You can easily derive new characteristics by applying arithmetic on existing typed columns using the `D.derive` function and a custom pipe operator `|>` to sequence data transformations.

Let's compute the number of rooms per household, population density per household, and bedrooms relative to total rooms:

```haskell
  -- rooms_per_household, bedrooms_per_room, population_per_household
  let enriched =
        df
          |> D.derive "rooms_per_household"
               (F.toDouble (F.col @Int "total_rooms") / F.toDouble (F.col @Int "households"))
          |> D.derive "population_per_household"
               (F.toDouble (F.col @Int "population") / F.toDouble (F.col @Int "households"))
          |> D.derive "bedrooms_per_room"
               (F.toDouble (F.col @Int "total_bedrooms") / F.toDouble (F.col @Int "total_rooms"))
```

## Filtering and Selection

For narrower views of data domains, the `D.filter` and `D.select` combinators slice via row bounds and column scopes. Let's isolate the high-value properties along the coastline:

```haskell
  -- Filter: keep high-value coastal properties
  let expensive =
        enriched
          |> D.filter (F.col @Double "median_house_value") (> 400000)
          |> D.filter (F.col @Text   "ocean_proximity")    (\p -> p `elem` ["NEAR BAY", "NEAR OCEAN", "<1H OCEAN"])

  -- Select relevant columns only
  let selected =
        expensive
          |> D.select ["ocean_proximity", "median_income", "median_house_value",
                       "rooms_per_household", "population_per_household"]
```

## Sorting

Data representation often necessitates ordering by weight or date. To organize our dataset sequentially descending by value, `D.sortBy` applies the required transformation:

```haskell
  -- Sort by median house value descending
  let sorted =
        enriched
          |> D.sortBy [D.Desc (F.col @Double "median_house_value")]
```

## Grouping and Aggregation

Analyzing wide margins requires grouping data under unique traits and gathering statistical clusters. 

For instance, we can group attributes by their proximity to the ocean and compute aggregate values. Notice we leverage aliases using `F.as` for these computed categories.

```haskell
  -- Group by ocean proximity, aggregate
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
```

## Writing Data to Files

Finally, we use `writeCsv` to save the enriched dataframe into a fresh text representation ready for broader sharing.

```haskell
  -- Write enriched dataset to CSV
  D.writeCsv "./data/housing_enriched.csv" enriched
  putStrLn "\nEnriched dataset written to ./data/housing_enriched.csv"
```

The dataframe structure showcases Haskell's elegant pipe-forward functional capability and statically typed robustness, letting us perform common Pandas-like analyses fluently, without leaving the type safety of Haskell behind.

Here is partial output from running this example (output that spans > 100 columns not show - run the example to see the full output):

```
 $ cabal run dataframe_example
HEAD is now at 5790ef4 Fix Functions module compilation in ghc 9.10 (#194)
Configuration is affected by the following files:
- cabal.project

=== Column Descriptions ===
---------------------------------------------------------------
   Column Name     | # Non-null Values | # Null Values |  Type 
-------------------|-------------------|---------------|-------
       Text        |        Int        |      Int      |  Text 
-------------------|-------------------|---------------|-------
ocean_proximity    | 50                | 0             | Text  
median_house_value | 50                | 0             | Double
median_income      | 50                | 0             | Double
households         | 50                | 0             | Int   
population         | 50                | 0             | Int   
total_bedrooms     | 50                | 0             | Int   
total_rooms        | 50                | 0             | Int   
housing_median_age | 50                | 0             | Int   
latitude           | 50                | 0             | Double
longitude          | 50                | 0             | Double

----------------------------------------------------------------------

=== Average House Value by Ocean Proximity ===
--------------------------------------------------------------------------------------------
ocean_proximity | num_districts |  avg_house_value   |    avg_income     | avg_rooms_per_hh 
----------------|---------------|--------------------|-------------------|------------------
     Text       |      Int      |       Double       |      Double       |      Double      
----------------|---------------|--------------------|-------------------|------------------
<1H OCEAN       | 10            | 484000.0           | 5.88              | 5.891623561548036
BAY             | 5             | 450000.0           | 5.5               | 5.679258351578158
NEAR OCEAN      | 10            | 333000.0           | 4.3               | 5.738715647098   
NEAR BAY        | 10            | 314480.0           | 4.99608           | 5.736540211611564
INLAND          | 15            | 212333.33333333334 | 3.266666666666667 | 5.655433028354371

----------------------------------------------------------------------

=== Inland Districts with Median Income >= $40k ===
-------------------------------------------------------------------------------
longitude | latitude | median_income | median_house_value | rooms_per_household
----------|----------|---------------|--------------------|--------------------
 Double   |  Double  |    Double     |       Double       |       Double       
----------|----------|---------------|--------------------|--------------------
-122.0    | 37.4     | 4.6           | 330000.0           | 5.6521739130434785 
-119.8    | 36.65    | 4.5           | 240000.0           | 5.6716417910447765 
-121.95   | 37.38    | 4.2           | 310000.0           | 5.641025641025641  
-119.75   | 36.62    | 4.0           | 210000.0           | 5.660377358490566  

----------------------------------------------------------------------

Enriched dataset written to ./data/housing_enriched.csv
$
```

