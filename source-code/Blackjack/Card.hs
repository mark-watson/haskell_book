-- Card model: defines `Rank`, `Suit`, and `Card`, with helpers
-- `orderedCardDeck` builds a deterministic deck; `cardValue` maps ranks to scores
module Card (Card(..), Rank(..), Suit(..), orderedCardDeck, cardValue) where

import Data.Maybe (fromMaybe)
import Data.List (elemIndex)
import Data.Map (Map, fromList, lookup, keys)

data Card = Card { rank :: Rank
                 , suit :: Suit }
                 deriving (Eq, Show)
                 
data Suit = Hearts | Diamonds | Clubs | Spades
          deriving (Eq, Show, Enum, Ord, Bounded)

data Rank = Two | Three | Four
          | Five | Six | Seven | Eight
          | Nine | Ten | Jack  | Queen | King | Ace
          deriving (Eq, Show, Enum, Ord)

-- | Map each 'Rank' to its Blackjack point value.
rankMap :: Map Rank Int
rankMap = fromList [(Two,2), (Three,3), (Four,4), (Five,5),
                    (Six,6), (Seven,7), (Eight,8), (Nine,9),
                    (Ten,10), (Jack,10), (Queen,10),
                    (King,10), (Ace,11)]

-- | Deterministic deck: list-comprehension over all ranks and all four suits.
-- Uses [minBound .. maxBound] to guarantee every Suit is included.
orderedCardDeck :: [Card]
orderedCardDeck = [Card r s | r <- keys rankMap,
                              s <- [minBound .. maxBound]]

-- | Look up the point value of a card's rank.
cardValue :: Card -> Int
cardValue aCard = fromMaybe 0 (Data.Map.lookup (rank aCard) rankMap)
