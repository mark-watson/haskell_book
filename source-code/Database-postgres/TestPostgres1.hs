{-# LANGUAGE OverloadedStrings #-}

-- | PostgreSQL database example using the @postgresql-simple@ library.
--
-- __Prerequisites__: Before running, ensure the @customers@ table exists:
--
-- @
--   CREATE TABLE customers (
--     id    INTEGER PRIMARY KEY,
--     name  TEXT NOT NULL,
--     email TEXT NOT NULL
--   );
-- @
--
-- Connection credentials are read from environment variables:
--
--   * @PGDATABASE@ – database name  (default: @haskell@)
--   * @PGUSER@     – database user   (default: @postgres@)
--   * @PGPASSWORD@ – user password   (default: empty)

module Main where

import Control.Exception          (bracket)
import Data.Maybe                 (fromMaybe)
import Database.PostgreSQL.Simple
import System.Environment         (lookupEnv)

main :: IO ()
main = do
  -- Read connection parameters from environment variables, with sensible defaults.
  dbName <- fromMaybe "haskell"  <$> lookupEnv "PGDATABASE"
  dbUser <- fromMaybe "postgres" <$> lookupEnv "PGUSER"
  dbPass <- fromMaybe ""         <$> lookupEnv "PGPASSWORD"

  let connInfo = defaultConnectInfo
        { connectDatabase = dbName
        , connectUser     = dbUser
        , connectPassword = dbPass
        }

  -- Use `bracket` to guarantee the connection is closed even if an exception
  -- is thrown during the database operations.
  bracket (connect connInfo) close $ \conn -> do
    -- List names from the 'customers' table:
    r <- query_ conn "SELECT name FROM customers" :: IO [(Only String)]
    print "names and emails in table 'customers' in database haskell:"
    mapM_ (print . fromOnly) r

    -- Add a row to table 'customers' and print the updated contents:
    let rows :: [(Int, String, String)]
        rows = [(4, "Mary Smith", "marys@acme.com")]
    executeMany conn "INSERT INTO customers (id, name, email) VALUES (?,?,?)" rows
    r2 <- query_ conn "SELECT * from customers" :: IO [(Int, String, String)]
    print "number of rows in table 'customers':"
    print (length r2)
    print "rows in table 'customers':"
    mapM_ print r2