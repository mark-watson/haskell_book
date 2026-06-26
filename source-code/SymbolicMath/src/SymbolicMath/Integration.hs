module SymbolicMath.Integration
  ( -- * Core integration
    integrateTerm
  , integrate

    -- * Definite integral evaluation
  , evaluateDefinite

    -- * Higher-order / iterated integrals
  , integrateN

    -- * SymIntegral shell helpers
  , makeIndefiniteIntegral
  , makeDefiniteIntegral

    -- * Smoke test
  , runSmokeTest
  ) where

import SymbolicMath.Types hiding (runSmokeTest)

-- | Apply the reverse power rule to a single monomial.
--
-- @∫ c · x^n dx = (c / (n+1)) · x^(n+1)@
--
-- The constant of integration (+C) is handled at the polynomial level
-- by the caller. Returns a new 'Term'.
integrateTerm :: Term -> Term
integrateTerm (Term c v n) =
  let newExp  = n + 1
      newCoef = c / fromIntegral newExp
  in Term newCoef v newExp

-- | Return the antiderivative of a polynomial (without the constant of
-- integration +C). Applies the reverse power rule to each term and the
-- sum rule across terms.
--
-- Returns a new 'Polynomial' of degree @degree(p) + 1@.
integrate :: Polynomial -> Polynomial
integrate (Polynomial var terms domain) =
  let newTerms = map integrateTerm terms
  in if null newTerms
     then zeroPolynomial var
     else makePolynomial var newTerms domain

-- | Evaluate the definite integral @∫[a,b] p dx@ numerically.
--
-- Lower and upper bounds may be 'Rational' numbers or 'Constant' objects.
-- Uses the Fundamental Theorem of Calculus:
-- @∫[a,b] f dx = F(b) - F(a)@ where @F = integrate p@.
evaluateDefinite :: Polynomial
                 -> Either Rational Constant
                 -> Either Rational Constant
                 -> Double
evaluateDefinite poly lower upper =
  let f = integrate poly
      a = resolveBoundToDouble lower
      b = resolveBoundToDouble upper
  in polynomialEvaluate f b - polynomialEvaluate f a

-- | Convert a bound (rational or constant) to a 'Double'.
resolveBoundToDouble :: Either Rational Constant -> Double
resolveBoundToDouble (Left r)              = fromRational r
resolveBoundToDouble (Right c)             = constantNumericValue c

-- | Return the /n/-th iterated antiderivative of a polynomial.
-- /n/ must be non-negative.
--
-- @integrateN p 0@ → p (identity)
-- @integrateN p 1@ → ∫p dx
-- @integrateN p 2@ → ∫∫p dx dx
integrateN :: Polynomial -> Int -> Polynomial
integrateN poly n
  | n < 0     = error "integrateN: n must be non-negative"
  | n == 0    = poly
  | otherwise = integrateN (integrate poly) (n - 1)

-- | Wrap a polynomial's antiderivative in an indefinite 'SymIntegral'.
-- The stored integrand is the polynomial itself.
makeIndefiniteIntegral :: Polynomial -> SymIntegral
makeIndefiniteIntegral poly =
  makeIntegral poly (polyVariable poly) Nothing Nothing

-- | Wrap a polynomial with explicit bounds in a definite 'SymIntegral'.
-- Bounds may be 'Rational' numbers or 'Constant' objects.
makeDefiniteIntegral :: Polynomial
                     -> Either Rational Constant
                     -> Either Rational Constant
                     -> SymIntegral
makeDefiniteIntegral poly lower upper =
  makeIntegral poly (polyVariable poly) (Just lower) (Just upper)

-- | Run a quick sanity check on integration.
runSmokeTest :: IO ()
runSmokeTest = do
  let x    = makeVariable "x" Real
      piC  = makeConstant "pi" SymbolicPi

      -- p = 3x^2 - x + 5
      p = makePolynomial x
            [ makeTerm 3  x 2
            , makeTerm (-1) x 1
            , makeTerm 5  x 0 ] Real

      -- ∫p dx = x^3 - (1/2)x^2 + 5x
      ip = integrate p

      -- ∫²p dx = (1/4)x^4 - (1/6)x^3 + (5/2)x^2
      iip = integrateN p 2

      -- q = 6x + 2
      q = makePolynomial x
            [ makeTerm 6 x 1
            , makeTerm 2 x 0 ] Real

      -- ∫q dx = 3x^2 + 2x
      iq = integrate q

      -- Definite: ∫₀¹ p dx = F(1) - F(0) = 5.5
      def01 = evaluateDefinite p (Left 0) (Left 1)

      -- Definite: ∫₀¹ q dx = 5
      defQ01 = evaluateDefinite q (Left 0) (Left 1)

      -- Definite: ∫₀^π p dx
      defPi = evaluateDefinite p (Left 0) (Right piC)

      -- SymIntegral shells
      indefShell = makeIndefiniteIntegral p
      defShell   = makeDefiniteIntegral p (Left 0) (Left 1)
      piShell    = makeDefiniteIntegral p (Left 0) (Right piC)

  putStrLn ""
  putStrLn "=== Integration Smoke Test ==="
  putStrLn ""
  putStrLn $ "p              : " ++ polynomialToString p
  putStrLn $ "∫p dx          : " ++ polynomialToString ip
  putStrLn $ "∫∫p dx dx      : " ++ polynomialToString iip
  putStrLn ""
  putStrLn $ "q              : " ++ polynomialToString q
  putStrLn $ "∫q dx          : " ++ polynomialToString iq
  putStrLn ""
  putStrLn $ "∫₀¹  p dx      : " ++ show def01 ++ "  (expected 5.5)"
  putStrLn $ "∫₀¹  q dx      : " ++ show defQ01 ++ "  (expected 5.0)"
  putStrLn $ "∫₀^π p dx      : " ++ show defPi
  putStrLn ""
  putStrLn $ "indef shell    : " ++ integralToString indefShell
  putStrLn $ "def [0,1]      : " ++ integralToString defShell
  putStrLn $ "def [0,pi]     : " ++ integralToString piShell
  putStrLn ""
  putStrLn "=============================="
