{-# LANGUAGE OverloadedStrings #-} -- allow string literals for multiple string types (e.g., Text)

-- | SQLite database example using the @sqlite-simple@ library.
--
-- SQLite is a __serverless__, zero-configuration, file-based database engine.
-- There is no separate server process – the library reads and writes directly
-- to an ordinary disk file (here @test.db@).
--
-- This example is derived from the example at github.com/nurpax/sqlite-simple
-- Program flow: connect → ensure table exists → list tables → show schema
--                → insert a row → list rows

module Main where

import Database.SQLite.Simple -- open, close, withConnection, query_, execute, execute_, Only, fromOnly

-- | Entry point: perform database actions inside IO.
--
-- Uses 'withConnection' (instead of manual 'open'/'close') so the database
-- handle is always released, even if an exception is thrown.
main :: IO ()
main = withConnection "test.db" $ \conn -> do
  -- Self-initialize: create the table if it doesn't already exist.
  -- This removes the need for the external `sqlite3 test.db "create table …"` step.
  execute_ conn "CREATE TABLE IF NOT EXISTS test (id INTEGER PRIMARY KEY, str text)"

  -- List table names in the database:
  -- `query_` runs a SQL string and returns rows.
  -- `Only` is a newtype wrapper for single-column results – it exists because
  -- Haskell tuples need at least two elements, so a one-element "tuple" is
  -- represented by `Only a`.  `fromOnly` unwraps the value back out.
  r <- query_ conn "SELECT name FROM sqlite_master WHERE type='table'" :: IO [Only String]
  print "Table names in database test.db:"
  mapM_ (print . fromOnly) r

  -- Get the metadata for table 'test' in test.db:
  -- Each row is a single text column containing the table's CREATE statement.
  r1 <- query_ conn "SELECT sql FROM sqlite_master WHERE type='table' and name='test'" :: IO [Only String]
  print "SQL to create table 'test' in database test.db:"
  mapM_ (print . fromOnly) r1

  -- Add a row to table 'test' and then print out the rows in table 'test':
  -- `execute` runs a parameterized statement; `Only` binds the single placeholder ("?").
  execute conn "INSERT INTO test (str) VALUES (?)"
    (Only ("test string 2" :: String))
  -- Query all rows; result type is a tuple matching columns: (id :: Int, str :: String).
  r2 <- query_ conn "SELECT * from test" :: IO [(Int, String)]
  print "number of rows in table 'test':"
  print (length r2)
  print "rows in table 'test':"
  -- `mapM_` applies `print` to each row in the result list.
  mapM_ print r2