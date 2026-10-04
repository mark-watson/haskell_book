# Computing π and e: Three Classical Algorithms Each

This chapter presents two programs that compute π and e. Each constant uses three different algorithms. The point is not to compute π or e — one line of `Prelude` does that. The point is how six classical algorithms behave differently. One needs ten million terms for six digits. One fails due to floating-point rounding. One squeezes the answer between polygons. One algorithm shows why e is irrational.

The programs live in `source-code/maths`. Build and run with:

```bash
cd source-code/maths
cabal run pi      # three methods for π
cabal run e       # three methods for e
```

## π: Three Methods

### 2.1 Madhava-Leibniz: Two Lines, Ten Million Terms

The series

```
π/4 = 1 - 1/3 + 1/5 - 1/7 + 1/9 - ...
```

gives

```$
\pi = 4 \sum_{k=0}^{\infty} \frac{(-1)^k}{2k+1}
```

Everything is elementary: a geometric series, integrated term by term, evaluated at x = 1.

**The trouble is that x = 1 is the boundary of convergence.** The terms `1/(2k+1)` shrink like 1/k. The truncation error after n terms is about 1/n:

```
after n terms:   error ≈ 1/n
```

Measured:

| budget | abs error |
| --- | --- |
| 1,000,000 | 1.000e-6 |
| 10,000,000 | 1.000e-7 |

Ten digits need ten billion terms.

This series converges only conditionally. Group terms and you can make it sum to anything — Riemann's rearrangement theorem. Madhava found it around 1400, two and a half centuries before Leibniz.

### 2.2 Machin: 100 Digits by Hand

```
π = 16·arctan(1/5) - 4·arctan(1/239)
```

John Machin published this in 1706 and used it to compute 100 digits by hand.

**Where does it come from?** Multiply complex numbers:

```
(5+i)⁴ · (239-i) = 114244·(1+i)
```

The argument of `1+i` is 45° = π/4. Arguments add under multiplication, so:

```
4·arctan(1/5) - arctan(1/239) = π/4
```

Multiply by 4. That is the entire proof.

**The magic is small arguments.** The arctangent series converges quickly when x is small. Successive terms shrink by x²:

- arctan(1/5): terms shrink by 1/25 → about 1.4 digits per term
- arctan(1/239): terms shrink by 1/57121 → about 4.8 digits per term

Measured:

| terms | abs error |
| --- | --- |
| 4 | 8.814e-7 |
| 10 | 8.882e-16 |
| 20 | 8.882e-16 |

Each term multiplies error by about 25 until `Double` precision ends.

### 2.3 Archimedes: The Squeeze, 2000 Years Before Calculus

Around 250 BC Archimedes trapped π between inscribed and circumscribed polygons:

```
n·sin(π/n)   <  π
n·tan(π/n)   >  π
```

Starting from a hexagon (6 sides) and doubling repeatedly, he concluded:

```
223/71 < π < 22/7
```

**The error falls off quadratically** because

```$
\begin{aligned}
n\sin(\pi/n) &= \pi - \frac{\pi^3}{6n^2} + \cdots \\
n\tan(\pi/n) &= \pi + \frac{\pi^3}{3n^2} + \cdots
\end{aligned}
```

Every doubling divides error by 4.

**The textbook recurrence is numerically dead.** Written naively:

```
s_{2n} = sqrt(2 - sqrt(4 - s^2))
```

As s shrinks, the inner square root rounds to nearly 2. Subtracting two nearly-equal numbers throws away digits. By 26 doublings the tangent rounds to 0 and the result becomes NaT.

The fix is rationalising the numerator:

```$
s_{2n} = \frac{s_n}{\sqrt{2 + \sqrt{4 - s_n^2}}}
```

**And then the method runs out of bits.** At 25 doublings the error is below `Double` spacing (4.4e-16). More doublings give identical results.

## e: Three Methods

### 3.1 Maclaurin: Factorials, and Why e Is Irrational

```
e = Σ 1/k! = 1 + 1 + 1/2 + 1/6 + 1/24 + ...
```

Convergence is factorial. Term k is 1/k!, so the ratio of consecutive terms is 1/k which improves as you go. Eighteen terms exhaust `Double` precision.

**This is also a proof that e is irrational.** Suppose e = p/q. Multiply by q!:

```
q!·e = (q-1)!·p          ← an integer

q!·e = Σ_{k≤q} q!/k!  +  Σ_{k>q} q!/k!
        integer          strictly between 0 and 1
```

An integer that is not an integer: e cannot be a fraction.

**Do not compute factorials.** `Double` overflows at 171!. The code divides repeatedly: 1/k! = (1/(k-1)!)/k.

### 3.2 Compound Interest: Bernoulli's Limit, Richardson's Rescue

Jacob Bernoulli (1683) discovered e from compound interest:

```$
e = \lim_{n \to \infty} \left(1 + \frac{1}{n}\right)^n
```

As a computational method it is terrible. The error is only e/(2n) — first order. Even n = 10⁶ leaves the sixth decimal wrong.

**Richardson extrapolation cancels the error.** The expansion

```
L(n) = e·(1 - 1/(2n) + 11/(24n²) - ...)
```

shows that `2·L(2n) - L(n)` cancels the 1/n term, leaving error of order 1/n².

| n | raw error | after Richardson |
| --- | --- | --- |
| 10³ | 1.359e-3 | 6.220e-7 |
| 10⁸ | 1.359e-8 | 4.441e-16 |

**The floating-point trap.** Computing `(1 + 1/n)^n` for large n:

```
log(1 + 1/n) rounds 1/n, then multiplies by n, amplifying the error.
```

At n = 10¹² the naive computation is off by eight orders of magnitude with wrong sign.

The code uses `log1p` computed via `2·atanh(x/(2+x))`.

### 3.3 Euler's Continued Fraction: The Pattern e Has

Euler proved:

```
e = [2; 1, 2, 1, 1, 4, 1, 1, 6, 1, 1, 8, ...]
```

The pattern: a₀ = 2, aₖ = 2(k+1)/3 when k ≡ 2 (mod 3), otherwise 1. Almost no number has such a pattern.

Convergents alternate above and below e, closing in quickly. Twenty-one convergents give exact `Double` precision.

**Contrast π.** Its continued fraction has no pattern:

```
π = [3; 7, 15, 1, 292, 1, 1, 1, 2, 1, 3, 1, 14, 2, ...]
```

The large term 292 generates 103993/33102 — nine correct decimals from five digits. The convergent before it is 355/113 — six correct decimals from three digits.

## Code Structure

Both programs follow the same pattern:

1. Three algorithm functions
2. Data type for methods with metadata
3. Command-line interface
4. Timing and reporting

```
maths/
├── pi.hs            π: 3 methods, CLI, reporting
├── e.hs             e: 3 methods, CLI, reporting
├── maths.cabal      two executables
└── README.md        detailed discussion
```

Each program is one file. No shared modules. For two files this is simpler than a module split.

## Running the Methods

| Program | Method | Budget Meaning | Default |
| --- | --- | --- | --- |
| pi | leibniz | terms | 1,000,000 |
| pi | machin | terms each arctangent | 20 |
| pi | archimedes | doublings (n = 6·2ᵏ) | 25 |
| e | taylor | terms of Σ1/k! | 20 |
| e | limit | compounding periods n | 100,000,000 |
| e | continued-fraction | convergents | 30 |

Options:

- `-m NAME` — run one method
- `-n N` — set budget
- `-j` — JSON output
- `-v` — verbose mode
- `--list` — describe methods


## Source Code Listings

The complete source code for both programs is in the `source-code/maths` directory. Each file is self-contained with all algorithm implementations, command-line handling, and output formatting.

### pi.hs

The program estimates π using three classical methods: Madhava-Leibniz series, Machin's arctangent formula, and Archimedes' polygon method.

See `source-code/maths/pi.hs` for the complete implementation.

### e.hs

The program estimates Euler's number e using three methods: Maclaurin series, compound-interest limit with Richardson extrapolation, and Euler's continued fraction.

See `source-code/maths/e.hs` for the complete implementation.

### π Program (pi.hs)

The complete `pi.hs` implementation estimates π using three classical algorithms. The program is self-contained with all algorithm implementations, command-line interface, and reporting logic in a single file.

**Key algorithm: Madhava-Leibniz Series**

The `leibnizPi` function computes π using the alternating series. Each term is added to an accumulator, keeping the computation in constant space.

```haskell
leibnizPi :: Int -> Double
leibnizPi terms
  | terms <= 0 = 0
  | otherwise = 4 * go 0 0 1
  where
    go :: Double -> Int -> Double -> Double
    go acc k denominator
      | k >= terms = acc
      | otherwise = go (acc + sign / denominator) (k + 1) (denominator + 2)
      where
        sign = if even k then 1 else -1
```

**Key algorithm: Machin's Formula**

The `machinPi` function uses Machin's arctangent identity with Taylor series evaluation.

```haskell
machinPi :: Int -> Double
machinPi terms =
  16 * arctanSeries (1 / 5) terms - 4 * arctanSeries (1 / 239) terms
```

**Key algorithm: Archimedes' Method**

The `archimedesPi` function bounds π using inscribed and circumscribed polygons, with numerically stable recurrences.

```haskell
archimedesBounds :: Int -> (Double, Double)
archimedesBounds doublings = go 6 1 (2 / sqrt 3) (max 0 doublings)
  where
    go :: Double -> Double -> Double -> Int -> (Double, Double)
    go sides inscribed circumscribed remaining
      | remaining <= 0 = (sides * inscribed / 2, sides * circumscribed / 2)
      | otherwise = go (2 * sides) inscribed' circumscribed' (remaining - 1)
      where
        inscribed' = inscribed / sqrt (2 + sqrt (4 - inscribed * inscribed))
        circumscribed' = circumscribed / (1 + sqrt (1 + circumscribed * circumscribed / 4))
```

**Full implementation:** See `source-code/maths/pi.hs` for the complete file including imports, command-line handling, and output formatting.

### e Program (e.hs)

The complete `e.hs` implementation estimates Euler's number e using three classical algorithms. The program uses exact rational arithmetic for the continued fraction method.

**Key algorithm: Maclaurin Series**

The `eTaylor` function computes e using the series Σ 1/k!, building each term by division to avoid factorial overflow.

```haskell
eTaylor :: Int -> Double
eTaylor terms
  | terms <= 0 = 0
  | otherwise = go 1 1 1
  where
    go :: Double -> Double -> Int -> Double
    go acc term k
      | k >= terms = acc
      | otherwise = go (acc + next) next (k + 1)
      where
        next = term / fromIntegral k
```

**Key algorithm: Compound Interest Limit with Richardson Extrapolation**

The `eLimitRichardson` function accelerates the convergence of the naive limit using Richardson extrapolation.

```haskell
eLimitRichardson :: Int -> Double
eLimitRichardson n
  | n <= 0 = 0
  | otherwise = 2 * eLimit (2 * n) - eLimit n
```

**Key algorithm: Euler's Continued Fraction**

The `eContinuedFraction` function computes e using Euler's continued fraction with exact rational arithmetic.

```haskell
eContinuedFractionCoef :: Int -> Integer
eContinuedFractionCoef 0 = 2
eContinuedFractionCoef k
  | k `mod` 3 == 2 = 2 * fromIntegral ((k + 1) `div` 3)
  | otherwise = 1
```

**Full implementation:** See `source-code/maths/e.hs` for the complete file including imports, command-line handling, and output formatting.

## Running the Code

To build and run the programs:

```bash
cd source-code/maths
cabal build
cabal run pi      # compute π with three methods
cabal run e       # compute e with three methods
```

For verbose output with method descriptions:

```bash
cabal run pi -- --verbose
cabal run e -- --list
```

To see JSON output:

```bash
cabal run pi -- --json
cabal run e -- --json
```


## Lessons

1. **Error analysis matters.** The Madhava-Leibniz series is simple but slow. Machin's formula is complex but fast.

2. **Numerical stability matters.** Archimedes' naive recurrence fails at 26 doublings. Rationalising helps.

3. **Exact arithmetic beats floating-point.** The continued fraction uses `Rational` until the final conversion.

4. **Convergence rates differ.** Leibniz: 1/n. Machin: geometric. Archimedes: 1/n². Taylor: factorial. Continued fraction: each convergent is the best possible approximation.

5. **Algorithms have stories.** Madhava (1400s), Machin (1706), Archimedes (250 BC), Bernoulli (1683), Euler (1737). Each represents a different era of mathematics.
