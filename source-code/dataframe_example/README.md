# dataframe_example

A Haskell project demonstrating the [`dataframe` 1.0.0.0 library](https://hackage.haskell.org/package/dataframe) with a California housing dataset.

**Reference:** [ANN: dataframe 1.0.0.0](https://discourse.haskell.org/t/ann-dataframe-1-0-0-0/13834)

## Project Layout

```
dataframe_example/
├── dataframe_example.cabal   -- build configuration
├── data/
│   └── housing.csv           -- 50-row California housing dataset
├── src/
│   └── Main.hs               -- analysis example
└── README.md
```

## Dataset

`data/housing.csv` contains 50 synthetic California housing district records with:

| Column | Type | Description |
|---|---|---|
| `longitude` / `latitude` | Double | Geographic coordinates |
| `housing_median_age` | Double | Median age of houses in district |
| `total_rooms` | Double | Total number of rooms |
| `total_bedrooms` | Double | Total number of bedrooms |
| `population` | Double | District population |
| `households` | Double | Number of households |
| `median_income` | Double | Median household income (tens of thousands USD) |
| `median_house_value` | Double | Median house value (USD) |
| `ocean_proximity` | Text | Distance category from ocean |

## What the Example Demonstrates

The `Main.hs` program walks through a typical data analysis pipeline:

1. **Load** — `D.readCsv` reads the CSV
2. **Explore** — `D.take`, `D.describeColumns`, `D.summarize`
3. **Derive columns** — `D.derive` with arithmetic on typed column references (`total_rooms / households`)
4. **Filter rows** — `D.filter` to select expensive coastal properties
5. **Select columns** — `D.select` to narrow the schema
6. **Sort** — `D.sortBy D.Descending` to rank by value
7. **Group & aggregate** — `D.groupBy` + `D.aggregate` with `F.count`, `F.mean`
8. **Write** — `D.writeCsv` exports the enriched dataset

### Key API Elements Used

```haskell
-- I/O
D.readCsv  :: FilePath -> IO DataFrame
D.writeCsv :: FilePath -> DataFrame -> IO ()

-- Exploration
D.take           :: Int -> DataFrame -> DataFrame
D.describeColumns :: DataFrame -> DataFrame
D.summarize      :: DataFrame -> DataFrame

-- Column operations
D.derive  :: Text -> Expr a   -> DataFrame -> DataFrame
D.select  :: [Text]           -> DataFrame -> DataFrame
D.exclude :: [Text]           -> DataFrame -> DataFrame

-- Row operations
D.filter      :: Expr a -> (a -> Bool) -> DataFrame -> DataFrame
D.filterWhere :: Expr Bool             -> DataFrame -> DataFrame
D.sortBy      :: SortOrder -> [Text]   -> DataFrame -> DataFrame

-- Grouping
D.groupBy   :: [Text]        -> DataFrame        -> GroupedDataFrame
D.aggregate :: [NamedExpr]   -> GroupedDataFrame -> DataFrame

-- Expression DSL
F.col  @Type "column_name"   -- typed column reference
F.lit  @Type value           -- typed literal
F.mean, F.sum, F.count, F.min, F.max  -- aggregators
F.as   :: Expr a -> Text -> NamedExpr -- rename aggregated column

-- TH helper (generates typed column bindings at compile time)
$(F.declareColumnsFromCsvFile "./data/housing.csv")
```

## Building & Running

Requires [GHC](https://www.haskell.org/ghcup/) and [cabal](https://cabal.readthedocs.io).

```bash
cd dataframe_example
cabal update
cabal run dataframe_example
```

The program prints analysis results to stdout and writes
`data/housing_enriched.csv` with the extra derived columns.

## Expected Output (excerpt)

```
=== California Housing Dataset ===
First 5 rows:
...

=== Average House Value by Ocean Proximity ===
ocean_proximity | avg_house_value | avg_income | avg_rooms_per_hh
----------------|-----------------|------------|------------------
<1H OCEAN       |        474000.0 |       5.66 |             5.19
NEAR BAY        |        338000.0 |       5.48 |             6.14
...
```

## Further Reading

- [Dataframe documentation](https://dataframe.readthedocs.io/en/latest/)
- [Hackage API reference](https://hackage.haskell.org/package/dataframe/docs/DataFrame.html)
- [GitHub examples](https://github.com/DataHaskell/dataframe/tree/main/examples)
