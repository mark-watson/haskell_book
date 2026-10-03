# maths — π and e, three ways each

Two self-contained Haskell programs, one per constant. Each computes its
number three times, by three genuinely different algorithms, and prints how
wrong each answer is:

| | method 1 | method 2 | method 3 |
| --- | --- | --- | --- |
| **π** | Madhava–Leibniz series | Machin's arctangent formula | Archimedes' polygons |
| **e** | Maclaurin series | compound-interest limit | Euler's continued fraction |

The point is not to compute π or e — one line of `Prelude` does that. The point
is that six classical algorithms, every one of them correct mathematics, behave
nothing alike. One needs ten million terms to reach six digits. One is
destroyed by floating-point rounding in a form that looks perfectly innocent.
One squeezes the answer between two polygons until it runs out of bits. And one
is the reason we know e is irrational. This README is mostly about that.

---

# 1. Running it

## Requirements

GHC and cabal, installed with [GHCup](https://www.haskell.org/ghcup/):

```console
$ ghc --version
The Glorious Glasgow Haskell Compilation System, version 9.10.3
$ cabal --version
cabal-install version 3.16.1.0
```

The only dependency is `optparse-applicative`. The mathematics uses nothing
beyond `base`, `Data.Ratio` and `GHC.Clock`.

## Build and run

```console
$ make build          # cabal build all
$ make run-pi         # cabal run pi
$ make run-e          # cabal run e
$ make check          # cabal build all -O0   (fast rebuilds while editing)
$ make list           # describe the methods of both programs
$ make clean          # cabal clean
```

The same thing without `make`:

```console
$ cabal run pi
$ cabal run e
```

Either program accepts the same options:

| Option | Meaning |
| --- | --- |
| `-m`, `--method NAME` | run one method; repeat for several. `all` (the default) runs everything |
| `-n`, `--terms N` | budget for the selected methods, overriding each default |
| `-j`, `--json` | machine-readable output instead of the table |
| `-v`, `--verbose` | print a description of each method first |
| `--list` | describe the available methods and exit |
| `-h`, `--help` | usage |

## Default output

```console
$ cabal run pi
pi
reference value : 3.141592653589793

method                    budget  estimate             abs error          time
------------------  ------------  -------------------  -----------  ----------
leibniz                1,000,000  3.141591653589774    1.000e-6      0.169640s
machin                        20  3.141592653589794    8.882e-16     0.000008s
archimedes                    25  3.141592653589795    1.776e-15     0.000030s
```

```console
$ cabal run e
e
reference value : 2.718281828459045

method                    budget  estimate             abs error          time
------------------  ------------  -------------------  -----------  ----------
taylor                        20  2.718281828459046    4.441e-16     0.000197s
limit                100,000,000  2.718281828459045    4.441e-16     0.000069s
continued-fraction            30  2.718281828459045    0.000e0       0.000250s
```

Read the last digit of `machin`: `...794` where the reference has `...793`.
That digit is not a defect in Machin's formula — it is the arithmetic running
out of room. The formula is exact; a `Double` is not.

## What one unit of budget means

The `-n` flag means something different for every method, which is the
interesting part:

| Method | `-n` counts | Default |
| --- | --- | --- |
| `pi -m leibniz` | terms of the alternating series | 1,000,000 |
| `pi -m machin` | terms of each arctangent series | 20 |
| `pi -m archimedes` | doublings of the polygon's sides (n = 6·2ᵏ) | 25 |
| `e -m taylor` | terms of Σ1/k! | 20 |
| `e -m limit` | compounding periods n | 100,000,000 |
| `e -m continued-fraction` | convergents of the continued fraction | 30 |

## Runs worth trying

```console
# the same budget, two wildly different answers
$ cabal run pi -- -m leibniz -n 1000000      # 1.000e-6
$ cabal run pi -- -m machin  -n 1000000      # 8.882e-16

# each doubling of Archimedes' polygon cuts the error by 4
$ cabal run pi -- -m archimedes -n 10        # 6.845e-8
$ cabal run pi -- -m archimedes -n 11        # 1.711e-8

# Bernoulli's limit after one Richardson step: error falls like 1/n^2
$ cabal run e -- -m limit -n 1000            # 6.220e-7  (raw limit: 1.359e-3)
$ cabal run e -- -m limit -n 100000000       # 4.441e-16 (raw limit: 1.359e-8)

# watch a method saturate: identical estimates from 21 convergents onwards
$ cabal run e -- -m continued-fraction -n 21
$ cabal run e -- -m continued-fraction -n 40
```

---

# 2. Three ways to get π

## 2.1 Madhava–Leibniz: two lines of code, ten million terms

```
π/4 = 1 - 1/3 + 1/5 - 1/7 + 1/9 - ...
π   = 4 · Σ (-1)^k / (2k+1)
```

The series comes from expanding the integrand of the arctangent,

```
arctan x = ∫₀ˣ dt/(1+t²) = ∫₀ˣ (1 - t² + t⁴ - ...) dt
         = x - x³/3 + x⁵/5 - ...
```

and setting x = 1, where the left side is π/4. Everything is elementary: a
geometric series, integrated term by term, evaluated at the one point that
gives π.

**The trouble is that x = 1 is exactly the boundary of the geometric series'
interval of convergence.** At x = 1 the terms `1/(2k+1)` shrink to zero, but
only like 1/k — and that, not the 4 or the signs, sets the accuracy:

```
after n terms:   error ≈ 1/n
```

Measured, with this program:

| budget | abs error |
| --- | --- |
| 1,000,000 | 1.000e-6 |
| 10,000,000 | 1.000e-7 |

Ten digits would need ten *billion* terms. The estimate of the error is not
merely an upper bound, it is almost exactly 1/n, and the reason is worth
noticing: the first neglected term is `4/(2n+1) ≈ 2/n`, and since consecutive
terms are nearly equal, the alternating tail behind it sums to about *half*
its first term — leaving 1/n.

Two more things make this series interesting rather than merely slow:

* **It converges only conditionally.** Group or reorder the terms and you can
  make it sum to anything you want — Riemann's rearrangement theorem. The
  series does not have a "sum" so much as a value that depends on the order
  you add things in.
* **Madhava got there first.** This is the Madhava–Leibniz series because the
  Kerala school had it around 1400, two and a half centuries before Gregory
  (1671) and Leibniz (1674) rediscovered it in Europe.

It survives in this project as the honest baseline: the algorithm everybody
writes first, and the one nobody should use.

## 2.2 Machin: 100 digits by hand, and a one-line proof

```
π = 16·arctan(1/5) - 4·arctan(1/239)
```

John Machin published this in 1706 and used it to compute 100 digits of π by
hand. Formulas of this shape were behind every record for the next 250 years.

Where does such a strange identity come from? Multiply two complex numbers in
your head:

```
(5+i)² = 24 + 10i
(5+i)⁴ = (24+10i)² = 476 + 480i
(5+i)⁴ · (239-i) = 114244 + 114244i = 114244·(1+i)
```

A complex number's argument is the angle it makes with the real axis, and
`114244·(1+i)` points at exactly 45° = π/4. Arguments add under multiplication,
so:

```
4·arg(5+i) + arg(239-i) = π/4
4·arctan(1/5) - arctan(1/239) = π/4
```

Multiply by 4 and you have Machin's formula. That is the entire proof — no
calculus, no series, just the fact that `114244 + 114244i` sits on the diagonal.

The practical magic is in the *small arguments*. The arctangent series from
2.1 converges quickly when x is small, because successive terms shrink by x²:

```
arctan(1/5):   terms shrink by 1/25   →  log₁₀25 ≈ 1.4 digits per term
arctan(1/239): terms shrink by 1/57121 →  log₁₀57121 ≈ 4.8 digits per term
```

Measured on this implementation:

| terms | abs error |
| --- | --- |
| 4 | 8.814e-7 |
| 5 | 2.881e-8 |
| 6 | 9.745e-10 |
| 8 | 1.191e-12 |
| 10 | 8.882e-16 ← the floating-point floor |
| 20 | 8.882e-16 ← six times the work, nothing gained |

Each term multiplies the error by about 25, exactly as predicted, until the
result runs into the last bit of a `Double` — two ulps of π — and stops.

**Why this mattered.** Hand computation has no error checking. William Shanks
published 707 digits of π in 1873 after fifteen years of work, and in 1946
D. F. Ferguson found by recomputation that only the first 527 were right: the
last 180 digits had been wrong for seventy years and nobody could tell. What
Machin's formula offered was not only speed but a check — arctangent identities
can be varied and run against one another, so a mistake shows up as a
disagreement instead of as silence.

## 2.3 Archimedes: the squeeze, 2000 years before calculus

Around 250 BC Archimedes trapped a circle between two 96-sided polygons and
concluded:

```
223/71 = 3.1408... < π < 3.1429... = 22/7
```

No trigonometry, no algebra, no decimal notation — just geometry and a
willingness to double the number of sides. For an n-sided regular polygon
around a unit circle:

```
inscribed half-perimeter:      n·sin(π/n)   <  π
circumscribed half-perimeter:  n·tan(π/n)   >  π
```

A chord is shorter than the arc it spans and a tangent is longer, so these
bracket π from both sides — an *interval*, not an estimate. This is the method
of exhaustion, the direct ancestor of the limit: a constant pinned down by a
controlled limiting process, two thousand years before anyone had the words for
one.

Archimedes' actual computation doubled the sides four times, from a hexagon
(6 → 12 → 24 → 48 → 96) without ever taking a sine. The recurrence he used in
geometric form is, in modern notation, a half-angle formula:

```
s₂ₙ = sₙ / √(2 + √(4 - sₙ²))        starting from s₆ = 1
t₂ₙ = tₙ / (1 + √(1 + tₙ²/4))      starting from t₆ = 2/√3
```

**The error falls off quadratically**, because both half-perimeters miss π by
terms of order 1/n²:

```
n·sin(π/n) = π - π³/(6n²) + ...
n·tan(π/n) = π + π³/(3n²) + ...
midpoint   = π + π³/(12n²) + ...
```

so every doubling of n divides the error by 4. Measured against the prediction
`π³/(12n²)`:

| doublings | sides n | measured error | π³/(12n²) |
| --- | --- | --- | --- |
| 5 | 192 | 7.011e-5 | 7.009e-5 |
| 10 | 6,144 | 6.845e-8 | 6.845e-8 |
| 15 | 196,608 | 6.685e-11 | 6.684e-11 |
| 20 | 6,291,456 | 6.617e-14 | 6.528e-14 |
| 25 | 201,326,592 | 1.776e-15 | 6.375e-17 |
| 30 | 6,442,450,944 | 1.776e-15 | 6.2e-20 |

Two lessons are hiding in that table.

**The textbook form of the recurrence is numerically dead.** Written the
obvious way round, `s₂ₙ = √(2 - √(4 - sₙ²))`, the two square roots each round
to nearly 2 as sₙ shrinks, and subtracting two nearly-equal numbers throws away
the digits that mattered. Running that version:

| doublings | naive | stable |
| --- | --- | --- |
| 10 | 6.864e-8 | 6.845e-8 |
| 15 | 3.630e-7 | 6.685e-11 |
| 20 | 4.838e-4 | 6.617e-14 |
| 25 | 6.898e-2 | 1.776e-15 |
| 26 | tangent side rounds to 0 | 1.776e-15 |
| 30 | **NaN** | 1.776e-15 |

The naive version is fine for the first ten doublings, then loses digits
steadily. By 26 doublings the tangent side length has rounded to exactly 0, and
the recurrence divides by it; from that point on every value is NaN. Nothing
crashes and nothing warns — the numbers simply stop being numbers — which is
what makes numerical analysis a subject rather than a footnote. The fix is one
algebraic step, rationalising the numerator:

```
2 - √(4 - s²) = s² / (2 + √(4 - s²))
```

which is the same number computed without any cancellation, and is what
`pi.hs` uses.

**And then the method runs out of bits.** At 25 doublings the truncation error
`π³/(12n²)` is 6.4e-17, already below the spacing between neighbouring
`Double` values near π (4.4e-16). Doubling five more times — 6.4 billion sides,
32 times the work — returns the identical estimate. The limit is real but it is
no longer representable.

---

# 3. Three ways to get e

## 3.1 Maclaurin: factorials, and why e is irrational

```
e = Σ 1/k! = 1 + 1 + 1/2 + 1/6 + 1/24 + ...
```

The series follows from the property that defines e — `d/dx eˣ = eˣ` with
`e⁰ = 1` — since differentiating the series term by term returns itself.

Its convergence is not geometric, it is factorial. Term k is 1/k! and the ratio
of consecutive terms is 1/k, which *improves* as you go:

| terms | abs error |
| --- | --- |
| 10 | 3.029e-7 |
| 15 | 8.149e-13 |
| 17 | 2.220e-15 |
| 18 | 4.441e-16 ← one ulp of e |
| 20 | 4.441e-16 |

Eighteen terms. Each additional term is worth about one more decimal digit —
a rate no geometric series can match.

**This series is also a proof that e is irrational**, and it takes three lines.
Suppose e = p/q for integers p and q. Multiply by q!:

```
q!·e = q!·p/q = (q-1)!·p          ← an integer
```

On the other hand, split the series at k = q:

```
q!·e = Σ_{k≤q} q!/k!  +  Σ_{k>q} q!/k!
        └─ integer ─┘    └─ strictly between 0 and 1 ─┘
```

The first part is a whole number. The tail is positive but smaller than
`1/(q+1) + 1/(q+1)² + ... < 1/q ≤ 1`. An integer that is not an integer: e
cannot be a fraction. (Euler proved this in 1737; Hermite showed in 1873 that
e is not merely irrational but transcendental.)

**A practical note from the implementation:** do not compute factorials.
A `Double` overflows at 171! — 170! is the last factorial it can hold — so a
direct `1/fromIntegral (factorial k)` would produce `Infinity` long before the
series finished. `e.hs` instead divides repeatedly, using
`1/k! = (1/(k-1)!)/k`, which never forms a factorial at all and is also faster.

## 3.2 Compound interest: Bernoulli's limit, and Richardson's rescue

The second method is where e was actually discovered, in 1683, by Jacob
Bernoulli, in a question about money. If a bank pays 100% interest per year and
compounds n times, one unit of currency becomes

```
L(n) = (1 + 1/n)ⁿ
```

and with continuous compounding, n → ∞, this tends to e. Bernoulli could only
show that the limit lies between 2 and 3.

**As a computational method it is terrible.** Take the logarithm and expand:

```
log L(n) = n·log(1 + 1/n)
         = 1 - 1/(2n) + 1/(3n²) - 1/(4n³) + ...

so  L(n) = e·(1 - 1/(2n) + 11/(24n²) - ...)
```

The error is only **e/(2n)** — first order. Even a million compounding periods
leave the sixth decimal wrong:

```
raw limit, n = 10⁶:  error 1.359e-6
raw limit, n = 10⁸:  error 1.359e-8
```

**But that expansion is also the cure.** The 1/n error term is a nuisance that
depends on n in a known way, so evaluate the limit at two different values of n
and cancel it:

```
L(n)   = e·(1 - 1/(2n) + ...)
L(2n)  = e·(1 - 1/(4n) + ...)

2·L(2n) - L(n) = e·(1 - 11/(48n²) + ...)     ← the 1/n terms cancel exactly
```

This is Richardson extrapolation, and it turns an O(1/n) method into an
O(1/n²) one for the price of a second evaluation:

| n | raw error ≈ e/(2n) | measured after Richardson | predicted 11e/(48n²) |
| --- | --- | --- | --- |
| 10³ | 1.359e-3 | 6.220e-7 | 6.229e-7 |
| 10⁶ | 1.359e-6 | 6.235e-13 | 6.229e-13 |
| 10⁸ | 1.359e-8 | 4.441e-16 — one ulp of e | 6.2e-17 — below the ulp |

At n = 10⁸ that one multiplication and one subtraction buy a factor of thirty
million. (The `limit` method in `e.hs` is this accelerated version; the raw
limit is still there as `eLimit`, which `eLimitRichardson` calls twice.)

### The floating-point trap underneath it

To evaluate `L(n) = (1 + 1/n)ⁿ` you go through the logarithm — either
explicitly, or inside `(**)`, which is how it is implemented. That is where a
correct formula silently becomes a wrong one: forming `1 + 1/n` rounds it, and
`log` of a number very close to 1 amplifies that rounding by a factor of 1/x.
Measured in Haskell (GHC 9.10.3, `-O0`):

| n | `(1+1/n)**n` | `exp (n * log (1+1/n))` | theory: -e/(2n) | `exp (n * log1p (1/n))` |
| --- | --- | --- | --- | --- |
| 10⁴ | -1.3590e-4 | -1.3590e-4 | -1.3591e-4 | -1.3590e-4 |
| 10⁶ | -1.3594e-6 | -1.3594e-6 | -1.3591e-6 | -1.3591e-6 |
| 10⁸ | **-3.0112e-8** | **-3.0112e-8** | -1.3591e-8 | -1.3591e-8 |
| 10¹² | **+2.4167e-4** | **+2.4167e-4** | -1.3591e-12 | -1.3589e-12 |

At n = 10¹² the direct computation is off by eight orders of magnitude and has
the *wrong sign* — the value is drifting away from e rather than towards it.
Note that `**` and the explicit log/exp agree bit for bit: GHC's `(**)` goes
through `log` internally, so the naive version is not a strawman, it is what
you get by writing the formula down.

`log1p (x) = log (1+x)`, computed without forming `1+x` and cancelling, keeps
the true truncation error at every n. `base` does not export `log1p`, so `e.hs`
implements it the classical way:

```
log1p x = 2·atanh(x/(2+x)),   atanh y = y + y³/3 + y⁵/5 + ...
```

For x = 10⁻¹² the series argument is 5·10⁻¹³ and one term is all a `Double`
needs. That single helper is the difference between a method that works and one
that does not.

## 3.3 Euler's continued fraction: the pattern π doesn't have

```
e = [2; 1, 2, 1, 1, 4, 1, 1, 6, 1, 1, 8, 1, 1, 10, ...]
```

In 1737 Euler proved that e has this continued fraction — and used it to prove
e is irrational. Like Machin's formula, the coefficients are known in closed
form: a₀ = 2, and aₖ = 2(k+1)/3 when k ≡ 2 (mod 3), otherwise 1. Almost no
number has a pattern like this.

You evaluate it by *convergents*, the fractions you get by cutting the
expansion off at each step:

```
2,  3,  8/3,  11/4,  19/7,  87/32,  106/39,  193/71,  1264/465, ...
```

each one from `pₖ = aₖpₖ₋₁ + pₖ₋₂` over `qₖ = aₖqₖ₋₁ + qₖ₋₂`. The convergents
take turns being below and above e, closing in on alternate sides.

**Convergents are the best rational approximations that exist.** A convergent
p/q beats every fraction with a smaller denominator, and satisfies

```
|e - p/q| < 1/(qₖ·qₖ₊₁) < 1/qₖ²
```

That is why the method is so strong here: the denominators grow by a factor of
aₖ each step, and the non-unit coefficients keep growing (2, 4, 6, 8, ...), so
the denominators grow faster than any exponential. Measured:

| convergents | abs error |
| --- | --- |
| 10 | 1.754e-6 |
| 15 | 1.364e-11 |
| 18 | 1.998e-14 |
| 20 | 8.882e-16 |
| 21 | **0.000e0** — exact |
| 25 | 0.000e0 |

At 21 convergents the fraction is 410105312/150869313, a ratio with a nine-digit
denominator, and converting it gives *exactly* the `Double` nearest to e. Every
further convergent is pointless, which is why the default budget is 30 and why
the error column reads a flat zero.

**And here is the contrast that makes this the right place to finish.** π's own
continued fraction has no known pattern at all:

```
π = [3; 7, 15, 1, 292, 1, 1, 1, 2, 1, 3, 1, 14, 2, ...]
```

A large partial quotient means an unusually good approximation, and that 292
generates 103993/33102 — nine correct decimals from a five-digit denominator.
The convergent just before it is the famous one:

```
355/113 = 3.14159292...   six correct decimals from a three-digit denominator
```

Zu Chongzhi found that fraction in China around 480 AD, a millennium before
Europe, and it is still the best approximation to π that fits in three digits.
So the two constants have opposite characters: e is *easy* to approximate by
fractions because its continued fraction is riddled with large terms, while π
resists — its coefficients are irregular, and the good approximations look like
accidents rather than structure. (The hardest number of all to approximate is
the golden ratio, `[1; 1, 1, 1, ...]`, whose partial quotients are all as small
as possible.)

---

# 4. Reference values and layout

The reference values are `pi` from `Prelude` and the literal
`2.718281828459045`, both the nearest `Double` to their constant. Errors in
every table above are measured against them, so "0.000e0" means the program and
the reference are bit-identical.

```
maths/
├── pi.hs            the whole π program: 3 methods, CLI, reporting
├── e.hs             the whole e program: 3 methods, CLI, reporting
├── maths.cabal      two executables, hs-source-dirs: .
├── cabal.project
├── Makefile
└── README.md
```

There is deliberately no `src/` library and no `app/` directory: each program is
one file, its mathematics first, so either can be read or printed on its own.
The cost is that `addCommas` and the table renderer are written twice. For two
programs of this size that is a cheaper price than a module split.
