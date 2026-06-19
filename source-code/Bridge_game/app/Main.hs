module Main where

import Bridge.Types
import Bridge.Cards
import Bridge.Bidding
import Bridge.Play
import Bridge.Scoring
import Bridge.Engine

import System.Random (getStdGen, StdGen, split)
import qualified Data.Map.Strict as Map
import Data.Char (toUpper, isDigit)
import Data.List (find, sortBy)
import System.IO (hFlush, stdout)
import Control.Monad (when)

-- ---------------------------------------------------------------------------
-- Text Formatting & Padding
-- ---------------------------------------------------------------------------

data Align = AlignLeft | AlignRight | AlignCenter

padString :: String -> Int -> Align -> String
padString str width align =
  let len = length str
  in if len >= width
     then take width str
     else case align of
       AlignLeft  -> str ++ replicate (width - len) ' '
       AlignRight -> replicate (width - len) ' ' ++ str
       AlignCenter ->
         let
           leftPad = (width - len) `div` 2
           rightPad = width - len - leftPad
         in replicate leftPad ' ' ++ str ++ replicate rightPad ' '

suitLineString :: [Card] -> Suit -> String
suitLineString hand suit =
  let
    cards = handSuitCards hand suit
    sortedCards = sortBy (\c1 c2 -> compare (cardRank c2) (cardRank c1)) cards
    rankSymbols = map rankSymbol sortedCards
  in showSuit suit ++ " " ++ if null rankSymbols then "---" else unwords rankSymbols
  where
    showSuit Clubs = "C:"
    showSuit Diamonds = "D:"
    showSuit Hearts = "H:"
    showSuit Spades = "S:"

    rankSymbol (Card _ Ace) = "A"
    rankSymbol (Card _ King) = "K"
    rankSymbol (Card _ Queen) = "Q"
    rankSymbol (Card _ Jack) = "J"
    rankSymbol (Card _ R10) = "10"
    rankSymbol (Card _ r) = show (fromEnum r + 2)

-- ---------------------------------------------------------------------------
-- Board / Table Display
-- ---------------------------------------------------------------------------

displayBoard :: GameState -> IO ()
displayBoard gs = do
  let
    nHand = hands gs Map.! North
    eHand = hands gs Map.! East
    sHand = hands gs Map.! South
    wHand = hands gs Map.! West
    
    human = humanPlayer gs
    dm = dummy gs
    
    showNorth = human == North || dm == Just North
    showEast  = human == East  || dm == Just East
    showSouth = human == South || dm == Just South
    showWest  = human == West  || dm == Just West
    
    width = 60
    
    formatPlayerHand :: Bool -> [Card] -> [String]
    formatPlayerHand True hand = [suitLineString hand s | s <- [Spades, Hearts, Diamonds, Clubs]]
    formatPlayerHand False hand = [padString ("[" ++ show (length hand) ++ " cards]") width AlignCenter, "", "", ""]
  
  putStrLn ""
  putStrLn (replicate width '═')
  putStrLn (padString "♠ ♥ ♦ ♣  BRIDGE TABLE  ♣ ♦ ♥ ♠" width AlignCenter)
  putStrLn (padString ("Vulnerability: " ++ show (vulnerability gs)) width AlignCenter)
  putStrLn (replicate width '─')
  
  -- North (Top)
  let nLabel = "NORTH" ++ (if human == North then " (You)" else "") ++ (if dm == Just North then " (Dummy)" else "")
  putStrLn (padString nLabel width AlignCenter)
  let nLines = formatPlayerHand showNorth nHand
  mapM_ (\line -> putStrLn (padString line width AlignCenter)) nLines
  putStrLn ""
  
  -- West and East
  let
    wLabel = "WEST" ++ (if human == West then " (You)" else "") ++ (if dm == Just West then " (Dummy)" else "")
    eLabel = "EAST" ++ (if human == East then " (You)" else "") ++ (if dm == Just East then " (Dummy)" else "")
    
    wLines = if showWest
             then [suitLineString wHand s | s <- [Spades, Hearts, Diamonds, Clubs]]
             else ["[" ++ show (length wHand) ++ " cards]", "", "", ""]
             
    eLines = if showEast
             then [suitLineString eHand s | s <- [Spades, Hearts, Diamonds, Clubs]]
             else ["[" ++ show (length eHand) ++ " cards]", "", "", ""]
             
    trickLines = formatTrick (reverse (currentTrick gs)) (trickLead gs)
  
  putStrLn (padString wLabel 20 AlignLeft ++ padString "" 20 AlignCenter ++ padString eLabel 20 AlignRight)
  mapM_ (\i -> putStrLn (padString (wLines !! i) 20 AlignLeft ++ padString (trickLines !! i) 20 AlignCenter ++ padString (eLines !! i) 20 AlignRight)) [0..3]
  
  putStrLn ""
  
  -- South (Bottom)
  let sLabel = "SOUTH" ++ (if human == South then " (You)" else "") ++ (if dm == Just South then " (Dummy)" else "")
  putStrLn (padString sLabel width AlignCenter)
  let sLines = formatPlayerHand showSouth sHand
  mapM_ (\line -> putStrLn (padString line width AlignCenter)) sLines
  
  putStrLn (replicate width '═')

formatTrick :: [(Player, Card)] -> Player -> [String]
formatTrick trick _leader =
  let
    formatted = case trick of
      [] -> ["", "Empty Trick", "", ""]
      _ ->
        let
          lines' = [show p ++ ": " ++ show c | (p, c) <- trick]
        in lines' ++ replicate (4 - length lines') ""
  in formatted

-- ---------------------------------------------------------------------------
-- Scoring Display
-- ---------------------------------------------------------------------------

displayRubberScore :: RubberState -> IO ()
displayRubberScore rs = do
  putStrLn "\n  ╔════════════════════╦════════════════════╗"
  putStrLn   "  ║   RUBBER BRIDGE SCORECARD              ║"
  putStrLn   "  ╠════════════════════╬════════════════════╣"
  putStrLn   "  ║      N-S           ║      E-W           ║"
  putStrLn   "  ╠════════════════════╬════════════════════╣"
  putStrLn $ "  ║  Above: " ++ padString (show (nsAbove rs)) 5 AlignRight ++ "      ║  Above: " ++ padString (show (ewAbove rs)) 5 AlignRight ++ "      ║"
  putStrLn   "  ╠────────────────────╬────────────────────╣"
  putStrLn $ "  ║  Below: " ++ padString (show (nsBelow rs)) 5 AlignRight ++ "      ║  Below: " ++ padString (show (ewBelow rs)) 5 AlignRight ++ "      ║"
  putStrLn $ "  ║  Games: " ++ show (nsGames rs) ++ "          ║  Games: " ++ show (ewGames rs) ++ "          ║"
  putStrLn $ "  ║  Vul:   " ++ (if nsVulnerable rs then "YES" else "No ") ++ "       ║  Vul:   " ++ (if ewVulnerable rs then "YES" else "No ") ++ "       ║"
  putStrLn   "  ╚════════════════════╩════════════════════╝"

displayDealResult :: GameState -> Int -> IO ()
displayDealResult gs dealScore =
  case (contract gs, declarer gs) of
    (Just contract', Just declarer') -> do
      let
        level = case contract' of SuitBid l _ -> l; _ -> 1
        strain = case contract' of SuitBid _ s -> s; _ -> NoTrump
        doubled' = doubled gs
        tricksWon = if side declarer' == 0 then tricksNs gs else tricksEw gs
        tricksNeeded = level + 6
        result = tricksWon - tricksNeeded
      
      putStrLn "\n  ── Deal Result ──"
      putStrLn $ "  Contract: " ++ show level ++ show strain ++
                 (case doubled' of 1 -> " Doubled"; 2 -> " Redoubled"; _ -> "") ++
                 " by " ++ show declarer'
      putStrLn $ "  Tricks needed: " ++ show tricksNeeded ++ "  Tricks won: " ++ show tricksWon
      if result >= 0
        then do
          let resStr = if result == 0 then "exactly" else "+" ++ show result
          putStrLn $ "  Made " ++ resStr ++ "  (below the line: " ++ show (if dealScore > 0 then dealScore else 0) ++ ")"
        else
          putStrLn $ "  Down " ++ show (abs result) ++ "  (penalty: " ++ show (abs dealScore) ++ " to defenders)"
      putStrLn "  ─────────────────────"
    _ -> return ()

displayRubberFinal :: RubberState -> IO ()
displayRubberFinal rs = do
  let
    (bonus, winner) = rubberBonus rs
    (nsTotal, ewTotal) = rubberTotalScores rs
    winningGames = if winner == Just "N-S" then nsGames rs else ewGames rs
    losingGames = if winner == Just "N-S" then ewGames rs else nsGames rs
  
  putStrLn "\n╔═════════════════════════════════════════╗"
  putStrLn   "║         RUBBER COMPLETE!                ║"
  putStrLn   "╠═════════════════════════════════════════╣"
  putStrLn $ "║  " ++ padString (show winner ++ " wins the rubber (" ++ show winningGames ++ "-" ++ show losingGames ++ ")") 39 AlignLeft ++ " ║"
  putStrLn $ "║  Rubber bonus: " ++ padString (show bonus) 25 AlignLeft ++ " ║"
  putStrLn   "╠─────────────────────────────────────────╣"
  putStrLn $ "║  N-S total: " ++ padString (show nsTotal) 27 AlignLeft ++ " ║"
  putStrLn $ "║  E-W total: " ++ padString (show ewTotal) 27 AlignLeft ++ " ║"
  let netWinner = if nsTotal > ewTotal then "N-S" else "E-W"
  let netAmt = abs (nsTotal - ewTotal)
  putStrLn $ "║  Net: " ++ padString (netWinner ++ " +" ++ show netAmt) 33 AlignLeft ++ " ║"
  putStrLn   "╚═════════════════════════════════════════╝"

-- ---------------------------------------------------------------------------
-- Parsers
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

parseCardInput :: String -> [Card] -> Maybe Card
parseCardInput raw legal =
  let s = map toUpper (trim raw)
  in if not (null s) && all isDigit s
     then
       let idx = read s :: Int
       in if idx >= 1 && idx <= length legal
          then Just (legal !! (idx - 1))
          else Nothing
     else
       case s of
         "10C" -> findCard Clubs R10
         "10D" -> findCard Diamonds R10
         "10H" -> findCard Hearts R10
         "10S" -> findCard Spades R10
         (rChar:sChar:[]) ->
           do
             rank <- parseRank rChar
             suit <- parseSuit sChar
             findCard suit rank
         _ -> Nothing
  where
    findCard suit rank = find (\c -> cardSuit c == suit && cardRank c == rank) legal
    
    parseRank 'A' = Just Ace
    parseRank 'K' = Just King
    parseRank 'Q' = Just Queen
    parseRank 'J' = Just Jack
    parseRank c | c >= '2' && c <= '9' = Just (toEnum (read [c] - 2))
    parseRank _ = Nothing
    
    parseSuit 'C' = Just Clubs
    parseSuit 'D' = Just Diamonds
    parseSuit 'H' = Just Hearts
    parseSuit 'S' = Just Spades
    parseSuit _ = Nothing

-- ---------------------------------------------------------------------------
-- Prompt Interfaces
-- ---------------------------------------------------------------------------

promptForBid :: GameState -> IO (Either String BidType)
promptForBid gs = do
  let currentHighest = lastSuitBid (bidHistory gs)
  putStrLn "\n  Your hand:"
  displayHandBySuit (hands gs Map.! South)
  putStrLn $ "  HCP: " ++ show (handHcp (hands gs Map.! South))
  putStrLn $ "  Current highest bid: " ++ maybe "None" show currentHighest
  putStr "  Enter bid (e.g. 1H, 2NT, 3S, PASS, DBL, Q=quit): "
  hFlush stdout
  input <- getLine
  let s = map toUpper (trim input)
  if s `elem` ["Q", "QUIT"]
    then return (Left "quit")
    else case parseBidInput input of
      Nothing -> do
        putStrLn "  Invalid bid syntax. Try again."
        promptForBid gs
      Just bid ->
        case (bid, currentHighest) of
          (SuitBid _ _, Just ch) | not (bidHigherThan bid ch) -> do
            putStrLn $ "  Bid must be higher than " ++ show ch ++ "."
            promptForBid gs
          _ -> return (Right bid)

promptForCard :: GameState -> Player -> Maybe Suit -> IO (Either String Card)
promptForCard gs player leadSuit = do
  let
    hand = hands gs Map.! player
    legal = legalPlays hand leadSuit
    isDummy = Just player == dummy gs
  
  when isDummy $
    putStrLn $ "\n  >>> Playing DUMMY's hand (" ++ show player ++ ") <<<"
    
  putStrLn $ "\n  " ++ (if isDummy then "Dummy's" else "Your") ++ " hand:"
  displayHandBySuit hand
  
  case leadSuit of
    Nothing -> putStrLn $ "\n  " ++ (if isDummy then "Dummy is" else "You are") ++ " leading — select any card:"
    Just ls ->
      if any (\c -> cardSuit c == ls) hand
      then putStrLn $ "\n  Must follow " ++ showSuit ls ++ " — legal plays:"
      else putStrLn $ "\n  No " ++ showSuit ls ++ " — play any card:"
      
  mapM_ (\(c, idx) -> putStrLn $ "    " ++ show (idx :: Int) ++ ". " ++ show c ++ "  (" ++ showCardName c ++ ")") (zip legal [1..])
  
  putStr "  Select card (number or name like AS, KH, 10C, Q=quit): "
  hFlush stdout
  input <- getLine
  let s = map toUpper (trim input)
  if s `elem` ["Q", "QUIT"]
    then return (Left "quit")
    else case parseCardInput input legal of
      Nothing -> do
        putStrLn "  Invalid card selection. Try again."
        promptForCard gs player leadSuit
      Just card -> return (Right card)
  where
    showSuit Clubs = "Clubs"
    showSuit Diamonds = "Diamonds"
    showSuit Hearts = "Hearts"
    showSuit Spades = "Spades"

    showCardName (Card suit rank) = showRank rank ++ " of " ++ show suit
    showRank Ace = "Ace"
    showRank King = "King"
    showRank Queen = "Queen"
    showRank Jack = "Jack"
    showRank R10 = "10"
    showRank r = show (fromEnum r + 2)

displayHandBySuit :: [Card] -> IO ()
displayHandBySuit hand = do
  putStrLn $ "  " ++ suitLineString hand Spades
  putStrLn $ "  " ++ suitLineString hand Hearts
  putStrLn $ "  " ++ suitLineString hand Diamonds
  putStrLn $ "  " ++ suitLineString hand Clubs

displayBiddingHistory :: [(Player, BidType)] -> Player -> IO ()
displayBiddingHistory history dealerVal = do
  putStrLn "\n"
  putStrLn (replicate 44 '─')
  putStrLn " BIDDING AUCTION"
  putStrLn (replicate 44 '─')
  
  let players = [North, East, South, West]
  putStrLn $ concatMap (\p -> padString (show p) 11 AlignLeft) players
  putStrLn (replicate 44 '─')
  
  let
    dealerIdx = fromEnum dealerVal
    chrono = reverse history
    initialPadding = concat (replicate dealerIdx (padString "" 11 AlignLeft))
    
    printBids [] _ accum = accum
    printBids ((_, bid):xs) col accum =
      let
        bidStr = padString (show bid) 11 AlignLeft
        accum' = accum ++ bidStr
        col' = col + 1
      in if col' `mod` 4 == 0
         then printBids xs col' (accum' ++ "\n")
         else printBids xs col' accum'
  
  putStr (printBids chrono dealerIdx initialPadding)
  putStrLn ""
  putStrLn (replicate 44 '─')

displayWelcome :: IO ()
displayWelcome = do
  putStrLn ""
  putStrLn "╔══════════════════════════════════════════════╗"
  putStrLn "║          RUBBER BRIDGE — AI Edition          ║"
  putStrLn "║                                              ║"
  putStrLn "║  You play as South.                          ║"
  putStrLn "║  North is your AI partner.                   ║"
  putStrLn "║  East-West are AI opponents.                 ║"
  putStrLn "║                                              ║"
  putStrLn "║  Scoring: Rubber bridge (first to 2 games)   ║"
  putStrLn "║  Bidding: Standard American (simplified)     ║"
  putStrLn "║  Play:   Heuristic AI                        ║"
  putStrLn "╚══════════════════════════════════════════════╝"

-- ---------------------------------------------------------------------------
-- Phase Game Loops
-- ---------------------------------------------------------------------------

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
        -- AI turn
        let
          aiBid = aiSelectBid (hands gs Map.! actor) (bidHistory gs) actor (dealer gs)
        putStrLn $ "  " ++ show actor ++ " bids: " ++ show aiBid
        runBiddingLoop (applyBid aiBid gs)

runPlayingLoop :: GameState -> IO (Either String GameState)
runPlayingLoop gs =
  if phase gs /= Playing
  then return (Right gs)
  else case currentActor gs of
    Nothing -> return (Right gs)
    Just actor -> do
      -- Print running stats for new trick
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
        -- Show current trick so far
        when (not (null (currentTrick gs))) $ do
          putStrLn "\n  Trick in progress:"
          mapM_ (\(p, c) -> putStrLn $ "    " ++ show p ++ " played: " ++ show c) (reverse (currentTrick gs))
        
        res <- promptForCard gs actor leadSuit
        case res of
          Left err -> return (Left err)
          Right card -> do
            let gs' = applyCardPlay card gs
            -- If trick is finished, show trick winner
            when (null (currentTrick gs')) $ do
              let prevTrickWinner = trickLead gs'
              putStrLn $ "  → " ++ show prevTrickWinner ++ " wins the trick."
            runPlayingLoop gs'
      else do
        -- AI plays card
        let
          card = aiSelectCard (hands gs Map.! actor) (map snd (currentTrick gs)) (trickLead gs) (trumpSuit gs) actor (maybe South id (declarer gs))
          isActorDummy = Just actor == dummy gs
        putStrLn $ "  " ++ show actor ++ (if isActorDummy then " (Dummy)" else "") ++ " plays: " ++ show card
        
        let gs' = applyCardPlay card gs
        when (null (currentTrick gs')) $ do
          let prevTrickWinner = trickLead gs'
          putStrLn $ "  → " ++ show prevTrickWinner ++ " wins the trick."
        runPlayingLoop gs'

-- ---------------------------------------------------------------------------
-- Main Loop
-- ---------------------------------------------------------------------------

rubberLoop :: RubberState -> StdGen -> IO ()
rubberLoop rs gen =
  if rubberComplete rs
  then displayRubberFinal rs
  else do
    let
      dealerVal = currentDealer rs
      vul = case (nsVulnerable rs, ewVulnerable rs) of
              (True, True)  -> Both
              (True, False) -> NsOnly
              (False, True) -> EwOnly
              (False, False)-> None
              
      dealNum = dealsPlayed rs + 1
      
    putStrLn "\n\n══════════════════════════════════════════"
    putStrLn $ "  DEAL #" ++ show dealNum ++ "   (N-S games won: " ++ show (nsGames rs) ++ "  E-W games won: " ++ show (ewGames rs) ++ ")"
    putStrLn "══════════════════════════════════════════"
    
    -- Generate the new game state for this deal
    let
      (gen1, gen2) = split gen
      initialGs = newGame dealerVal vul South gen1
      
    -- Run bidding phase
    putStrLn "\n═══════════════════════════════════════"
    putStrLn $ " BIDDING PHASE  (Dealer: " ++ show dealerVal ++ ")"
    putStrLn "═══════════════════════════════════════"
    
    biddingResult <- runBiddingLoop initialGs
    case biddingResult of
      Left _ -> putStrLn "\n  Thanks for playing!"
      Right gsAfterBidding ->
        if phase gsAfterBidding == Done
        then do
          putStrLn "\n  *** PASSED OUT — no contract ***"
          -- Rotate dealer and start next deal
          let
            rs' = rs { dealsPlayed = dealNum, currentDealer = nextPlayer dealerVal }
          rubberLoop rs' gen2
        else case (contract gsAfterBidding, declarer gsAfterBidding) of
          (Just contract', Just declarer') -> do
            -- Display final contract and bidding history
            displayBiddingHistory (bidHistory gsAfterBidding) (dealer gsAfterBidding)
            let
              doubled' = doubled gsAfterBidding
              dummy' = dummy gsAfterBidding
            
            putStrLn $ "\n  Contract: " ++ show contract' ++ " by " ++ show declarer' ++ (case doubled' of 1 -> " (Doubled)"; 2 -> " (Redoubled)"; _ -> "")
            putStrLn $ "  Dummy: " ++ maybe "None" show dummy'
            
            -- Display the table/hands
            displayBoard gsAfterBidding
            
            -- Run card play phase
            putStrLn "\n═══════════════════════════════════════"
            putStrLn " PLAYING PHASE"
            putStrLn "═══════════════════════════════════════"
            
            playingResult <- runPlayingLoop gsAfterBidding
            case playingResult of
              Left _ -> putStrLn "\n  Thanks for playing!"
              Right gsAfterPlaying -> do
                -- Scoring
                putStrLn "\n═══════════════════════════════════════"
                putStrLn " ALL TRICKS PLAYED"
                putStrLn $ "  N-S tricks won: " ++ show (tricksNs gsAfterPlaying) ++ "   E-W tricks won: " ++ show (tricksEw gsAfterPlaying)
                putStrLn "═══════════════════════════════════════"
                
                let
                  (rs', dealScore) =
                    scoreRubberDeal
                      (case contract' of SuitBid l _ -> l; _ -> 1)
                      (case contract' of SuitBid _ s -> s; _ -> NoTrump)
                      (if side declarer' == 0 then tricksNs gsAfterPlaying else tricksEw gsAfterPlaying)
                      declarer'
                      doubled'
                      rs
                      
                displayDealResult gsAfterPlaying dealScore
                let rs'' = rs' { dealsPlayed = dealNum, currentDealer = nextPlayer dealerVal }
                displayRubberScore rs''
                
                -- Recurse rubber loop
                rubberLoop rs'' gen2
          _ -> putStrLn "\n  Error: missing contract or declarer after bidding."

main :: IO ()
main = do
  displayWelcome
  gen <- getStdGen
  rubberLoop newRubberState gen
