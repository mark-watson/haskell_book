{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}

module Bridge.Engine where

import Bridge.Types
import Bridge.Cards
import Bridge.Bidding
import Bridge.Play
import System.Random (StdGen)
import qualified Data.Map.Strict as Map
import GHC.Generics (Generic)
import Data.Aeson (ToJSON, FromJSON)

data Vulnerability = None | NsOnly | EwOnly | Both
  deriving (Eq, Show, Generic, ToJSON, FromJSON)

data GameState = GameState
  { hands          :: Map.Map Player [Card]
  , originalHands  :: Map.Map Player [Card]
  , dealer         :: Player
  , vulnerability  :: Vulnerability
  , humanPlayer    :: Player
  -- Bidding
  , bidHistory     :: [(Player, BidType)]
  , contract       :: Maybe BidType
  , declarer       :: Maybe Player
  , doubled        :: Int
  -- Play
  , dummy          :: Maybe Player
  , currentTrick   :: [(Player, Card)] -- Play order: newest played first
  , trickLead      :: Player
  , tricksNs       :: Int
  , tricksEw       :: Int
  , tricksPlayed   :: Int
  , cardsPlayed    :: [Card]
  , trumpSuit      :: Maybe Suit
  -- Phase
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
    { hands = handsMap
    , originalHands = handsMap
    , dealer = dealerVal
    , vulnerability = vul
    , humanPlayer = humanVal
    , bidHistory = []
    , contract = Nothing
    , declarer = Nothing
    , doubled = 0
    , dummy = Nothing
    , currentTrick = []
    , trickLead = dealerVal
    , tricksNs = 0
    , tricksEw = 0
    , tricksPlayed = 0
    , cardsPlayed = []
    , trumpSuit = Nothing
    , phase = Bidding
    }

currentActor :: GameState -> Maybe Player
currentActor gs =
  case phase gs of
    Bidding ->
      case bidHistory gs of
        [] -> Just (dealer gs)
        ((actor, _):_) -> Just (nextPlayer actor)
    Playing ->
      case currentTrick gs of
        [] -> Just (trickLead gs)
        ((actor, _):_) -> Just (nextPlayer actor)
    _ -> Nothing

-- Apply a bid in the bidding phase
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
                   ts = case contract' of
                          SuitBid _ (SuitStrain s) -> Just s
                          _ -> Nothing

                   -- When partner North wins the contract, move the declaring hand
                   -- into the South seat so the human plays it, and treat South as the
                   -- effective declarer. This keeps declarer, dummy, trick credit, and
                   -- lead rotation consistent (declarer and dummy stay partners).
                   (hands', effDeclarer) =
                     if declarer' == North && humanPlayer gs == South
                     then
                       let
                         northCards = hands gs Map.! North
                         southCards = hands gs Map.! South
                         swapped = Map.fromList [(North, southCards), (East, hands gs Map.! East), (South, northCards), (West, hands gs Map.! West)]
                       in (swapped, South)
                     else (hands gs, declarer')
                 in gs
                   { bidHistory = history'
                   , contract = Just contract'
                   , declarer = Just effDeclarer
                   , doubled = doubled'
                   , dummy = Just (partner effDeclarer)
                   , trumpSuit = ts
                   , trickLead = nextPlayer effDeclarer
                   , phase = Playing
                   , hands = hands'
                   }
         else gs { bidHistory = history' }

-- Apply a card play in the playing phase
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
             -- The currentTrick' is stored newest-first. Reverse to get play order.
             trickInPlayOrder = map snd (reverse currentTrick')
             winner = trickWinner trickInPlayOrder (trickLead gs) (trumpSuit gs)
             
             nsScore = if winner == North || winner == South then 1 else 0
             ewScore = if winner == East || winner == West then 1 else 0
             
             tricksNs' = tricksNs gs + nsScore
             tricksEw' = tricksEw gs + ewScore
             tricksPlayed' = tricksPlayed gs + 1
             
             nextPhase = if tricksPlayed' == 13 then Scoring else Playing
           in gs
             { hands = hands'
             , currentTrick = []
             , trickLead = winner
             , tricksNs = tricksNs'
             , tricksEw = tricksEw'
             , tricksPlayed = tricksPlayed'
             , cardsPlayed = cardsPlayed'
             , phase = nextPhase
             }
         else gs
           { hands = hands'
           , currentTrick = currentTrick'
           , cardsPlayed = cardsPlayed'
           }
