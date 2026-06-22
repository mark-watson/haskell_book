# Building a Rubber Bridge Game Engine and AI in Haskell

Contract bridge is a trick-taking card game played by four players in two competing partnerships. It is a game of high strategic depth, divided into two distinct phases: the **bidding auction** (where players bid for the minimum number of tricks they expect to win) and the **card play** (where the declaring side attempts to win those tricks while the defenders attempt to defeat them).

In this chapter, we build a complete **Rubber Bridge game engine and AI** in Haskell (ported from Common Lisp's `Bridge_game`). 

An important focus of this chapter is **decoupled software architecture**. When building games or applications, it is a best practice to separate core domain data, rules, and AI algorithms from any specific user interface (UI) rendering. By encapsulating all Bridge rules and game state transformations into a pure Haskell library (`Bridge_game`), we keep the engine completely independent of I/O. In this chapter, we drive the engine with an interactive Command Line Interface (CLI) client, but this exact same library can be reused in the future to drive a native macOS WebKit GUI client (`Bridge_webkit`) without modifying a single line of game logic.

The code for this project is located in the directory **haskell_book/source-code/Bridge_game**.

---

## Decoupled Architecture Design

Our Bridge project is structured as a Haskell Cabal package consisting of two parts: a reusable library containing all game logic and an executable CLI wrapper that manages user prompts and table displays.

```
                           ┌─────────────────────────────┐
                           │      CLI (app/Main.hs)      │
                           │   CLI loop, input prompts   │
                           └──────────────┬──────────────┘
                                          | (Actions)
                                          v
                           ┌─────────────────────────────┐
                           │     src/Bridge/Engine.hs    │
                           │   State Machine & deal loop │
                           └──────────────┬──────────────┘
                                          |
                 +------------------------+------------------------+
                 |                        |                        |
                 v                        v                        v
        src/Bridge/Bidding.hs     src/Bridge/Play.hs      src/Bridge/Scoring.hs
        AI Bidding Rules &        AI Card Play & Legal    Rubber scorecard &
        Contract Extraction       Plays Heuristics        Bonus/Penalty maths
```

By storing the hands, bid history, trick plays, and scoring rules in pure algebraic data types (ADTs), the library functions represent **pure state transformers**. They take a `GameState` and an action (like a `BidType` or a `Card` play) and return an updated `GameState`, making the core engine simple to test and isolate.

---

## Domain Data Types: `Bridge.Types`

We start by defining the type-safe domain representation for Bridge cards, players, suits, and bids in `src/Bridge/Types.hs`.

```haskell
module Bridge.Types where

data Suit = Clubs | Diamonds | Hearts | Spades
  deriving (Eq, Ord, Enum, Bounded, Show)

data Rank = R2 | R3 | R4 | R5 | R6 | R7 | R8 | R9 | R10 | Jack | Queen | King | Ace
  deriving (Eq, Ord, Enum, Bounded, Show)

data Card = Card { cardSuit :: Suit, cardRank :: Rank }
  deriving (Eq)

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
  deriving (Eq, Ord, Enum, Bounded)

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
  deriving (Eq)

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
  deriving (Eq)

instance Show BidType where
  show (SuitBid level strain) = show level ++ show strain
  show Pass = "Pass"
  show DoubleBid = "Dbl"
  show RedoubleBid = "Rdbl"

data Phase = Dealing | Bidding | Playing | Scoring | Done
  deriving (Eq, Show)
```

---

## Cards, Deck Shuffling, and Hand Analysis: `Bridge.Cards`

The `Bridge.Cards` module implements deck generation, shuffles the deck using a standard random number generator, deals the cards, and analyzes hands for High Card Points (HCP) and distribution.

```haskell
module Bridge.Cards where

import Bridge.Types
import System.Random (RandomGen, randomR)
import Data.List (sortBy, sort)

makeDeck :: [Card]
makeDeck = [Card s r | s <- [Clubs .. Spades], r <- [R2 .. Ace]]

-- Fisher-Yates pure shuffling using random number generator
shuffleDeck :: RandomGen g => [Card] -> g -> ([Card], g)
shuffleDeck [] g = ([], g)
shuffleDeck xs g = 
  let (n, g') = randomR (0, length xs - 1) g
      (left, x:right) = splitAt n xs
      (shuffled, g'') = shuffleDeck (left ++ right) g'
  in (x : shuffled, g'')

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

-- Sort hands with Spades (highest) down to Clubs, then Ace down to R2
sortHand :: [Card] -> [Card]
sortHand = sortBy compareBridge
  where
    compareBridge (Card s1 r1) (Card s2 r2) =
      case compare s2 s1 of
        EQ -> compare r2 r1
        other -> other

-- Hand analysis: HCP (Milton Work count)
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
```

---

## AI Bidding Conventions & Rule Decisions: `Bridge.Bidding`

Bridge bidding conventions communicate hand features between partners. The bidding module implements:
1. **Simplified Standard American rules**:
   - Opening at 1-level in majors (5+ cards) or minors.
   - 1NT (balanced 15-17 HCP) or 2NT (balanced 20-21 HCP).
   - Strong artificial 2♣ (22+ HCP) forcing opening.
   - Weak twos and preemptive 3-level openings.
2. **Responder bids**: Raises, Stayman inquiries (asking for 4-card majors), and slam explorations (Gerber and Blackwood).
3. **Contract extraction**: Traverses the chronological bidding history to find the final contract bid, declarer (the first player on the winning side who bid the contract strain), and doubling status.

```haskell
module Bridge.Bidding where

import Bridge.Types
import Bridge.Cards
import Data.List (find)

lastSuitBid :: [(Player, BidType)] -> Maybe BidType
lastSuitBid history = fmap snd $ find (\(_, b) -> isSuitBid b) history

isSuitBid :: BidType -> Bool
isSuitBid (SuitBid _ _) = True
isSuitBid _ = False

bidIndex :: BidType -> Maybe Int
bidIndex (SuitBid level strain) =
  let strainIdx = case strain of
                    SuitStrain Clubs -> 0
                    SuitStrain Diamonds -> 1
                    SuitStrain Hearts -> 2
                    SuitStrain Spades -> 3
                    NoTrump -> 4
  in Just ((level - 1) * 5 + strainIdx)
bidIndex _ = Nothing

bidHigherThan :: BidType -> BidType -> Bool
bidHigherThan b1 b2 =
  case (bidIndex b1, bidIndex b2) of
    (Just idx1, Just idx2) -> idx1 > idx2
    _ -> False

biddingComplete :: [(Player, BidType)] -> Bool
biddingComplete history =
  let
    bids = map snd history
    hasSuitBid = any isSuitBid bids
  in case bids of
    _ | length bids == 4 && all (== Pass) bids -> True
    (Pass:Pass:Pass:_) | hasSuitBid -> True
    _ -> False

passedOut :: [(Player, BidType)] -> Bool
passedOut history = length history == 4 && all (\(_, b) -> b == Pass) history

extractContract :: [(Player, BidType)] -> Player -> Maybe (BidType, Player, Int)
extractContract history _dealer =
  let
    findLastSuit [] = Nothing
    findLastSuit ((p, SuitBid l s):_) = Just (SuitBid l s, p)
    findLastSuit (_:xs) = findLastSuit xs
  in case findLastSuit history of
    Just (contract@(SuitBid _ strain), finalBidder) ->
      let
        declSide = side finalBidder
        chronoHistory = reverse history
        
        firstBidderOfStrain [] = finalBidder
        firstBidderOfStrain ((p, SuitBid _ s):xs)
          | s == strain && side p == declSide = p
          | otherwise = firstBidderOfStrain xs
        firstBidderOfStrain (_:xs) = firstBidderOfStrain xs
        
        declarer = firstBidderOfStrain chronoHistory
        
        checkDouble [] d = d
        checkDouble ((_, SuitBid _ _):_) d = d
        checkDouble ((_, DoubleBid):xs) 0 = checkDouble xs 1
        checkDouble ((_, RedoubleBid):xs) 1 = checkDouble xs 2
        checkDouble (_:xs) d = checkDouble xs d
        
        doubled = checkDouble history 0
      in Just (contract, declarer, doubled)
    _ -> Nothing

findPartnerOpening :: [(Player, BidType)] -> Player -> Maybe BidType
findPartnerOpening history me =
  let
    p = partner me
    chrono = reverse history
    partnerBids = [bid | (bidder, bid) <- chrono, bidder == p, isSuitBid bid]
  in case partnerBids of
    (firstBid:_) -> Just firstBid
    [] -> Nothing

findMyOpening :: [(Player, BidType)] -> Player -> Maybe BidType
findMyOpening history me =
  let
    chrono = reverse history
    myBids = [bid | (bidder, bid) <- chrono, bidder == me, isSuitBid bid]
  in case myBids of
    (firstBid:_) -> Just firstBid
    [] -> Nothing

staymanResponseP :: BidType -> BidType -> Bool
staymanResponseP (SuitBid 2 (SuitStrain Clubs)) (SuitBid 1 NoTrump) = True
staymanResponseP (SuitBid 3 (SuitStrain Clubs)) (SuitBid 2 NoTrump) = True
staymanResponseP _ _ = False

blackwoodResponseP :: BidType -> Bool
blackwoodResponseP (SuitBid 4 NoTrump) = True
blackwoodResponseP _ = False

blackwoodKingAskP :: BidType -> Bool
blackwoodKingAskP (SuitBid 5 NoTrump) = True
blackwoodKingAskP _ = False

gerberResponseP :: BidType -> BidType -> Bool
gerberResponseP (SuitBid 4 (SuitStrain Clubs)) (SuitBid _ NoTrump) = True
gerberResponseP _ _ = False

gerberKingAskP :: BidType -> Bool
gerberKingAskP (SuitBid 5 (SuitStrain Clubs)) = True
gerberKingAskP _ = False

aiOpeningBid :: [Card] -> Maybe BidType
aiOpeningBid hand
  | hcp >= 22 = Just (SuitBid 2 (SuitStrain Clubs))
  | balanced && hcp >= 20 && hcp <= 21 = Just (SuitBid 2 NoTrump)
  | balanced && hcp >= 15 && hcp <= 17 = Just (SuitBid 1 NoTrump)
  | hcp >= 13 && hcp <= 21 = Just (SuitBid 1 openingSuit)
  | hcp < 13, (s:_) <- sevenCardSuits = Just (SuitBid 3 s)
  | hcp < 13 && hcp >= 5, (s:_) <- weakTwoSuits = Just (SuitBid 2 s)
  | otherwise = Nothing
  where
    hcp = handHcp hand
    balanced = isBalanced hand
    
    openingSuit
      | suitLength Spades hand >= 5 && suitLength Hearts hand >= 5 = SuitStrain Spades
      | suitLength Spades hand >= 5 = SuitStrain Spades
      | suitLength Hearts hand >= 5 = SuitStrain Hearts
      | suitLength Diamonds hand > suitLength Clubs hand = SuitStrain Diamonds
      | otherwise = SuitStrain Clubs
      
    sevenCardSuits =
      [SuitStrain s | s <- [Clubs .. Spades], suitLength s hand >= 7, handSuitHonorCount hand s >= 2]
      
    weakTwoSuits =
      [SuitStrain s | s <- [Diamonds, Hearts, Spades], suitLength s hand >= 6]

aiRespondingBid :: [Card] -> BidType -> Maybe BidType
aiRespondingBid hand partnerBid =
  case partnerBid of
    SuitBid pLevel NoTrump ->
      let hcp = handHcp hand
      in if pLevel == 1
         then
           if hcp <= 7
           then
             if suitLength Spades hand >= 5 then Just (SuitBid 2 (SuitStrain Spades))
             else if suitLength Hearts hand >= 5 then Just (SuitBid 2 (SuitStrain Hearts))
             else if suitLength Diamonds hand >= 5 then Just (SuitBid 2 (SuitStrain Diamonds))
             else Nothing
           else if hcp >= 8 && (suitLength Hearts hand >= 4 || suitLength Spades hand >= 4)
           then Just (SuitBid 2 (SuitStrain Clubs))
           else if hcp <= 9 then Just (SuitBid 2 NoTrump)
           else if hcp <= 15 && suitLength Spades hand >= 6 then Just (SuitBid 4 (SuitStrain Spades))
           else if hcp <= 15 && suitLength Hearts hand >= 6 then Just (SuitBid 4 (SuitStrain Hearts))
           else if hcp <= 15 && suitLength Spades hand >= 5 then Just (SuitBid 3 (SuitStrain Spades))
           else if hcp <= 15 && suitLength Hearts hand >= 5 then Just (SuitBid 3 (SuitStrain Hearts))
           else if hcp <= 15 then Just (SuitBid 3 NoTrump)
           else Just (SuitBid 4 NoTrump)
         else
           if hcp <= 4 && all (\s -> suitLength s hand < 5) [Clubs .. Spades]
           then Nothing
           else if hcp >= 4 && (suitLength Hearts hand >= 4 || suitLength Spades hand >= 4)
           then Just (SuitBid 3 (SuitStrain Clubs))
           else if hcp >= 5 then Just (SuitBid 3 NoTrump)
           else Nothing
           
    SuitBid pLevel (SuitStrain pSuit) ->
      let hcp = handHcp hand
      in if pLevel == 1
         then
           if pSuit >= Hearts
           then
             if hcp <= 5 then Nothing
             else if hcp <= 10
             then
               if suitLength pSuit hand >= 3
               then Just (SuitBid 2 (SuitStrain pSuit))
               else if pSuit == Hearts && suitLength Spades hand >= 4
                    then Just (SuitBid 1 (SuitStrain Spades))
                    else Just (SuitBid 1 NoTrump)
             else if hcp <= 12
             then
               if suitLength pSuit hand >= 3
               then Just (SuitBid 3 (SuitStrain pSuit))
               else
                 let longest = handLongestSuit hand
                 in if longest > pSuit
                    then Just (SuitBid 2 (SuitStrain longest))
                    else Just (SuitBid 2 NoTrump)
             else 
               if suitLength pSuit hand >= 3
               then Just (SuitBid 4 (SuitStrain pSuit))
               else Just (SuitBid 3 NoTrump)
           else
             if hcp < 6 then Nothing
             else if suitLength Hearts hand >= 4 || suitLength Spades hand >= 4
             then
               let
                 hLen = suitLength Hearts hand
                 sLen = suitLength Spades hand
               in Just $ if hLen >= 5 && sLen >= 5 then SuitBid 1 (SuitStrain Spades)
                         else if hLen >= 4 && sLen >= 4 then SuitBid 1 (SuitStrain Hearts)
                         else if hLen >= 4 then SuitBid 1 (SuitStrain Hearts)
                         else SuitBid 1 (SuitStrain Spades)
             else if hcp <= 10 then Just (SuitBid 1 NoTrump)
             else if hcp <= 12
             then
               if suitLength pSuit hand >= 4
               then Just (SuitBid 3 (SuitStrain pSuit))
               else Just (SuitBid 2 NoTrump)
             else if hcp <= 15
             then
               if suitLength pSuit hand >= 4
               then Just (SuitBid 5 (SuitStrain pSuit))
               else Just (SuitBid 3 NoTrump)
             else Just (SuitBid 4 NoTrump)
         else if pSuit == Clubs
         then
           if hcp < 8 then Just (SuitBid 2 (SuitStrain Diamonds))
           else if not (isBalanced hand) && suitLength Spades hand >= 5 then Just (SuitBid 2 (SuitStrain Spades))
           else if not (isBalanced hand) && suitLength Hearts hand >= 5 then Just (SuitBid 2 (SuitStrain Hearts))
           else if not (isBalanced hand) && suitLength Diamonds hand >= 5 then Just (SuitBid 3 (SuitStrain Diamonds))
           else if not (isBalanced hand) && suitLength Clubs hand >= 5 then Just (SuitBid 3 (SuitStrain Clubs))
           else Just (SuitBid 2 NoTrump)
         else 
           if pLevel == 2
           then
             if suitLength pSuit hand >= 3 && hcp >= 14 then Just (SuitBid 4 (SuitStrain pSuit))
             else if suitLength pSuit hand >= 3 && hcp >= 10 then Just (SuitBid 3 (SuitStrain pSuit))
             else Nothing
           else 
             if suitLength pSuit hand >= 3 && hcp >= 14
             then Just (SuitBid (if pSuit >= Hearts then 4 else 5) (SuitStrain pSuit))
             else Nothing
    _ -> Nothing

aiOpenerRebid :: [Card] -> BidType -> BidType -> Maybe BidType
aiOpenerRebid hand myOpening partnerResponse =
  case (myOpening, partnerResponse) of
    (SuitBid _ myStrain, SuitBid pLevel pStrain) ->
      cond myStrain pStrain pLevel
    _ -> Nothing
  where
    hcp = handHcp hand
    cond myStrain pStrain pLevel
      | staymanResponseP partnerResponse myOpening =
        let responseLevel = if bidLevel myOpening == 1 then 2 else 3
        in Just $ if suitLength Hearts hand >= 4 && suitLength Spades hand >= 4 then SuitBid responseLevel (SuitStrain Hearts)
                  else if suitLength Hearts hand >= 4 then SuitBid responseLevel (SuitStrain Hearts)
                  else if suitLength Spades hand >= 4 then SuitBid responseLevel (SuitStrain Spades)
                  else SuitBid responseLevel (SuitStrain Diamonds)
      
      | blackwoodResponseP partnerResponse =
        let aces = length [c | c <- hand, cardRank c == Ace]
        in Just (SuitBid 5 (intToStrain (aces `mod` 5)))

      | blackwoodKingAskP partnerResponse =
        let kings = length [c | c <- hand, cardRank c == King]
        in Just (SuitBid 6 (intToStrain (kings `mod` 5)))

      | gerberResponseP partnerResponse myOpening =
        let aces = length [c | c <- hand, cardRank c == Ace]
        in Just $ case aces of
          0 -> SuitBid 4 (SuitStrain Diamonds)
          1 -> SuitBid 4 (SuitStrain Hearts)
          2 -> SuitBid 4 (SuitStrain Spades)
          3 -> SuitBid 4 NoTrump
          _ -> SuitBid 5 (SuitStrain Clubs)

      | gerberKingAskP partnerResponse =
        let kings = length [c | c <- hand, cardRank c == King]
        in Just $ case kings of
          0 -> SuitBid 5 (SuitStrain Diamonds)
          1 -> SuitBid 5 (SuitStrain Hearts)
          2 -> SuitBid 5 (SuitStrain Spades)
          3 -> SuitBid 5 NoTrump
          _ -> SuitBid 6 (SuitStrain Clubs)

      | pStrain == NoTrump =
        case myStrain of
          SuitStrain s | suitLength s hand >= 6 -> Just (SuitBid (pLevel + 1) myStrain)
          _ | hcp <= 15 -> Nothing
          _ | hcp <= 17 -> Just (SuitBid (pLevel + 1) NoTrump)
          _ -> Just (SuitBid (pLevel + 2) NoTrump)

      | SuitStrain s <- myStrain, SuitStrain ps <- pStrain, s == ps =
        if hcp <= 15 then Nothing
        else if hcp >= 19 && s >= Hearts then Just (SuitBid 4 NoTrump)
        else if s >= Hearts && hcp <= 18 then Just (SuitBid 4 myStrain)
        else Just (SuitBid (if s >= Hearts then 4 else 5) myStrain)

      | SuitStrain ps <- pStrain =
        if suitLength ps hand >= 4
        then Just (SuitBid (pLevel + 1) pStrain)
        else case myStrain of
          SuitStrain s | suitLength s hand >= 6 -> Just (SuitBid 2 myStrain)
          _ | hcp <= 15 && isBalanced hand -> Just (SuitBid (if pLevel >= 2 then pLevel else 1) NoTrump)
          SuitStrain s | suitLength s hand >= 5 -> Just (SuitBid 2 myStrain)
          _ -> Just (SuitBid 1 NoTrump)

      | otherwise = Nothing

    bidLevel (SuitBid l _) = l
    bidLevel _ = 1

    intToStrain 0 = SuitStrain Clubs
    intToStrain 1 = SuitStrain Diamonds
    intToStrain 2 = SuitStrain Hearts
    intToStrain 3 = SuitStrain Spades
    intToStrain _ = NoTrump

ensureLegalBid :: Maybe BidType -> Maybe BidType -> Maybe BidType
ensureLegalBid Nothing _ = Nothing
ensureLegalBid (Just bid) Nothing = Just bid
ensureLegalBid (Just bid) (Just currentHighest)
  | not (isSuitBid bid) = Just bid
  | bidHigherThan bid currentHighest = Just bid
  | otherwise = Nothing

aiSelectBid :: [Card] -> [(Player, BidType)] -> Player -> Player -> BidType
aiSelectBid hand history me _dealer =
  let
    currentHighest = lastSuitBid history
    partnerBid = findPartnerOpening history me
    myBid = findMyOpening history me
    
    rawBid = case (myBid, partnerBid) of
      (Just mb, Just pb) -> aiOpenerRebid hand mb pb
      (Nothing, Just pb) -> aiRespondingBid hand pb
      _ | Nothing <- currentHighest -> aiOpeningBid hand
      _ ->
        let hcp = handHcp hand
        in if hcp >= 13 && handHasMajor hand 5
           then if suitLength Spades hand >= 5
                then Just (SuitBid 1 (SuitStrain Spades))
                else Just (SuitBid 1 (SuitStrain Hearts))
           else if hcp >= 15 && hcp <= 18 && isBalanced hand
                then Just (SuitBid 1 NoTrump)
                else Nothing
                
    legalBid = ensureLegalBid rawBid currentHighest
  in case legalBid of
    Just b -> b
    Nothing -> Pass
```

---

## Trick Play & Legal Rules: `Bridge.Play`

Card play AI evaluates tricks using heuristics:
* **Opening Leads**: Leads from sequences (top of a sequence, e.g. King from King-Queen-Jack), 4th-best from the longest non-trump suit, or short side suits.
* **Following Suit**: Plays low if partner is already winning (saving high cards), plays cheapest winner if able to win the trick, and plays lowest card when losing.
* **Trumping / Discarding**: Ruffs (trumps) if partner is losing and has trumps, otherwise discards from weakest suits.

```haskell
module Bridge.Play where

import Bridge.Types
import Bridge.Cards
import Data.List (sortBy, minimumBy, maximumBy, find)

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

cardScore :: Card -> Suit -> Maybe Suit -> Int
cardScore (Card suit rank) leadSuit trumpSuit =
  case trumpSuit of
    Just ts | suit == ts -> 100 + fromEnum rank
    _ | suit == leadSuit -> 50 + fromEnum rank
    _ -> fromEnum rank

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

lowestCard :: [Card] -> Card
lowestCard = minimumBy (\c1 c2 -> compare (cardRank c1) (cardRank c2))

highestCard :: [Card] -> Card
highestCard = maximumBy (\c1 c2 -> compare (cardRank c1) (cardRank c2))

isPartnerWinning :: [Card] -> Player -> Maybe Suit -> Player -> Bool
isPartnerWinning [] _ _ _ = False
isPartnerWinning trick leader trumpSuit me =
  let winner = trickWinner trick leader trumpSuit
  in side winner == side me

canWinTrick :: [Card] -> [Card] -> Player -> Maybe Suit -> Bool
canWinTrick [] _ _ _ = False
canWinTrick _ [] _ _ = True
canWinTrick inSuit trick leader trumpSuit =
  let
    leadSuit = cardSuit (head trick)
    score c = cardScore c leadSuit trumpSuit
    winningScore = maximum (map score trick)
  in any (\c -> score c > winningScore) inSuit

cheapestWinner :: [Card] -> [Card] -> Player -> Maybe Suit -> Card
cheapestWinner inSuit trick leader trumpSuit =
  let
    leadSuit = cardSuit (head trick)
    score c = cardScore c leadSuit trumpSuit
    winningScore = maximum (map score trick)
    winners = [c | c <- inSuit, score c > winningScore]
  in if null winners
     then lowestCard inSuit
     else lowestCard winners

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

aiSelectLead :: [Card] -> Maybe Suit -> Player -> Player -> Card
aiSelectLead hand trumpSuit me declarer =
  let
    meSide = side me
    declSide = side declarer
    defending = meSide /= declSide
  in if defending
     then 
       case leadTopOfSequence hand trumpSuit of
         Just c -> c
         Nothing ->
           case leadFourthBest hand trumpSuit of
             Just c -> c
             Nothing ->
               case leadShortSuit hand trumpSuit of
                 Just c -> c
                 Nothing -> lowestCard (handSuitCards hand (handLongestNonTrump hand trumpSuit))
     else 
       case trumpSuit of
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
leadShortSuit hand Nothing = Nothing
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

aiSelectFollow :: [Card] -> [Card] -> Player -> Maybe Suit -> Player -> Player -> Card
aiSelectFollow hand trick leader trumpSuit me declarer =
  let
    leadSuit = cardSuit (head trick)
    legal = legalPlays hand (Just leadSuit)
    cardsPlayed = length trick
    partnerWinning = isPartnerWinning trick leader trumpSuit me
    defending = side me /= side declarer
  in case legal of
    [singlePlay] -> singlePlay
    _ | any (\c -> cardSuit c == leadSuit) legal ->
      let inSuit = [c | c <- legal, cardSuit c == leadSuit]
      in if cardsPlayed == 3 && partnerWinning
         then lowestCard inSuit
         else if canWinTrick inSuit trick leader trumpSuit
              then cheapestWinner inSuit trick leader trumpSuit
              else lowestCard inSuit
    _ -> 
      let
        trumps = case trumpSuit of
                   Just ts -> [c | c <- legal, cardSuit c == ts]
                   Nothing -> []
        nonTrumps = case trumpSuit of
                      Just ts -> [c | c <- legal, cardSuit c /= ts]
                      Nothing -> legal
      in if not partnerWinning && not (null trumps)
         then lowestCard trumps
         else bestDiscard nonTrumps trumpSuit

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
```

---

## Scoring Rules: `Bridge.Scoring`

Rubber bridge is scored using two columns (N-S and E-W), separated by a horizontal line:
1. **Below the line**: Houses trick scores for contracts bid and made. Accumulating 100+ points below the line wins a *game*, reset both sides' below-the-line columns, and makes that side *vulnerable*.
2. **Above the line**: Houses penalties (when declarer goes down), overtrick bonuses, insult bonuses (for making doubled/redoubled contracts), and slam bonuses (slam/grand slam).
3. **Rubber completion**: The first side to win 2 games wins the rubber, earning a bonus of 700 (if won 2-0) or 500 (if won 2-1).

```haskell
module Bridge.Scoring where

import Bridge.Types

data RubberState = RubberState
  { nsBelow      :: Int
  , ewBelow      :: Int
  , nsAbove      :: Int
  , ewAbove      :: Int
  , nsGames      :: Int
  , ewGames      :: Int
  , nsVulnerable :: Bool
  , ewVulnerable :: Bool
  , currentDealer:: Player
  , dealsPlayed  :: Int
  } deriving (Show, Eq)

newRubberState :: RubberState
newRubberState = RubberState
  { nsBelow = 0, ewBelow = 0, nsAbove = 0, ewAbove = 0
  , nsGames = 0, ewGames = 0, nsVulnerable = False, ewVulnerable = False
  , currentDealer = North, dealsPlayed = 0
  }

trickValue :: Strain -> Int -> Int
trickValue strain doubled =
  let
    base = case strain of
             SuitStrain Clubs -> 20
             SuitStrain Diamonds -> 20
             _ -> 30
    mult = case doubled of 1 -> 2; 2 -> 4; _ -> 1
  in base * mult

contractTrickScore :: Int -> Strain -> Int -> Int
contractTrickScore level strain doubled =
  let
    basePerTrick = trickValue strain doubled
    extra = case (strain, doubled) of
              (NoTrump, 0) -> 10
              (NoTrump, 1) -> 20
              (NoTrump, 2) -> 40
              _ -> 0
  in extra + basePerTrick * level

scoreRubberDeal :: Int -> Strain -> Int -> Player -> Int -> RubberState -> (RubberState, Int)
scoreRubberDeal level strain tricksWon declarer doubled rs =
  let
    tricksNeeded = level + 6
    overtricks = tricksWon - tricksNeeded
    made = tricksWon >= tricksNeeded
    nsSide = declarer == North || declarer == South
    vul = if nsSide then nsVulnerable rs else ewVulnerable rs
  in if made
     then
       let
         belowScore = contractTrickScore level strain doubled
         overtrickVal = case doubled of
           0 -> trickValue strain 0
           1 -> if vul then 200 else 100
           _ -> if vul then 400 else 200
         overtrickBonus = if overtricks > 0 then overtricks * overtrickVal else 0
         insultBonus = case doubled of 1 -> 50; 2 -> 100; _ -> 0
         slamBonus = if level == 6 then (if vul then 750 else 500)
                     else if level == 7 then (if vul then 1500 else 1000)
                     else 0
         aboveScore = overtrickBonus + insultBonus + slamBonus
         
         (rs1, newBelow) =
           if nsSide
           then (rs { nsBelow = nsBelow rs + belowScore, nsAbove = nsAbove rs + aboveScore }, nsBelow rs + belowScore)
           else (rs { ewBelow = ewBelow rs + belowScore, ewAbove = ewAbove rs + aboveScore }, ewBelow rs + belowScore)
             
         rs2 = if newBelow >= 100
               then if nsSide
                    then rs1 { nsGames = nsGames rs1 + 1, nsVulnerable = True, nsBelow = 0, ewBelow = 0 }
                    else rs1 { ewGames = ewGames rs1 + 1, ewVulnerable = True, nsBelow = 0, ewBelow = 0 }
               else rs1
       in (rs2, belowScore)
     else
       let
         down = abs overtricks
         penalty = case doubled of
           0 -> down * (if vul then 100 else 50)
           1 -> if vul
                then 200 + (down - 1) * 300
                else case down of
                  1 -> 100
                  2 -> 300
                  3 -> 500
                  _ -> 500 + (down - 3) * 300
           _ -> 2 * if vul
                    then 200 + (down - 1) * 300
                    else case down of
                      1 -> 100
                      2 -> 300
                      3 -> 500
                      _ -> 500 + (down - 3) * 300
         rs1 = if nsSide
               -- Penalties go above line for defenders
               then rs { ewAbove = ewAbove rs + penalty }
               else rs { nsAbove = nsAbove rs + penalty }
       in (rs1, -penalty)

rubberComplete :: RubberState -> Bool
rubberComplete rs = nsGames rs >= 2 || ewGames rs >= 2

rubberBonus :: RubberState -> (Int, Maybe String)
rubberBonus rs
  | nsGames rs >= 2 = (if ewGames rs == 0 then 700 else 500, Just "N-S")
  | ewGames rs >= 2 = (if nsGames rs == 0 then 700 else 500, Just "E-W")
  | otherwise = (0, Nothing)

rubberTotalScores :: RubberState -> (Int, Int)
rubberTotalScores rs =
  let
    (bonus, winner) = rubberBonus rs
    nsTotal = nsAbove rs + if winner == Just "N-S" then bonus else 0
    ewTotal = ewAbove rs + if winner == Just "E-W" then bonus else 0
  in (nsTotal, ewTotal)
```

---

## Core Game State Machine: `Bridge.Engine`

The game engine brings everything together. `GameState` holds the deals, hands, bidding auction histories, trick queues, and phase indicators. The engine defines pure FFI-friendly state transformers (`applyBid` and `applyCardPlay`) to drive the game forward.

```haskell
module Bridge.Engine where

import Bridge.Types
import Bridge.Cards
import Bridge.Bidding
import Bridge.Play
import System.Random (StdGen)
import qualified Data.Map.Strict as Map

data Vulnerability = None | NsOnly | EwOnly | Both
  deriving (Eq, Show)

data GameState = GameState
  { hands          :: Map.Map Player [Card]
  , originalHands  :: Map.Map Player [Card]
  , dealer         :: Player
  , vulnerability  :: Vulnerability
  , humanPlayer    :: Player
  , bidHistory     :: [(Player, BidType)]
  , contract       :: Maybe BidType
  , declarer       :: Maybe Player
  , doubled        :: Int
  , dummy          :: Maybe Player
  , currentTrick   :: [(Player, Card)]
  , trickLead      :: Player
  , tricksNs       :: Int
  , tricksEw       :: Int
  , tricksPlayed   :: Int
  , cardsPlayed    :: [Card]
  , trumpSuit      :: Maybe Suit
  , phase          :: Phase
  } deriving (Show)

newGame :: Player -> Vulnerability -> Player -> StdGen -> GameState
newGame dealerVal vul humanVal gen =
  let
    deck = makeDeck
    (shuffled, _) = shuffleDeck deck gen
    (n, e, s, w) = dealHands shuffled
    handsMap = Map.fromList [(North, n), (East, e), (South, s), (West, w)]
  in GameState
    { hands = handsMap, originalHands = handsMap, dealer = dealerVal, vulnerability = vul
    , humanPlayer = humanVal, bidHistory = [], contract = Nothing, declarer = Nothing
    , doubled = 0, dummy = Nothing, currentTrick = [], trickLead = dealerVal
    , tricksNs = 0, tricksEw = 0, tricksPlayed = 0, cardsPlayed = []
    , trumpSuit = Nothing, phase = Bidding
    }

currentActor :: GameState -> Maybe Player
currentActor gs =
  case phase gs of
    Bidding ->
      if null (bidHistory gs)
      then Just (dealer gs)
      else Just (nextPlayer (fst (head (bidHistory gs))))
    Playing ->
      if null (currentTrick gs)
      then Just (trickLead gs)
      else Just (nextPlayer (fst (head (currentTrick gs))))
    _ -> Nothing

applyBid :: BidType -> GameState -> GameState
applyBid bid gs =
  case currentActor gs of
    Nothing -> gs
    Just actor ->
      let
        history' = (actor, bid) : bidHistory gs
        complete = biddingComplete history'
      in if complete
         then
           if passedOut history'
           then gs { bidHistory = history', phase = Done }
           else
             case extractContract history' (dealer gs) of
               Nothing -> gs { bidHistory = history', phase = Done }
               Just (contract', declarer', doubled') ->
                 let
                   dummy' = partner declarer'
                   ts = case contract' of
                          SuitBid _ (SuitStrain s) -> Just s
                          _ -> Nothing
                      
                   (hands', dummy'') =
                     if declarer' == North && humanPlayer gs == South
                     then
                       let
                         northCards = hands gs Map.! North
                         southCards = hands gs Map.! South
                         swapped = Map.fromList [(North, southCards), (East, hands gs Map.! East), (South, northCards), (West, hands gs Map.! West)]
                       in (swapped, North)
                     else (hands gs, dummy')
                 in gs
                   { bidHistory = history', contract = Just contract', declarer = Just declarer'
                   , doubled = doubled', dummy = Just dummy'', trumpSuit = ts
                   , trickLead = nextPlayer declarer', phase = Playing, hands = hands'
                   }
         else gs { bidHistory = history' }

applyCardPlay :: Card -> GameState -> GameState
applyCardPlay card gs =
  case currentActor gs of
    Nothing -> gs
    Just actor ->
      let
        hand' = filter (/= card) (hands gs Map.! actor)
        hands' = Map.insert actor hand' (hands gs)
        currentTrick' = (actor, card) : currentTrick gs
        cardsPlayed' = card : cardsPlayed gs
      in if length currentTrick' == 4
         then
           let
             trickInPlayOrder = map snd (reverse currentTrick')
             winner = trickWinner trickInPlayOrder (trickLead gs) (trumpSuit gs)
             
             nsScore = if winner == North || winner == South then 1 else 0
             ewScore = if winner == East || winner == West then 1 else 0
             
             tricksNs' = tricksNs gs + nsScore
             tricksEw' = tricksEw gs + ewScore
             tricksPlayed' = tricksPlayed gs + 1
             nextPhase = if tricksPlayed' == 13 then Scoring else Playing
           in gs
             { hands = hands', currentTrick = [], trickLead = winner, tricksNs = tricksNs'
             , tricksEw = tricksEw', tricksPlayed = tricksPlayed', cardsPlayed = cardsPlayed'
             , phase = nextPhase
             }
         else gs { hands = hands', currentTrick = currentTrick', cardsPlayed = cardsPlayed' }
```

### Swapping Hands for North Contracts

A critical detail in the `applyBid` logic:
```haskell
(hands', dummy'') =
  if declarer' == North && humanPlayer gs == South
  then ...
```
When South's partner (North) wins the auction, North becomes the declarer, and South becomes the dummy. In actual bridge, declarer plays both their own hand and dummy's cards. Thus, the human (South) must take over North's original cards, while their original hand moves to North as the dummy. This swap is cleanly executed by modifying the `hands` map inside the pure state transition.

---

## Interactive Command Line Front-end: `app/Main.hs`

The command line application implements the interactive prompts, parses inputs, and updates state. We design the interface with recursive monadic state loops in the GHC `IO` monad, providing the player with side-by-side terminal rendering of West/East/South hands and cards in play.

Due to the length of `Main.hs`, we showcase its most vital loops and parsing functions. The complete file can be examined in the source folder.

### Running Bidding and Playing loops

```haskell
runBiddingLoop :: GameState -> IO (Either String GameState)
runBiddingLoop gs =
  if phase gs /= Bidding
  then return (Right gs)
  else case currentActor gs of
    Nothing -> return (Right gs)
    Just actor ->
      if actor == South
      then do
        res <- promptForBid gs
        case res of
          Left err -> return (Left err)
          Right bid -> runBiddingLoop (applyBid bid gs)
      else do
        let aiBid = aiSelectBid (hands gs Map.! actor) (bidHistory gs) actor (dealer gs)
        putStrLn $ "  " ++ show actor ++ " bids: " ++ show aiBid
        runBiddingLoop (applyBid aiBid gs)

runPlayingLoop :: GameState -> IO (Either String GameState)
runPlayingLoop gs =
  if phase gs /= Playing
  then return (Right gs)
  else case currentActor gs of
    Nothing -> return (Right gs)
    Just actor -> do
      when (null (currentTrick gs)) $ do
        putStrLn $ "\n── Trick " ++ show (tricksPlayed gs + 1) ++ " ──"
        putStrLn $ "  N-S tricks won: " ++ show (tricksNs gs) ++ "   E-W tricks won: " ++ show (tricksEw gs)
      
      let
        isHuman = actor == South
        isDummy = Just actor == dummy gs
        declarerSide = fmap side (declarer gs)
        humanPlaysDummy = isDummy && (declarerSide == Just 0)
        humanPlaysThis = isHuman || humanPlaysDummy
        leadSuit = case currentTrick gs of
                     [] -> Nothing
                     _  -> Just (cardSuit (snd (last (currentTrick gs))))
                     
      if humanPlaysThis
      then do
        when (not (null (currentTrick gs))) $ do
          putStrLn "\n  Trick in progress:"
          mapM_ (\(p, c) -> putStrLn $ "    " ++ show p ++ " played: " ++ show c) (reverse (currentTrick gs))
        
        res <- promptForCard gs actor leadSuit
        case res of
          Left err -> return (Left err)
          Right card -> do
            let gs' = applyCardPlay card gs
            when (null (currentTrick gs')) $ do
              let prevTrickWinner = trickLead gs'
              putStrLn $ "  → " ++ show prevTrickWinner ++ " wins the trick."
            runPlayingLoop gs'
      else do
        let
          card = aiSelectCard (hands gs Map.! actor) (map snd (currentTrick gs)) (trickLead gs) (trumpSuit gs) actor (maybe South id (declarer gs))
          isActorDummy = Just actor == dummy gs
        putStrLn $ "  " ++ show actor ++ (if isActorDummy then " (Dummy)" else "") ++ " plays: " ++ show card
        
        let gs' = applyCardPlay card gs
        when (null (currentTrick gs')) $ do
          let prevTrickWinner = trickLead gs'
          putStrLn $ "  → " ++ show prevTrickWinner ++ " wins the trick."
        runPlayingLoop gs'
```

---

## Compilation and Running the Game

Building and running the bridge game is fully integrated into GHC's build system and the root repository `Makefile`.

### Building with Cabal

Navigate to the `Bridge_game` directory and build the package:

```bash
cd Bridge_game
cabal build
```

This compiles all library modules and links the command line executable.

### Playing the Game

Run the executable using Cabal:

```bash
cabal run bridge-game
```

When prompted during the bidding phase, enter standard bids (such as `1H`, `1NT`, `PASS`, or `DBL`). During the playing phase, you can select card plays using the index numbers shown on the screen (e.g., `1`, `2`) or short symbols (such as `AS`, `10H`). Typing `Q` or `QUIT` at any prompt exits the game.


## Optional Practice Problems

1. Extend the heuristic bidding AI in the Bridge game library to evaluate the vulnerability status (vulnerable vs. non-vulnerable) of all players before choosing a bid.
2. Write Hspec test assertions under `Bridge_game/test` to verify that contract scoring calculations for trick points match official scoring rules under doubled or redoubled states.
