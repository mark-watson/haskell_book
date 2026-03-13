-- Main.hs – entry point; collects player count then hands off to the TUI
module Main where

import Card           -- pure code (card types + values)
import Table          -- pure code (game state + rules)
import RandomizedList -- impure code (random shuffle)
import TUI            -- Brick-based terminal UI

randomDeck :: IO [Card]
randomDeck = randomizedList orderedCardDeck

main :: IO ()
main = do
  putStrLn "♠ ♥  Welcome to Blackjack!  ♦ ♣"
  putStrLn "Besides yourself, how many other players do you want at the table? (1-4)"
  s <- getLine
  let n = (read s :: Int) + 1  -- 0=user, 1=dealer, 2+= other players
  cardDeck <- randomDeck
  let aTable = initialDeal cardDeck (createNewTable n) n
  runTUI aTable n
