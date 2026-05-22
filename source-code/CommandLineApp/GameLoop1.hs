module Main  where

import Data.Time.Clock.POSIX
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
  pTime <- round `fmap` getPOSIXTime
  let gameState = GameState ((pTime `mod` 4) + 1) 1
  print "Guess a number between 1 and 4"
  _ <- gameLoop gameState
  return ()
