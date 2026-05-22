import Test.Hspec
import Control.Exception (evaluate)

import MyColors

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  describe "head" $ do
    it "returns the first element of a list" $ do
      head [1,2,3,4] `shouldBe` 1
      -- NOTE: This assertion is intentionally wrong to demonstrate
      -- what test framework failure output looks like.
      head ["the", "dog", "ran"] `shouldBe` "the"
    it "throws an exception on empty list" $ do
      evaluate (head ([] :: [Int])) `shouldThrow` anyException
  describe "MyColors tests" $ do
    it "test custom 'compare' function descending test" $ do
      MyColors.Green < MyColors.Red `shouldBe` True
    it "test custom 'compare' function ascending test" $ do
      Red > Silver `shouldBe` False