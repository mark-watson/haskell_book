# Running the program snippets from the Pure Haskell Tutorial Chapter

~~~~~~~~
stack  ghci
~~~~~~~~

These simple examples are some of the code used in the very long introductory tutorial chapter on using "pure" Haskell.

## Running with Replit.com, Nix, Cabal:

    cabal update
    cabal build
    cabal run

Note that Pure.cabal only is configured to run SImple.hs. To run the other files
that contain a main funtion:

```
$ runghc MapExamples.hs
120
-1
$ runghc Cases.hs  
"Too low"
"just right"
"OK, that is a number"
$ runghc ChainedCalls.hs 
[0,2,2,6,4,10,6,14,8]
[0,20,20,60,40,100]
[0,20,20,60,40,100]
$ cabal exec runghc -- Guards.hs
-1
0
1
Nothing
Just 2
$ runghc MapExamples.hs     
120
-1
```

## runghc vs. 'cabal exec runghc --'

**runghc** bypasses the cabal build sandbox. If a Haskell file imports a library specified
in the project's cabal file, then use **cabal exec runghc --** to run **runghc** inside the cabal sandbox.
