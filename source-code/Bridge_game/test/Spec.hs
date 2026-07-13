module Main where

import Test.Hspec
import Bridge.Types
import Bridge.Cards
import Bridge.Bidding
import Bridge.Scoring

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "Cards" $ do
    it "makeDeck produces 52 cards" $
      length makeDeck `shouldBe` 52
    it "cardHcp returns correct values" $ do
      cardHcp (Card Spades Ace) `shouldBe` 4
      cardHcp (Card Hearts King) `shouldBe` 3
      cardHcp (Card Diamonds Queen) `shouldBe` 2
      cardHcp (Card Clubs Jack) `shouldBe` 1
      cardHcp (Card Spades R2) `shouldBe` 0
    it "handHcp sums HCP correctly" $ do
      let hand = [Card Spades Ace, Card Hearts King, Card Diamonds Queen, Card Clubs Jack]
      handHcp hand `shouldBe` 10
    it "sortHand sorts by suit then rank" $ do
      let hand = [Card Hearts R2, Card Spades Ace, Card Hearts King]
          sorted = sortHand hand
      head sorted `shouldBe` Card Spades Ace
    it "isBalanced identifies balanced hands" $ do
      let balanced = [Card Spades R2, Card Spades R3, Card Spades R4, Card Spades R5
                     ,Card Hearts R2, Card Hearts R3, Card Hearts R4
                     ,Card Diamonds R2, Card Diamonds R3, Card Diamonds R4
                     ,Card Clubs R2, Card Clubs R3, Card Clubs R4]
      isBalanced balanced `shouldBe` True
    it "suitLength counts cards of a suit" $ do
      let hand = [Card Spades Ace, Card Spades King, Card Hearts R2]
      suitLength Spades hand `shouldBe` 2
      suitLength Hearts hand `shouldBe` 1
      suitLength Clubs hand `shouldBe` 0
    it "handTotalPoints uses shortness points with trump fit" $ do
      let hand = [Card Spades Ace, Card Spades King, Card Hearts R2] -- void in diamonds and clubs
      handTotalPoints hand True `shouldSatisfy` (> handHcp hand)

  describe "Bidding" $ do
    it "biddingComplete detects all pass" $
      biddingComplete [(North, Pass), (East, Pass), (South, Pass), (West, Pass)] `shouldBe` True
    it "biddingComplete detects 3 passes after suit bid" $
      biddingComplete [(West, Pass), (South, Pass), (East, Pass), (North, SuitBid 1 (SuitStrain Hearts))] `shouldBe` True
    it "biddingComplete not complete with just 2 passes" $
      biddingComplete [(North, SuitBid 1 (SuitStrain Hearts)), (East, Pass), (South, Pass)] `shouldBe` False
    it "bidIndex gives correct values" $ do
      bidIndex (SuitBid 1 (SuitStrain Clubs)) `shouldBe` Just 0
      bidIndex (SuitBid 1 (SuitStrain Diamonds)) `shouldBe` Just 1
      bidIndex (SuitBid 1 NoTrump) `shouldBe` Just 4
      bidIndex (SuitBid 2 (SuitStrain Clubs)) `shouldBe` Just 5
      bidIndex Pass `shouldBe` Nothing
    it "bidHigherThan compares bids correctly" $ do
      bidHigherThan (SuitBid 2 (SuitStrain Clubs)) (SuitBid 1 NoTrump) `shouldBe` True
      bidHigherThan (SuitBid 1 (SuitStrain Hearts)) (SuitBid 1 (SuitStrain Spades)) `shouldBe` False
    it "aiOpeningBid suggests 1NT with 15-17 balanced" $ do
      let hand = [Card Spades Ace, Card Spades King, Card Spades R3, Card Spades R4
                 ,Card Hearts Queen, Card Hearts Jack, Card Hearts R2
                 ,Card Diamonds King, Card Diamonds R2, Card Diamonds R3
                 ,Card Clubs Queen, Card Clubs R2, Card Clubs R3]
      case aiOpeningBid hand of
        Just (SuitBid 1 NoTrump) -> pure ()
        other -> expectationFailure $ "Expected 1NT, got: " ++ show other

  describe "Scoring" $ do
    it "trickValue for clubs/diamonds is 20" $ do
      trickValue (SuitStrain Clubs) 0 `shouldBe` 20
      trickValue (SuitStrain Diamonds) 0 `shouldBe` 20
    it "trickValue for hearts/spades/NT is 30" $ do
      trickValue (SuitStrain Hearts) 0 `shouldBe` 30
      trickValue (SuitStrain Spades) 0 `shouldBe` 30
      trickValue NoTrump 0 `shouldBe` 30
    it "contractTrickScore includes NT bonus" $ do
      contractTrickScore 1 NoTrump 0 `shouldBe` 40  -- 30 + 10
      contractTrickScore 1 (SuitStrain Hearts) 0 `shouldBe` 30
    it "newRubberState starts with all zeros" $ do
      let rs = newRubberState
      nsBelow rs `shouldBe` 0
      ewBelow rs `shouldBe` 0
      nsGames rs `shouldBe` 0
      ewGames rs `shouldBe` 0
