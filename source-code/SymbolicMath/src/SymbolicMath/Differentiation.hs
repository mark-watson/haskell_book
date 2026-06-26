module SymbolicMath.Differentiation
  ( -- * Core differentiation
    differentiateTerm
  , differentiate

    -- * Higher-order derivatives
  , differentiateN

    -- * Convenience
  , gradientAt
  , criticalPointP

    -- * Smoke test
  , runSmokeTest
  ) where

import SymbolicMath.Types hiding (runSmokeTest)

-- | Apply the power rule to a single monomial.
--
-- @d/dx(c · x^n) = n·c · x^(n-1)@ for n ≥ 1.
-- @d/dx(c) = 0@ for n = 0 (returns 'Nothing').
--
-- Returns a new 'Term', or 'Nothing' when the term differentiates to zero.
differentiateTerm :: Term -> Maybe Term
differentiateTerm (Term c v n)
  | n == 0    = Nothing
  | otherwise = Just (Term (fromIntegral n * c) v (n - 1))

-- | Differentiate a polynomial with respect to its variable.
--
-- Uses the power rule on each term and the sum rule across terms.
-- Returns a new 'Polynomial' (the zero polynomial for a constant input).
differentiate :: Polynomial -> Polynomial
differentiate (Polynomial var terms domain) =
  let diffTerms = mapMaybeT differentiateTerm terms
  in if null diffTerms
     then zeroPolynomial var
     else makePolynomial var diffTerms domain

-- | Return the /n/-th derivative of a polynomial.
-- /n/ must be non-negative.
--
-- @differentiateN p 0@ → p (identity)
-- @differentiateN p 1@ → p'
-- @differentiateN p 2@ → p''
differentiateN :: Polynomial -> Int -> Polynomial
differentiateN poly n
  | n < 0     = error "differentiateN: n must be non-negative"
  | n == 0    = poly
  | otherwise = differentiateN (differentiate poly) (n - 1)

-- | Return the numerical value of the derivative of a polynomial at a point.
-- Differentiates symbolically then evaluates numerically.
gradientAt :: Polynomial -> Double -> Double
gradientAt poly x = polynomialEvaluate (differentiate poly) x

-- | Return 'True' if the point is (numerically) a critical point of the
-- polynomial, i.e. @|p'(x)| < tolerance@.
criticalPointP :: Polynomial -> Double -> Double -> Bool
criticalPointP poly x tolerance =
  abs (gradientAt poly x) < tolerance

-- | 'mapMaybe' for lists.
mapMaybeT :: (a -> Maybe b) -> [a] -> [b]
mapMaybeT _ []     = []
mapMaybeT f (x:xs) = case f x of
  Just y  -> y : mapMaybeT f xs
  Nothing -> mapMaybeT f xs

-- | Run a quick sanity check on differentiation.
runSmokeTest :: IO ()
runSmokeTest = do
  let x = makeVariable "x" Real

      -- p = 3x^2 - x + 5
      p = makePolynomial x
            [ makeTerm 3  x 2
            , makeTerm (-1) x 1
            , makeTerm 5  x 0 ] Real

      -- p' = 6x - 1
      dp = differentiate p

      -- p'' = 6
      ddp = differentiate dp

      -- p''' = 0 (zero polynomial)
      dddp = differentiate ddp

      -- q = x^4 - 2x^3 + x
      q = makePolynomial x
            [ makeTerm 1  x 4
            , makeTerm (-2) x 3
            , makeTerm 1  x 1 ] Real

      -- q' = 4x^3 - 6x^2 + 1
      dq = differentiate q

      -- q'' = 12x^2 - 12x
      ddq = differentiateN q 2

      -- Critical point of p: p'(x)=0 → 6x-1=0 → x=1/6
      cp = 1/6 :: Double

  putStrLn ""
  putStrLn "=== Differentiation Smoke Test ==="
  putStrLn ""
  putStrLn $ "p            : " ++ polynomialToString p
  putStrLn $ "p'           : " ++ polynomialToString dp
  putStrLn $ "p''          : " ++ polynomialToString ddp
  putStrLn $ "p'''         : " ++ polynomialToString dddp
  putStrLn ""
  putStrLn $ "q            : " ++ polynomialToString q
  putStrLn $ "q'           : " ++ polynomialToString dq
  putStrLn $ "q'' (via n=2): " ++ polynomialToString ddq
  putStrLn ""
  putStrLn $ "gradient-at(p, 0)      : " ++ show (gradientAt p 0)
           ++ "  (expected -1)"
  putStrLn $ "gradient-at(p, 1)      : " ++ show (gradientAt p 1)
           ++ "  (expected  5)"
  putStrLn $ "critical-point-p(p,1/6): " ++ show (criticalPointP p cp 1e-9)
           ++ "  (expected True)"
  putStrLn $ "critical-point-p(p,0)  : " ++ show (criticalPointP p 0 1e-9)
           ++ "  (expected False)"
  putStrLn ""
  putStrLn "=================================="
