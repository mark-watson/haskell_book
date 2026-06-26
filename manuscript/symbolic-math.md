# Symbolic Mathematics in Haskell

Symbolic computation manipulates mathematical expressions as data structures rather than as floating-point approximations. When you differentiate \(3x^2 - x + 5\) by hand, you apply the power rule to each term and write \(6x - 1\) — you are doing symbolic math. A numeric approach, by contrast, would estimate the derivative by evaluating the function at two nearby points and dividing. Symbolic computation gives you exact, algebraic results.

Haskell is a natural fit for symbolic math. Algebraic data types let you model mathematical expressions directly as trees of constructors. Pattern matching lets you write transformation rules that read almost exactly like the rules you learned in calculus. And because coefficients use `Rational` (exact fractions), differentiation and integration produce results with no floating-point drift.

Dear reader, you might wonder: why study symbolic math? In an age where everyone is talking about large language models there is room and a real need for deterministic technologies that stand on their own merits as well as augment sometime non-deterministic AI/LLM based systems. I hope you enjoy this material.

The library we will study in this chapter is located in the `source-code/SymbolicMath` directory, and provides symbolic differentiation and integration for single-variable polynomials. It was ported from the Common Lisp symbolic math library I wrote for my book [Loving Common Lisp, or the Savvy Programmer's Secret Weapon](https://leanpub.com/read/lovinglisp), and the translation from Lisp to Haskell is instructive: where the Lisp version uses lists and runtime type checking, the Haskell version uses statically-checked algebraic data types and precise function signatures.


## Project Structure

The library is organized as a Cabal project with three exposed modules and a smoke-test executable:

```
SymbolicMath/
├── symbolic-math.cabal
├── src/SymbolicMath/
│   ├── Types.hs              -- Core data structures
│   ├── Differentiation.hs    -- Symbolic differentiation
│   └── Integration.hs        -- Symbolic integration
└── app/Main.hs               -- Smoke test runner
```

Build and run with:

```bash
cd source-code/SymbolicMath
cabal build
cabal run symbolic-math
```

The smoke test exercises every function in the library and prints expected versus actual results. If you are working through this chapter, keep a REPL open (`cabal repl`) and experiment with the examples as you read.

## Core Data Structures

The module `SymbolicMath.Types` defines five data types that together model everything we need for single-variable polynomial calculus. Let us walk through each one.

### Domain

A `Domain` tags whether a variable or polynomial lives in the reals, the complex numbers, or the integers:

```haskell
data Domain = Real | Complex | Integer_
  deriving (Show, Eq)
```

The library uses `Domain` mostly for bookkeeping; the differentiation and integration rules do not inspect it. But encoding the domain in the type gives you the option to add domain-specific validation later. For example this code refuses to take a square root in `Integer_` domain.

### Variable

A `Variable` is a named symbol with a domain:

```haskell
data Variable = Variable
  { varName   :: String
  , varDomain :: Domain
  } deriving (Show)
```

Two variables are equal when both name and domain match:

```haskell
makeVariable :: String -> Domain -> Variable
makeVariable name domain = Variable name domain
```

In the REPL:

```haskell
ghci> let x = makeVariable "x" Real
ghci> let n = makeVariable "n" Integer_
ghci> variableEq x x
True
ghci> variableEq x (makeVariable "x" Complex)
False
```

### Constant

A `Constant` represents a named mathematical constant like *pi* or *e*, or an exact rational number you want to treat symbolically:

```haskell
data ConstantValue
  = ExactValue Rational
  | SymbolicPi
  | SymbolicE
  deriving (Show, Eq)

data Constant = Constant
  { constName  :: String
  , constValue :: ConstantValue
  } deriving (Show, Eq)
```

The function `constantNumericValue` collapses a constant to a `Double` when you need a numeric answer:

```haskell
ghci> let piConst = makeConstant "pi" SymbolicPi
ghci> let eConst  = makeConstant "e"  SymbolicE
ghci> let g       = makeConstant "g"  (ExactValue 9.80665)
ghci> constantNumericValue piConst
3.141592653589793
ghci> constantNumericValue g
9.80665
```

Constants are used most often as integral bounds — writing *int_0^pi* reads more naturally than *int_0^3.14159*.

### Term

A `Term` is a single monomial: coefficient times variable raised to a non-negative integer exponent:

```haskell
data Term = Term
  { termCoefficient :: Rational
  , termVariable    :: Variable
  , termExponent    :: Int
  } deriving (Show)
```

The constructor `makeTerm` enforces the non-negative exponent invariant:

```haskell
makeTerm :: Rational -> Variable -> Int -> Term
makeTerm coeff var exp_
  | exp_ < 0  = error "makeTerm: exponent must be non-negative"
  | otherwise = Term coeff var exp_
```

A few examples:

```haskell
ghci> makeTerm 3  x 2    -- 3x²
ghci> makeTerm (-1) x 1  -- -x
ghci> makeTerm 5  x 0    -- constant 5
```

The module provides `termNegate` (multiply coefficient by \(-1\)), `termScale` (multiply coefficient by a scalar), and `termToString` for display:

```haskell
ghci> termToString (makeTerm 3 x 2)
"3x^2"
ghci> termToString (makeTerm (-1) x 1)
"-1x"
ghci> termToString (makeTerm 5 x 0)
"5"
```

### Polynomial

A `Polynomial` is an ordered list of `Term` values in a single variable, with terms stored in descending exponent order:

```haskell
data Polynomial = Polynomial
  { polyVariable :: Variable
  , polyTerms    :: [Term]
  , polyDomain   :: Domain
  } deriving (Show)
```

The smart constructor `makePolynomial` is where the real work happens. It takes a variable, a list of terms (possibly unsorted, possibly with duplicate exponents), and a domain. It combines like-exponent terms by summing their coefficients, drops any terms whose coefficient sums to zero, and sorts by descending exponent:

```haskell
makePolynomial :: Variable -> [Term] -> Domain -> Polynomial
makePolynomial var terms domain =
  let coeffMap = Map.fromListWith (+) [(termExponent t, termCoefficient t) | t <- terms]
      pairs    = [(e, coeff) | (e, coeff) <- Map.toList coeffMap, coeff /= 0]
      sorted   = sortOn (\(e, _) -> Down e) pairs
      newTerms = [Term coeff var e | (e, coeff) <- sorted]
  in Polynomial var newTerms domain
```

This uses `Data.Map.Strict` to group by exponent and sum coefficients — a nice example of using the right data structure to simplify the logic. The `Down` newtype from `Data.Ord` gives us descending sort order.

Let us build a polynomial:

```haskell
ghci> let x = makeVariable "x" Real
ghci> let p = makePolynomial x
        [ makeTerm  3  x 2
        , makeTerm (-1) x 1
        , makeTerm  5  x 0 ] Real
ghci> polynomialToString p
"3x^2 + -1x + 5"
```

Since `makePolynomial` normalizes automatically, you can feed it messy input and still get a canonical result:

```haskell
ghci> let messy = makePolynomial x
        [ makeTerm 2 x 2, makeTerm 1 x 2, makeTerm 3 x 1
        , makeTerm (-3) x 1, makeTerm 4 x 0 ] Real
ghci> polynomialToString messy
"3x^2 + 4"
```

The *2x^2* and *1x^2* combined to *3x^2*; the *3x* and *-3x* canceled; the constant 4 remained. This normalization guarantee means every polynomial has exactly one representation, which simplifies equality checking and debugging.

#### Polynomial Arithmetic

The module provides addition, subtraction, negation, and scalar multiplication. All return new polynomials and inputs are never mutated:

```haskell
ghci> let q = makePolynomial x [makeTerm 1 x 1, makeTerm 2 x 0] Real
ghci> polynomialToString (polynomialAdd p q)
"3x^2 + 7"
ghci> polynomialToString (polynomialSubtract p q)
"3x^2 + -2x + 3"
ghci> polynomialToString (polynomialScale 2 p)
"6x^2 + -2x + 10"
```

Addition checks that both polynomials use the same variable and errors out if they do not so you cannot add a polynomial in *x* to a polynomial in *y*.

#### Evaluation and Inspection

`polynomialEvaluate` substitutes a numeric value for the variable. The type signature uses `Fractional a` so it works with `Rational`, `Double`, or any fractional type:

```haskell
polynomialEvaluate :: Fractional a => Polynomial -> a -> a
polynomialEvaluate (Polynomial _ terms _) x =
  sum [fromRational c * x ^ n | Term c _ n <- terms]
```

```haskell
ghci> polynomialEvaluate p (0 :: Rational)
5
ghci> polynomialEvaluate p (1 :: Rational)
7
ghci> polynomialEvaluate p (2 :: Rational)
15
```

`polynomialDegree` returns the highest exponent, or *-1* for the zero polynomial (a convention borrowed from computer algebra systems). `polynomialLeadingTerm` returns the first term in the sorted list, or `Nothing`.

Three convenience constructors round out the API:

```haskell
zeroPolynomial var        -- 0
constantPolynomial var 7  -- 7
identityPolynomial var    -- x
```

### SymIntegral

The final data type stores an unevaluated integral along with its bounds:

```haskell
data SymIntegral = SymIntegral
  { integrand   :: Polynomial
  , intVariable :: Variable
  , intLower    :: Maybe (Either Rational Constant)
  , intUpper    :: Maybe (Either Rational Constant)
  } deriving (Show, Eq)
```

Bounds use `Maybe` because an integral is either definite (both bounds present) or indefinite (both absent). The `Either Rational Constant` lets you write numeric bounds like *0* and *1* or symbolic bounds like *pi* and *e*. The constructor enforces the invariant that both bounds must be `Just` or both `Nothing`:

```haskell
makeIntegral :: Polynomial -> Variable
             -> Maybe (Either Rational Constant)
             -> Maybe (Either Rational Constant)
             -> SymIntegral
```

```haskell
ghci> -- indefinite: ∫(3x² - x + 5) dx
ghci> let indef = makeIntegral p x Nothing Nothing
ghci> -- definite: ∫₀¹ (3x² - x + 5) dx
ghci> let def01 = makeIntegral p x (Just (Left 0)) (Just (Left 1))
ghci> -- definite with symbolic bound: ∫₀^π
ghci> let piInt = makeIntegral p x (Just (Left 0)) (Just (Right piConst))
ghci> integralToString indef
"∫(3x^2 + -1x + 5) dx"
ghci> integralToString def01
"∫[0,1](3x^2 + -1x + 5) dx"
```

## Symbolic Differentiation

The module `SymbolicMath.Differentiation` implements the power rule and sum rule. The core function operates on a single term:

```haskell
differentiateTerm :: Term -> Maybe Term
differentiateTerm (Term c v n)
  | n == 0    = Nothing          -- derivative of a constant is 0
  | otherwise = Just (Term (fromIntegral n * c) v (n - 1))
```

The `Maybe` return type handles the case where a term differentiates to zero so we want to drop those terms from the result polynomial rather than storing a zero-coefficient term. This is exactly the pattern the power rule describes:

\[\frac{d}{dx}(c \cdot x^n) = n \cdot c \cdot x^{n-1} \quad \text{for } n \geq 1\]

The polynomial-level `differentiate` applies `differentiateTerm` to each term via a local `mapMaybe` helper, then constructs a new normalized polynomial (or the zero polynomial if every term differentiated to zero):

```haskell
differentiate :: Polynomial -> Polynomial
differentiate (Polynomial var terms domain) =
  let diffTerms = mapMaybeT differentiateTerm terms
  in if null diffTerms
     then zeroPolynomial var
     else makePolynomial var diffTerms domain
```

Higher-order derivatives use simple recursion:

```haskell
differentiateN :: Polynomial -> Int -> Polynomial
differentiateN poly n
  | n < 0     = error "differentiateN: n must be non-negative"
  | n == 0    = poly
  | otherwise = differentiateN (differentiate poly) (n - 1)
```

Two convenience functions bridge the symbolic and numeric worlds. `gradientAt` differentiates symbolically and then evaluates numerically at a point. `criticalPointP` checks whether the absolute value of the derivative at a point falls below a tolerance:

```haskell
gradientAt :: Polynomial -> Double -> Double
gradientAt poly x = polynomialEvaluate (differentiate poly) x

criticalPointP :: Polynomial -> Double -> Double -> Bool
criticalPointP poly x tolerance = abs (gradientAt poly x) < tolerance
```

Let us see the differentiation functions in action. We will use the polynomial \(p = 3x^2 - x + 5\):

```haskell
ghci> let x = makeVariable "x" Real
ghci> let p = makePolynomial x
        [ makeTerm 3  x 2
        , makeTerm (-1) x 1
        , makeTerm 5  x 0 ] Real
ghci> let dp = differentiate p
ghci> polynomialToString dp
"6x + -1"
ghci> let ddp = differentiate dp
ghci> polynomialToString ddp
"6"
ghci> let dddp = differentiate ddp
ghci> polynomialToString dddp
"0"
ghci> gradientAt p 0
-1.0
ghci> gradientAt p 1
5.0
ghci> criticalPointP p (1/6) 1e-9
True
```

The critical point check at \(x = 1/6\) returns `True` because \(p'(x) = 6x - 1\) equals zero at \(x = 1/6\). This is the minimum of the parabola.

Let us also differentiate \(q = x^4 - 2x^3 + x\) to see higher-degree behavior:

```haskell
ghci> let q = makePolynomial x
        [ makeTerm 1  x 4
        , makeTerm (-2) x 3
        , makeTerm 1  x 1 ] Real
ghci> polynomialToString (differentiate q)
"4x^3 + -6x^2 + 1"
ghci> polynomialToString (differentiateN q 2)
"12x^2 + -12x"
```

## Symbolic Integration

The module `SymbolicMath.Integration` implements the reverse power rule and the Fundamental Theorem of Calculus for definite integrals.

The reverse power rule on a single term is:

\[\int c \cdot x^n \, dx = \frac{c}{n+1} \cdot x^{n+1}\]

In Haskell:

```haskell
integrateTerm :: Term -> Term
integrateTerm (Term c v n) =
  let newExp  = n + 1
      newCoef = c / fromIntegral newExp
  in Term newCoef v newExp
```

Unlike differentiation, integration of a term never produces zero — even a constant term \(c\) integrates to \(c \cdot x\). So `integrateTerm` returns a `Term` directly rather than a `Maybe Term`.

The polynomial-level `integrate` maps `integrateTerm` over every term and normalizes:

```haskell
integrate :: Polynomial -> Polynomial
integrate (Polynomial var terms domain) =
  let newTerms = map integrateTerm terms
  in if null newTerms
     then zeroPolynomial var
     else makePolynomial var newTerms domain
```

Note that `integrate` does not add a constant of integration \(+C\). The antiderivative is returned as a polynomial, and you can add a constant term yourself if needed.

For definite integrals, `evaluateDefinite` uses the Fundamental Theorem of Calculus:

\[\int_a^b f(x)\,dx = F(b) - F(a) \quad \text{where } F = \int f\]

```haskell
evaluateDefinite :: Polynomial
                 -> Either Rational Constant
                 -> Either Rational Constant
                 -> Double
evaluateDefinite poly lower upper =
  let f = integrate poly
      a = resolveBoundToDouble lower
      b = resolveBoundToDouble upper
  in polynomialEvaluate f b - polynomialEvaluate f a
```

The helper `resolveBoundToDouble` converts either a rational or a symbolic constant to `Double`. This is the one place in the library where exact arithmetic gives way to floating-point — it happens at the very last step, after all symbolic manipulation is complete.

Higher-order integration uses the same recursive pattern as higher-order differentiation:

```haskell
integrateN :: Polynomial -> Int -> Polynomial
integrateN poly n
  | n < 0     = error "integrateN: n must be non-negative"
  | n == 0    = poly
  | otherwise = integrateN (integrate poly) (n - 1)
```

Two convenience functions wrap a polynomial's antiderivative in a `SymIntegral` for display:

```haskell
makeIndefiniteIntegral :: Polynomial -> SymIntegral
makeDefiniteIntegral :: Polynomial
                     -> Either Rational Constant
                     -> Either Rational Constant
                     -> SymIntegral
```

Let us run through the integration examples using \(p = 3x^2 - x + 5\):

```haskell
ghci> let x = makeVariable "x" Real
ghci> let piC = makeConstant "pi" SymbolicPi
ghci> let p = makePolynomial x
        [ makeTerm 3  x 2
        , makeTerm (-1) x 1
        , makeTerm 5  x 0 ] Real
ghci> let ip = integrate p
ghci> polynomialToString ip
"1x^3 + -1/2x^2 + 5x"
ghci> evaluateDefinite p (Left 0) (Left 1)
5.5
ghci> evaluateDefinite p (Left 0) (Right piC)
41.779...
```

The indefinite integral of \(3x^2 - x + 5\) is \(x^3 - \frac{1}{2}x^2 + 5x\). The definite integral from 0 to 1 evaluates to \(5.5\) — you can verify this by hand: \(F(1) - F(0) = (1 - 0.5 + 5) - 0 = 5.5\).

We can also integrate a simpler polynomial \(q = 6x + 2\):

```haskell
ghci> let q = makePolynomial x [makeTerm 6 x 1, makeTerm 2 x 0] Real
ghci> polynomialToString (integrate q)
"3x^2 + 2x"
ghci> evaluateDefinite q (Left 0) (Left 1)
5.0
```

## Running the Smoke Tests

The `app/Main.hs` file runs all three smoke tests in sequence:

```haskell
module Main where

import qualified SymbolicMath.Types           as T
import qualified SymbolicMath.Differentiation as D
import qualified SymbolicMath.Integration     as I

main :: IO ()
main = do
  T.runSmokeTest
  D.runSmokeTest
  I.runSmokeTest
```

Running it produces:

```
=== Symbolic Math Data Layer Smoke Test ===

p         : 3x^2 + -1x + 5
q         : 1x + 2
p + q     : 3x^2 + 7
p - q     : 3x^2 + -2x + 3
2 * p     : 6x^2 + -2x + 10
degree(p) : 2
p(0)      : 5
p(1)      : 7
p(2)      : 15
indef     : ∫(3x^2 + -1x + 5) dx
def       : ∫[0,1](3x^2 + -1x + 5) dx
pi-int    : ∫[0,pi](3x^2 + -1x + 5) dx

=== Differentiation Smoke Test ===

p            : 3x^2 + -1x + 5
p'           : 6x + -1
p''          : 6
p'''         : 0

q            : 1x^4 + -2x^3 + 1x
q'           : 4x^3 + -6x^2 + 1
q'' (via n=2): 12x^2 + -12x

gradient-at(p, 0)      : -1.0  (expected -1)
gradient-at(p, 1)      : 5.0  (expected  5)
critical-point-p(p,1/6): True  (expected True)
critical-point-p(p,0)  : False (expected False)

=== Integration Smoke Test ===

p              : 3x^2 + -1x + 5
∫p dx          : 1x^3 + -1/2x^2 + 5x
∫∫p dx dx      : 1/4x^4 + -1/6x^3 + 5/2x^2

q              : 1x + 2
∫q dx          : 3x^2 + 2x

∫₀¹  p dx      : 5.5  (expected 5.5)
∫₀¹  q dx      : 5.0  (expected 5.0)
∫₀^π p dx      : 41.779...
```

## Design Notes

A few architectural choices are worth calling out because they make the library pleasant to work with and safe against common errors:

**Exact arithmetic.** Coefficients use `Rational` (a ratio of `Integer` values), so differentiation and integration produce exact fractions. Floating-point only enters when you call `evaluateDefinite` or `polynomialEvaluate` with a `Double` argument — and even then, the symbolic manipulation that precedes evaluation is exact.

**Automatic normalization.** `makePolynomial` combines like terms and sorts by descending exponent on every call. There is no way to construct a polynomial with duplicate-degree terms or zero-coefficient terms. This invariant means equality checking is structural and `polynomialToString` always produces readable output.

**Immutability.** Every arithmetic function returns a fresh polynomial. You never need to worry about a differentiation call silently modifying a polynomial you are still using elsewhere.

**Bound flexibility.** Integral bounds accept `Rational` numbers or `Constant` values, making it straightforward to express \(\int_0^\pi\) or \(\int_0^e\) without manually converting to floating-point.

**Single-variable limitation.** The library handles one variable at a time. Multi-variable polynomials and partial derivatives would require a different term representation (e.g., a map from tuples of variable-exponent pairs to coefficients). This is a natural extension if you want to deepen your understanding of the design.

## Wrap Up

We have built a small but complete symbolic math library in three modules. The key insight is that mathematical expressions are trees, and algebraic data types let you model those trees directly. Once you have the data types right, the transformation rules: the power rule, the sum rule, the reverse power rule, then you translate almost word-for-word into pattern-matching function definitions.

The library uses exact rational arithmetic throughout, normalizes polynomials automatically, and cleanly separates the symbolic manipulation layer from the numeric evaluation layer. The same design pattern of modeling your domain as algebraic data types, then writing pure functions that transform those types. This pattern applies to compilers, theorem provers, equation solvers, and many other domains beyond calculus.

I encourage you to experiment with the code in a REPL as you work through the practice problems below. The best way to internalize these ideas is to extend the library yourself.

## Optional Practice Problems

1. Extend the `Polynomial` data type and arithmetic functions to support polynomials in *two* variables (e.g., \(2x^2y + 3xy - y\)). You will need to change the term representation so that a `Term` can hold an exponent for each variable. Then implement `partialDerivativeX` and `partialDerivativeY` functions that differentiate with respect to one variable while treating the other as a constant.

2. Add a `simplify` function to `SymbolicMath.Types` that improves the display of polynomials. Currently `polynomialToString` renders \(-1x + 5\) with a leading coefficient of \(-1\) and a trailing `+` before negative terms. Write `simplify` to produce cleaner output: render \(1x\) as just \(x\), omit the coefficient when it is 1 (except for constant terms), and replace `+ -` with `- ` between terms. For example, `3x^2 + -1x + 5` should become `3x^2 - x + 5`.
