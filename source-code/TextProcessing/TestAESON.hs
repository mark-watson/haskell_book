{-# LANGUAGE DeriveGeneric #-}

module Main where

import Data.Aeson
import GHC.Generics
import Data.Maybe

data Person = Person {name::String, email::String } deriving (Show, Generic)

-- nice trick from School Of Haskell tutorial on Aeson:
instance FromJSON Person  -- DeriveGeneric language setting allows
instance ToJSON Person    -- automatic generation of instance of
                          -- types deriving Generic.

main :: IO ()
main = do
  let a = encode $ Person "Sam" "sam@a.com"
  print a
  case decode a :: Maybe Person of
    Nothing -> putStrLn "Error: failed to decode JSON back to Person"
    Just d  -> do
      print d
      print $ name d
      print $ email d

