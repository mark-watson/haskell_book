-- |
-- Program     : pi
-- Description : Estimate pi with three classical methods.
--
-- A deliberately self-contained program: the three estimators, the command
-- line interface, and the reporting all live in this one file.
--
-- The three methods are
--
-- 1. 'leibnizPi' — the Madhava-Leibniz alternating series.  Two lines of
--    code, but the error only falls off like @1\/n@.
-- 2. 'machinPi' — Machin's 1706 arctangent formula.  Twenty terms are enough
--    to saturate a 'Double'.
-- 3. 'archimedesPi' — Archimedes' inscribed and circumscribed polygons, which
--    squeeze @pi@ between two explicit bounds.
--
-- Examples:
--
-- > cabal run pi                       -- all three methods, default budgets
-- > cabal run pi -- -m machin -n 10    -- one method, ten arctangent terms
-- > cabal run pi -- --json             -- machine readable output
-- > cabal run pi -- --list             -- describe the available methods
module Main (main) where

import Control.Exception (evaluate)
import Control.Monad (when)
import Data.Char (toLower)
import Data.List (intercalate)
import GHC.Clock (getMonotonicTime)
import Options.Applicative
import System.Exit (ExitCode (ExitFailure), exitSuccess, exitWith)
import System.IO (BufferMode (LineBuffering), hPutStrLn, hSetBuffering, stderr, stdout)
import Text.Printf (printf)

-- | The closest 'Double' to @pi@.  The standard library's 'pi' is correctly
-- rounded, so there is no reason to write the digits out by hand.
piReference :: Double
piReference = pi

--------------------------------------------------------------------------------
-- Method 1: the Madhava-Leibniz series
--------------------------------------------------------------------------------

-- | The Madhava-Leibniz alternating series
--
-- \[ \pi = 4 \sum_{k \ge 0} \frac{(-1)^k}{2k+1} \]
--
-- It could hardly be simpler, and it could hardly be slower: the truncation
-- error after @n@ terms is still about @1\/n@, so a million terms buy only
-- six correct decimals.  The alternating sum is evaluated left to right with
-- an explicit accumulator, which keeps it in constant space.
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

--------------------------------------------------------------------------------
-- Method 2: Machin's arctangent formula
--------------------------------------------------------------------------------

-- | Machin's formula (1706):
--
-- \[ \pi = 16 \arctan \tfrac{1}{5} - 4 \arctan \tfrac{1}{239} \]
--
-- The arctangents are evaluated with the Taylor series of 'arctanSeries'.
-- Both arguments are small, so the terms shrink quickly: by @1\/25@ in the
-- first series and by @1\/57121@ in the second.  Twenty terms already take the
-- result to the limit of 'Double' precision, which is why this formula was
-- used to set records for hand computation.
machinPi :: Int -> Double
machinPi terms =
  16 * arctanSeries (1 / 5) terms - 4 * arctanSeries (1 / 239) terms

-- | Taylor series for @arctan x@, truncated after @terms@ terms:
--
-- \[ \arctan x = \sum_{k \ge 0} \frac{(-1)^k x^{2k+1}}{2k+1} \]
--
-- Valid for @|x| <= 1@; it is only useful in practice for small @x@.  The
-- running power @x^(2k+1)@ is carried along instead of being recomputed, so
-- each term costs one multiplication.
arctanSeries :: Double -> Int -> Double
arctanSeries x terms
  | terms <= 0 = 0
  | otherwise = go 0 0 x
  where
    xSquared = x * x
    go :: Double -> Int -> Double -> Double
    go acc k power
      | k >= terms = acc
      | otherwise =
          go (acc + sign * power / fromIntegral (2 * k + 1)) (k + 1) (power * xSquared)
      where
        sign = if even k then 1 else -1

--------------------------------------------------------------------------------
-- Method 3: Archimedes' polygons
--------------------------------------------------------------------------------

-- | Bracket @pi@ between the half-perimeters of regular polygons inscribed in
-- and circumscribed about the unit circle.
--
-- The calculation starts from a hexagon and doubles the number of sides
-- @doublings@ times.  For an @n@-gon the two half-perimeters are @n sin(pi\/n)@
-- (a lower bound) and @n tan(pi\/n)@ (an upper bound), so the returned pair is
-- a genuine interval containing @pi@.
--
-- The recurrences used are the numerically stable forms:
--
-- \[ s_{2n} = \frac{s_n}{\sqrt{2 + \sqrt{4 - s_n^2}}}, \qquad
--    t_{2n} = \frac{t_n}{1 + \sqrt{1 + t_n^2/4}} \]
--
-- where @s_6 = 1@ and @t_6 = 2\/\sqrt{3}@.  Written the more obvious way
-- round, as @sqrt (2 - sqrt (4 - s^2))@, they lose most of their significant
-- digits as @s@ shrinks.
archimedesBounds :: Int -> (Double, Double)
archimedesBounds doublings = go 6 1 (2 / sqrt 3) (max 0 doublings)
  where
    go :: Double -> Double -> Double -> Int -> (Double, Double)
    go sides inscribed circumscribed remaining
      | remaining <= 0 = (sides * inscribed / 2, sides * circumscribed / 2)
      | otherwise = go (2 * sides) inscribed' circumscribed' (remaining - 1)
      where
        inscribed' =
          inscribed / sqrt (2 + sqrt (4 - inscribed * inscribed))
        circumscribed' =
          circumscribed / (1 + sqrt (1 + circumscribed * circumscribed / 4))

-- | Archimedes' point estimate: the midpoint of the inscribed and
-- circumscribed bracket, accurate to roughly @pi^3 \/ (12 n^2)@ for an
-- @n@-gon.  Because the error falls off quadratically, 25 doublings
-- (@n = 6 * 2^25 = 201326592@ sides) are enough to exhaust a 'Double'.
archimedesPi :: Int -> Double
archimedesPi doublings = (lower + upper) / 2
  where
    (lower, upper) = archimedesBounds doublings

--------------------------------------------------------------------------------
-- The three methods, as data
--------------------------------------------------------------------------------

-- | The three methods offered by this program.
data Method
  = Leibniz
  | Machin
  | Archimedes
  deriving (Bounded, Enum, Eq, Ord, Show)

-- | All methods, in the order they are presented to the user.
allMethods :: [Method]
allMethods = [minBound .. maxBound]

-- | Command line name of a method.
methodKey :: Method -> String
methodKey Leibniz = "leibniz"
methodKey Machin = "machin"
methodKey Archimedes = "archimedes"

-- | One line description of the mathematics.
methodSummary :: Method -> String
methodSummary Leibniz =
  "Madhava-Leibniz series 4*sum (-1)^k/(2k+1); trivial, error ~ 1/n"
methodSummary Machin =
  "Machin 1706: 16*arctan(1/5) - 4*arctan(1/239); a few terms reach machine precision"
methodSummary Archimedes =
  "Archimedes polygons: n = 6*2^k sides, pi bracketed by n*sin(pi/n) and n*tan(pi/n)"

-- | What the budget counts for this method.
methodBudgetLabel :: Method -> String
methodBudgetLabel Leibniz = "terms"
methodBudgetLabel Machin = "terms"
methodBudgetLabel Archimedes = "doublings"

-- | Default budget, chosen so that each method shows its characteristic
-- behaviour: Leibniz still visibly approximate, the other two exact to the
-- last bit of a 'Double'.
methodDefaultBudget :: Method -> Int
methodDefaultBudget Leibniz = 1000000
methodDefaultBudget Machin = 20
methodDefaultBudget Archimedes = 25

-- | Evaluate one method with the given budget.
estimate :: Method -> Int -> Double
estimate Leibniz = leibnizPi
estimate Machin = machinPi
estimate Archimedes = archimedesPi

--------------------------------------------------------------------------------
-- Running methods and reporting the result
--------------------------------------------------------------------------------

-- | The result of running one method once.
data Outcome = Outcome
  { outcomeMethod :: Method
  , outcomeBudget :: Int
  , outcomeEstimate :: Double
  , outcomeError :: Double
  -- ^ Absolute difference from 'piReference'.
  , outcomeSeconds :: Double
  -- ^ Wall clock time taken by the estimate.
  }

-- | Run a method with a given budget and time it.
--
-- The estimate is forced with 'evaluate' inside the timed region: without
-- that, laziness would happily time the construction of an unevaluated thunk
-- and report that a million-term series takes no time at all.
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
      , outcomeError = abs (estimateValue - piReference)
      , outcomeSeconds = end - start
      }

-- | Render the outcomes as an aligned comparison table.
renderTable :: [Outcome] -> String
renderTable outcomes =
  unlines $
    [ "pi"
    , printf "reference value : %.15f" piReference
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
    , "  \"constant\": \"pi\","
    , printf "  \"reference\": %s," (jsonDouble piReference)
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
              <> help "budget: series terms, or polygon doublings for archimedes"
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
        <> progDesc "Estimate pi with three classical methods"
        <> header "pi - three ways to compute 3.141592653589793"
    )

main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  options <- execParser parserInfo
  if optList options
    then do
      putStrLn "pi estimation methods:"
      mapM_ (putStrLn . describeMethod) allMethods
      exitSuccess
    else case resolveMethods (optMethodKeys options) of
      Left message -> do
        hPutStrLn stderr ("pi: " ++ message)
        exitWith (ExitFailure 2)
      Right methods -> do
        when (optVerbose options) $ do
          putStrLn "pi estimation methods:"
          mapM_ (putStrLn . describeMethod) methods
          putStrLn ""
        let budgetFor method = maybe (methodDefaultBudget method) id (optBudget options)
        outcomes <- traverse (\method -> runMethod method (budgetFor method)) methods
        if optJson options
          then putStr (renderJson outcomes)
          else putStr (renderTable outcomes)
