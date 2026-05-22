module ChainedCalls where
  
doubleOddElements :: Integral a => [a] -> [a]
doubleOddElements =
  map (\x -> if x `mod` 2 == 0 then x else 2 * x)

times10Elements :: Num a => [a] -> [a]
times10Elements = map (* 10)
    
main :: IO ()
main = do
  print $ doubleOddElements [0,1,2,3,4,5,6,7,8]
  let aList = [0,1,2,3,4,5]
  -- ($) is function application: f $ x = f x, but with low precedence
  -- so it avoids parentheses: times10Elements $ doubleOddElements aList
  -- is equivalent to: times10Elements (doubleOddElements aList)
  let newList = times10Elements $ doubleOddElements aList
  print newList
  -- (.) is function composition: (f . g) x = f (g x)
  -- It creates a new function that applies g first, then f.
  let newList2 = (times10Elements . doubleOddElements) aList
  print newList2
