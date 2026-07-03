module Bridge.Cards where

import Bridge.Types
import System.Random (RandomGen, randomR)
import Data.List (sortBy, sort)

makeDeck :: [Card]
makeDeck = [Card s r | s <- [Clubs .. Spades], r <- [R2 .. Ace]]

shuffleDeck :: RandomGen g => [Card] -> g -> ([Card], g)
shuffleDeck [] g = ([], g)
shuffleDeck xs g = 
  let (n, g') = randomR (0, length xs - 1) g
      (left, rest) = splitAt n xs
  in case rest of
       (x:right) -> let (shuffled, g'') = shuffleDeck (left ++ right) g'
                    in (x : shuffled, g'')
       []        -> (xs, g')

dealHands :: [Card] -> ([Card], [Card], [Card], [Card])
dealHands deck =
  let
    distribute [] (h1, h2, h3, h4) = (h1, h2, h3, h4)
    distribute (c1:c2:c3:c4:rest) (h1, h2, h3, h4) = distribute rest (c1:h1, c2:h2, c3:h3, c4:h4)
    distribute (c1:c2:c3:[]) (h1, h2, h3, h4) = (c1:h1, c2:h2, c3:h3, h4)
    distribute (c1:c2:[]) (h1, h2, h3, h4) = (c1:h1, c2:h2, h3, h4)
    distribute (c1:[]) (h1, h2, h3, h4) = (c1:h1, h2, h3, h4)
    (n, e, s, w) = distribute deck ([], [], [], [])
  in (sortHand n, sortHand e, sortHand s, sortHand w)

sortHand :: [Card] -> [Card]
sortHand = sortBy compareBridge
  where
    compareBridge (Card s1 r1) (Card s2 r2) =
      case compare s2 s1 of
        EQ -> compare r2 r1
        other -> other

cardHcp :: Card -> Int
cardHcp (Card _ Ace) = 4
cardHcp (Card _ King) = 3
cardHcp (Card _ Queen) = 2
cardHcp (Card _ Jack) = 1
cardHcp _ = 0

handHcp :: [Card] -> Int
handHcp = sum . map cardHcp

suitLength :: Suit -> [Card] -> Int
suitLength suit hand = length [c | c <- hand, cardSuit c == suit]

handSuitCards :: [Card] -> Suit -> [Card]
handSuitCards hand suit = [c | c <- hand, cardSuit c == suit]

handShape :: [Card] -> [Int]
handShape hand = [suitLength Spades hand, suitLength Hearts hand, suitLength Diamonds hand, suitLength Clubs hand]

handShapeSorted :: [Card] -> [Int]
handShapeSorted hand = reverse $ sort $ handShape hand

handLengthPoints :: [Card] -> Int
handLengthPoints hand =
  sum [len - 4 | s <- [Clubs .. Spades], let len = suitLength s hand, len > 4]

handShortnessPoints :: [Card] -> Int
handShortnessPoints hand =
  sum [points len | s <- [Clubs .. Spades], let len = suitLength s hand]
  where
    points 0 = 3
    points 1 = 2
    points 2 = 1
    points _ = 0

handTotalPoints :: [Card] -> Bool -> Int
handTotalPoints hand trumpFitFound =
  handHcp hand + if trumpFitFound then handShortnessPoints hand else handLengthPoints hand

isBalanced :: [Card] -> Bool
isBalanced hand =
  let shape = handShapeSorted hand
  in shape == [4, 3, 3, 3] || shape == [4, 4, 3, 2] || shape == [5, 3, 3, 2]

isSemiBalanced :: [Card] -> Bool
isSemiBalanced hand =
  isBalanced hand ||
  let shape = handShapeSorted hand
  in shape == [5, 4, 2, 2] || shape == [6, 3, 2, 2]

handHasMajor :: [Card] -> Int -> Bool
handHasMajor hand minLen =
  suitLength Hearts hand >= minLen || suitLength Spades hand >= minLen

handLongestSuit :: [Card] -> Suit
handLongestSuit hand =
  let
    lengths = [(suitLength s hand, s) | s <- [Clubs .. Spades]]
    compareSuit (len1, s1) (len2, s2) =
      case compare len2 len1 of
        EQ -> compare s2 s1
        other -> other
  in snd $ head $ sortBy compareSuit lengths

handSuitHcp :: [Card] -> Suit -> Int
handSuitHcp hand suit = sum [cardHcp c | c <- hand, cardSuit c == suit]

handHasStopper :: [Card] -> Suit -> Bool
handHasStopper hand suit =
  let
    cards = handSuitCards hand suit
    len = length cards
    ranks = map cardRank cards
  in
    len > 0 &&
    (Ace `elem` ranks ||
     (len >= 2 && King `elem` ranks) ||
     (len >= 3 && Queen `elem` ranks) ||
     (len >= 4 && Jack `elem` ranks))

handSuitHonorCount :: [Card] -> Suit -> Int
handSuitHonorCount hand suit =
  length [c | c <- hand, cardSuit c == suit, cardRank c >= R10]
