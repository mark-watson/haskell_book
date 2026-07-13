module Main where

import Test.Hspec
import BridgeWebKit.Parsing
import Bridge.Types
import qualified Data.Aeson as Aeson
import qualified Data.ByteString.Lazy.Char8 as LBS

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "trim" $ do
    it "removes leading and trailing spaces" $ do
      trim "  hello  " `shouldBe` "hello"
    it "preserves internal spaces" $ do
      trim "  hello world  " `shouldBe` "hello world"
    it "handles empty string" $ do
      trim "" `shouldBe` ""

  describe "parseStrain" $ do
    it "parses clubs short form" $
      parseStrain "C" `shouldBe` Just (SuitStrain Clubs)
    it "parses clubs long form" $
      parseStrain "CLUBS" `shouldBe` Just (SuitStrain Clubs)
    it "parses diamonds" $
      parseStrain "D" `shouldBe` Just (SuitStrain Diamonds)
    it "parses hearts" $
      parseStrain "H" `shouldBe` Just (SuitStrain Hearts)
    it "parses spades" $
      parseStrain "S" `shouldBe` Just (SuitStrain Spades)
    it "parses NT" $
      parseStrain "NT" `shouldBe` Just NoTrump
    it "parses NOTRUMP" $
      parseStrain "NOTRUMP" `shouldBe` Just NoTrump
    it "returns Nothing for invalid strain" $
      parseStrain "XYZ" `shouldBe` Nothing

  describe "parseBidInput" $ do
    it "parses Pass" $
      parseBidInput "PASS" `shouldBe` Just Pass
    it "parses short Pass" $
      parseBidInput "P" `shouldBe` Just Pass
    it "parses Double" $
      parseBidInput "X" `shouldBe` Just DoubleBid
    it "parses Redouble" $
      parseBidInput "XX" `shouldBe` Just RedoubleBid
    it "parses 1NT" $
      parseBidInput "1NT" `shouldBe` Just (SuitBid 1 NoTrump)
    it "parses 2S" $
      parseBidInput "2S" `shouldBe` Just (SuitBid 2 (SuitStrain Spades))
    it "parses 4H" $
      parseBidInput "4H" `shouldBe` Just (SuitBid 4 (SuitStrain Hearts))
    it "returns Nothing for invalid bid" $
      parseBidInput "8H" `shouldBe` Nothing
    it "handles trailing spaces" $
      parseBidInput " 1NT  " `shouldBe` Just (SuitBid 1 NoTrump)

  describe "PlayedCard JSON" $ do
    it "encodes pcPlayer field" $ do
      let json = LBS.unpack (Aeson.encode (PlayedCard "North" "AS"))
      json `shouldContain` "\"pcPlayer\":\"North\""
    it "encodes pcCard field" $ do
      let json = LBS.unpack (Aeson.encode (PlayedCard "North" "AS"))
      json `shouldContain` "\"pcCard\":\"AS\""

  describe "BidEntry JSON" $ do
    it "encodes bePlayer field" $ do
      let json = LBS.unpack (Aeson.encode (BidEntry "South" "1NT"))
      json `shouldContain` "\"bePlayer\":\"South\""
    it "encodes beBid field" $ do
      let json = LBS.unpack (Aeson.encode (BidEntry "South" "1NT"))
      json `shouldContain` "\"beBid\":\"1NT\""

  describe "HandList JSON" $ do
    it "encodes all four hand fields" $ do
      let json = LBS.unpack (Aeson.encode (HandList [] [] [] []))
      json `shouldContain` "\"hlNorth\":[]"
      json `shouldContain` "\"hlEast\":[]"
      json `shouldContain` "\"hlSouth\":[]"
      json `shouldContain` "\"hlWest\":[]"
