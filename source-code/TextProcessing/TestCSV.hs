module Main where

import Text.CSV (parseCSVFromFile, CSV)

readCsvFile :: FilePath -> IO CSV
readCsvFile fname = do
  c <- parseCSVFromFile fname
  case c of
    Left err -> do
      putStrLn $ "CSV parse error: " ++ show err
      return []
    Right csv -> return csv

main :: IO ()
main = do
  c <- readCsvFile "test.csv"
  print  c
  print $ map head c
  case c of
    [] -> putStrLn "Warning: CSV file is empty, no header or rows."
    (header:rows) -> do
      print header
      print rows

