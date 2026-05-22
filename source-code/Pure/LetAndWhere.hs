module Main where

funnySummation :: Num a => a -> a -> a -> a -> a
funnySummation w x y z =
  let bob = w + x
      sally = y + z
  in bob + sally

testLetComprehension :: [(Int, Int)]
testLetComprehension =
  [(a,b) | a <- [0..5], let b = 10 * a]

testWhereBlocks :: Num a => a -> a
testWhereBlocks a =
  z * q
    where
      z = a + 2
      q = 2

functionWithWhere :: Num a => a -> a
functionWithWhere n  =
  (n + 1) * tenn
  where
    tenn = 10 * n

main :: IO ()
main = do
  print $ funnySummation 1 2 3 4
  let n = "Rigby"
  print n
  print testLetComprehension
  print $ testWhereBlocks 11
  print $ functionWithWhere 1
  
  
