{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}

module Bridge.Types where

import GHC.Generics (Generic)
import Data.Aeson (ToJSON, FromJSON)

data Suit = Clubs | Diamonds | Hearts | Spades
  deriving (Eq, Ord, Enum, Bounded, Show, Generic, ToJSON, FromJSON)

data Rank = R2 | R3 | R4 | R5 | R6 | R7 | R8 | R9 | R10 | Jack | Queen | King | Ace
  deriving (Eq, Ord, Enum, Bounded, Show, Generic, ToJSON, FromJSON)

data Card = Card { cardSuit :: Suit, cardRank :: Rank }
  deriving (Eq, Generic, ToJSON, FromJSON)

instance Ord Card where
  compare (Card s1 r1) (Card s2 r2) =
    case compare s1 s2 of
      EQ -> compare r1 r2
      other -> other

instance Show Card where
  show (Card suit rank) = rankSymbol rank ++ suitSymbol suit
    where
      rankSymbol Ace = "A"
      rankSymbol King = "K"
      rankSymbol Queen = "Q"
      rankSymbol Jack = "J"
      rankSymbol R10 = "10"
      rankSymbol r = show (fromEnum r + 2)

      suitSymbol Clubs = "C"
      suitSymbol Diamonds = "D"
      suitSymbol Hearts = "H"
      suitSymbol Spades = "S"

data Player = North | East | South | West
  deriving (Eq, Ord, Enum, Bounded, Generic, ToJSON, FromJSON)

instance Show Player where
  show North = "North"
  show East = "East"
  show South = "South"
  show West = "West"

partner :: Player -> Player
partner North = South
partner South = North
partner East = West
partner West = East

nextPlayer :: Player -> Player
nextPlayer North = East
nextPlayer East = South
nextPlayer South = West
nextPlayer West = North

side :: Player -> Int
side North = 0
side South = 0
side East = 1
side West = 1

data Strain = SuitStrain Suit | NoTrump
  deriving (Eq, Generic, ToJSON, FromJSON)

instance Ord Strain where
  compare (SuitStrain s1) (SuitStrain s2) = compare s1 s2
  compare (SuitStrain _) NoTrump = LT
  compare NoTrump (SuitStrain _) = GT
  compare NoTrump NoTrump = EQ

instance Show Strain where
  show (SuitStrain Clubs) = "C"
  show (SuitStrain Diamonds) = "D"
  show (SuitStrain Hearts) = "H"
  show (SuitStrain Spades) = "S"
  show NoTrump = "NT"

data BidType = SuitBid Int Strain | Pass | DoubleBid | RedoubleBid
  deriving (Eq, Generic, ToJSON, FromJSON)

instance Show BidType where
  show (SuitBid level strain) = show level ++ show strain
  show Pass = "Pass"
  show DoubleBid = "Dbl"
  show RedoubleBid = "Rdbl"

data Phase = Dealing | Bidding | Playing | Scoring | Done
  deriving (Eq, Show, Generic, ToJSON, FromJSON)
