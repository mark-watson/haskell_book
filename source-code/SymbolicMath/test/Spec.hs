module Main where

import Control.Exception (evaluate)
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
  describe "Variable" $ do
    it "variableEq matches identical name and domain" $
      variableEq (makeVariable "x" Real) (makeVariable "x" Real) `shouldBe` True
    it "variableEq rejects different names" $
      variableEq (makeVariable "x" Real) (makeVariable "y" Real) `shouldBe` False
    it "variableEq rejects different domains" $
      variableEq (makeVariable "x" Real) (makeVariable "x" Integer_) `shouldBe` False

  describe "Constant" $ do
    it "constantNumericValue resolves pi" $
      constantNumericValue (makeConstant "pi" SymbolicPi) `shouldBe` pi
    it "constantNumericValue resolves e" $
      constantNumericValue (makeConstant "e" SymbolicE) `shouldBe` exp 1
    it "constantNumericValue resolves exact rational" $
      constantNumericValue (makeConstant "g" (ExactValue 9.80665)) `shouldBe` 9.80665
    it "makeConstant preserves name" $
      constName (makeConstant "pi" SymbolicPi) `shouldBe` "pi"

  describe "Term" $ do
    it "termEq matches identical terms" $
      termEq (makeTerm 3 x 2) (makeTerm 3 x 2) `shouldBe` True
    it "termEq rejects different coefficients" $
      termEq (makeTerm 3 x 2) (makeTerm 4 x 2) `shouldBe` False
    it "termToString renders -1x" $
      termToString (makeTerm (-1) x 1) `shouldBe` "-1x"
    it "termScale by zero gives a zero term" $
      termScale 0 (makeTerm 3 x 2) `shouldBe` makeTerm 0 x 2
    it "makeTerm rejects negative exponents" $
      evaluate (makeTerm 1 x (-1)) `shouldThrow` anyException
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
    it "polynomialScale scales every coefficient" $ do
      let p = makePolynomial x [makeTerm 3 x 2, makeTerm (-1) x 1] Real
      polynomialToString (polynomialScale 2 p) `shouldBe` "6x^2 + -2x"
    it "polynomialNormalize drops zero terms" $ do
      let p = makePolynomial x [makeTerm 3 x 2, makeTerm 0 x 1, makeTerm 5 x 0] Real
      polynomialToString p `shouldBe` "3x^2 + 5"
    it "polynomialLeadingTerm returns highest-degree term" $ do
      let p = makePolynomial x [makeTerm 3 x 2, makeTerm 5 x 0] Real
      polynomialLeadingTerm p `shouldBe` Just (makeTerm 3 x 2)
    it "polynomialLeadingTerm is Nothing for zero polynomial" $
      polynomialLeadingTerm (zeroPolynomial x) `shouldBe` Nothing
    it "polynomialEvaluate with Rational keeps exactness" $ do
      let p = makePolynomial x [makeTerm 1 x 1, makeTerm 1 x 0] Real
      polynomialEvaluate p (1/2 :: Rational) `shouldBe` (3/2 :: Rational)
    it "constantPolynomial renders its value" $
      polynomialToString (constantPolynomial x 7) `shouldBe` "7"

  describe "SymIntegral" $ do
    it "integralDefiniteP is False when indefinite" $ do
      let p = makePolynomial x [makeTerm 3 x 2] Real
          i = makeIntegral p x Nothing Nothing
      integralDefiniteP i `shouldBe` False
    it "integralDefiniteP is True when definite" $ do
      let p = makePolynomial x [makeTerm 3 x 2] Real
          i = makeIntegral p x (Just (Left 0)) (Just (Left 1))
      integralDefiniteP i `shouldBe` True
    it "integralToString renders a constant bound" $ do
      let p = makePolynomial x [makeTerm 3 x 2] Real
          piConst = makeConstant "pi" SymbolicPi
          i = makeIntegral p x (Just (Left 0)) (Just (Right piConst))
      integralToString i `shouldBe` "∫[0,pi](3x^2) dx"
    it "makeIntegral rejects a single bound" $
      evaluate (makeIntegral (zeroPolynomial x) x (Just (Left 0)) Nothing)
        `shouldThrow` anyException

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
    it "differentiateN zero returns original polynomial" $ do
      let p = makePolynomial x [makeTerm 1 x 3] Real
      differentiateN p 0 `shouldBe` p
    it "differentiateN of high order returns zero polynomial" $ do
      let p = makePolynomial x [makeTerm 3 x 2] Real
      polynomialDegree (differentiateN p 5) `shouldBe` (-1)
    it "differentiateN rejects negative n" $
      evaluate (differentiateN (zeroPolynomial x) (-1)) `shouldThrow` anyException
    it "gradientAt computes numerical gradient" $ do
      let p = makePolynomial x [makeTerm 3 x 2, makeTerm (-1) x 1, makeTerm 5 x 0] Real
      gradientAt p 2 `shouldBe` 11.0  -- p' = 6x - 1, at x=2: 11
    it "criticalPointP identifies critical points" $ do
      let p = makePolynomial x [makeTerm 3 x 2, makeTerm (-1) x 1] Real
      criticalPointP p (1/6) 1e-9 `shouldBe` True
    it "criticalPointP returns False away from critical point" $ do
      let p = makePolynomial x [makeTerm 3 x 2, makeTerm (-1) x 1] Real
      criticalPointP p 0 1e-9 `shouldBe` False
    it "gradientAt is zero at a critical point" $ do
      let p = makePolynomial x [makeTerm 3 x 2, makeTerm (-1) x 1] Real
      abs (gradientAt p (1/6)) `shouldSatisfy` (< 1e-9)

  describe "Integration" $ do
    it "integrateTerm applies reverse power rule" $ do
      let t = integrateTerm (makeTerm 3 x 2)
      termCoefficient t `shouldBe` 1  -- 3/(2+1) = 1
      termExponent t `shouldBe` 3
    it "integrateTerm yields fractional coefficient" $ do
      let t = integrateTerm (makeTerm 1 x 1)
      termCoefficient t `shouldBe` (1/2 :: Rational)
      termExponent t `shouldBe` 2
    it "integrateTerm of constant gives linear term" $ do
      let t = integrateTerm (makeTerm 5 x 0)
      termCoefficient t `shouldBe` 5
      termExponent t `shouldBe` 1
    it "integrate of zero polynomial is zero" $
      polynomialDegree (integrate (zeroPolynomial x)) `shouldBe` (-1)
    it "integrate computes antiderivative" $ do
      let p = makePolynomial x [makeTerm 3 x 2] Real
      polynomialToString (integrate p) `shouldBe` "1x^3"
    it "integrate raises degree by one" $ do
      let p = makePolynomial x [makeTerm 3 x 2] Real
      polynomialDegree (integrate p) `shouldBe` 3
    it "integrateN twice gives double antiderivative" $ do
      let p = makePolynomial x [makeTerm 6 x 1] Real
      polynomialToString (integrateN p 2) `shouldBe` "1x^3"
    it "integrateN zero returns original polynomial" $ do
      let p = makePolynomial x [makeTerm 6 x 1] Real
      integrateN p 0 `shouldBe` p
    it "integrateN rejects negative n" $
      evaluate (integrateN (zeroPolynomial x) (-1)) `shouldThrow` anyException
    it "evaluateDefinite computes a definite integral" $ do
      let p = makePolynomial x [makeTerm 6 x 1, makeTerm 2 x 0] Real
      -- ∫(6x+2)dx = 3x^2+2x, from 0 to 1: (3+2) - 0 = 5
      abs (evaluateDefinite p (Left 0) (Left 1) - 5.0) `shouldSatisfy` (< 1e-9)
    it "evaluateDefinite handles a constant upper bound" $ do
      let p = makePolynomial x [makeTerm 1 x 1] Real
          piConst = makeConstant "pi" SymbolicPi
      -- ∫x dx = x^2/2, from 0 to pi: pi^2/2
      abs (evaluateDefinite p (Left 0) (Right piConst) - (pi^2 / 2 :: Double)) `shouldSatisfy` (< 1e-9)
    it "makeIndefiniteIntegral builds a shell" $ do
      let p = makePolynomial x [makeTerm 3 x 2] Real
      integralToString (makeIndefiniteIntegral p) `shouldBe` "∫(3x^2) dx"
    it "makeDefiniteIntegral builds a definite shell" $ do
      let p = makePolynomial x [makeTerm 3 x 2] Real
      integralToString (makeDefiniteIntegral p (Left 0) (Left 1)) `shouldBe` "∫[0,1](3x^2) dx"
