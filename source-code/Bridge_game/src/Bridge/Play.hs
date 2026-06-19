module Bridge.Play where

import Bridge.Types
import Bridge.Cards
import Data.List (sortBy, minimumBy, maximumBy, find)

-- List legal plays for a hand given the lead suit
legalPlays :: [Card] -> Maybe Suit -> [Card]
legalPlays hand Nothing = hand
legalPlays hand (Just leadSuit) =
  let inSuit = handSuitCards hand leadSuit
  in if null inSuit then hand else inSuit

playersInPlayOrder :: Player -> [Player]
playersInPlayOrder leader =
  [ leader
  , nextPlayer leader
  , nextPlayer (nextPlayer leader)
  , nextPlayer (nextPlayer (nextPlayer leader))
  ]

-- Score a card's strength in a trick context
cardScore :: Card -> Suit -> Maybe Suit -> Int
cardScore (Card suit rank) leadSuit trumpSuit =
  case trumpSuit of
    Just ts | suit == ts -> 100 + fromEnum rank
    _ | suit == leadSuit -> 50 + fromEnum rank
    _ -> fromEnum rank

-- Determine the winner of a completed (or partial) trick
trickWinner :: [Card] -> Player -> Maybe Suit -> Player
trickWinner [] leader _ = leader
trickWinner trick leader trumpSuit =
  let
    leadCard = head trick
    leadSuit = cardSuit leadCard
    plays = zip trick (playersInPlayOrder leader)
    
    score c = cardScore c leadSuit trumpSuit
    comparePlays (c1, _) (c2, _) = compare (score c1) (score c2)
    (_, winner) = maximumBy comparePlays plays
  in winner

-- Helper functions for min/max cards
lowestCard :: [Card] -> Card
lowestCard = minimumBy (\c1 c2 -> compare (cardRank c1) (cardRank c2))

highestCard :: [Card] -> Card
highestCard = maximumBy (\c1 c2 -> compare (cardRank c1) (cardRank c2))

-- Determine if partner is currently winning the trick
isPartnerWinning :: [Card] -> Player -> Maybe Suit -> Player -> Bool
isPartnerWinning [] _ _ _ = False
isPartnerWinning trick leader trumpSuit me =
  let winner = trickWinner trick leader trumpSuit
  in side winner == side me

-- Check if any in-suit card can win the trick
canWinTrick :: [Card] -> [Card] -> Player -> Maybe Suit -> Bool
canWinTrick [] _ _ _ = False
canWinTrick _ [] _ _ = True
canWinTrick inSuit trick _leader trumpSuit =
  let
    leadSuit = cardSuit (head trick)
    score c = cardScore c leadSuit trumpSuit
    winningScore = maximum (map score trick)
  in any (\c -> score c > winningScore) inSuit

-- Play the cheapest card that wins the trick
cheapestWinner :: [Card] -> [Card] -> Player -> Maybe Suit -> Card
cheapestWinner inSuit trick _leader trumpSuit =
  let
    leadSuit = cardSuit (head trick)
    score c = cardScore c leadSuit trumpSuit
    winningScore = maximum (map score trick)
    winners = [c | c <- inSuit, score c > winningScore]
  in if null winners
     then lowestCard inSuit
     else lowestCard winners

-- Choose the best discard card (lowest card of longest non-trump suit)
bestDiscard :: [Card] -> Maybe Suit -> Card
bestDiscard [] _ = error "Empty hand to discard from"
bestDiscard cards trumpSuit =
  let
    longest = handLongestNonTrump cards trumpSuit
    inLongest = handSuitCards cards longest
  in if null inLongest
     then lowestCard cards
     else lowestCard inLongest

handLongestNonTrump :: [Card] -> Maybe Suit -> Suit
handLongestNonTrump hand trumpSuit =
  let
    suits = case trumpSuit of
              Just ts -> [s | s <- [Clubs .. Spades], s /= ts]
              Nothing -> [Clubs .. Spades]
    lengths = [(suitLength s hand, s) | s <- suits]
    compareSuit (len1, s1) (len2, s2) =
      case compare len2 len1 of
        EQ -> compare s2 s1
        other -> other
  in if null lengths
     then handLongestSuit hand
     else snd $ head $ sortBy compareSuit lengths

-- AI selects a card to lead
aiSelectLead :: [Card] -> Maybe Suit -> Player -> Player -> Card
aiSelectLead hand trumpSuit me declarer =
  let
    meSide = side me
    declSide = side declarer
    defending = meSide /= declSide
  in if defending
     then -- Defending strategies
       case leadTopOfSequence hand trumpSuit of
         Just c -> c
         Nothing ->
           case leadFourthBest hand trumpSuit of
             Just c -> c
             Nothing ->
               case leadShortSuit hand trumpSuit of
                 Just c -> c
                 Nothing -> lowestCard (handSuitCards hand (handLongestNonTrump hand trumpSuit))
     else -- Declarer/dummy strategies
       case trumpSuit of
         -- Draw trumps if we hold 3+ trumps including Q or higher
         Just ts | suitLength ts hand >= 3 && any (\c -> cardRank c >= Queen) (handSuitCards hand ts) ->
           maximumBy (\c1 c2 -> compare (cardRank c1) (cardRank c2)) (handSuitCards hand ts)
         _ ->
           case leadTopOfSequence hand trumpSuit of
             Just c -> c
             Nothing ->
               case leadFourthBest hand trumpSuit of
                 Just c -> c
                 Nothing -> head hand

leadTopOfSequence :: [Card] -> Maybe Suit -> Maybe Card
leadTopOfSequence hand trumpSuit =
  let
    suits = case trumpSuit of
              Just ts -> [s | s <- [Clubs .. Spades], s /= ts]
              Nothing -> [Clubs .. Spades]
    checkSuit suit =
      let cards = sortBy (\c1 c2 -> compare (cardRank c2) (cardRank c1)) (handSuitCards hand suit)
      in case cards of
        (c1:c2:c3:_) | cardRank c1 >= Jack
                      && fromEnum (cardRank c1) == fromEnum (cardRank c2) + 1
                      && fromEnum (cardRank c2) == fromEnum (cardRank c3) + 1 -> Just c1
        _ -> Nothing
    results = [c | s <- suits, Just c <- [checkSuit s]]
  in case results of
    (res:_) -> Just res
    [] -> Nothing

leadFourthBest :: [Card] -> Maybe Suit -> Maybe Card
leadFourthBest hand trumpSuit =
  let
    longest = handLongestNonTrump hand trumpSuit
    cards = sortBy (\c1 c2 -> compare (cardRank c2) (cardRank c1)) (handSuitCards hand longest)
  in if length cards >= 4
     then Just (cards !! 3)
     else Nothing

leadShortSuit :: [Card] -> Maybe Suit -> Maybe Card
leadShortSuit _hand Nothing = Nothing
leadShortSuit hand (Just ts) =
  let
    sideSuits = [s | s <- [Clubs .. Spades], s /= ts]
    lengths = sortBy (\(l1, _) (l2, _) -> compare l1 l2)
                     [(suitLength s hand, s) | s <- sideSuits, suitLength s hand > 0]
  in case lengths of
    ((_, shortSuit):_) ->
      let cards = sortBy (\c1 c2 -> compare (cardRank c2) (cardRank c1)) (handSuitCards hand shortSuit)
      in Just (head cards)
    _ -> Nothing

-- AI selects card when following
aiSelectFollow :: [Card] -> [Card] -> Player -> Maybe Suit -> Player -> Player -> Card
aiSelectFollow hand trick leader trumpSuit me _declarer =
  let
    leadSuit = cardSuit (head trick)
    legal = legalPlays hand (Just leadSuit)
    cardsPlayed = length trick
    partnerWinning = isPartnerWinning trick leader trumpSuit me
  in case legal of
    [singlePlay] -> singlePlay
    _ | any (\c -> cardSuit c == leadSuit) legal ->
      let inSuit = [c | c <- legal, cardSuit c == leadSuit]
      in if cardsPlayed == 3 && partnerWinning
         then lowestCard inSuit
         else if canWinTrick inSuit trick leader trumpSuit
              then cheapestWinner inSuit trick leader trumpSuit
              else lowestCard inSuit
    _ -> -- Can't follow suit
      let
        trumps = case trumpSuit of
                   Just ts -> [c | c <- legal, cardSuit c == ts]
                   Nothing -> []
        nonTrumps = case trumpSuit of
                      Just ts -> [c | c <- legal, cardSuit c /= ts]
                      Nothing -> legal
      in if not partnerWinning && not (null trumps)
         then lowestCard trumps -- Ruff
         else bestDiscard nonTrumps trumpSuit

-- Main AI card play entry point
aiSelectCard :: [Card] -> [Card] -> Player -> Maybe Suit -> Player -> Player -> Card
aiSelectCard hand trick leader trumpSuit me declarer =
  let
    leadSuit = fmap cardSuit (find (\_ -> True) trick)
    card = if null trick
           then aiSelectLead hand trumpSuit me declarer
           else aiSelectFollow hand trick leader trumpSuit me declarer
    legal = legalPlays hand leadSuit
  in if card `elem` legal
     then card
     else case legal of
       (fallback:_) -> fallback
       [] -> head hand
