# Data Analysis in Haskell with DataFrame

Haskell's mathematical purity allows for highly performant and expressive data manipulation algorithms. In this chapter, we will explore the `dataframe` library (version 1.0.0.0), a powerful tool for tabular data analysis, akin to Pandas in Python but built on Haskell's robust type system. 

We will walk through an example project that analyzes a California housing dataset. We will cover how to read and write CSV files, compute summary statistics, derive new columns, and perform complex filtering, sorting, and aggregations.

## Setup and Boilerplate

Before working directly with tabular data, we initialize our project with the required extensions and imports. We make use of `OverloadedStrings` for cleaner string literals and `TemplateHaskell` to securely typecheck column names at compile time.

```haskell
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}

module Main where

import qualified DataFrame          as D
import qualified DataFrame.Functions as F
import           DataFrame.Operators          -- re-exports (|>), (.==), (.>=), etc.
import           Data.Text          (Text)
```

The dataframe library uses Template Haskell to read the CSV headers at compile time. This ensures type-safe column references without tedious manual definition:

```haskell
-- Template-haskell: inspect the CSV at compile time and generate typed
-- column-reference bindings such as `total_rooms`, `households`, etc.
$(F.declareColumnsFromCsvFile "./data/housing.csv")
```

## Loading Data and Summary Statistics

To get started, we read the CSV into a DataFrame layout. The `dataframe` library affords commands similar to familiar database and analysis tools:

```haskell
main :: IO ()
main = do
  -- Load the dataset
  df <- D.readCsv "./data/housing.csv"

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
  -- Derive new columns: rooms_per_household, population_per_household, bedrooms_per_room
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
  -- Group by ocean proximity, aggregate metrics
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

Here is partial output from running this example:

```
 $ cabal run dataframe_example
HEAD is now at 5790ef4 Fix Functions module compilation in ghc 9.10 (#194)
Configuration is affected by the following files:
- cabal.project

=== California Housing Dataset ===
First 5 rows:
--------------------------------------------------------------------------------------------------------------------------------------------------------------
longitude | latitude | housing_median_age | total_rooms | total_bedrooms | population | households |   median_income    | median_house_value | ocean_proximity
----------|----------|--------------------|-------------|----------------|------------|------------|--------------------|--------------------|----------------
 Double   |  Double  |        Int         |     Int     |      Int       |    Int     |    Int     |       Double       |       Double       |      Text      
----------|----------|--------------------|-------------|----------------|------------|------------|--------------------|--------------------|----------------
-122.23   | 37.88    | 41                 | 880         | 129            | 322        | 126        | 8.3252             | 452600.0           | NEAR BAY       
-122.22   | 37.86    | 21                 | 7099        | 1106           | 2401       | 1138       | 8.3014             | 358500.0           | NEAR BAY       
-122.24   | 37.85    | 52                 | 1467        | 190            | 496        | 177        | 7.2574             | 352100.0           | NEAR BAY       
-122.25   | 37.85    | 52                 | 1274        | 235            | 558        | 219        | 5.6431000000000004 | 341300.0           | NEAR BAY       
-122.25   | 37.85    | 52                 | 1627        | 280            | 565        | 259        | 3.8462             | 342200.0           | NEAR BAY       

----------------------------------------------------------------------

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

=== Summary Statistics ===
---------------------------------------------------------------------------------------------------------------------------------------------------
Statistic | longitude | latitude | housing_median_age | total_rooms | total_bedrooms | population | households | median_income | median_house_value
----------|-----------|----------|--------------------|-------------|----------------|------------|------------|---------------|-------------------
  Text    |  Double   |  Double  |       Double       |   Double    |     Double     |   Double   |   Double   |    Double     |       Double      
----------|-----------|----------|--------------------|-------------|----------------|------------|------------|---------------|-------------------
Count     | 50.0      | 50.0     | 50.0               | 50.0        | 50.0           | 50.0       | 50.0       | 50.0          | 50.0              
Mean      | -120.6    | 36.56    | 30.38              | 3216.18     | 634.22         | 1272.06    | 560.04     | 4.57          | 334996.0          
Minimum   | -124.2    | 33.75    | 8.0                | 880.0       | 129.0          | 322.0      | 126.0      | 1.5           | 120000.0          
25%       | -122.21   | 34.26    | 20.0               | 1670.25     | 312.5          | 625.0      | 280.0      | 3.5           | 230025.0          
Median    | -120.88   | 36.69    | 28.0               | 2800.0      | 560.0          | 1120.0     | 507.0      | 4.5           | 341750.0          
75%       | -118.61   | 37.78    | 40.75              | 4200.0      | 840.0          | 1680.0     | 747.5      | 5.61          | 447500.0          
Max       | -117.8    | 41.8     | 52.0               | 8100.0      | 1600.0         | 3200.0     | 1250.0     | 8.33          | 560000.0          
StdDev    | 1.91      | 2.03     | 13.5               | 1879.38     | 365.1          | 727.44     | 308.12     | 1.59          | 122465.13         
IQR       | 3.6       | 3.52     | 20.75              | 2529.75     | 527.5          | 1055.0     | 467.5      | 2.11          | 217475.0          
Skewness  | -1.0e-2   | 0.5      | 0.27               | 0.79        | 0.67           | 0.71       | 0.48       | 0.29          | -5.0e-2           

----------------------------------------------------------------------

=== Derived Columns (first 5 rows) ===
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
longitude | latitude | housing_median_age | total_rooms | total_bedrooms | population | households |   median_income    | median_house_value | ocean_proximity | rooms_per_household | population_per_household |  bedrooms_per_room 
----------|----------|--------------------|-------------|----------------|------------|------------|--------------------|--------------------|-----------------|---------------------|--------------------------|--------------------
 Double   |  Double  |        Int         |     Int     |      Int       |    Int     |    Int     |       Double       |       Double       |      Text       |       Double        |          Double          |       Double       
----------|----------|--------------------|-------------|----------------|------------|------------|--------------------|--------------------|-----------------|---------------------|--------------------------|--------------------
-122.23   | 37.88    | 41                 | 880         | 129            | 322        | 126        | 8.3252             | 452600.0           | NEAR BAY        | 6.984126984126984   | 2.5555555555555554       | 0.14659090909090908
-122.22   | 37.86    | 21                 | 7099        | 1106           | 2401       | 1138       | 8.3014             | 358500.0           | NEAR BAY        | 6.238137082601054   | 2.109841827768014        | 0.15579659106916466
-122.24   | 37.85    | 52                 | 1467        | 190            | 496        | 177        | 7.2574             | 352100.0           | NEAR BAY        | 8.288135593220339   | 2.8022598870056497       | 0.12951601908657123
-122.25   | 37.85    | 52                 | 1274        | 235            | 558        | 219        | 5.6431000000000004 | 341300.0           | NEAR BAY        | 5.8173515981735155  | 2.547945205479452        | 0.18445839874411302
-122.25   | 37.85    | 52                 | 1627        | 280            | 565        | 259        | 3.8462             | 342200.0           | NEAR BAY        | 6.281853281853282   | 2.1814671814671813       | 0.1720958819913952 

----------------------------------------------------------------------

=== Expensive Coastal Properties (value > $400k) ===
Row count: 13
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
longitude | latitude | housing_median_age | total_rooms | total_bedrooms | population | households | median_income | median_house_value | ocean_proximity | rooms_per_household | population_per_household |  bedrooms_per_room 
----------|----------|--------------------|-------------|----------------|------------|------------|---------------|--------------------|-----------------|---------------------|--------------------------|--------------------
 Double   |  Double  |        Int         |     Int     |      Int       |    Int     |    Int     |    Double     |       Double       |      Text       |       Double        |          Double          |       Double       
----------|----------|--------------------|-------------|----------------|------------|------------|---------------|--------------------|-----------------|---------------------|--------------------------|--------------------
-122.23   | 37.88    | 41                 | 880         | 129            | 322        | 126        | 8.3252        | 452600.0           | NEAR BAY        | 6.984126984126984   | 2.5555555555555554       | 0.14659090909090908
-118.4    | 33.98    | 15                 | 5600        | 1100           | 2200       | 900        | 5.2           | 480000.0           | NEAR OCEAN      | 6.222222222222222   | 2.4444444444444446       | 0.19642857142857142
-118.2    | 34.1     | 40                 | 2800        | 550            | 1100       | 500        | 6.1           | 410000.0           | NEAR OCEAN      | 5.6                 | 2.2                      | 0.19642857142857142
-117.8    | 33.75    | 10                 | 7200        | 1400           | 2800       | 1100       | 6.8           | 520000.0           | <1H OCEAN       | 6.545454545454546   | 2.5454545454545454       | 0.19444444444444445
-117.85   | 33.8     | 12                 | 6500        | 1280           | 2500       | 1050       | 6.2           | 490000.0           | <1H OCEAN       | 6.190476190476191   | 2.380952380952381        | 0.19692307692307692

----------------------------------------------------------------------

=== Selected Columns ===
-----------------------------------------------------------------------------------------------------
ocean_proximity | median_income | median_house_value | rooms_per_household | population_per_household
----------------|---------------|--------------------|---------------------|-------------------------
     Text       |    Double     |       Double       |       Double        |          Double         
----------------|---------------|--------------------|---------------------|-------------------------
NEAR BAY        | 8.3252        | 452600.0           | 6.984126984126984   | 2.5555555555555554      
NEAR OCEAN      | 5.2           | 480000.0           | 6.222222222222222   | 2.4444444444444446      
NEAR OCEAN      | 6.1           | 410000.0           | 5.6                 | 2.2                     
<1H OCEAN       | 6.8           | 520000.0           | 6.545454545454546   | 2.5454545454545454      
<1H OCEAN       | 6.2           | 490000.0           | 6.190476190476191   | 2.380952380952381       

----------------------------------------------------------------------

=== Top 5 Most Expensive Properties ===
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
longitude | latitude | housing_median_age | total_rooms | total_bedrooms | population | households | median_income | median_house_value | ocean_proximity | rooms_per_household | population_per_household |  bedrooms_per_room 
----------|----------|--------------------|-------------|----------------|------------|------------|---------------|--------------------|-----------------|---------------------|--------------------------|--------------------
 Double   |  Double  |        Int         |     Int     |      Int       |    Int     |    Int     |    Double     |       Double       |      Text       |       Double        |          Double          |       Double       
----------|----------|--------------------|-------------|----------------|------------|------------|---------------|--------------------|-----------------|---------------------|--------------------------|--------------------
-117.9    | 33.82    | 8                  | 8100        | 1600           | 3200       | 1250       | 7.1           | 560000.0           | <1H OCEAN       | 6.48                | 2.56                     | 0.19753086419753085
-117.8    | 33.75    | 10                 | 7200        | 1400           | 2800       | 1100       | 6.8           | 520000.0           | <1H OCEAN       | 6.545454545454546   | 2.5454545454545454       | 0.19444444444444445
-118.6    | 34.25    | 15                 | 6400        | 1280           | 2560       | 1120       | 6.3           | 520000.0           | <1H OCEAN       | 5.714285714285714   | 2.2857142857142856       | 0.2                
-122.2    | 37.61    | 15                 | 4800        | 960            | 1920       | 845        | 6.2           | 500000.0           | BAY             | 5.680473372781065   | 2.272189349112426        | 0.2                
-117.85   | 33.8     | 12                 | 6500        | 1280           | 2500       | 1050       | 6.2           | 490000.0           | <1H OCEAN       | 6.190476190476191   | 2.380952380952381        | 0.19692307692307692

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

