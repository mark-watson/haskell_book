# Tutorial on Writing Haskell Applications

We will use what you have learned in the last two chapters to write applications that combine pure Haskell code with impure code to deal with I/O and network programming. You will then see many longer examples of complete Haskell applications in the second section.

## Writing Command Line Applications in Haskell


{lang="haskell",linenos=on}
~~~~~~~~
module Main where
  
import System.IO
import Data.Char (toUpper, toLower)

main = do
  putStrLn "Enter a line of text:"
  s <- getLine
  putStrLn $ "As upper case:\t" ++ (map toUpper s)
  main
~~~~~~~~
