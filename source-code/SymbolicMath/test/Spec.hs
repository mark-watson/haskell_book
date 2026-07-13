module Main where

import Test.Hspec
import SymbolicMath.Types
import SymbolicMath.Differentiation
import SymbolicMath.Integration

main :: IO ()
main = hspec spec

x :: Variable
x = makeVariable "x" Real

spec :: Spec
spec = do
  describe "Term" $ do
    it "termToString renders a monomial" $
      termToString (makeTerm 3 x 2) `shouldBe` "3x^2"
    it "termToString renders constant term" $
      termToString (makeTerm 5 x 0) `shouldBe` "5"
    it "termNegate negates the coefficient" $
      termNegate (makeTerm 3 x 2) `shouldBe` makeTerm (-3) x 2
    it "termScale scales the coefficient" $
      termScale 2 (makeTerm 3 x 2) `shouldBe` makeTerm 6 x 2

  describe "Polynomial" $ do
    it "polynomialDegree returns highest exponent" $ do
      let p = makePolynomial x [makeTerm 3 x 2, makeTerm (-1) x 1, makeTerm 5 x 0] Real
      polynomialDegree p `shouldBe` 2
    it "polynomialDegree returns -1 for zero polynomial" $
      polynomialDegree (zeroPolynomial x) `shouldBe` (-1)
    it "polynomialAdd combines like terms" $ do
      let p = makePolynomial x [makeTerm 1 x 1, makeTerm 2 x 0] Real
          q = makePolynomial x [makeTerm 3 x 1, makeTerm 4 x 0] Real
      polynomialToString (polynomialAdd p q) `shouldBe` "4x + 6"
    it "polynomialSubtract subtracts correctly" $ do
      let p = makePolynomial x [makeTerm 5 x 1] Real
          q = makePolynomial x [makeTerm 3 x 1] Real
      polynomialToString (polynomialSubtract p q) `shouldBe` "2x"
    it "polynomialEvaluate computes value" $ do
      let p = makePolynomial x [makeTerm 3 x 2, makeTerm (-1) x 1, makeTerm 5 x 0] Real
      polynomialEvaluate p (2 :: Double) `shouldBe` 15.0  -- 3*4 - 2 + 5 = 15
    it "polynomialNegate negates all terms" $ do
      let p = makePolynomial x [makeTerm 3 x 2, makeTerm (-1) x 1] Real
      polynomialToString (polynomialNegate p) `shouldBe` "-3x^2 + 1x"
    it "zeroPolynomial renders as '0'" $
      polynomialToString (zeroPolynomial x) `shouldBe` "0"
    it "identityPolynomial is just x" $
      polynomialToString (identityPolynomial x) `shouldBe` "1x"

  describe "Differentiation" $ do
    it "differentiateTerm applies power rule" $
      differentiateTerm (makeTerm 3 x 2) `shouldBe` Just (makeTerm 6 x 1)
    it "differentiateTerm of constant returns Nothing" $
      differentiateTerm (makeTerm 5 x 0) `shouldBe` Nothing
    it "differentiate computes derivative of polynomial" $ do
      let p = makePolynomial x [makeTerm 3 x 2, makeTerm (-1) x 1, makeTerm 5 x 0] Real
      polynomialToString (differentiate p) `shouldBe` "6x + -1"
    it "differentiate of constant returns zero polynomial" $
      polynomialDegree (differentiate (constantPolynomial x 7)) `shouldBe` (-1)
    it "differentiateN twice gives second derivative" $ do
      let p = makePolynomial x [makeTerm 1 x 3] Real
      polynomialToString (differentiateN p 2) `shouldBe` "6x"
    it "gradientAt computes numerical gradient" $ do
      let p = makePolynomial x [makeTerm 3 x 2, makeTerm (-1) x 1, makeTerm 5 x 0] Real
      gradientAt p 2 `shouldBe` 11.0  -- p' = 6x - 1, at x=2: 11
    it "criticalPointP identifies critical points" $ do
      let p = makePolynomial x [makeTerm 3 x 2, makeTerm (-1) x 1] Real
      criticalPointP p (1/6) 1e-9 `shouldBe` True

  describe "Integration" $ do
    it "integrateTerm applies reverse power rule" $ do
      let t = integrateTerm (makeTerm 3 x 2)
      termCoefficient t `shouldBe` 1  -- 3/(2+1) = 1
      termExponent t `shouldBe` 3
    it "integrate computes antiderivative" $ do
      let p = makePolynomial x [makeTerm 3 x 2] Real
      polynomialToString (integrate p) `shouldBe` "1x^3"
    it "integrateN twice gives double antiderivative" $ do
      let p = makePolynomial x [makeTerm 6 x 1] Real
      polynomialToString (integrateN p 2) `shouldBe` "1x^3"
    it "evaluateDefinite computes a definite integral" $ do
      let p = makePolynomial x [makeTerm 6 x 1, makeTerm 2 x 0] Real
      -- ∫(6x+2)dx = 3x^2+2x, from 0 to 1: (3+2) - 0 = 5
      abs (evaluateDefinite p (Left 0) (Left 1) - 5.0) `shouldSatisfy` (< 1e-9)
