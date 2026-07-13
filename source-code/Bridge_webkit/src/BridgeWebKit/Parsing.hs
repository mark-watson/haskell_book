{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}

module BridgeWebKit.Parsing
  ( -- * Types
    PlayedCard (..)
  , BidEntry (..)
  , HandList (..)
    -- * Parsing
  , trim
  , parseBidInput
  , parseStrain
  ) where

import Data.Char (toUpper, isDigit)
import Bridge.Types
import GHC.Generics (Generic)
import qualified Data.Aeson as Aeson

-- | A card played by a specific player.
data PlayedCard = PlayedCard
  { pcPlayer :: String
  , pcCard   :: String
  } deriving (Generic, Aeson.ToJSON, Eq, Show)

-- | An entry in the bidding history.
data BidEntry = BidEntry
  { bePlayer :: String
  , beBid    :: String
  } deriving (Generic, Aeson.ToJSON, Eq, Show)

-- | All four hands as card strings.
data HandList = HandList
  { hlNorth :: [String]
  , hlEast  :: [String]
  , hlSouth :: [String]
  , hlWest  :: [String]
  } deriving (Generic, Aeson.ToJSON, Eq, Show)

-- | Trim leading and trailing spaces.
trim :: String -> String
trim = f . f
  where f = reverse . dropWhile (== ' ')

-- | Parse user input into a BidType.
parseBidInput :: String -> Maybe BidType
parseBidInput raw =
  let s = map toUpper (trim raw)
  in case s of
    "PASS" -> Just Pass
    "P" -> Just Pass
    "DOUBLE" -> Just DoubleBid
    "DBL" -> Just DoubleBid
    "X" -> Just DoubleBid
    "REDOUBLE" -> Just RedoubleBid
    "RDBL" -> Just RedoubleBid
    "XX" -> Just RedoubleBid
    (c:strainStr) | isDigit c ->
      let
        level = read [c] :: Int
      in if level >= 1 && level <= 7
         then case parseStrain strainStr of
                Just strain -> Just (SuitBid level strain)
                Nothing -> Nothing
         else Nothing
    _ -> Nothing

-- | Parse a strain suffix string (e.g., "NT", "S", "HEARTS").
parseStrain :: String -> Maybe Strain
parseStrain s
  | s `elem` ["C", "CLUBS"] = Just (SuitStrain Clubs)
  | s `elem` ["D", "DIAMONDS"] = Just (SuitStrain Diamonds)
  | s `elem` ["H", "HEARTS"] = Just (SuitStrain Hearts)
  | s `elem` ["S", "SPADES"] = Just (SuitStrain Spades)
  | s `elem` ["N", "NT", "NOTRUMP", "NO TRUMP"] = Just NoTrump
  | otherwise = Nothing
