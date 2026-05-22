module Main where

import System.Random
import Text.Read (readMaybe)

data GameState = GameState { numberToGuess::Integer, numTries::Integer}
                   deriving (Show)

gameLoop :: GameState -> IO GameState
gameLoop gs = do
  putStrLn "Enter a number:"
  s <- getLine
  case readMaybe s :: Maybe Integer of
    Nothing -> do
      putStrLn "Invalid input, please enter a number."
      gameLoop gs
    Just num ->
      if num == numberToGuess gs then
        return gs
      else gameLoop $ GameState (numberToGuess gs) ((numTries gs) + 1)

main :: IO ()
main = do
  pTime <- randomRIO(1,4)
  let gameState = GameState pTime 1
  print "Guess a number between 1 and 4"
  _ <- gameLoop gameState
  return ()
