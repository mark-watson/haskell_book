# Symbolic Math — Haskell

A foundational library for **symbolic mathematics** in Haskell.
Provides core data structures and operations for symbolic differentiation
and integration of single-variable polynomials. Ported from the
[Common Lisp symbolic-math](https://leanpub.com/read/lovinglisp/symbolic-mathematics-in-common-lisp) library.

---

## Project Structure

```
SymbolicMath/
├── symbolic-math.cabal          ← Cabal build file
├── src/SymbolicMath/
│   ├── Types.hs                 ← Core data structures
│   ├── Differentiation.hs       ← Symbolic differentiation
│   └── Integration.hs           ← Symbolic integration
├── app/Main.hs                  ← Smoke test runner
└── README.md
```

---

## Data Structures

All types are in the `SymbolicMath.Types` module.

### 1. `Variable` — Symbolic Variable

Represents a mathematical variable such as *x*, *y*, or *t*.

| Field | Type | Description |
|-------|------|-------------|
| `varName` | `String` | The variable name (e.g. `"x"`) |
| `varDomain` | `Domain` | One of `Real`, `Complex`, or `Integer_` |

**Constructor:** `makeVariable :: String -> Domain -> Variable`

```haskell
let x = makeVariable "x" Real
let n = makeVariable "n" Integer_
```

**Equality:** `variableEq a b` — `True` when name and domain both match.

---

### 2. `Constant` — Named Constant

A symbolic constant with an optional closed-form name.

| Field | Type | Description |
|-------|------|-------------|
| `constName` | `String` | Human-readable label (e.g. `"pi"`) |
| `constValue` | `ConstantValue` | `ExactValue Rational`, `SymbolicPi`, or `SymbolicE` |

**Constructor:** `makeConstant :: String -> ConstantValue -> Constant`

```haskell
let piConst = makeConstant "pi" SymbolicPi
let eConst  = makeConstant "e"  SymbolicE
let g       = makeConstant "g"  (ExactValue 9.80665)
```

**Numeric evaluation:** `constantNumericValue c` returns a `Double`:

```haskell
constantNumericValue piConst  -- 3.141592653589793
constantNumericValue g        -- 9.80665
```

---

### 3. `Term` — Monomial

A single term of the form **c · xⁿ**.

| Field | Type | Description |
|-------|------|-------------|
| `termCoefficient` | `Rational` | Numeric coefficient *c* |
| `termVariable` | `Variable` | The variable *x* |
| `termExponent` | `Int` | Non-negative integer exponent *n* |

**Constructor:** `makeTerm :: Rational -> Variable -> Int -> Term`

```haskell
-- 3x²
makeTerm 3  x 2
-- -x
makeTerm (-1) x 1
-- constant 5  (exponent = 0)
makeTerm 5  x 0
```

| Function | Signature | Returns |
|----------|-----------|---------|
| `termEq` | `Term -> Term -> Bool` | Structural equality |
| `termNegate` | `Term -> Term` | New term `-coefficient` |
| `termScale` | `Rational -> Term -> Term` | New term `scalar·coefficient` |
| `termToString` | `Term -> String` | Human-readable string |

```haskell
termToString (makeTerm 3 x 2)    -- "3x^2"
termToString (makeTerm (-1) x 1) -- "-1x"
termToString (makeTerm 5 x 0)    -- "5"
```

---

### 4. `Polynomial` — Polynomial

A polynomial in **one variable** stored as an ordered list of `Term`
records (descending exponent). Like-degree terms are **automatically
combined** on construction; zero-coefficient terms are dropped.

| Field | Type | Description |
|-------|------|-------------|
| `polyVariable` | `Variable` | The indeterminate |
| `polyTerms` | `[Term]` | Terms, descending exponent |
| `polyDomain` | `Domain` | `Real` (default) or `Complex` |

**Constructor:** `makePolynomial :: Variable -> [Term] -> Domain -> Polynomial`

```haskell
let x = makeVariable "x" Real
let p = makePolynomial x [ makeTerm  3  x 2
                         , makeTerm (-1) x 1
                         , makeTerm  5  x 0 ] Real
-- p = 3x² - x + 5
```

#### Inspection

| Function | Returns |
|----------|---------|
| `polynomialDegree poly` | Highest exponent; `-1` for zero polynomial |
| `polynomialLeadingTerm poly` | First (highest-degree) `Term`, or `Nothing` |

#### Arithmetic

All arithmetic functions return **new** polynomials; inputs are never mutated.

| Function | Description |
|----------|-------------|
| `polynomialAdd p q` | *p* + *q* |
| `polynomialSubtract p q` | *p* − *q* |
| `polynomialNegate poly` | −*p* |
| `polynomialScale scalar poly` | *scalar* · *p* |
| `polynomialNormalize poly` | Re-sort and drop zero terms |

```haskell
polynomialToString (polynomialAdd p q)       -- "3x^2 + 7"
polynomialToString (polynomialSubtract p q)  -- "3x^2 + -2x + 3"
polynomialToString (polynomialScale 2 p)     -- "6x^2 + -2x + 10"
```

#### Evaluation

```haskell
polynomialEvaluate p (0 :: Rational)  -- 5
polynomialEvaluate p (1 :: Rational)  -- 7
polynomialEvaluate p (2 :: Rational)  -- 15
```

#### Display

```haskell
polynomialToString p  -- "3x^2 + -1x + 5"
```

#### Convenience Constructors

| Function | Description |
|----------|-------------|
| `zeroPolynomial var` | The zero polynomial (no terms) |
| `constantPolynomial var val` | Constant polynomial *val* |
| `identityPolynomial var` | *x* (degree-1, coefficient 1) |

---

### 5. `SymIntegral` — Definite or Indefinite Integral

Stores an unevaluated integral expression together with its bounds.

| Field | Type | Description |
|-------|------|-------------|
| `integrand` | `Polynomial` | The expression ∫ *f*(*x*) |
| `intVariable` | `Variable` | Variable of integration |
| `intLower` | `Maybe (Either Rational Constant)` | Lower bound (`Nothing` → indefinite) |
| `intUpper` | `Maybe (Either Rational Constant)` | Upper bound (`Nothing` → indefinite) |

**Constructor:** `makeIntegral` — either both bounds must be `Just` or both `Nothing`.

```haskell
-- Indefinite: ∫ (3x² - x + 5) dx
makeIntegral p x Nothing Nothing

-- Definite: ∫₀¹ (3x² - x + 5) dx
makeIntegral p x (Just (Left 0)) (Just (Left 1))

-- Definite with a symbolic bound: ∫₀^π p dx
makeIntegral p x (Just (Left 0)) (Just (Right piConst))
```

| Function | Returns |
|----------|---------|
| `integralDefiniteP i` | `True` if the integral has explicit bounds |
| `integralToString i` | Human-readable Unicode representation |

```haskell
integralToString (makeIntegral p x Nothing Nothing)
-- "∫(3x^2 + -1x + 5) dx"

integralToString (makeIntegral p x (Just (Left 0)) (Just (Left 1)))
-- "∫[0,1](3x^2 + -1x + 5) dx"
```

---

## Differentiation (`SymbolicMath.Differentiation`)

Implements standard polynomial differentiation rules:

| Function | Description |
|----------|-------------|
| `differentiateTerm term` | Power rule on one monomial; returns `Maybe Term` |
| `differentiate poly` | Derivative of a polynomial |
| `differentiateN poly n` | *n*-th derivative |
| `gradientAt poly x` | Numerical value of derivative at *x* |
| `criticalPointP poly x tol` | `True` if \|*p'*(*x*)\| < `tol` |

```haskell
differentiate p        -- p = 3x² - x + 5  →  6x - 1
differentiateN p 2     -- p'' = 6
gradientAt p 1         -- 5.0
criticalPointP p (1/6) 1e-9  -- True
```

---

## Integration (`SymbolicMath.Integration`)

Implements the reverse power rule and the Fundamental Theorem of Calculus:

| Function | Description |
|----------|-------------|
| `integrateTerm term` | Reverse power rule on one monomial |
| `integrate poly` | Antiderivative of a polynomial |
| `evaluateDefinite poly a b` | Numeric value of ∫[a,b] *p* dx |
| `integrateN poly n` | *n*-th iterated antiderivative |
| `makeIndefiniteIntegral poly` | Wrap in an indefinite `SymIntegral` |
| `makeDefiniteIntegral poly a b` | Wrap in a definite `SymIntegral` |

```haskell
integrate p                           -- ∫(3x² - x + 5)dx = x³ - ½x² + 5x
evaluateDefinite p (Left 0) (Left 1)  -- 5.5
evaluateDefinite p (Left 0) (Right piConst)  -- ~41.78
```

---

## Building & Running

```bash
cabal build
cabal run symbolic-math
```

The smoke test verifies data structures, differentiation, and integration:

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

p'           : 6x + -1
p''          : 6
gradient-at(p, 0)      : -1.0  (expected -1)
gradient-at(p, 1)      : 5.0  (expected  5)
critical-point-p(p,1/6): True  (expected True)

=== Integration Smoke Test ===

∫p dx          : 1x^3 + -1/2x^2 + 5x
∫₀¹  p dx      : 5.5  (expected 5.5)
∫₀^π p dx      : 41.779...
```

---

## Design Notes

- **Exact arithmetic** — coefficients use `Rational`, so differentiation and
  integration produce exact fractions (no floating-point drift until the
  final `Double` evaluation of definite integrals).
- **Immutability** — arithmetic functions always return fresh values.
- **Single-variable polynomials** — multi-variable support is future work.
- **Automatic normalisation** — `makePolynomial` combines like terms and
  sorts on every call, so the representation is always canonical.
- **Bound flexibility** — integral bounds accept plain `Rational` numbers or
  `Constant` structs, making it straightforward to express bounds like *π*
  or *e* symbolically.
