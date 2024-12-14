# Appendix A - Haskell Tools Setup

Here I discuss the *stack* build tool but as I update this book in September 2024, I now frequently just use *Cabal* to build and run projects. The README files for the examples in the [GitHub repository for this book](https://github.com/mark-watson/haskell_tutorial_cookbook_examples) usually have directions for both *stack* and *Cabal*.

I recommend that if you are new to Haskell that you at least do a minimal installation of *stack* and work through the first chapter using an interactive REPL. After experimenting with the REPL then do please come back to Appendix A and install support for the editor of your choice (or an IDE) and hlint.

## stack

I assume that you have the Haskell package manager *stack* installed. If you have not installed *stack* yet please follow [these directions](http://docs.haskellstack.org/en/stable/README.html).

After installing stack and running it you will have a directory ".stack" in your home directory where stack will keep compiled libraries and configuration data. You will want to create a file "~/.stack/config.yaml" with contents similar to my stack configuration file:

{lang="haskell",linenos=on}
~~~~~~~~
templates:
  params:
      author-email: markw@markwatson.com
      author-name: Mark Watson
      category: dev
      copyright: Copyright 2016-2024 Mark Watson. All rights reserved
      github-username: mark-watson
~~~~~~~~

Replace my name and email address with yours. You might also want to install the package manager Cabal and the "lint" program hlint:

{linenos=off}
~~~~~~~~
$ stack install cabal-install
$ stack install hlint
~~~~~~~~

These installs might take a while so go outside for ten minutes and get some fresh air.

You should get in the habit of running hlint on your code and consider trying to remove all or at least most warnings. You can customize the types of warnings hlint shows: [read the documentation for hlint](https://github.com/ndmitchell/hlint#readme).

### Creating a New Stack Project

I have already created stack projects for the examples in this book. When you have worked through them, then please refer to the [stack documentation for creating projects](https://docs.haskellstack.org/en/stable/README/#start-your-new-project).


## Emacs Setup

There are several good alternatives to using the Emacs editor but Emacs with *haskell-mode* is my favorite environment. There are instructions for adding *haskell-mode* to Emacs on the [project home page on github](https://github.com/haskell/haskell-mode). If you follow these instructions you will have syntax hi-liting and Emacs will understand Haskell indentation rules.

## Do you want more of an IDE-like Development Environment?

I recommend and use the [Intero Emacs package](https://commercialhaskell.github.io/intero/) to get auto completions and real time syntax error warnings. **Intero** is designed to work with *stack*.

I add the following to the bottom of my .emacs file:

(add-hook 'haskell-mode-hook 'intero-mode)

and if Intero is too "heavy weight" for my current project, then I comment out the add-hook expression. Intero can increase the startup time for Emacs for editing Haskell files. That said, I almost always keep Intero enabled in my Emacs environment.

## hlint

**hlint** is a wonderful tool for refining your knowledge and use of the Haskell language. After writing new code and checking that it works, then run **hlint** for suggestions on how to improve your code.

Install **hlint** using:

{lang="haskell",linenos=on}
~~~~~~~~
stack install hlint
~~~~~~~~


