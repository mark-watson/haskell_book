module SymbolicMath.Types
  ( -- * Domain
    Domain(..)

    -- * Variable
  , Variable(..)
  , makeVariable
  , variableEq

    -- * Constant
  , ConstantValue(..)
  , Constant(..)
  , makeConstant
  , constantNumericValue

    -- * Term (monomial)
  , Term(..)
  , makeTerm
  , termEq
  , termNegate
  , termScale
  , termToString

    -- * Polynomial
  , Polynomial(..)
  , makePolynomial
  , polynomialDegree
  , polynomialLeadingTerm
  , polynomialAdd
  , polynomialSubtract
  , polynomialNegate
  , polynomialScale
  , polynomialToString
  , polynomialEvaluate
  , polynomialNormalize
  , zeroPolynomial
  , constantPolynomial
  , identityPolynomial

    -- * Integral
  , SymIntegral(..)
  , makeIntegral
  , integralDefiniteP
  , integralToString

    -- * Smoke test
  , runSmokeTest
  ) where

import Data.List (intercalate, sortOn)
import Data.Ord (Down(..))
import Data.Ratio (numerator, denominator)
import qualified Data.Map.Strict as Map

-- | Display a 'Rational' without the @\"% 1\"@ suffix for whole numbers,
-- and with numerator/denominator notation for fractions.
showRational :: Rational -> String
showRational r
  | denom == 1 = show num
  | otherwise  = show num ++ "/" ++ show denom
  where
    num   = numerator r
    denom = denominator r

--------------------------------------------------------------------
-- 1. Domain
--------------------------------------------------------------------

-- | The mathematical domain of a variable or polynomial.
data Domain = Real | Complex | Integer_
  deriving (Show, Eq)

--------------------------------------------------------------------
-- 2. Variable
--------------------------------------------------------------------

-- | A symbolic variable such as /x/, /y/, or /t/.
data Variable = Variable
  { varName   :: String
  , varDomain :: Domain
  } deriving (Show)

-- | Two variables are equal when their names and domains match.
instance Eq Variable where
  Variable n1 d1 == Variable n2 d2 = n1 == n2 && d1 == d2

-- | Create a symbolic variable.
makeVariable :: String -> Domain -> Variable
makeVariable name domain = Variable name domain

-- | Return 'True' if two variables are the same.
variableEq :: Variable -> Variable -> Bool
variableEq = (==)

--------------------------------------------------------------------
-- 3. Constant
--------------------------------------------------------------------

-- | The value of a symbolic constant: an exact rational, @π@, or @e@.
data ConstantValue
  = ExactValue Rational
  | SymbolicPi
  | SymbolicE
  deriving (Show, Eq)

-- | A named mathematical constant.
data Constant = Constant
  { constName  :: String
  , constValue :: ConstantValue
  } deriving (Show, Eq)

-- | Create a named constant.
makeConstant :: String -> ConstantValue -> Constant
makeConstant = Constant

-- | Return the numeric ('Double') value of a constant.
-- π → 'pi', e → @'exp' 1@, numbers are returned as-is.
constantNumericValue :: Constant -> Double
constantNumericValue (Constant _ cv) = case cv of
  SymbolicPi   -> pi
  SymbolicE    -> exp 1
  ExactValue r -> fromRational r

--------------------------------------------------------------------
-- 4. Term (monomial: coefficient * variable ^ exponent)
--------------------------------------------------------------------

-- | A single monomial: @coefficient * variable ^ exponent@.
-- Exponent is a non-negative integer (0 gives a constant term).
data Term = Term
  { termCoefficient :: Rational
  , termVariable    :: Variable
  , termExponent    :: Int
  } deriving (Show)

instance Eq Term where
  Term c1 v1 e1 == Term c2 v2 e2 =
    c1 == c2 && v1 == v2 && e1 == e2

-- | Create a monomial. Exponent must be non-negative.
makeTerm :: Rational -> Variable -> Int -> Term
makeTerm coeff var exp_
  | exp_ < 0  = error "makeTerm: exponent must be non-negative"
  | otherwise = Term coeff var exp_

-- | Return 'True' if two terms are structurally equal.
termEq :: Term -> Term -> Bool
termEq = (==)

-- | Return a new term equal to @-term@.
termNegate :: Term -> Term
termNegate (Term c v n) = Term (-c) v n

-- | Return a new term equal to @scalar * term@.
termScale :: Rational -> Term -> Term
termScale scalar (Term c v n) = Term (scalar * c) v n

-- | Human-readable string for a term (e.g. @3x^2@, @-x@, @5@).
termToString :: Term -> String
termToString (Term c (Variable name _) n)
  | n == 0     = showRational c
  | n == 1     = showRational c ++ name
  | otherwise  = showRational c ++ name ++ "^" ++ show n

--------------------------------------------------------------------
-- 5. Polynomial
--------------------------------------------------------------------

-- | A polynomial in one variable, represented as an ordered list of
-- terms (descending exponent). Terms are automatically combined and
-- sorted on construction via 'makePolynomial'.
data Polynomial = Polynomial
  { polyVariable :: Variable
  , polyTerms    :: [Term]
  , polyDomain   :: Domain
  } deriving (Show)

instance Eq Polynomial where
  Polynomial v1 ts1 d1 == Polynomial v2 ts2 d2 =
    v1 == v2 && ts1 == ts2 && d1 == d2

-- | Create a polynomial from a variable, a list of terms, and a domain.
-- Like-exponent terms are combined; zero-coefficient terms are dropped.
-- Terms are stored in descending exponent order.
makePolynomial :: Variable -> [Term] -> Domain -> Polynomial
makePolynomial var terms domain =
  let coeffMap = Map.fromListWith (+) [(termExponent t, termCoefficient t) | t <- terms]
      pairs    = [(e, coeff) | (e, coeff) <- Map.toList coeffMap, coeff /= 0]
      sorted   = sortOn (\(e, _) -> Down e) pairs
      newTerms = [Term coeff var e | (e, coeff) <- sorted]
  in Polynomial var newTerms domain

-- | Re-normalize a polynomial (re-sort, drop zero terms).
polynomialNormalize :: Polynomial -> Polynomial
polynomialNormalize (Polynomial var terms domain) =
  makePolynomial var terms domain

-- | Degree (highest exponent) of the polynomial.
-- Returns @-1@ for the zero polynomial.
polynomialDegree :: Polynomial -> Int
polynomialDegree (Polynomial _ [] _)     = -1
polynomialDegree (Polynomial _ (t:_) _)  = termExponent t

-- | Leading (highest-degree) term, or 'Nothing' for the zero polynomial.
polynomialLeadingTerm :: Polynomial -> Maybe Term
polynomialLeadingTerm (Polynomial _ [] _)    = Nothing
polynomialLeadingTerm (Polynomial _ (t:_) _) = Just t

-- | @p + q@. Variables must match.
polynomialAdd :: Polynomial -> Polynomial -> Polynomial
polynomialAdd p@(Polynomial v1 ts1 _) (Polynomial v2 ts2 _)
  | v1 /= v2  = error $ "Cannot add polynomials in different variables: "
                     ++ varName v1 ++ " and " ++ varName v2
  | otherwise = makePolynomial v1 (ts1 ++ ts2) (polyDomain p)

-- | @-p@.
polynomialNegate :: Polynomial -> Polynomial
polynomialNegate (Polynomial var terms domain) =
  makePolynomial var (map termNegate terms) domain

-- | @p - q@.
polynomialSubtract :: Polynomial -> Polynomial -> Polynomial
polynomialSubtract p q = polynomialAdd p (polynomialNegate q)

-- | @scalar * p@.
polynomialScale :: Rational -> Polynomial -> Polynomial
polynomialScale scalar (Polynomial var terms domain) =
  makePolynomial var (map (termScale scalar) terms) domain

-- | Evaluate the polynomial at a given value.
polynomialEvaluate :: Fractional a => Polynomial -> a -> a
polynomialEvaluate (Polynomial _ terms _) x =
  sum [fromRational c * x ^ n | Term c _ n <- terms]

-- | Human-readable string in descending exponent order, terms joined by @\" + \"@.
-- The zero polynomial renders as @\"0\"@.
polynomialToString :: Polynomial -> String
polynomialToString (Polynomial _ [] _) = "0"
polynomialToString (Polynomial _ terms _) =
  intercalate " + " (map termToString terms)

-- | The zero polynomial in a given variable.
zeroPolynomial :: Variable -> Polynomial
zeroPolynomial var = Polynomial var [] Real

-- | A constant polynomial (value with exponent 0).
constantPolynomial :: Variable -> Rational -> Polynomial
constantPolynomial var val =
  makePolynomial var [Term val var 0] Real

-- | The identity polynomial @x@ (degree 1, coefficient 1).
identityPolynomial :: Variable -> Polynomial
identityPolynomial var =
  makePolynomial var [Term 1 var 1] Real

--------------------------------------------------------------------
-- 6. SymIntegral
--------------------------------------------------------------------

-- | A definite or indefinite integral.
data SymIntegral = SymIntegral
  { integrand   :: Polynomial
  , intVariable :: Variable
  , intLower    :: Maybe (Either Rational Constant)
  , intUpper    :: Maybe (Either Rational Constant)
  } deriving (Show, Eq)

-- | Create a symbolic integral. Either both bounds must be provided
-- (definite) or neither (indefinite).
makeIntegral :: Polynomial -> Variable
             -> Maybe (Either Rational Constant)
             -> Maybe (Either Rational Constant)
             -> SymIntegral
makeIntegral integrand_ var lower upper
  | (isJust lower) /= (isJust upper) =
      error "makeIntegral: either both bounds or neither must be provided"
  | otherwise = SymIntegral integrand_ var lower upper
  where
    isJust = maybe False (const True)

-- | Return 'True' if the integral is definite (has bounds).
integralDefiniteP :: SymIntegral -> Bool
integralDefiniteP = maybe False (const True) . intLower

-- | Render a bound (number or constant) as a string.
boundToString :: Either Rational Constant -> String
boundToString (Left r)              = showRational r
boundToString (Right (Constant n _)) = n

-- | Human-readable string for an integral.
-- Indefinite: @∫(expr) dx@ / Definite: @∫[a,b](expr) dx@.
integralToString :: SymIntegral -> String
integralToString (SymIntegral integrand_ var lo hi) =
  let varStr    = varName var
      body      = polynomialToString integrand_
      boundsStr = case (lo, hi) of
        (Just l, Just h) -> "[" ++ boundToString l ++ "," ++ boundToString h ++ "]"
        _                -> ""
  in "∫" ++ boundsStr ++ "(" ++ body ++ ") d" ++ varStr

--------------------------------------------------------------------
-- 7. Smoke test
--------------------------------------------------------------------

-- | Run a quick sanity check on the data structures, printing results.
runSmokeTest :: IO ()
runSmokeTest = do
  let x       = makeVariable "x" Real
      piConst = makeConstant "pi" SymbolicPi

      -- Build  3x^2 - x + 5
      p = makePolynomial x
            [ makeTerm  3  x 2
            , makeTerm (-1) x 1
            , makeTerm  5  x 0 ] Real

      -- Build  x + 2
      q = makePolynomial x
            [ makeTerm 1 x 1
            , makeTerm 2 x 0 ] Real

      sumPQ    = polynomialAdd p q
      diffPQ   = polynomialSubtract p q
      scaled   = polynomialScale 2 p
      indef    = makeIntegral p x Nothing Nothing
      def01    = makeIntegral p x (Just (Left 0)) (Just (Left 1))
      piInt    = makeIntegral p x (Just (Left 0)) (Just (Right piConst))

  putStrLn ""
  putStrLn "=== Symbolic Math Data Layer Smoke Test ==="
  putStrLn ""
  putStrLn $ "p         : " ++ polynomialToString p
  putStrLn $ "q         : " ++ polynomialToString q
  putStrLn $ "p + q     : " ++ polynomialToString sumPQ
  putStrLn $ "p - q     : " ++ polynomialToString diffPQ
  putStrLn $ "2 * p     : " ++ polynomialToString scaled
  putStrLn $ "degree(p) : " ++ show (polynomialDegree p)
  putStrLn $ "p(0)      : " ++ showRational (polynomialEvaluate p (0 :: Rational))
  putStrLn $ "p(1)      : " ++ showRational (polynomialEvaluate p (1 :: Rational))
  putStrLn $ "p(2)      : " ++ showRational (polynomialEvaluate p (2 :: Rational))
  putStrLn $ "indef     : " ++ integralToString indef
  putStrLn $ "def       : " ++ integralToString def01
  putStrLn $ "pi-int    : " ++ integralToString piInt
  putStrLn ""
  putStrLn "==========================================="
