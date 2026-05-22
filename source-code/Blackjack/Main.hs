-- Main.hs – entry point; collects player count then hands off to the TUI
module Main where

import Card           -- pure code (card types + values)
import Table          -- pure code (game state + rules)
import RandomizedList -- impure code (random shuffle)
import TUI            -- Brick-based terminal UI
import Text.Read (readMaybe)

randomDeck :: IO [Card]
randomDeck = randomizedList orderedCardDeck

-- | Prompt for the number of other players, validating input.
getPlayerCount :: IO Int
getPlayerCount = do
  putStrLn "Besides yourself, how many other players do you want at the table? (1-4)"
  s <- getLine
  case readMaybe s :: Maybe Int of
    Just n | n >= 1 && n <= 4 -> return (n + 1)  -- 0=user, 1=dealer, 2+= other players
    _ -> do
      putStrLn "Invalid input. Please enter a number between 1 and 4."
      getPlayerCount

main :: IO ()
main = do
  putStrLn "♠ ♥  Welcome to Blackjack!  ♦ ♣"
  n <- getPlayerCount
  cardDeck <- randomDeck
  let aTable = initialDeal cardDeck (createNewTable n) n
  runTUI aTable n
