-- |
-- Program     : e
-- Description : Estimate Euler's number e with three classical methods.
--
-- A deliberately self-contained program: the three estimators, the command
-- line interface, and the reporting all live in this one file.
--
-- (Despite the traditional name \"Euler's constant\", @e = 2.71828...@ is
-- Euler's number; the Euler-Mascheroni constant is @gamma = 0.57721...@.)
--
-- The three methods are
--
-- 1. 'eTaylor' — the Maclaurin series @sum 1\/k!@, which converges
--    super-linearly.
-- 2. 'eLimitRichardson' — the compound-interest limit @(1 + 1\/n)^n@, with
--    the leading error term removed.
-- 3. 'eContinuedFraction' — the continued fraction @[2; 1, 2, 1, 1, 4, 1, ...]@,
--    evaluated with exact rational arithmetic.
--
-- Examples:
--
-- > cabal run e                              -- all three methods
-- > cabal run e -- -m continued-fraction     -- just the continued fraction
-- > cabal run e -- -m limit -n 1000          -- a deliberately poor limit
-- > cabal run e -- --json                    -- machine readable output
module Main (main) where

import Control.Exception (evaluate)
import Control.Monad (when)
import Data.Char (toLower)
import Data.List (intercalate)
import Data.Ratio ((%))
import GHC.Clock (getMonotonicTime)
import Options.Applicative
import System.Exit (ExitCode (ExitFailure), exitSuccess, exitWith)
import System.IO (BufferMode (LineBuffering), hPutStrLn, hSetBuffering, stderr, stdout)
import Text.Printf (printf)

-- | The closest 'Double' to @e@.  There is no standard library constant to
-- reuse, so the digits are written out.
eReference :: Double
eReference = 2.718281828459045

--------------------------------------------------------------------------------
-- Method 1: the Maclaurin series
--------------------------------------------------------------------------------

-- | The Maclaurin series for @e@:
--
-- \[ e = \sum_{k \ge 0} \frac{1}{k!} = 1 + 1 + \frac{1}{2} + \frac{1}{6} + \cdots \]
--
-- The terms are built up by repeated division, using @1\/k! = (1\/(k-1)!) \/ k@,
-- so no factorials are ever formed and nothing can overflow.  Convergence is
-- faster than geometric: the first 18 terms already exhaust a 'Double'.
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

--------------------------------------------------------------------------------
-- Method 2: the compound-interest limit
--------------------------------------------------------------------------------

-- | The limit that defines @e@ in every calculus course, the value of one
-- unit of currency compounded @n@ times at 100% interest:
--
-- \[ e = \lim_{n \to \infty} \left(1 + \frac{1}{n}\right)^n \]
--
-- It is evaluated as @exp (n * log1p (1\/n))@ rather than by forming
-- @1 + 1\/n@ and taking a power: for large @n@ the addition destroys most of
-- the information in the logarithm, and the naive version stops improving
-- long before @n@ reaches @10^8@.  The bare limit converges only like
-- @1\/n@, so the interesting version of this method is 'eLimitRichardson'.
eLimit :: Int -> Double
eLimit n
  | n <= 0 = 0
  | otherwise = exp (fromIntegral n * log1p (1 / fromIntegral n))

-- | @log (1 + x)@ computed without the cancellation that ruins the naive
-- formula for tiny @x@.
--
-- GHC's @base@ does not export @log1p@, so it is written here as
-- @2 * atanh (x \/ (2 + x))@, using the series
-- @atanh y = y + y^3\/3 + y^5\/5 + ...@.  For @|x| < 10^-4@ the argument of
-- the series is below @5 * 10^-5@, so two terms already reach the precision
-- of a 'Double'; twelve are summed for good measure.
log1p :: Double -> Double
log1p x
  | x <= -1 = log (1 + x)
  | abs x < 1e-4 = 2 * atanhSeries (x / (2 + x))
  | otherwise = log (1 + x)
  where
    atanhSeries y = go y (y * y) 1 0
      where
        go :: Double -> Double -> Int -> Double -> Double
        go power ySquared k acc
          | k >= 25 = acc
          | otherwise =
              go (power * ySquared) ySquared (k + 2) (acc + power / fromIntegral k)

-- | Richardson extrapolation of the compound-interest limit.
--
-- The limit has the asymptotic expansion
--
-- \[ L(n) = \left(1 + \frac{1}{n}\right)^n
--        = e \left(1 - \frac{1}{2n} + O\!\left(\frac{1}{n^2}\right)\right) \]
--
-- so the combination @2 L(2n) - L(n)@ cancels the @1\/n@ term exactly and
-- leaves an error of order @1\/n^2@.  With @n = 10^8@ that is smaller than
-- the gap between neighbouring 'Double' values, and the method reaches
-- machine precision — from a formula that on its own converges abominably.
eLimitRichardson :: Int -> Double
eLimitRichardson n
  | n <= 0 = 0
  | otherwise = 2 * eLimit (2 * n) - eLimit n

--------------------------------------------------------------------------------
-- Method 3: the continued fraction
--------------------------------------------------------------------------------

-- | Partial quotients of the simple continued fraction for @e@:
--
-- \[ e = [2; 1, 2, 1, 1, 4, 1, 1, 6, 1, 1, 8, \ldots] \]
--
-- The pattern, discovered by Euler, is @a(3j+2) = 2(j+1)@ with @1@ in every
-- other position.  It is one of the few continued fractions whose coefficients
-- are known in closed form.
eContinuedFractionCoef :: Int -> Integer
eContinuedFractionCoef 0 = 2
eContinuedFractionCoef k
  | k `mod` 3 == 2 = 2 * fromIntegral ((k + 1) `div` 3)
  | otherwise = 1

-- | The convergents @p_k \/ q_k@ of that continued fraction, as exact
-- rationals:
--
-- \[ \frac{p_k}{q_k} = a_k \frac{p_{k-1}}{q_{k-1}} + \frac{p_{k-2}}{q_{k-2}} \]
--
-- The list begins @2, 3, 8\/3, 11\/4, 19\/7, 87\/32, 106\/39, 193\/71, ...@
-- and alternates around @e@.  Because the recurrence is carried out in exact
-- 'Integer' arithmetic, the only error in the resulting estimate is the
-- truncation of the fraction itself plus the final rounding to 'Double'.
eConvergents :: [Rational]
eConvergents = go 1 2 0 1 0
  where
    go :: Integer -> Integer -> Integer -> Integer -> Int -> [Rational]
    go pPrev pCur qPrev qCur k = (pCur % qCur) : go pCur pNext qCur qNext (k + 1)
      where
        a = eContinuedFractionCoef (k + 1)
        pNext = a * pCur + pPrev
        qNext = a * qCur + qPrev

-- | The @terms@-th convergent (counting from one) as a 'Double'.  Roughly
-- thirty convergents are enough for machine precision.
eContinuedFraction :: Int -> Double
eContinuedFraction terms
  | terms <= 0 = 0
  | otherwise = fromRational (eConvergents !! (terms - 1))

--------------------------------------------------------------------------------
-- The three methods, as data
--------------------------------------------------------------------------------

-- | The three methods offered by this program.
data Method
  = Taylor
  | CompoundInterest
  | ContinuedFraction
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | All methods, in the order they are presented to the user.
allMethods :: [Method]
allMethods = [minBound .. maxBound]

-- | Command line name of a method.
methodKey :: Method -> String
methodKey Taylor = "taylor"
methodKey CompoundInterest = "limit"
methodKey ContinuedFraction = "continued-fraction"

-- | One line description of the mathematics.
methodSummary :: Method -> String
methodSummary Taylor =
  "Maclaurin series sum 1/k!; super-linear, machine precision in ~18 terms"
methodSummary CompoundInterest =
  "compound interest limit (1+1/n)^n with Richardson extrapolation; error ~ 1/n^2"
methodSummary ContinuedFraction =
  "continued fraction [2; 1,2,1, 1,4,1, 1,6,1, ...] evaluated in exact rationals"

-- | What the budget counts for this method.
methodBudgetLabel :: Method -> String
methodBudgetLabel Taylor = "terms"
methodBudgetLabel CompoundInterest = "periods"
methodBudgetLabel ContinuedFraction = "convergents"

-- | Default budget for each method.
methodDefaultBudget :: Method -> Int
methodDefaultBudget Taylor = 20
methodDefaultBudget CompoundInterest = 100000000
methodDefaultBudget ContinuedFraction = 30

-- | Evaluate one method with the given budget.
estimate :: Method -> Int -> Double
estimate Taylor = eTaylor
estimate CompoundInterest = eLimitRichardson
estimate ContinuedFraction = eContinuedFraction

--------------------------------------------------------------------------------
-- Running methods and reporting the result
--------------------------------------------------------------------------------

-- | The result of running one method once.
data Outcome = Outcome
  { outcomeMethod :: Method
  , outcomeBudget :: Int
  , outcomeEstimate :: Double
  , outcomeError :: Double
  -- ^ Absolute difference from 'eReference'.
  , outcomeSeconds :: Double
  -- ^ Wall clock time taken by the estimate.
  }

-- | Run a method with a given budget and time it.
--
-- The estimate is forced with 'evaluate' inside the timed region: without
-- that, laziness would happily time the construction of an unevaluated thunk
-- and report that a thirty-convergent fraction takes no time at all.
runMethod :: Method -> Int -> IO Outcome
runMethod method budget = do
  start <- getMonotonicTime
  estimateValue <- evaluate (estimate method budget)
  end <- getMonotonicTime
  pure
    Outcome
      { outcomeMethod = method
      , outcomeBudget = budget
      , outcomeEstimate = estimateValue
      , outcomeError = abs (estimateValue - eReference)
      , outcomeSeconds = end - start
      }

-- | Render the outcomes as an aligned comparison table.
renderTable :: [Outcome] -> String
renderTable outcomes =
  unlines $
    [ "e"
    , printf "reference value : %.15f" eReference
    , ""
    , printf headerFormat "method" "budget" "estimate" "abs error" "time"
    , separator
    ]
      ++ map row outcomes
  where
    headerFormat = "%-18s  %12s  %-19s  %-11s  %10s"
    rowFormat = "%-18s  %12s  %-19.15f  %-11.3e  %9.6fs"
    separator = intercalate "  " (map (\w -> replicate w '-') [18, 12, 19, 11, 10])

    row outcome =
      printf
        rowFormat
        (methodKey (outcomeMethod outcome))
        (addCommas (outcomeBudget outcome))
        (outcomeEstimate outcome)
        (outcomeError outcome)
        (outcomeSeconds outcome)

-- | Render the outcomes as a small JSON document.
--
-- Hand rolled on purpose: a program whose entire dependency list is @base@
-- plus the option parser should not pull in a JSON library to print five
-- fields, and the escaping needed here is trivial (every string is a method
-- key we chose ourselves).
renderJson :: [Outcome] -> String
renderJson outcomes =
  unlines $
    [ "{"
    , "  \"constant\": \"e\","
    , printf "  \"reference\": %s," (jsonDouble eReference)
    , "  \"results\": ["
    ]
      ++ commaSeparated (map entry outcomes)
      ++ ["  ]", "}"]
  where
    entry outcome =
      printf
        "    { \"method\": \"%s\", \"budget\": %d, \"estimate\": %s, \"abs_error\": %s, \"seconds\": %.6f }"
        (methodKey (outcomeMethod outcome))
        (outcomeBudget outcome)
        (jsonDouble (outcomeEstimate outcome))
        (jsonDouble (outcomeError outcome))
        (outcomeSeconds outcome)

    commaSeparated [] = []
    commaSeparated [x] = [x]
    commaSeparated (x : xs) = (x ++ ",") : commaSeparated xs

-- | One line description of a method, used by the @--list@ flag.
describeMethod :: Method -> String
describeMethod method =
  printf
    "  %-18s %-12s default %-11s %s"
    (methodKey method)
    (methodBudgetLabel method)
    (addCommas (methodDefaultBudget method))
    (methodSummary method)

-- | Group the digits of an integer with commas: @1000000 -> \"1,000,000\"@.
addCommas :: Int -> String
addCommas n = reverse (go (reverse (show n)))
  where
    -- Consume three digits at a time, inserting a separator only when more
    -- digits follow; otherwise 999 would come out as ",999".
    go (a : b : c : rest@(_ : _)) = a : b : c : ',' : go rest
    go rest = rest

-- | The shortest decimal string that reads back as the same 'Double', which is
-- what 'show' produces and exactly what a JSON number should look like.
jsonDouble :: Double -> String
jsonDouble = show

--------------------------------------------------------------------------------
-- Command line interface
--------------------------------------------------------------------------------

-- | Raw command line options.
data Options = Options
  { optMethodKeys :: [String]
  , optBudget :: Maybe Int
  , optJson :: Bool
  , optVerbose :: Bool
  , optList :: Bool
  }

-- | The list of method names accepted by @--method@.
methodChoices :: String
methodChoices = intercalate ", " (map methodKey allMethods) ++ ", all"

optionsParser :: Parser Options
optionsParser =
  Options
    <$> many
      ( strOption
          ( long "method"
              <> short 'm'
              <> metavar "METHOD"
              <> help ("estimation method: " ++ methodChoices ++ " (default: all)")
          )
      )
    <*> optional
      ( option
          auto
          ( long "terms"
              <> short 'n'
              <> metavar "N"
              <> help "budget: series terms, compounding periods, or convergents"
          )
      )
    <*> switch (long "json" <> short 'j' <> help "emit JSON instead of a table")
    <*> switch (long "verbose" <> short 'v' <> help "print a description of each method")
    <*> switch (long "list" <> help "list the available methods and exit")

-- | Turn the @--method@ keys into methods, rejecting unknown ones.  An empty
-- list (no @--method@ given) means \"all methods\".
resolveMethods :: [String] -> Either String [Method]
resolveMethods [] = Right allMethods
resolveMethods keys = concat <$> traverse resolve keys
  where
    resolve key
      | normalised == "all" = Right allMethods
      | otherwise = case filter ((== normalised) . methodKey) allMethods of
          [method] -> Right [method]
          _ -> Left ("unknown method " ++ show key ++ "; try " ++ methodChoices)
      where
        normalised = map toLower key

parserInfo :: ParserInfo Options
parserInfo =
  info
    (optionsParser <**> helper)
    ( fullDesc
        <> progDesc "Estimate Euler's number e with three classical methods"
        <> header "e - three ways to compute 2.718281828459045"
    )

main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  options <- execParser parserInfo
  if optList options
    then do
      putStrLn "e estimation methods:"
      mapM_ (putStrLn . describeMethod) allMethods
      exitSuccess
    else case resolveMethods (optMethodKeys options) of
      Left message -> do
        hPutStrLn stderr ("e: " ++ message)
        exitWith (ExitFailure 2)
      Right methods -> do
        when (optVerbose options) $ do
          putStrLn "e estimation methods:"
          mapM_ (putStrLn . describeMethod) methods
          putStrLn ""
        let budgetFor method = maybe (methodDefaultBudget method) id (optBudget options)
        outcomes <- traverse (\method -> runMethod method (budgetFor method)) methods
        if optJson options
          then putStr (renderJson outcomes)
          else putStr (renderTable outcomes)
