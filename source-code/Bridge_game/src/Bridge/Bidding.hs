module Bridge.Bidding where

import Bridge.Types
import Bridge.Cards
import Data.List (find)

-- Find the last suit bid in the history
lastSuitBid :: [(Player, BidType)] -> Maybe BidType
lastSuitBid history = fmap snd $ find (\(_, b) -> isSuitBid b) history

isSuitBid :: BidType -> Bool
isSuitBid (SuitBid _ _) = True
isSuitBid _ = False

-- Numeric index for comparisons: 1C = 0, 1D = 1, ..., 7NT = 34
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

-- Check if the bidding phase is complete
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


-- Extract contract, declarer, and doubled state
extractContract :: [(Player, BidType)] -> Player -> Maybe (BidType, Player, Int)
extractContract history _dealer =
  let
    -- Find the last suit bid
    findLastSuit [] = Nothing
    findLastSuit ((p, SuitBid l s):_) = Just (SuitBid l s, p)
    findLastSuit (_:xs) = findLastSuit xs
  in case findLastSuit history of
    Just (contract@(SuitBid _ strain), finalBidder) ->
      let
        declSide = side finalBidder
        chronoHistory = reverse history
        
        -- Find declarer: first player on declSide who bid this strain
        firstBidderOfStrain [] = finalBidder
        firstBidderOfStrain ((p, SuitBid _ s):xs)
          | s == strain && side p == declSide = p
          | otherwise = firstBidderOfStrain xs
        firstBidderOfStrain (_:xs) = firstBidderOfStrain xs
        
        declarer = firstBidderOfStrain chronoHistory
        
        -- Check double / redouble status
        checkDouble [] d = d
        checkDouble ((_, SuitBid _ _):_) d = d
        checkDouble ((_, DoubleBid):xs) 0 = checkDouble xs 1
        checkDouble ((_, RedoubleBid):xs) 1 = checkDouble xs 2
        checkDouble (_:xs) d = checkDouble xs d
        
        doubled = checkDouble history 0
      in Just (contract, declarer, doubled)
    _ -> Nothing

-- Find partner's first suit bid
findPartnerOpening :: [(Player, BidType)] -> Player -> Maybe BidType
findPartnerOpening history me =
  let
    p = partner me
    chrono = reverse history
    partnerBids = [bid | (bidder, bid) <- chrono, bidder == p, isSuitBid bid]
  in case partnerBids of
    (firstBid:_) -> Just firstBid
    [] -> Nothing

-- Find my own first suit bid
findMyOpening :: [(Player, BidType)] -> Player -> Maybe BidType
findMyOpening history me =
  let
    chrono = reverse history
    myBids = [bid | (bidder, bid) <- chrono, bidder == me, isSuitBid bid]
  in case myBids of
    (firstBid:_) -> Just firstBid
    [] -> Nothing

-- Stayman check
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

-- Opening bid decisions
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

-- Responding bid decisions
aiRespondingBid :: [Card] -> BidType -> Maybe BidType
aiRespondingBid hand partnerBid =
  case partnerBid of
    -- Partner opened No Trump
    SuitBid pLevel NoTrump ->
      let hcp = handHcp hand
      in if pLevel == 1
         then -- Responding to 1NT (15-17)
           if hcp <= 7
           then
             if suitLength Spades hand >= 5 then Just (SuitBid 2 (SuitStrain Spades))
             else if suitLength Hearts hand >= 5 then Just (SuitBid 2 (SuitStrain Hearts))
             else if suitLength Diamonds hand >= 5 then Just (SuitBid 2 (SuitStrain Diamonds))
             else Nothing
           else if hcp >= 8 && (suitLength Hearts hand >= 4 || suitLength Spades hand >= 4)
           then Just (SuitBid 2 (SuitStrain Clubs)) -- Stayman
           else if hcp <= 9 then Just (SuitBid 2 NoTrump)
           else if hcp <= 15 && suitLength Spades hand >= 6 then Just (SuitBid 4 (SuitStrain Spades))
           else if hcp <= 15 && suitLength Hearts hand >= 6 then Just (SuitBid 4 (SuitStrain Hearts))
           else if hcp <= 15 && suitLength Spades hand >= 5 then Just (SuitBid 3 (SuitStrain Spades))
           else if hcp <= 15 && suitLength Hearts hand >= 5 then Just (SuitBid 3 (SuitStrain Hearts))
           else if hcp <= 15 then Just (SuitBid 3 NoTrump)
           else Just (SuitBid 4 NoTrump)
         else -- Responding to 2NT (20-21)
           if hcp <= 4 && all (\s -> suitLength s hand < 5) [Clubs .. Spades]
           then Nothing
           else if hcp >= 4 && (suitLength Hearts hand >= 4 || suitLength Spades hand >= 4)
           then Just (SuitBid 3 (SuitStrain Clubs)) -- Stayman
           else if hcp >= 5 then Just (SuitBid 3 NoTrump)
           else Nothing
           
    -- Partner opened a suit
    SuitBid pLevel (SuitStrain pSuit) ->
      let hcp = handHcp hand
      in if pLevel == 1
         then
           if pSuit >= Hearts
           then -- Responding to a major (1H or 1S)
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
             else -- 13+
               if suitLength pSuit hand >= 3
               then Just (SuitBid 4 (SuitStrain pSuit))
               else Just (SuitBid 3 NoTrump)
           else -- Responding to a minor (1C or 1D)
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
         then -- Responding to 2C
           if hcp < 8 then Just (SuitBid 2 (SuitStrain Diamonds))
           else if not (isBalanced hand) && suitLength Spades hand >= 5 then Just (SuitBid 2 (SuitStrain Spades))
           else if not (isBalanced hand) && suitLength Hearts hand >= 5 then Just (SuitBid 2 (SuitStrain Hearts))
           else if not (isBalanced hand) && suitLength Diamonds hand >= 5 then Just (SuitBid 3 (SuitStrain Diamonds))
           else if not (isBalanced hand) && suitLength Clubs hand >= 5 then Just (SuitBid 3 (SuitStrain Clubs))
           else Just (SuitBid 2 NoTrump)
         else -- Responding to weak two or preemptive 3-level
           if pLevel == 2
           then
             if suitLength pSuit hand >= 3 && hcp >= 14 then Just (SuitBid 4 (SuitStrain pSuit))
             else if suitLength pSuit hand >= 3 && hcp >= 10 then Just (SuitBid 3 (SuitStrain pSuit))
             else Nothing
           else -- 3-level
             if suitLength pSuit hand >= 3 && hcp >= 14
             then Just (SuitBid (if pSuit >= Hearts then 4 else 5) (SuitStrain pSuit))
             else Nothing
    _ -> Nothing

-- Opener's rebid decisions
aiOpenerRebid :: [Card] -> BidType -> BidType -> Maybe BidType
aiOpenerRebid hand myOpening partnerResponse =
  case (myOpening, partnerResponse) of
    (SuitBid _ myStrain, SuitBid pLevel pStrain) ->
      cond myStrain pStrain pLevel
    _ -> Nothing
  where
    hcp = handHcp hand
    cond myStrain pStrain pLevel
      -- Stayman response
      | staymanResponseP partnerResponse myOpening =
        let responseLevel = if bidLevel myOpening == 1 then 2 else 3
        in Just $ if suitLength Hearts hand >= 4 && suitLength Spades hand >= 4 then SuitBid responseLevel (SuitStrain Hearts)
                  else if suitLength Hearts hand >= 4 then SuitBid responseLevel (SuitStrain Hearts)
                  else if suitLength Spades hand >= 4 then SuitBid responseLevel (SuitStrain Spades)
                  else SuitBid responseLevel (SuitStrain Diamonds)
      
      -- Blackwood Ace ask
      | blackwoodResponseP partnerResponse =
        let aces = length [c | c <- hand, cardRank c == Ace]
        in Just (SuitBid 5 (intToStrain (aces `mod` 5)))

      -- Blackwood King ask
      | blackwoodKingAskP partnerResponse =
        let kings = length [c | c <- hand, cardRank c == King]
        in Just (SuitBid 6 (intToStrain (kings `mod` 5)))

      -- Gerber Ace ask
      | gerberResponseP partnerResponse myOpening =
        let aces = length [c | c <- hand, cardRank c == Ace]
        in Just $ case aces of
          0 -> SuitBid 4 (SuitStrain Diamonds)
          1 -> SuitBid 4 (SuitStrain Hearts)
          2 -> SuitBid 4 (SuitStrain Spades)
          3 -> SuitBid 4 NoTrump
          _ -> SuitBid 5 (SuitStrain Clubs)

      -- Gerber King ask
      | gerberKingAskP partnerResponse =
        let kings = length [c | c <- hand, cardRank c == King]
        in Just $ case kings of
          0 -> SuitBid 5 (SuitStrain Diamonds)
          1 -> SuitBid 5 (SuitStrain Hearts)
          2 -> SuitBid 5 (SuitStrain Spades)
          3 -> SuitBid 5 NoTrump
          _ -> SuitBid 6 (SuitStrain Clubs)

      -- Partner responded in NT
      | pStrain == NoTrump =
        case myStrain of
          SuitStrain s | suitLength s hand >= 6 -> Just (SuitBid (pLevel + 1) myStrain)
          _ | hcp <= 15 -> Nothing
          _ | hcp <= 17 -> Just (SuitBid (pLevel + 1) NoTrump)
          _ -> Just (SuitBid (pLevel + 2) NoTrump)

      -- Partner raised my suit
      | SuitStrain s <- myStrain, SuitStrain ps <- pStrain, s == ps =
        if hcp <= 15 then Nothing
        else if hcp >= 19 && s >= Hearts then Just (SuitBid 4 NoTrump) -- Blackwood
        else if s >= Hearts && hcp <= 18 then Just (SuitBid 4 myStrain)
        else Just (SuitBid (if s >= Hearts then 4 else 5) myStrain)

      -- Partner bid a new suit
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

-- Ensure a bid is legal (higher than current highest bid)
ensureLegalBid :: Maybe BidType -> Maybe BidType -> Maybe BidType
ensureLegalBid Nothing _ = Nothing
ensureLegalBid (Just bid) Nothing = Just bid
ensureLegalBid (Just bid) (Just currentHighest)
  | not (isSuitBid bid) = Just bid
  | bidHigherThan bid currentHighest = Just bid
  | otherwise = Nothing

-- Select AI bid
aiSelectBid :: [Card] -> [(Player, BidType)] -> Player -> Player -> BidType
aiSelectBid hand history me _dealer =
  let
    currentHighest = lastSuitBid history
    partnerBid = findPartnerOpening history me
    myBid = findMyOpening history me
    
    rawBid = case (myBid, partnerBid) of
      -- I opened, partner responded -> Opener's rebid
      (Just mb, Just pb) -> aiOpenerRebid hand mb pb
      -- Partner opened, I haven't bid -> Respond
      (Nothing, Just pb) -> aiRespondingBid hand pb
      -- No suit bids yet -> Open
      _ | Nothing <- currentHighest -> aiOpeningBid hand
      -- Opponents bid, partner passed -> Simple overcall
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
