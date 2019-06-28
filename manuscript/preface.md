# Preface

This is the preface to the new second edition released summer of 2019.

It took me over a year learning Haskell before I became comfortable with the language because I tried to learn too much at once. There are two aspects to Haskell development: writing pure functional code and writing impure code that needs to maintain state and generally deal with the world non-deterministically. I usually find writing pure functional Haskell code to be easy and a lot of fun. Writing impure code is sometimes a different story. This is why I am taking a different approach to teaching you to program in Haskell: we begin techniques for writing concise, easy to read and understand efficient pure Haskell code. I will then show you patterns for writing impure code to deal with file IO, network IO, database access, and web access. You will see that the impure code tends to be (hopefully!) a small part of your application and is isolated in the impure main program and in a few impure helper functions used by the main program. Finally, we will look at a few larger Haskell programs.

## Additional Material in the Second Edition

I have added a few larger projects to the second edition as well as improved the introduction to Haskell and tutorial material.

The project **knowledge_graph_creator** helps to automate the process of creating Knowledge Graphs from raw text input and generates data for both the Neo4J open source graph database as well as RDF data for use in semantic web and linked data applications.


## A Request from the Author

I spent time writing this book to help you, dear reader. I release this book under the Creative Commons "share and share alike, no modifications, no commercial reuse" license and set the minimum purchase price to $5.00 in order to reach the most readers. Under this license you can share a PDF version of this book with your friends and coworkers. If you found this book on the web (or it was given to you) and if it provides value to you then please consider doing one of the following to support my future writing efforts and also to support future updates to this book:

- Purchase a copy of this book at [leanpub.com/haskell-cookbook](https://leanpub.com/haskell-cookbook)
- [Hire me as a consultant](http://markwatson.com/)

I enjoy writing and your support helps me write new editions and updates for my books and to develop new book projects. Thank you!


## Structure of the Book

The first section of this book contains two chapters:

- A tutorial on pure Haskell development: no side effects.

- A tutorial on impure Haskell development: dealing with the world (I/O, network access, database access, etc.). This includes examples of file IO and network programming as well as writing short applications: a mixture of pure and impure Haskell code.

After working through these tutorial chapters you will understand enough of Haskell development to understand and be able to make modifications for your own use of the cookbook examples in the second section. Some of the general topics will be covered again in the second book section that contains longer sample applications. For example, you will learn the basics for interacting with Sqlite and Postgres databases in the tutorial on impure Haskell code but you will see a much longer example later in the book when I provide code that implements a natural language processing (NLP) interface to relational databases.

The second section of this book contains the following recipes implemented as complete programs:

- Textprocessing CSV Files
- Textprocessing JSON Files
- Natural Language Processing (NLP) interface to relational databases, including annotating English text with Wikipedia/DBPedia URIs for entities in the original text. Entities can be people, places, organizations, etc.
- Accessing and Using Linked Data
- Querying Semantic Web RDF Data Sources
- Web scraping data on web sites
- Using Sqlite and Postgres relational databases
- Play a simple version of Blackjack card game


## Code Examples

The code examples in this book are licensed under two software licenses and you can choose the license that works best for your needs: Apache 2 and GPL 3. To be clear, you can use the examples in commercial projects under the Apache 2 license and if you like to write Free (Libre) software then use the GPL 3 license.

We will use *stack* as a build system for all code examples. The code examples are provided as 15 separate *stack* based projects. These examples [are found on github](https://github.com/mark-watson/haskell_tutorial_cookbook_examples).



## Functional Programming Requires a Different Mind Set

You will learn to look at problems differently when you write functional programs. We will use a bottom up approach in most of the examples in this book. I like to start by thinking of the problem domain and decide how I can represent the data required for the problem at hand. I prefer to use native data structures. This is the opposite approach to object oriented development where considerable analysis effort and coding effort is required to define class hierachies to represent data. In most of the code we use simple native data types like lists and maps.

Once we decide how to represent data for a program we then start designing and implementing simple functions to operate on and transform data. If we find ourselves writing functions that are too long or too complex, we can break up code into simpler functions. Haskell has good language support for composing simple functions into more complex operations.

I have spent many years engaged in object oriented programming starting with CLOS for Common Lisp, C++, Java, and Ruby. I now believe that in general, and I know it is sometimes a bad idea to generalize too much, functional programming is a superior paradigm to object oriented programming. Convincing you of this belief is one of my goals in writing this book!


## eBooks Are Living Documents

I wrote printed books for publishers like Springer-Verlag, McGraw-Hill, and Morgan Kaufman before I started self-publishing my own books. I prefer eBooks because I can update already published books and update the code examples for eBooks.

I encourage you to periodically check for updates to both this book and the code examples on the [leanpub.com web page for this book](https://leanpub.com/haskell-cookbook).


## Setting Up Your Development Environment

I strongly recommend that you use the *stack* tool from the [stack website](http://docs.haskellstack.org/en/stable/README.html). This web site has instructions for installing *stack* on OS X, Windows, and Linux. If you don't have *stack* installed yet please do so now and follow the "getting started" instructions for creating a small project. Appendix A contains material to help get you set up.

It is important for you to learn the basics of using *stack* before jumping into this book because I have set up all of the example programs using stack.

The github repository for the examples in this book is [located here[are found on github](https://github.com/mark-watson/haskell_tutorial_cookbook_examples).

Many of the example listings for code examples are partial or full listing of files in my github repository. I show the file name, the listing, and the output. To experiment with the example yourself you need to load it and execute the main function; for example, if the example file is TestSqLite1.hs in the sub-directory Database, then from the top level directory in the git repository for the book examples you would do the following:

{line-numbers=off}
~~~~~~~~
$ haskell_tutorial_cookbook_examples git:(master) > cd Database 
$ Database git:(master) > stack build --exec ghci
GHCi, version 7.10.3: http://www.haskell.org/ghc/  :? for help
Prelude> :l TestSqLite1
[1 of 1] Compiling Main             ( TestSqLite1.hs, interpreted )
Ok, modules loaded: Main.
*Main> main
"Table names in database test.db:"
"test"
"SQL to create table 'test' in database test.db:"
"CREATE TABLE test (id integer primary key, str text)"
"number of rows in table 'test':"
1
"rows in table 'test':"
(1,"test string 2")
*Main>
~~~~~~~~

If you don't want to run the example in a REPL in order to experiment with it interactively then you can just run it via stack using:

{line-numbers=off}
~~~~~~~~
$ Database git:(master) > stack build --exec TestSqlite1
"Table names in database test.db:"
"test"
"SQL to create table 'test' in database test.db:"
"CREATE TABLE test (id integer primary key, str text)"
"number of rows in table 'test':"
1
"rows in table 'test':"
(1,"test string 2")
~~~~~~~~

I include *README.md* files in the project directories with specific instructions.

If you are an Emacs user I recommend that you follow the instructions in Appendix A, load the tutorial files into an Emacs buffer, build an example and open a REPL frame. If one is not already open type control-c control-l, switch to the REPL frame, and run the **main** function. When you make changes to the tutorial files, doing another control-c control-l will re-build the example in less than a second. In addition to using Emacs I occasionally use the IntelliJ Community Edition (free) IDE with the Haskell plugin, the TextMate editor (OS X only) with the Haskell plugin, or the GNU GEdit editor (Linux only).

Whether you use Emacs or run a REPL in a terminal window (command window if you are using Windows) the important thing is to get used to and enjoy the interactive style of development that Haskell provides.

## Why Haskell?

I have been using Lisp programming languages professionally since 1982. Lisp languages are flexible and appropriate for many problems. Some might dissagree with me but I find that Haskell has most of the advantages of Lisp with the added benefit of being strongly typed. Both Lisp and Haskell support a style of development using an interactive shell (or "repl").

What does being a strongly typed language mean? In a practical sense it means that you will often encounter syntax errors caused by type mismatches that you will need to fix before your code will compile (or run in the GHCi shell interpreter). Once your code compiles it will likely work, barring a logic error. The other benefit  that you can get is having to write fewer unit tests - at least that is my experience. So, using a strongly typed language is a tradeoff. When I don't use Haskell I tend to use dynamic languages like Clojure and Ruby.

## Enjoy Yourself

I have worked hard to make learning Haskell as easy as possible for you. If you are new to the Haskell programming language then I have something to ask of you, dear reader: please don't rush through this book, rather take it slow and take time to experiment with the programming examples that most interest you.

## Acknowledgements

I would like to thank my wife Carol Watson for editing the manuscript for this book. I would like to thank Roy Marantz for reporting an error in the text.