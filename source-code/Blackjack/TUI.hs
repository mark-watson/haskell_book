-- TUI.hs – Brick-based terminal UI for Blackjack
-- Panels: Your Hand | Dealer | Other Players | Game Info
-- Keys:   h=hit  s=stay  1/2/3=bet(10/20/30)  n=new hand  q=quit
module TUI (runTUI) where

import Brick
import Brick.Widgets.Border
import Brick.Widgets.Border.Style
import Brick.Widgets.Center
import qualified Brick.Widgets.Dialog as D
import qualified Graphics.Vty as V
import qualified Graphics.Vty.CrossPlatform as VCP
import Control.Monad (void)
import Control.Monad.IO.Class (liftIO)
import Data.List (intercalate)

import Card
import Table
import RandomizedList

-- ---------------------------------------------------------------------------
-- Application state
-- ---------------------------------------------------------------------------
data Phase = Playing | HandOver String | GameOver
  deriving (Eq, Show)

data GameState = GameState
  { gsTable         :: Table
  , gsNumPlayers    :: Int
  , gsPhase         :: Phase
  , gsMessage       :: String   -- transient status line
  }

data Name = ViewPort deriving (Eq, Ord, Show)

-- ---------------------------------------------------------------------------
-- Card rendering helpers
-- ---------------------------------------------------------------------------
suitChar :: Suit -> String
suitChar Hearts   = "♥"
suitChar Diamonds = "♦"
suitChar Clubs    = "♣"
suitChar Spades   = "♠"

rankChar :: Rank -> String
rankChar Two   = "2"
rankChar Three = "3"
rankChar Four  = "4"
rankChar Five  = "5"
rankChar Six   = "6"
rankChar Seven = "7"
rankChar Eight = "8"
rankChar Nine  = "9"
rankChar Ten   = "10"
rankChar Jack  = "J"
rankChar Queen = "Q"
rankChar King  = "K"
rankChar Ace   = "A"

isRed :: Suit -> Bool
isRed Hearts   = True
isRed Diamonds = True
isRed _        = False

-- Render a single card as a coloured Widget
cardWidget :: Card -> Widget Name
cardWidget c =
  let s  = suit c
      r  = rank c
      lbl = rankChar r ++ suitChar s
      attr = if isRed s then redCard else whiteCard
  in  withAttr attr (str (" " ++ lbl ++ " "))

-- Render a hand (list of cards) with a total score
handWidget :: [Card] -> Widget Name
handWidget [] = withAttr dimAttr (str "(no cards)")
handWidget cs =
  let cards  = hBox (map cardWidget cs)
      total  = sum (map cardValue cs)
      bust   = total > 21
      scoreStr = " = " ++ show total ++ if bust then " BUST" else ""
      scoreAttr = if bust then bustAttr else scoreAttr'
  in  cards <+> withAttr scoreAttr (str scoreStr)

-- ---------------------------------------------------------------------------
-- Attribute names
-- ---------------------------------------------------------------------------
redCard, whiteCard, dimAttr, bustAttr, scoreAttr', titleAttr, helpAttr,
  panelTitle, overlayAttr, winAttr, loseAttr :: AttrName
redCard    = attrName "redCard"
whiteCard  = attrName "whiteCard"
dimAttr    = attrName "dim"
bustAttr   = attrName "bust"
scoreAttr' = attrName "score"
titleAttr  = attrName "title"
helpAttr   = attrName "help"
panelTitle = attrName "panelTitle"
overlayAttr= attrName "overlay"
winAttr    = attrName "win"
loseAttr   = attrName "lose"

theMap :: AttrMap
theMap = attrMap V.defAttr
  [ (redCard,     V.withForeColor (V.withStyle V.defAttr V.bold) V.red)
  , (whiteCard,   V.withForeColor (V.withStyle V.defAttr V.bold) V.white)
  , (dimAttr,     V.withForeColor V.defAttr V.brightBlack)
  , (bustAttr,    V.withForeColor (V.withStyle V.defAttr V.bold) V.red)
  , (scoreAttr',  V.withForeColor V.defAttr V.brightCyan)
  , (titleAttr,   V.withForeColor (V.withStyle V.defAttr V.bold) V.yellow)
  , (helpAttr,    V.withForeColor V.defAttr V.brightBlack)
  , (panelTitle,  V.withForeColor (V.withStyle V.defAttr V.bold) V.green)
  , (overlayAttr, V.withBackColor V.defAttr V.black)
  , (winAttr,     V.withForeColor (V.withStyle V.defAttr V.bold) V.green)
  , (loseAttr,    V.withForeColor (V.withStyle V.defAttr V.bold) V.red)
  ]

-- ---------------------------------------------------------------------------
-- UI drawing
-- ---------------------------------------------------------------------------
drawUI :: GameState -> [Widget Name]
drawUI gs = case gsPhase gs of
  HandOver msg -> [overlay msg gs, mainScreen gs]
  _            -> [mainScreen gs]

mainScreen :: GameState -> Widget Name
mainScreen gs =
  let t   = gsTable gs
      dc  = _dealtCards t
      cs  = _chipStacks t

      -- hands (guard against empty dealt-cards list)
      userHand    = if length dc > 0 then dc !! 0 else []
      dealerHand  = if length dc > 1 then dc !! 1 else []
      otherHands  = if length dc > 2 then drop 2 dc else []
      otherChips  = if length cs > 1 then tail cs else []

      bet       = _currentPlayerBet t
      playerChips = if null cs then 0 else head cs
      passes    = _userPasses t

      -- Top title bar
      titleBar = withAttr titleAttr $
                 hCenter (str "♠ ♥  B L A C K J A C K  ♦ ♣")

      -- Your hand panel
      yourPanel =
        withBorderStyle unicodeRounded $
        borderWithLabel (withAttr panelTitle (str " Your Hand ")) $
        padAll 1 $
        vBox [ handWidget userHand
             , str " "
             , withAttr helpAttr (str ("Bet: " ++ show bet ++
                                       "  Chips: " ++ show playerChips ++
                                       (if passes then "  [PASSED]" else "")))
             ]

      -- Dealer panel
      dealerPanel =
        withBorderStyle unicodeRounded $
        borderWithLabel (withAttr panelTitle (str " Dealer ")) $
        padAll 1 $
        handWidget dealerHand

      -- Other players panel
      otherInfo =
        if null otherHands
          then withAttr dimAttr (str "(none)")
          else vBox $ zipWith3 renderOther [1..] otherHands otherChips

      renderOther :: Int -> [Card] -> Int -> Widget Name
      renderOther i hand chips =
        vBox [ withAttr helpAttr (str ("Player " ++ show i ++
                                       "  (chips: " ++ show chips ++ ")"))
             , handWidget hand
             , str " "
             ]

      otherPanel =
        withBorderStyle unicodeRounded $
        borderWithLabel (withAttr panelTitle (str " Other Players ")) $
        padAll 1 otherInfo

      -- Game info / log panel
      infoPanel =
        withBorderStyle unicodeRounded $
        borderWithLabel (withAttr panelTitle (str " Game Info ")) $
        padAll 1 $
        vBox [ withAttr helpAttr (str ("Phase  : " ++ phaseStr (gsPhase gs)))
             , withAttr helpAttr (str ("Message: " ++ gsMessage gs))
             ]

      phaseStr Playing        = "Playing"
      phaseStr (HandOver _)   = "Hand Over"
      phaseStr GameOver       = "Game Over"

      -- Two-column top layout: (yourPanel | dealerPanel) / (otherPanel | infoPanel)
      topRow    = hBox [hLimitPercent 50 yourPanel, dealerPanel]
      bottomRow = hBox [hLimitPercent 50 otherPanel, infoPanel]

      -- Help bar at the bottom
      helpBar =
        withAttr helpAttr $
        hCenter $
        str " h:Hit  s:Stay  1:Bet10  2:Bet20  3:Bet30  n:NewHand  q:Quit "

  in  vBox [ titleBar
           , str " "
           , topRow
           , bottomRow
           , hBorder
           , helpBar
           ]

overlay :: String -> GameState -> Widget Name
overlay msg gs =
  centerLayer $
  withBorderStyle unicodeRounded $
  borderWithLabel (withAttr titleAttr (str " Hand Result ")) $
  padAll 2 $
  vBox [ withAttr overlayAttr (hCenter (str msg))
       , str " "
       , hCenter (withAttr helpAttr (str "Press n for a new hand, q to quit"))
       ]

-- ---------------------------------------------------------------------------
-- Event handling
-- ---------------------------------------------------------------------------
handleEvent :: BrickEvent Name () -> EventM Name GameState ()
handleEvent (VtyEvent (V.EvKey (V.KChar 'q') _)) = halt
handleEvent (VtyEvent (V.EvKey (V.KChar 'Q') _)) = halt

handleEvent (VtyEvent (V.EvKey (V.KChar 'n') _)) = do
  gs <- get
  case gsPhase gs of
    HandOver _ -> startNewHand gs
    _          -> return ()

handleEvent (VtyEvent (V.EvKey (V.KChar 'h') _)) = do
  gs <- get
  case gsPhase gs of
    Playing -> doHit gs
    _       -> return ()

handleEvent (VtyEvent (V.EvKey (V.KChar 's') _)) = do
  gs <- get
  case gsPhase gs of
    Playing -> doStay gs
    _       -> return ()

handleEvent (VtyEvent (V.EvKey (V.KChar '1') _)) = setBet 10
handleEvent (VtyEvent (V.EvKey (V.KChar '2') _)) = setBet 20
handleEvent (VtyEvent (V.EvKey (V.KChar '3') _)) = setBet 30

handleEvent _ = return ()

-- ---------------------------------------------------------------------------
-- Game actions
-- ---------------------------------------------------------------------------
freshDeck :: IO [Card]
freshDeck = randomizedList orderedCardDeck

doHit :: GameState -> EventM Name GameState ()
doHit gs = do
  let t       = gsTable gs
      n       = gsNumPlayers gs
      t'      = dealCards t [0 .. n]
  let t'' = t'
  let newGs = gs { gsTable = t'', gsMessage = "You hit." }
  put newGs
  checkHandOver newGs

doStay :: GameState -> EventM Name GameState ()
doStay gs = do
  let t   = gsTable gs
      t'  = setPlayerPasses t
  let newGs = gs { gsTable = t', gsMessage = "You stayed." }
  checkHandOver newGs

setBet :: Int -> EventM Name GameState ()
setBet n = do
  gs <- get
  case gsPhase gs of
    Playing -> do
      let t' = setPlayerBet n (gsTable gs)
      put gs { gsTable = t', gsMessage = "Bet set to " ++ show n }
    _ -> return ()

startNewHand :: GameState -> EventM Name GameState ()
startNewHand gs = do
  deck <- liftIO freshDeck
  let t'   = initialDeal deck (scoreHands (gsTable gs)) (gsNumPlayers gs)
  put gs { gsTable = t', gsPhase = Playing, gsMessage = "New hand dealt." }

checkHandOver :: GameState -> EventM Name GameState ()
checkHandOver gs = do
  let t = gsTable gs
  if handOver t
    then do
      let msg = buildResultMsg t
      put gs { gsPhase = HandOver msg }
    else put gs

buildResultMsg :: Table -> String
buildResultMsg t =
  let cs          = _chipStacks t
      playerScore = scoreForPlayer t 0
      dealerScore = scoreForPlayer t 1
      result
        | playerScore > 21  = "You busted! Dealer wins."
        | dealerScore > 21  = "Dealer busted! You win!"
        | playerScore > dealerScore = "You win! 🎉"
        | playerScore < dealerScore = "Dealer wins."
        | otherwise         = "Push (tie)."
      chipInfo = "Your chips: " ++ show (head cs)
  in  result ++ "  " ++ chipInfo

scoreForPlayer :: Table -> Int -> Int
scoreForPlayer t i =
  let dc = _dealtCards t
  in  if i < length dc
        then sum (map cardValue (dc !! i))
        else 0

-- ---------------------------------------------------------------------------
-- Application entry point
-- ---------------------------------------------------------------------------
theApp :: App GameState () Name
theApp = App
  { appDraw         = drawUI
  , appChooseCursor = neverShowCursor
  , appHandleEvent  = handleEvent
  , appStartEvent   = return ()
  , appAttrMap      = const theMap
  }

runTUI :: Table -> Int -> IO ()
runTUI initialTable numPlayers = do
  let initGs = GameState
        { gsTable      = initialTable
        , gsNumPlayers = numPlayers
        , gsPhase      = Playing
        , gsMessage    = "Welcome! Use h to hit, s to stay."
        }
  cfg <- VCP.mkVty V.defaultConfig
  void $ customMain cfg (return cfg) Nothing theApp initGs
