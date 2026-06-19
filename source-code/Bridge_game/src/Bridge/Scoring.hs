{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}

module Bridge.Scoring where

import Bridge.Types
import GHC.Generics (Generic)
import Data.Aeson (ToJSON, FromJSON)

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
  } deriving (Show, Eq, Generic, ToJSON, FromJSON)

newRubberState :: RubberState
newRubberState = RubberState
  { nsBelow = 0
  , ewBelow = 0
  , nsAbove = 0
  , ewAbove = 0
  , nsGames = 0
  , ewGames = 0
  , nsVulnerable = False
  , ewVulnerable = False
  , currentDealer = North
  , dealsPlayed = 0
  }

trickValue :: Strain -> Int -> Int
trickValue strain doubled =
  let
    base = case strain of
             SuitStrain Clubs -> 20
             SuitStrain Diamonds -> 20
             _ -> 30
    mult = case doubled of
             1 -> 2
             2 -> 4
             _ -> 1
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
         
         insultBonus = case doubled of
           1 -> 50
           2 -> 100
           _ -> 0
           
         slamBonus = if level == 6 then (if vul then 750 else 500)
                     else if level == 7 then (if vul then 1500 else 1000)
                     else 0
                     
         aboveScore = overtrickBonus + insultBonus + slamBonus
         
         (rs1, newBelow) =
           if nsSide
           then
             let nb = nsBelow rs + belowScore
             in (rs { nsBelow = nb, nsAbove = nsAbove rs + aboveScore }, nb)
           else
             let nb = ewBelow rs + belowScore
             in (rs { ewBelow = nb, ewAbove = ewAbove rs + aboveScore }, nb)
             
         -- Check if this side won the game (below >= 100)
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
               then rs { ewAbove = ewAbove rs + penalty }
               else rs { nsAbove = nsAbove rs + penalty }
       in (rs1, -penalty)

rubberComplete :: RubberState -> Bool
rubberComplete rs = nsGames rs >= 2 || ewGames rs >= 2

-- Calculate the rubber bonus and winner side
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
