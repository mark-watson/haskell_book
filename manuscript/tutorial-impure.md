# Tutorial on Impure Haskell Programming

One of the great things about Haskell is that the language encourages us to think of our code in two parts:

- Pure functional code (functions have no side effects) that is easy to write and test. Functional code tends to be shorter and less likely to be imperative (i.e., more functional, using maps and recursion, and less use of loops as in Java or C++).
- Impure code that deals with side effects like file and network IO, maintaining state in a type safe way, and isolate imperative code that has side effects.

In his excellent Functional Programming with Haskell class at [eDX](http://edx.org) Erik Meijer described pure code as being islands in the ocean and the ocean representing impure code. He says that it is a design decision how much of your code is pure (islands) and how much is impure (the ocean). This model of looking at Haskel programs works for me.

My use the word "impure" is common for referring to Haskell code with side effects. Haskell is a purely functional language and side effects like I/O are best handled in a pure functional way using by wrapping pure values in **Mondads**.

In addition to showing you reusable examples of impure code that you will likely need in your own programs, a major theme of this chapter is handling impure code in a convenient type safe fashion. Any **Monad**, which wraps a single value, is used to safely manage state. I will introduce you to using **Monad** types as required for the examples in this chapter. This tutorial style introduction will prepare you for understanding the sample applications later.


## Hello IO () Monad

I showed you many examples of pure code in the last chapter but most examples in source files (as opposed to those shown in a GHCi repl) had a bit of impure code in them: the **main** function like the following that simply writes a string of characters to standard output:

```haskell{line-numbers: false}
main = do
  print "hello world"
```

The type of function **main** is:

```haskell{line-numbers: false}
*Main> :t main
main :: IO ()
```

The **IO ()** monad is an IO value wrapped in a type safe way. Because Haskell is a lazy evaluation language, the value is not evaluated until it is used. Every **IO ()** action returns exactly one value. Think of the word "mono" (or "one") when you think of Monads because they always return one value. Monads are also used to connnect together parts of a program.

What is it about the function **main** in the last example that makes its type an **IO ()**? Consider the simple **main** function here:

```haskell{line-numbers: false}
module NoIO where

main = do
  let i = 1 in
    2 * i
```

and its type:

```haskell{line-numbers: false}
*Main> :l NoIO
[1 of 1] Compiling NoIO             ( NoIO.hs, interpreted )
Ok, modules loaded: NoIO.
*NoIO> main
2
*NoIO> :t main
main :: Integer
*NoIO> 
```

OK, now you see that there is nothing special about a **main** function: it gets its type from the type of value returned from the function. It is common to have the return type depend on the function argument types. The first example returns a type **IO ()** because it returns a print **do** expression:

```haskell{line-numbers: false}
*Main> :t print
print :: Show a => a -> IO ()
*Main> :t putStrLn
putStrLn :: String -> IO ()
```

The function **print** shows the enclosing quote characters when displaying a string while **putStrLn** does not. In the first example, what happens when we stitch together several expressions that have type **IO ()**? Consider:

```haskell{line-numbers: false}
main = do
  print 1
  print "cat"
```

Function **main** is still of type **IO ()**. You have seen **do** expressions frequently in examples and now we will dig into what the **do** expression is and why we use it.

The **do** notation makes working with monads easier. There are alternatives to using **do** that we will look at later.

One thing to note is that if you are doing bindings inside a **do** expression using a **let** with a **in** expression, you need to wrap the bindings in a new (inner) **do** expression if there is more than one line of code following the **let** statement. The way to avoid requiring a nested **do** expression is to not use **in** in a **let** expression inside a **do** block of code. Yes, this sounds complicated but let's clear up any confusion by looking at the examples found in the file *ImPure/DoLetExample.hs* (you might also want to look at the similar example file *ImPure/DoLetExample2.hs* that uses *bind* operators instead of a **do** statement; we will look at *bind* operators in the next section):

```haskell{line-numbers: false}
module DoLetExample where
  
example1 = do  -- good style
  putStrLn "Enter an integer number:"
  s <- getLine
  let number = (read s :: Int) + 2
  putStrLn $ "Number plus 2 = " ++ (show number)

example2 = do  -- avoid using "in" inside a do statement
  putStrLn "Enter an integer number:"
  s <- getLine
  let number = (read s :: Int) + 2 in
    putStrLn $ "Number plus 2 = " ++ (show number)

example3 = do  -- avoid using "in" inside a do statement
  putStrLn "Enter an integer number:"
  s <- getLine
  let number = (read s :: Int) + 2 in
    do -- this do is required since we have two dependent statements:
      putStrLn "Result is:"
      putStrLn $ "Number plus 2 = " ++ (show number)

main = do
  example1
  example2
  example3
```

You should use the pattern in function **example1** and not the pattern in **example2**. The **do** expression is syntactic sugar that allows programmers to string together a sequence of operations that can mix pure and impure code.

To be clear, the left arrow **<-** is used when the expression on the right side is some type of **IO ()** that needs to be *lifted* before being used. A **let** **do** expression is used when the right side expression is a pure value.

On lines 6 and 12 we are using function **read** to converting a string read out of **IO String ()** to an integer value. Remember that the value of **s** (from calling **readLine**) is an **IO ()** so in the same way you might read from a file, in this example we are reading a value from an **IO ()** value.

## A Note About **>>** and **>>=** Operators

So far in this book I have been using the syntactic sugar of the **do** expression to work with Monads like **IO ()** and I will usually use this syntactic sugar for the rest of this book.

Even though I find it easier to write and read code using **do**, many Haskell programmers prefer **>>** and **>>=** so let's go over these operators so you won't be confused when reading Haskell code that uses them. Also, when we use **do** expressions in code the compiler generates similar code using these **>>** and **>>=** operators.

The Monad type class defines the operators **>>=** and **return**. We turn to the GHCi repl to experiment with and learn about these operators:

```haskell{line-numbers: false}
*Main> :t (>>)
(>>) :: Monad m => m a -> m b -> m b
*Main> :t (>>=)
(>>=) :: Monad m => m a -> (a -> m b) -> m b
*Main> :t return
return :: Monad m => a -> m a
```

We start with the **return** function type **return :: Monad m => a -> m a** which tells us that for a monad **m** the function **return** takes a value and wraps it in a monad. We will see examples of the **return** function used to return a wrapped value from a function that returns **IO ()** values. The *bind* operator **(>>)** is used to evaluate two expressions in sequence. As an example, we can replace this **do** expression:

```haskell{line-numbers: false}
main = do
  example1
  example2
  example3
```

with the following:

```haskell{line-numbers: false}
main = example1 >> example2 >> example3
```

The operator **>>=** is similar to **>>** except that it evaluates the left-hand expression and pipes its value into the right-hand side expression. The left-hand side expression is evaluated to some type of **IO ()** and the expression on the right-hand side typically reads from the input **IO ()**. An example will make this simpler to understand:

```haskell{line-numbers: false}
module DoLetExample3 where
  
example3 =  putStrLn "Enter an integer number:" >>  getLine

example4 mv = do
  let number = (read mv :: Int) + 2
  putStrLn $ "Number plus 2 = " ++ (show number)

main = example3 >>= example4
```

Note that I could have used a **do** statement to define function **example3** but used a *bind* operator instead. Let's run this example and look at the function types. Please don't just quickly read through the following listing; when you understand what is happening in this example then for the rest of your life programming in Haskell things will be easier for you:

```haskell{line-numbers: true}
*DoLetExample3> main
Enter an integer number:
1
Number plus 2 = 3
*DoLetExample3> :t example3
example3 :: IO String
*DoLetExample3> :t example4
example4 :: String -> IO ()
*DoLetExample3> :t main
main :: IO ()
*DoLetExample3> let x = example3
*DoLetExample3> x
Enter an integer number:
4
"4"
*DoLetExample3> :t x
x :: IO String
*DoLetExample3> x >>= example4
Enter an integer number:
3
Number plus 2 = 5
```

The interesting part starts at line 11 when we define **x** to be the returned value from calling **example3**. Remember that Haskell is a lazy language: evaluation is postponed until a value is actually used.

Working inside a GHCi repl is like working interactively inside a **do** expression. When we evaluate **x** in line 12 then the code in function **example3** is actually executed (notice this is where the user prompt to enter a number occurs). In line 18 we are re-evaluationg the value in **x** and passing the resulting **IO String ()** value to the function **example4**.

Haskell is a "piecemeal" programming language as are the Lisp family of languages where a repl is used to write little pieces code that are collected into programs. For simple code in Haskell (and Lisp languages) I do sometimes directly enter code into a text editor but very ofter I start in a repl, experiment, debug, refine, and then copy into an edited file.


## Console IO Example with Stack Configuration

The directory *CommandLineApps* contains two simple applications that interact with STDIO, that is to write to the console and read from the keyboard. The first example can be found in file *CommandLineApp/CommandLine1.hs*:

```haskell{line-numbers: true}
module Main where
  
import System.IO
import Data.Char (toUpper)

main = do
  putStrLn "Enter a line of text for test 1:"
  s <- getLine
  putStrLn $ "As upper case:\t" ++ (map toUpper s)
  main
```

Lines 3 and 4 import the entire **System.IO** module (that is, import all exported symbols from **System.IO**) and just the function **toUpper** from module **Data.Char**. **System.IO** is a standard Haskell module and we do not have to do anything special to import it. The **Data.Char** is stored in the package **text**. The package **text** is contained in the library package **base** which is specifies in the *CommandLineApp.cabal* configuration file that we will look at soon.

Use of the **<-** assignment in line 8 in the last Haskell listing is important to understand. It might occur to you to leave out line 8 and just place the **getLine** function call directly in line 9, like this:

```haskell{line-numbers: false}
  putStrLn $ "As upper case:\t" ++ (map toUpper getLine)
```

If you try this (please do!) you will see compilation errors like:

```{line-numbers: false}
  Couldn't match expected type ‘[Char]’ with actual type ‘IO String’
  In the second argument of ‘map’, namely ‘getLine’
  In the second argument of ‘(++)’, namely ‘(map toUpper getLine)’
```
    
The type of **getLine** is an **IO ()** that is a wrapped IO call. The value is not computed until it is used. The **<-** assignment in line 8 evaluates the IO call and unwraps the result of the IO operation so that it can be used.

I don't spend much time covering *stack* project configuration files in this book but I do recommend that as you work through examples to also look for a file in each example directory ending with the file extension *.cabal* that specified which packages need to be loaded. For some examples it might take a while to download and configure libraries the first time you run either *stack build* or *stack ghci* in an example directory.

The Haskell stack project in the **CommandLineApp** directory has five target applications as we can see in the **CommandLineApp.cabal** file. I am not going to go into much detail about the project cabal and stack.yaml files generated by stack when you create a new project except for configuration data that I had to add manually; in this case, I added two executable targets at the end of the cabal file (note: the project in the github repository for this book has more executable targets, I just show a few here):

```{line-numbers: true}
executable CommandLine1
  hs-source-dirs:      .
  main-is:             CommandLine1.hs
  default-language:    Haskell2010
  build-depends:       base >= 4.7 && < 5
  
executable CommandLine2
  hs-source-dirs:      .
  main-is:             CommandLine2.hs
  default-language:    Haskell2010
  build-depends:       base >= 4.7 && < 5

executable ReadTextFile
  hs-source-dirs:      .
  main-is:             ReadTextFile.hs
  default-language:    Haskell2010
  build-depends:       base >= 4.7 && < 5

executable GameLoop1
  hs-source-dirs:      .
  main-is:             GameLoop1.hs
  default-language:    Haskell2010
  build-depends:       base >= 4.7 && < 5, time
        
executable GameLoop2
  hs-source-dirs:      .
  main-is:             GameLoop2.hs
  default-language:    Haskell2010
  build-depends:       base >= 4.7 && < 5, random
```

The executable name determines the compiled and linked executable file name. For line 1, an executable file "CommandLine1" (or "CommandLine1.exe"" on Windows) will be generated. The parameter **hs-source-dirs** is a comma separated list of source file directories. In this simple example all Haskell source files are in the project's top level directory "../". The **build-depends** is a comma separated list of module libraries; here we only use the base built-in modules packaged with Haskell.

Let's use a GHCi repl to poke at this code and understand it better. The project defined in *CommandLineApp/CommandLineApp.cabal* contains many executable targets so when we enter a GHCi repl, the available targets are shown and you can choose one; in this case I am selecting the first target defined in the *cabal* file. In later GHCi repl listings, I will edit out this output for brevity:

```haskell{line-numbers: true}
$ stack ghci

* * * * * * * *
The main module to load is ambiguous. Candidates are: 
1. Package `CommandLineApp' component exe:CommandLine1 with main-is file: /Users/markw/GITHUB/haskell_book/source-code/CommandLineApp/CommandLine1.hs
2. Package `CommandLineApp' component exe:CommandLine2 with main-is file: /Users/markw/GITHUB/haskell_book/source-code/CommandLineApp/CommandLine2.hs
3. Package `CommandLineApp' component exe:ReadTextFile with main-is file: /Users/markw/GITHUB/haskell_book/source-code/CommandLineApp/ReadTextFile.hs
You can specify which one to pick by: 
 * Specifying targets to stack ghci e.g. stack ghci CommandLineApp:exe:CommandLine1
 * Specifying what the main is e.g. stack ghci --main-is CommandLineApp:exe:CommandLine1
 * Choosing from the candidate above [1..3]
* * * * * * * *

Specify main module to use (press enter to load none): 1
Loading main module from cadidate 1, --main-is /Users/markw/GITHUB/haskell_book/source-code/CommandLineApp/CommandLine1.hs

Configuring GHCi with the following packages: CommandLineApp
GHCi, version 7.10.3: http://www.haskell.org/ghc/  :? for help
Ok, modules loaded: none.
[1 of 1] Compiling Main             ( /Users/markw/GITHUB/haskell_book/source-code/CommandLineApp/CommandLine1.hs, interpreted )
Ok, modules loaded: Main.
*Main> :t main
main :: IO b
*Main> :info main
main :: IO b
-- Defined at /Users/markw/GITHUB/haskell_book/source-code/CommandLineApp/CommandLine1.hs:6:1
*Main> :t getLine
getLine :: IO String
*Main> :t putStrLn
putStrLn :: String -> IO ()
*Main> main
Enter a line of text for test 1:
line 1
As upper case:	LINE 1
Enter a line of text for test 1:
line 2
As upper case:	LINE 2
Enter a line of text for test 1:
^C Interrupted.
*Main> 
```

In line 36 the function **getLine** is of type **getLine :: IO String** which means that calling **getLine** returns a value that is a computation to get a line of text from *stdio* but the IO operation is not performed until the value is used.

Please note that it is unusual to put five executable targets in a project's *cabal* file. I am only doing so here because I wanted to group five similar examples together in this subdirectory of the [github repo for this book](https://github.com/mark-watson/haskell_book/source-code). This repo has 16 example subdirectories, and the number would be much greater if I didn't collect similar examples together.

We will use the example in file *CommandLine2.hs* in the next section which is similar to this example but also appends the user input to a text file.

## File IO

We will now look at a short example of doing file IO. We will write Haskell simple string values to a file. If you are using the more efficient Haskell Text values, the code is the same. Text values are more efficient than simple string values when dealing with a lot of data and we will later use a compiler setting to automatically convert between the underlying formats. The following listing shows *CommandLineApp/CommandLine2.hs*:

```haskell{line-numbers: true}
module Main where
  
import System.IO
import Data.Char (toUpper)

main = do
  putStrLn "Enter a line of text for test2:"
  s <- getLine
  putStrLn $ "As upper case:\t" ++ (map toUpper s)
  appendFile "temp.txt" $ s ++ "\n"
  main
```

Note the use of recursion in line 11 to make this program loop forever until you use a *Control-c* to stop the program.

In line 10 we are using function **appendFile** to open a file, append a string to it, and then close the file. **appendFile** is of type **appendFile :: FilePath -> String -> IO ()**. It looks like we are passing a simple string as a file name instead of type **FilePath** but if you look up the definition of **FilePath** you will see that it is just an alias for string: **type FilePath = String**.

Running this example in a GHCi repl, with much of the initial printout from running *stack ghci* not shown:

{```haskell{line-numbers: false}
$ stack ghci
CommandLineApp-0.1.0.0: configure
Specify main module to use (press enter to load none): 2
Ok, modules loaded: Main.
*Main> main
Enter a line of text for test2:
line 1
As upper case:	LINE 1
Enter a line of text for test2:
line 2
As upper case:	LINE 2
Enter a line of text for test2:
^C Interrupted.
*Main> 
```

The file *temp.txt* was just created.

The next example used *ReadTextFile.hs* to read the file *temp.txt* and process the text by finding all words in the file:

```haskell{line-numbers: true}
module Main where
  
import System.IO
import Control.Monad

main = do
  entireFileAsString <- readFile "temp.txt"
  print entireFileAsString
  let allWords = words entireFileAsString
  print allWords
```

**readFile** is a high-level function because it manages for you reading a file and closing the file handle it uses internally. The built in function **words** splits a string on spaces and returns a list of strings **[String]** that are printed on line 7:

```haskell{line-numbers: true}
$ stack ghci
CommandLineApp-0.1.0.0: build
Specify main module to use (press enter to load none): 3
Ok, modules loaded: ReadTextFile.
*ReadTextFile> main
"line 1\nline 2\n"
["line","1","line","2"]
*ReadTextFile> 
*ReadTextFile> :t readFile
readFile :: FilePath -> IO String
*ReadTextFile> :type words
words :: String -> [String]
```

What if the function **readFile** encounters an error? That is the subject for the next section.

## Error Handling in Impure Code
I know you have been patiently waiting to see how we handle errors in Haskell code. Your wait is over! We will look at several common types of runtime errors and how to deal with them. In the last section we used the function **readFile** to read the contents of a text file *temp.txt*. What if *temp.txt* does not exist? Well, then we get an error like the following when running the example program in *ReadTextFile.hs*:

```haskell{line-numbers: false}
*Main> main
*** Exception: temp.txt: openFile: does not exist (No such file or directory)
```

Let's modify this last example in a new file *ReadTextFileErrorHandling.hs* that catches a file not found error. The following example is derived from the first example in Michael Snoyman's article [Catching all exceptions](https://www.schoolofhaskell.com/user/snoyberg/general-haskell/exceptions/catching-all-exceptions). This example does not work inside threads; if you need to catch errors inside a thread then see the second example in Michael's article.

```haskell{line-numbers: true}
module Main where
  
import System.IO
import Control.Exception

-- catchAny by Michael Snoyman:
catchAny :: IO a -> (SomeException -> IO a) -> IO a
catchAny = Control.Exception.catch

safeFileReader :: FilePath -> IO String
safeFileReader fPath = do
  entireFileAsString <- catchAny (readFile "temp.txt") $ \error -> do
    putStrLn $ "Error: " ++ show error
    return ""
  return entireFileAsString
  
main :: IO ()
main = do
  fContents <- safeFileReader "temp.txt"
  print fContents
  print $ words fContents
```

I will run this twice: the first time without the file *temp.txt* present and a second time with *temp.txt* in the current directory:

```haskell{line-numbers: true}
*Main> :l ReadTextFileErrorHandling.hs 
[1 of 1] Compiling Main             ( ReadTextFileErrorHandling.hs, interpreted )
Ok, modules loaded: Main.
*Main> main
Error: temp.txt: openFile: does not exist (No such file or directory)
""
[]
1
*Main> main
"line 1\nline 2\n"
["line","1","line","2"]
```

Until you need to handle runtime errors in a multi-threaded Haskell program, following this example should be sufficient. In the next section we look at Network IO.


## Network IO

We will experiment with three network IO examples in this book:

- A simple socket client/server example in this section.
- Reading web pages in the chapter "Web Scraping"
- Querying remote RDF endpoints in the chapter "Linked Data and the Semantic Web"

We start by using a high level library, **network-simple** for both the client and server examples in the next two sub-sections. The client and server examples are in the directory *haskell_book/source-code/ClientServer* in the files *Client.hs* and *Server.hs*.

### Server Using network-simple Library

The Haskell **Network** and **Network.Simple** modules use strings represented as **Data.ByteString.Char8** data so as seen in line 1 I set the language type *OverloadedStrings*. The following example in file *ClientServer/Server.hs* is derived from an example in the *network-simple* project:

```haskell{line-numbers: true}
{-# LANGUAGE OverloadedStrings #-}

module Server where

import Control.Monad
import qualified Data.ByteString.Char8 as B
import qualified Network.Simple.TCP as T

reverseStringLoop sock = do
  mbs <- T.recv sock 4096
  case mbs of
    Just bs -> T.send sock (B.reverse bs) >> reverseStringLoop sock
    Nothing -> return ()

main :: IO ()
main = T.withSocketsDo $ do -- derived from library example
  T.listen "*" "3000" $ \(lsock, laddr) -> do
    putStrLn $ "Listening at " ++ show laddr
    forever . T.acceptFork lsock $ \(sock, addr) -> do
      putStrLn $ "Connection from " ++ show addr
      reverseStringLoop sock
```

The server accepts a string, reverses the string, and returns the reversed string to the client.

I am assuming that you have done some network programming and are familiar with sockets, etc. The function **reverseStringLoop** defined in lines 9-13 accepts a socket as a parameter and returns a value of type **MonadIO** that wraps a byte-string value. In line 10 we use the **T.recv** function that takes two arguments: a socket and the maximum number of bytes to received from the client. The **case** expression reverses the received byte string, sends the reversed string back to the client, and recursively calls itself waiting for new data from the client. If the client breaks the socket connection, then the function returns an empty **MonadIO()**.

The **main** function defined in lines 15-21 listens on port 3000 for new client socket connections. In line 19, the function **T.acceptFork** accepts as an argument a socket value and a function to execute; the complete type is:

```haskell{line-numbers: true}
*Main> :t T.acceptFork
T.acceptFork
  :: transformers-0.4.2.0:Control.Monad.IO.Class.MonadIO m =>
     T.Socket
     -> ((T.Socket, T.SockAddr) -> IO ()) -> m GHC.Conc.Sync.ThreadId
```

Don't let line 3 scare you; the GHCi repl is just showing you where this type of **MonadIO** is defined. The return type refers to a thread ID that is passed to the function **forever :: Monad m => m a -> m b** that is defined in the module **Control.Monad** and lets the thread run until it terminates.

The *network-simple* package is fairly high level and relatively simple to use. If you are interested you can find many client/server examples on the web that use the lower-level *network* package.

We will develop a client application to talk with this server in the next section but if you want to immediately try the server, start it and then run *telnet* in another terminal window:

```haskell{line-numbers: false}
Prelude> :l Server
[1 of 1] Compiling Server           ( Server.hs, interpreted )
Ok, modules loaded: Server.
*Main> main
Listening at 0.0.0.0:3000
```

And run *telnet*:

```{line-numbers: false}
$ telnet localhost 3000
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
12345
54321
The dog ran down the street
teerts eht nwod nar god ehT
```

In the next section we write a simple client to talk with this service example.


### Client Using network-simple Library

I want to use automatic conversion between strings represented as **Data.ByteString.Char8** data and regular **[Char]** strings so as seen in line 1 I set the language type *OverloadedStrings* in the example in file *Client.hs*:

```haskell{line-numbers: true}
{-# LANGUAGE OverloadedStrings #-}

module Client where

import Control.Monad
import qualified Network.Simple.TCP as T

main = do
  T.connect "127.0.0.1" "3000" $ \(connectionSocket, remoteAddr) -> do
  putStrLn $ "Connection established to " ++ show remoteAddr
  T.send connectionSocket "test123"
  response <- T.recv connectionSocket 100
  case response of
    Just s -> putStrLn $ "Response: " ++ show s
    Nothing -> putStrLn "No response from server"
```

The function **T.connect** in line 9 accepts arguments for a host name, a port, and a function to call with the connection socket to the server and the server's address. The body of this inline function, defined in in the middle on line 9 and continuing in lines 10-15, prints the server address, sends a string "test123" to the server, and waits for a response back from the server (**T.recv** in line 12). The server response is printed, or a warning that no response was received.

While the example in file *Server.hs* is running in another terminal, we can run the client interactively:

```{line-numbers: false}
Prelude> :l Client.hs 
[1 of 1] Compiling Client           ( Client.hs, interpreted )
Ok, modules loaded: Client.
*Main main
Connection established to 127.0.0.1:3000
Response: "321tset"
```


## A Haskell Game Loop that Maintains State Functionally

The example in this section can be found in the file *GameLoop2.hs* in the directory *haskell_book/source-code/CommandLineApp*. This example uses the random package to generate a seed random number for a simple number guessing game. An alternative implementation in *GameLoop1.hs*, which I won't discuss, uses the system time to generate a seed.

This is an important example because it demonstrates one way to maintain state in a functional way. We have a read-only game state value that is passed to the function **gameLoop** which modifies the read-only game state passed as an argument and returns a newly constructed game state as the function's returned value. This is a common pattern that we will see again later when we develop an application to play a simplified version of the card game Blackjack in the chapter "Haskell Program to Play the Blackjack Card Game."

```haskell{line-numbers: true}
module GameLoop2 where

import System.Random

data GameState = GameState { numberToGuess::Integer, numTries::Integer}
                   deriving (Show)

gameLoop :: GameState -> IO GameState
gameLoop gs = do      
  print $ numberToGuess gs
  putStrLn "Enter a number:"
  s <- getLine
  let num = read s :: Integer
  if num == numberToGuess gs then
    return gs
  else gameLoop $ GameState (numberToGuess gs) ((numTries gs) + 1)
         
main = do
  pTime <- randomRIO(1,4)
  let gameState = GameState pTime 1
  print "Guess a number between 1 and 4"
  gameLoop gameState
```

You notice in line 12 that since we are inside of a **do** expression we can *lift* (or unwrap) the **IO String ()** value returned from **getLine** to a string value that we can use directly. This is a pattern we will use repeatedly. The value returned from **getLine** is not used until line 13 when we use function **read** to extract the value from the **IO String ()** value **getLine** returned.

In the **if** expression in lines 14-16 we check if the user has input the correct value and can then simply return the input game state to the calling **main** function. If the user has not guessed the correct number then in line 16 we create a new game state value and call the function **gameLoop** recursively with the newly constructed game state.

The following listing shows a sample session playing the number guessing game.

```haskell{line-numbers: false}
Prelude> :l GameLoop2.hs 
[1 of 1] Compiling GameLoop2        ( GameLoop2.hs, interpreted )
Ok, modules loaded: GameLoop2.
*GameLoop2> main
"Guess a number between 1 and 4"
Enter a number:
1
Enter a number:
3
Enter a number:
4
GameState {numberToGuess = 4, numTries = 3}
*GameLoop2> main
"Guess a number between 1 and 4"
Enter a number:
1
Enter a number:
2
GameState {numberToGuess = 2, numTries = 2}
*GameLoop2> 
```

We will use this pattern for maintaining state in a game in the later chapter "Haskell Program to Play the Blackjack Card Game."


### Efficiency of Haskell Strings

Except for the Client/Server example, so far we have been mostly using simple **String** values where **String** is a list of characters **[Char]**. For longer strings it is much more efficient to use the module [**Data.Text**](https://www.stackage.org/nightly-2016-09-18/package/text-1.2.2.1) that is defined in package **text** (so **text** needs to be added to the dependencies in your cabal file).

Many Haskell libraries use the simple **String** type but the use of **Data.Text** is also common, especially in applications handling large amounts of string data. We have already seen examples of this in the client/server example programs. Fortunately Haskell is a strongly typed language that supports a language extension for automatically handling both simple strings and the more efficient text types. This language extension, as we have seen in a previous example, is activated by adding the following near the top of a Haskell source file:

```haskell{line-numbers: false}
{-# LANGUAGE OverloadedStrings     #-}
```

As much as possible I am going to use simple strings in this book and when we need both simple strings and byte strings I will then use *OverloadedStrings* for automatic conversion. This conversion is performed by knowing the type signatures of data and functions in surrounding code. The compiler figures out what type of string is expected and does the conversion for you.


## A More Detailed Look at Monads

We have been casually using different types of **IO ()** monads. In this section I will introduce you to the **State** monad and then we will take a deeper look at **IO ()**. While we will be just skimming the surface of the topic of monads, my goal in this section is to teach you enough to work through the remaining examples in this book.

Monads are types belonging to the Monad type class that specifies one operator and one function:

```haskell{line-numbers: false}
class Monad m where
  (>>=) :: m a -> (a -> m b) -> m b
  return :: a -> m a
```

The **>>=** operator takes two arguments: a monad wrapping a value (type **a** in the above listing) and a function taking the same type **a** and returning a monad wrapping a new type **b**. The return value of **>>=** is a new monad wrapping a value of type **b**.

The Monad type class function **return** takes any value and wraps it in a new monad. The naming of **return** is confusing because it does not alter the flow of execution in a program like a *return* statement in Java, rather, it wraps a value in a monad.


### State Monad

The definition for the constructor of a State monad is:

```haskell{line-numbers: false}
newtype State s a = State { runState :: s -> (a, s) }
```

So far we have been using **data** to define new types and **newtype** is similar except **newtype** acts during compile time and no type information is present at runtime. All monads contain a value and for the State monad this value is a function. The **>>=** operator is called the *bind* operator.

The accessor function **runState** provides the means to access the value in the state. The following example is in the file *StateMonad/State1.hs*. In this example, **incrementState** is a state monad that increases its wrapped integer value by one when it is executed. Remember that the **return** function is perhaps poorly named because it does not immediately "return" from a computation block as it does in other languages; **return** simply wraps a value as a monad without redirecting the execution flow.

In order to make the following example more clear, I implement the increment state function twice, once using the **do** notation that you are already familiar with and once using the **>>=** bind operator:

```haskell{line-numbers: true}
module Main where

import Control.Monad.State

incrementState :: State Int Int
incrementState = do
  n <- get
  put (n + 1)
  return n

-- same state monad without using a 'do' expression:
incrementState2 :: State Int Int
incrementState2 = get >>= \a ->
                  put (a + 1) >>= \b ->
                  return a

bumpVals (a,b) = (a+1, b+2)

main = do
  print $ runState incrementState 1  -- (1,2) == (return value, final state)
  print $ runState incrementState2 1 -- (1,2) == (return value, final state)
  print $ runState (mapState bumpVals incrementState) 1 -- (2,4)
  print $ evalState incrementState 1  -- 1 == return value
  print $ execState incrementState 1  -- 2 == final state
```

Here we have used two very different looking, yet equivalent, styles for accessing and modifying state monad values. In lines 6-9 we are using the **do** notation. The function **get** in line 7 returns one value: the value wrapped in a state monad. Function **put** in line 8 replaces the wrapped value in the state monad, in this example by incrementing its numeric value. Finally **return** wraps the value in a monad.

I am using the **runState** function defined in lines 20-24 that returns a tuple: the first tuple value is the result of the computation performed by the function passed to **runState** (**incrementState** and **incrementState2** in these examples) and the second tuple value is the final wrapped state.

In lines 12-15 I reimplemented increment state using the *bind* function (**>>=**). We have seen before that **>>=** passes the value on its left side to the computation on its right side, that is function calls in lines 13-15:

```haskell{line-numbers: false}
  \a -> put (a + 1)
  \b -> return a
```

It is a matter of personal taste whether to code using bind or **do**. I almost always use the **do** notation in my own code but I wanted to cover bind both in case you prefer that notation and so you can also read and understand Haskell code using bind. We continue looking at alternatives to the **do** notation in the next section.


## Using Applicative Operators <$> and <*>: Finding Common Words in Files

My goal in this book is to show you a minimal subset of Haskell that is relatively easy to understand and use for coding. However, a big part of using a language is reading other people's code so I do need to introduce a few more constructs that are widely used: applicative operators.

Before we begin I need to introduce you to a new term: **Functor** which is a type class that defines only one method **fmap**. **fmap** is used to map a function over an **IO action** and has the type signature:

```haskell{line-numbers: false}
  fmap :: Functor f => (a -> b) -> f a -> f b
```
  
**fmap** can be used to apply a pure function like **(a -> b)** to an **IO a** and return a new **IO b** without unwrapping the original **IO ()**. The following short example (in file *ImPure/FmapExample.hs*) will let you play with this idea:

```haskell{line-numbers: true}
module FmapExample where

fileToWords fileName = do
  fileText <- readFile fileName
  return $ words fileText
    
main = do
  words1 <- fileToWords "text1.txt"
  print $ reverse words1
  words2 <- fmap reverse $ fileToWords "text1.txt"
  print words2
```

In lines 8-9 I am unwrapping the result of the **IO [String]** returned by the function **fileToWords** and then applying the pure function **words** to the unwrapped value. Wouldn't it be nice to operate on the words in the file without unwrapping the **[String]** value? You can do this using **fmap** as seen in lines 10-11. Please take a moment to understand what line 10 is doing. Here is line 10:

```haskell{line-numbers: false}
  words2 <- fmap reverse $ fileToWords "text1.txt"
```

First we read the words in a file into an **IO [String]** monad:

```haskell{line-numbers: false}
                           fileToWords "text1.txt"
```

Then we apply the pure function **reverse** to the values inside the **IO [String]** monad, creating a new copy:

```haskell{line-numbers: false}
            fmap reverse $ fileToWords "text1.txt"
```

Note that from the type of the **fmap** function, the input monad and output monad can wrap different types. For example, if we applied the function **head** to an **IO [String]** we would get an output of **IO [Char]**.

Finally we unwrap the [String] value inside the monad and set **words2** to this unwrapped value:

```haskell{line-numbers: false}
  words2 <- fmap reverse $ fileToWords "text1.txt"
```

In summary, the **Functor** type class defines one method **fmap** that is useful for operating on data wrapped inside a monad.


We will now implement a small application that finds common words in two text files, implementing the primary function three times, using:

- The **do** notation.
- The >>= bind operator.
- The Applicative operators <$> and <*>

Let's look at the types for these operators:

```haskell{line-numbers: false}
(<$>) :: Functor f => (a -> b) -> f a -> f b
(<*>) :: Applicative f => f (a -> b) -> f a -> f b
```

We will use both <$> and <*> in the function **commonWords3** in this example and I will explain how these operators work after the following program listing.

This practical example will give you a chance to experiment more with Haskell (you do have a GHCi repl open now, right?). The source file for this example is in the file *ImPure/CommonWords.hs*:

```haskell{line-numbers: true}
module CommonWords where

import Data.Set (fromList, toList, intersection)
import Data.Char (toLower)

fileToWords fileName = do
  fileText <- readFile fileName
  return $ (fromList . words) (map toLower fileText)
  
commonWords file1 file2 = do  
  words1 <- fileToWords file1
  words2 <- fileToWords file2
  return $  toList $ intersection words1 words2

commonWords2 file1 file2 =
  fileToWords file1 >>= \f1 ->
  fileToWords file2 >>= \f2 ->
  return $  toList $ intersection f1 f2
                                                            
commonWords3 file1 file2 =
  (\f1 f2 -> toList $ intersection f1 f2)
    <$> fileToWords file1
    <*> fileToWords file2
    
main = do
  cw <- commonWords "text1.txt" "text2.txt"
  print cw
  cw2 <- commonWords2 "text1.txt" "text2.txt"
  print cw2
  cw3 <- commonWords3 "text1.txt" "text2.txt"
  print cw3
```

The function **fileToWords** defined in lines 6-8 simply reads a file, as in the last example, maps contents of the file to lower case, uses **words** to convert a **String** to a **[String]** list of individual words, and uses the function **Data.Set.fromList** to create a set from a list of words that in general will have duplicates. We are retuning an **IO (Data.Set.Base.Set String)** value so we can later perform a set intersection operation. In other applications you might want to apply **Data.Set.toList**  before returning the value from **fileToWords** so the return type of the function would be **IO [String]**.

The last listing defines three similar functions **commonWords**, **commonWords2**, and **commonWords3**.

**commonWords** defined in lines 10-13 should hopefully look routine and familiar to you now. We set the local variables with the unwrapped (i.e., extracted from a monad) contents of the unique words in two files, and then return monad wrapping the intersection of the words in both files.

The function **commonWords2** is really the same as **commonWords** except that it uses the bind **>>=** operator instead of the **do** notation.

The interesting function in this example is **commonWords3** in lines 20-23 which uses the applicative operators <$> and <\*>. Notice the pure function defined inline in line 21: it takes two arguments of type set and returns the set intersection of the arguments. The operator <$> takes a function on the left side and a monad on the right side which contains the wrapped value to be passed as the argument **f1**. <*> supplies the value for the inline function arguments **f2**. To rephrase how lines 21-23 work: we are calling **fileToWords** twice, both times getting a monad. These two wrapped monad values are passed as arguments to the inline function in line 21 and the result of evaluating this inline function is returned as the value of the function **commonWords3**.

I hope that this example has at least provided you with "reading knowledge" of the Applicative operators <$> and <*> and has also given you one more example of replacing the **do** notation with the use of the bind **>>=** operator.



## List Comprehensions Using the **do** Notation

We saw examples of list comprehensions in the last chapter on pure Haskell programming. We can use **return** to get lists values that are instances of type Monad:

```haskell{line-numbers: false}
*Prelude> :t (return [])
(return []) :: Monad m => m [t]
*Prelude> :t (return [1,2,3])
(return [1,2,3]) :: (Monad m, Num t) => m [t]
*Prelude> :t (return ["the","tree"])
(return ["the","tree"]) :: Monad m => m [[Char]]
```

We can get list comprehension behavior from the **do** notation (here I am using the GHCi repl **:{** and **:}** commands to enter multiple line examples):

```haskell{line-numbers: true}
*Main> :{
*Main| do num <- [1..3]
*Main|    animal <- ["parrot", "ant", "dolphin"]
*Main|    return (num, animal)
*Main| :}
[(1,"parrot"),(1,"ant"),(1,"dolphin"),
 (2,"parrot"),(2,"ant"),(2,"dolphin"),
 (3,"parrot"),(3,"ant"),(3,"dolphin")]
```

I won't use this notation further but you now will recognize this pattern if you read it in other people's code.

## Dealing With Time

In the example in this section we will see how to time a block of code (using two different methods) and how to set a timeout for code that runs in an **IO ()**.

The first way we time a block of code uses **getPOSIXTime** and can be used to time pure or impure code. The second method using **timeIt** takes an **IO ()** as an argument; in the following example I wrapped pure code in a **print** function call which returns an **IO ()** as its value. The last example in the file *TimerTest.hs* shows how to run impure code wrapped in a timeout.

```haskell{line-numbers: true}
module Main where

import Data.Time.Clock.POSIX -- for getPOSIXTime
import System.TimeIt         -- for timeIt
import System.Timeout        -- for timeout

anyCalculationWillDo n =  -- a function that can take a while to run
  take n $ sieve [2..]
            where
              sieve (x:xs) =
                x:sieve [y | y <- xs, rem y x > 0]
                
main = do
  startingTime <- getPOSIXTime
  print startingTime
  print $ last $ take 20000001 [0..]
  endingTime <- getPOSIXTime
  print endingTime
  print (endingTime - startingTime)
  timeIt $ print $ last $ anyCalculationWillDo 2000

  let somePrimes = anyCalculationWillDo 3333 in
    timeIt $ print $ last somePrimes

  -- 100000 microseconds timeout tests:
  timeout 100000 $ print "simple print **do** expression did not timeout"
  timeout 100000 $ print $ last $ anyCalculationWillDo 4
  timeout 100000 $ print $ last $ anyCalculationWillDo 40
  timeout 100000 $ print $ last $ anyCalculationWillDo 400
  timeout 100000 $ print $ last $ anyCalculationWillDo 4000
  timeout 100000 $ print $ last $ anyCalculationWillDo 40000
  print $ anyCalculationWillDo 5
```

I wanted a function that takes a while to run so for **anyCalculationWillDo** (lines 7 to 11) I implemented an inefficient prime number generator.

When running this example on my laptop, the last two timeout calls (lines 26 and 31) are terminated for taking more than 100000 microseconds to execute.

The last line 32 of code prints out the first 5 prime numbers greater than 1 so you can see the results of calling the time wasting test function **anyCalculationWillDo**.

```{line-numbers: false}
$ stack build --exec TimerTest
1473610528.2177s
20000000
1473610530.218574s
2.000874s
17389
CPU time:   0.14s
30911
CPU time:   0.25s
"simple print **do** expression did not timeout"
7
173
2741
[2,3,5,7,11]
```

The **timeout** function is useful for setting a maximum time that you are willing to wait for a calculation to complete. I mostly use **timeout** for timing out operations fetching data from the web.

## Using Debug.Trace

Inside an **IO** you can use print statements to understand what is going on in your code when debugging. You can not use print statements inside pure code but the Haskell base library contains the **trace** functions that internally perform impure writes to stdout. You do not want to use these debug tools in production code.

As an example, I have rewritten the example from the last section to use Debug.Trace.trace and Debug.Trace.traceShow:

```haskell{line-numbers: true}
module Main where

import Debug.Trace  (trace, traceShow) -- for debugging only!

anyCalculationWillDo n =
  trace
      ("+++ anyCalculationWillDo: " ++ show n) $
      anyCalculationWillDo' n

anyCalculationWillDo' n =
  take n $ trace ("   -- sieve n:" ++ (show n)) $ sieve [2..]
            where
              sieve (x:xs) =
                  traceShow ("     -- inside sieve recursion") $
                            x:sieve [y | y <- xs, rem y x > 0]
                
main = do
  print $ anyCalculationWillDo 5
```

In line 3 we import the **trace** and **showTrace** functions:

```haskell{line-numbers: false}
*Main> :info trace
trace :: String -> a -> a 	-- Defined in ‘Debug.Trace’
*Main> :info traceShow
traceShow :: Show a => a -> b -> b 	-- Defined in ‘Debug.Trace’
```

**trace** takes two arguments: the first is a string that that is written to stdout and the second is a function call to be evaluated. **traceShow** is like **trace* except that the first argument is converted to a string. The output from running this example is:

```{line-numbers: false}
+++ anyCalculationWillDo: 5
   -- sieve n:5
"     -- inside sieve recursion"
"     -- inside sieve recursion"
"     -- inside sieve recursion"
"     -- inside sieve recursion"
"     -- inside sieve recursion"
[2,3,5,7,11]
```

I don't usually like using the **trace** functions because debugging with them involves slightly rewriting my code. My preference is to get low level code written interactively in the GHCI repl so it does not need to be debugged. I very frequently use print statement inside **IO**s since adding them requires no significant modification of my code.

## Wrap Up

I tried to give you a general fast-start in this chapter for using monads and in general writing impure Haskell code. This chapter should be sufficient for you to be able to understand and experiment with the examples in the rest of this book.

This is the end of the first section. We will now look at a variety of application examples using the Haskell language.

While I expect you to have worked through the previous chapters in order, for the rest of the book you can skip around and read the material in any order that you wish.

