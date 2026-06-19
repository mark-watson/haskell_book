{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedRecordDot #-}

module Main where

import Bridge.Types
import Bridge.Bidding
import Bridge.Play
import Bridge.Scoring
import Bridge.Engine

import WebKitHaskell
import System.Random (getStdGen, StdGen, split)
import Data.IORef
import qualified Data.Aeson as Aeson
import GHC.Generics (Generic)
import Data.Char (toUpper, isDigit)
import Data.List (find)
import qualified Data.Map.Strict as Map
import System.Directory (doesFileExist)

-- ---------------------------------------------------------------------------
-- Payload and State Representations
-- ---------------------------------------------------------------------------

data ActiveState = ActiveState
  { currentGameState   :: GameState
  , currentRubberState  :: RubberState
  , randomGen           :: StdGen
  , lastTrickCards      :: [PlayedCard]
  }

data BidPayload = BidPayload
  { bid :: String
  } deriving (Generic, Aeson.FromJSON)

data PlayPayload = PlayPayload
  { card :: String
  } deriving (Generic, Aeson.FromJSON)

data PlayedCard = PlayedCard
  { pcPlayer :: String
  , pcCard   :: String
  } deriving (Generic, Aeson.ToJSON, Eq, Show)

data BidEntry = BidEntry
  { bePlayer :: String
  , beBid    :: String
  } deriving (Generic, Aeson.ToJSON)

data HandList = HandList
  { hlNorth :: [String]
  , hlEast  :: [String]
  , hlSouth :: [String]
  , hlWest  :: [String]
  } deriving (Generic, Aeson.ToJSON)

data GameStatePayload = GameStatePayload
  { phase              :: String
  , dealer             :: String
  , vulnerability      :: String
  , humanPlayer        :: String
  , activeActor        :: Maybe String
  , hands              :: HandList
  , originalHands      :: HandList
  , bidHistory         :: [BidEntry]
  , contract           :: Maybe String
  , declarer           :: Maybe String
  , doubled            :: Int
  , dummy              :: Maybe String
  , dummyVisible       :: Bool
  , currentTrick       :: [PlayedCard]
  , lastCompletedTrick :: [PlayedCard]
  , trickLead          :: String
  , tricksNs           :: Int
  , tricksEw           :: Int
  , tricksPlayed       :: Int
  , trumpSuit          :: Maybe String
  , rubberState        :: RubberState
  , legalCards         :: [String]
  , dealNum            :: Int
  } deriving (Generic, Aeson.ToJSON)

-- ---------------------------------------------------------------------------
-- Game State Marshalling
-- ---------------------------------------------------------------------------

makePayload :: GameState -> RubberState -> Int -> [PlayedCard] -> GameStatePayload
makePayload gs rs dNum lastTrick =
  let
    actor = currentActor gs
    leadSuit = case gs.currentTrick of
                 [] -> Nothing
                 tr -> Just (cardSuit (snd (last tr)))
    
    isHuman = actor == Just South
    isDummy = actor == gs.dummy
    declarerSide = fmap side gs.declarer
    humanPlaysDummy = isDummy && (declarerSide == Just 0)
    humanPlaysThis = isHuman || humanPlaysDummy
    
    legalList =
      if gs.phase == Playing && humanPlaysThis
      then case actor of
             Just act -> legalPlays (gs.hands Map.! act) leadSuit
             Nothing  -> []
      else []
      
    isDummyVis =
      gs.phase == Playing && (not (null gs.cardsPlayed) || humanPlaysThis)
      
    cardCode (Card s r) = show (Card s r)
    
    playedCardList = map (\(p, c) -> PlayedCard (show p) (cardCode c)) (reverse gs.currentTrick)
    bidEntryList = map (\(p, b) -> BidEntry (show p) (show b)) (reverse gs.bidHistory)
    
    handList = HandList
      { hlNorth = map cardCode (gs.hands Map.! North)
      , hlEast  = map cardCode (gs.hands Map.! East)
      , hlSouth = map cardCode (gs.hands Map.! South)
      , hlWest  = map cardCode (gs.hands Map.! West)
      }
      
    origHandList = HandList
      { hlNorth = map cardCode (gs.originalHands Map.! North)
      , hlEast  = map cardCode (gs.originalHands Map.! East)
      , hlSouth = map cardCode (gs.originalHands Map.! South)
      , hlWest  = map cardCode (gs.originalHands Map.! West)
      }
  in GameStatePayload
    { phase = show gs.phase
    , dealer = show gs.dealer
    , vulnerability = show gs.vulnerability
    , humanPlayer = show gs.humanPlayer
    , activeActor = fmap show actor
    , hands = handList
    , originalHands = origHandList
    , bidHistory = bidEntryList
    , contract = fmap show gs.contract
    , declarer = fmap show gs.declarer
    , doubled = gs.doubled
    , dummy = fmap show gs.dummy
    , dummyVisible = isDummyVis
    , currentTrick = playedCardList
    , lastCompletedTrick = lastTrick
    , trickLead = show gs.trickLead
    , tricksNs = gs.tricksNs
    , tricksEw = gs.tricksEw
    , tricksPlayed = gs.tricksPlayed
    , trumpSuit = fmap show gs.trumpSuit
    , rubberState = rs
    , legalCards = map cardCode legalList
    , dealNum = dNum
    }

-- ---------------------------------------------------------------------------
-- Heuristic AI Autoplay Loops
-- ---------------------------------------------------------------------------

runAiBidding :: GameState -> GameState
runAiBidding gs
  | gs.phase /= Bidding = gs
  | otherwise =
      case currentActor gs of
        Just South -> gs
        Just actor ->
          let aiBid = aiSelectBid (gs.hands Map.! actor) gs.bidHistory actor gs.dealer
              gs' = applyBid aiBid gs
          in runAiBidding gs'
        Nothing -> gs

runAiPlaying :: GameState -> GameState
runAiPlaying gs
  | gs.phase /= Playing = gs
  | otherwise =
      case currentActor gs of
        Just actor ->
          let isHuman = actor == South
              isDummy = Just actor == gs.dummy
              declarerSide = fmap side gs.declarer
              humanPlaysDummy = isDummy && (declarerSide == Just 0)
              humanPlaysThis = isHuman || humanPlaysDummy
          in if humanPlaysThis
             then gs
             else
               let cardVal = aiSelectCard (gs.hands Map.! actor) (map snd gs.currentTrick) gs.trickLead gs.trumpSuit actor (maybe South id gs.declarer)
                   gs' = applyCardPlay cardVal gs
               in runAiPlaying gs'
        Nothing -> gs

nextDeal :: ActiveState -> ActiveState
nextDeal state =
  let
    rs = state.currentRubberState
    dealerVal = rs.currentDealer
    vul = case (rs.nsVulnerable, rs.ewVulnerable) of
            (True, True)  -> Both
            (True, False) -> NsOnly
            (False, True) -> EwOnly
            (False, False)-> None
    (gen1, gen2) = split state.randomGen
    gs = newGame dealerVal vul South gen1
    gs' = runAiBidding gs
  in state
    { currentGameState = gs'
    , randomGen = gen2
    , lastTrickCards = []
    }

-- Helper to apply a card play and transition/score the game step
playCardAndStep :: Card -> Player -> ActiveState -> ActiveState
playCardAndStep cardVal actor state =
  let gsVal = state.currentGameState
      currentTrick' = (actor, cardVal) : gsVal.currentTrick
      
      completedTrick =
        if length currentTrick' == 4
        then map (\(p, c) -> PlayedCard (show p) (show c)) (reverse currentTrick')
        else []
        
      gs' = applyCardPlay cardVal gsVal
      
      state' =
        if gs'.phase == Scoring
        then
          let
            rsVal = state.currentRubberState
            contractVal = maybe (SuitBid 1 NoTrump) id gs'.contract
            level = case contractVal of SuitBid l _ -> l; _ -> 1
            strain = case contractVal of SuitBid _ s -> s; _ -> NoTrump
            declarerVal = maybe South id gs'.declarer
            doubledVal = gs'.doubled
            tricksWon = if side declarerVal == 0 then gs'.tricksNs else gs'.tricksEw
            (rs', _) = scoreRubberDeal level strain tricksWon declarerVal doubledVal rsVal
            rs'' = rs' { dealsPlayed = rs'.dealsPlayed + 1, currentDealer = nextPlayer rs'.currentDealer }
          in state { currentGameState = gs', currentRubberState = rs'' }
        else
          state { currentGameState = gs' }
  in state' { lastTrickCards = completedTrick }

-- ---------------------------------------------------------------------------
-- Bid / Card Input Parsers
-- ---------------------------------------------------------------------------

trim :: String -> String
trim = f . f
  where f = reverse . dropWhile (== ' ')

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

parseStrain :: String -> Maybe Strain
parseStrain s
  | s `elem` ["C", "CLUBS"] = Just (SuitStrain Clubs)
  | s `elem` ["D", "DIAMONDS"] = Just (SuitStrain Diamonds)
  | s `elem` ["H", "HEARTS"] = Just (SuitStrain Hearts)
  | s `elem` ["S", "SPADES"] = Just (SuitStrain Spades)
  | s `elem` ["N", "NT", "NOTRUMP", "NO TRUMP"] = Just NoTrump
  | otherwise = Nothing

-- ---------------------------------------------------------------------------
-- Main Program Wrapper
-- ---------------------------------------------------------------------------

main :: IO ()
main = do
  putStrLn "Starting bridge-webkit WebKit desktop application..."

  -- Create the 1000x820 native Cocoa window with WebKit view
  app <- newWebKitApp "Rubber Bridge — WebKit" 1000 820

  -- Initialize Game and Rubber state inside IORef
  initGen <- getStdGen
  let
    (initGen1, initGen2) = split initGen
    initRs = newRubberState
    initGs = newGame North None South initGen1
    initGs' = runAiBidding initGs
  stateRef <- newIORef (ActiveState initGs' initRs initGen2 [])

  -- Register handlers for Javascript bridge invocations
  registerHandler app "get-state" $ \_ -> do
    state <- readIORef stateRef
    return $ Aeson.toJSON (makePayload state.currentGameState state.currentRubberState (state.currentRubberState.dealsPlayed + 1) state.lastTrickCards)

  registerHandler app "bid" $ \payload ->
    case Aeson.fromJSON payload of
      Aeson.Success (BidPayload bidStr) -> do
        putStrLn $ "[Haskell] Received bid command: " ++ bidStr
        state <- readIORef stateRef
        let gsVal = state.currentGameState
        case parseBidInput bidStr of
          Just bidVal ->
            let
              currentHighest = lastSuitBid gsVal.bidHistory
              isLegal = case (bidVal, currentHighest) of
                (SuitBid _ _, Just ch) -> bidHigherThan bidVal ch
                _ -> True
            in if isLegal
               then do
                 let
                   gs' = applyBid bidVal gsVal
                   gs'' = runAiBidding gs'
                   state' =
                     if gs''.phase == Done
                     then nextDeal state
                     else state { currentGameState = gs'', lastTrickCards = [] }
                 writeIORef stateRef state'
                 stateFinal <- readIORef stateRef
                 return $ Aeson.toJSON (makePayload stateFinal.currentGameState stateFinal.currentRubberState (stateFinal.currentRubberState.dealsPlayed + 1) stateFinal.lastTrickCards)
               else
                 return $ Aeson.object ["error" Aeson..= ("Bid " ++ bidStr ++ " is not legal." :: String)]
          Nothing ->
            return $ Aeson.object ["error" Aeson..= ("Failed to parse bid: " ++ bidStr :: String)]
      _ ->
        return $ Aeson.object ["error" Aeson..= ("Invalid bid payload syntax." :: String)]

  registerHandler app "play-card" $ \payload ->
    case Aeson.fromJSON payload of
      Aeson.Success (PlayPayload cardStr) -> do
        putStrLn $ "[Haskell] Received play-card command: " ++ cardStr
        state <- readIORef stateRef
        let gsVal = state.currentGameState
            actor = currentActor gsVal
            leadSuit = case gsVal.currentTrick of
                         [] -> Nothing
                         tr -> Just (cardSuit (snd (last tr)))
        case actor of
          Just act -> do
            let legal = legalPlays (gsVal.hands Map.! act) leadSuit
            case find (\c -> show c == cardStr) legal of
              Just cardVal -> do
                let state' = playCardAndStep cardVal act state
                writeIORef stateRef state'
                stateFinal <- readIORef stateRef
                return $ Aeson.toJSON (makePayload stateFinal.currentGameState stateFinal.currentRubberState (stateFinal.currentRubberState.dealsPlayed + 1) stateFinal.lastTrickCards)
              Nothing ->
                return $ Aeson.object ["error" Aeson..= ("Card " ++ cardStr ++ " is not a legal play." :: String)]
          Nothing ->
            return $ Aeson.object ["error" Aeson..= ("No active player found." :: String)]
      _ ->
        return $ Aeson.object ["error" Aeson..= ("Invalid play-card payload syntax." :: String)]

  registerHandler app "ai-play-single" $ \_ -> do
    putStrLn "[Haskell] Received ai-play-single command"
    state <- readIORef stateRef
    let gsVal = state.currentGameState
    case currentActor gsVal of
      Just actor -> do
        let isHuman = actor == South
            isDummy = Just actor == gsVal.dummy
            declarerSide = fmap side gsVal.declarer
            humanPlaysDummy = isDummy && (declarerSide == Just 0)
            humanPlaysThis = isHuman || humanPlaysDummy
        if humanPlaysThis
          then return $ Aeson.object ["error" Aeson..= ("It is human's turn to play, not AI." :: String)]
          else do
            let cardVal = aiSelectCard (gsVal.hands Map.! actor) (map snd gsVal.currentTrick) gsVal.trickLead gsVal.trumpSuit actor (maybe South id gsVal.declarer)
                state' = playCardAndStep cardVal actor state
            writeIORef stateRef state'
            stateFinal <- readIORef stateRef
            return $ Aeson.toJSON (makePayload stateFinal.currentGameState stateFinal.currentRubberState (stateFinal.currentRubberState.dealsPlayed + 1) stateFinal.lastTrickCards)
      Nothing ->
        return $ Aeson.object ["error" Aeson..= ("No active player found." :: String)]

  registerHandler app "next-deal" $ \_ -> do
    putStrLn "[Haskell] Received next-deal command"
    state <- readIORef stateRef
    let state' = nextDeal state
    writeIORef stateRef state'
    stateFinal <- readIORef stateRef
    return $ Aeson.toJSON (makePayload stateFinal.currentGameState stateFinal.currentRubberState (stateFinal.currentRubberState.dealsPlayed + 1) stateFinal.lastTrickCards)

  registerHandler app "reset-game" $ \_ -> do
    putStrLn "[Haskell] Received reset-game command"
    state <- readIORef stateRef
    let
      (gen1, gen2) = split state.randomGen
      rsVal = newRubberState
      gsVal = newGame North None South gen1
      gs' = runAiBidding gsVal
    writeIORef stateRef (ActiveState gs' rsVal gen2 [])
    return $ Aeson.toJSON (makePayload gs' rsVal (rsVal.dealsPlayed + 1) [])

  -- Load index.html safely
  htmlPath <- do
    exists1 <- doesFileExist "app/index.html"
    if exists1
      then return "app/index.html"
      else do
        exists2 <- doesFileExist "index.html"
        if exists2
          then return "index.html"
          else error "Could not find index.html in app/ or current directory!"
          
  htmlContent <- readFile htmlPath
  loadHTML app htmlContent

  -- Run Cocoa UI app loops
  runWebKitApp app
  destroyWebKitApp app
  putStrLn "bridge-webkit terminated successfully."
