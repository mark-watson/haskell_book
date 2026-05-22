module Main where

import System.IO
import Control.Exception (IOException, catch)

-- | Catch only IOExceptions rather than SomeException.
-- Catching SomeException is considered bad practice because it also
-- catches async exceptions (e.g. ThreadKilled, UserInterrupt) that
-- should normally be allowed to propagate.  Narrowing the catch to
-- IOException ensures we only handle file-system / IO errors.
catchIO :: IO a -> (IOException -> IO a) -> IO a
catchIO = Control.Exception.catch

safeFileReader :: FilePath -> IO String
safeFileReader fPath = do
  entireFileAsString <- catchIO (readFile fPath) $ \err -> do
    putStrLn $ "Error: " ++ show err
    return ""
  return entireFileAsString

main :: IO ()
main = do
  fContents <- safeFileReader "temp.txt"
  print fContents
  print $ words fContents
