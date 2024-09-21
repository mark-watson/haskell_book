# Hybrid Haskell and Python For Coreference Resolution

Here we will write a Haskell client for using a server written in Python that performs coreference resolution (more on this later). There is some common material in this chapter and the last chapter *Hybrid Haskell and Python Natural Language Processing* because I wanted both chapters to be self contained. The code for this chapter can be found in the subdirectory **HybridHaskellPythonCorefAnaphoraResolution**.

Coreference resolution is also called anaphora resolution and is the process for replacing pronouns in text with the original nouns, proper nouns, or noun phrases that the pronouns refer to.

Before discussing setting up the Python library for performing coreference analysis and the Haskell client, let's run the client so you can see and understand anaphora resolution:

```{line-numbers: false}
 $ stack build --fast --exec HybridHaskellPythonCorefAnaphoraResolution-exe
Enter text (all on one line)
John Smith drove a car. He liked it.


***  Processing John%20Smith%20drove%20a%20car.%20He%20liked%20it.
status code: 200
content type: Just "application/text"
response body: John Smith drove a car. John Smith liked a car.
response from coreference server:	"John Smith drove a car. John Smith liked a car."
Enter text (all on one line)
```

In this example notice that the words "He" and "it" in the second sentence are replaced by "John Smith" and "a car" which makes it easier to write information extraction applications.

## Installing the Python Coreference Server

I recommend that you use virtual Python environments when using Python applications to separate the dependencies required for each application or development project. Here I assume that you are running in a Python version 3.6 (or higher) version environment. If you want to install the **neuralcoref** library using **pip** you must use and older version of **spaCy**. First install the dependencies:

```{line-numbers: false}
pip install spacy==2.1.0
pip install neuralcoref 
pip install falcon
```

As I write this chapter the *neuralcoref* model and library require a old version of **spaCy**.

If you want to instead use the latest version of **spaCy** then install **neuralcoref** from source:

```{line-numbers: false}
pip install spacy
git clone https://github.com/huggingface/neuralcoref.git
cd neuralcoref
python setup.py install
pip install falcon
```

After installing all dependencies, then change directory to the subdirectory **python_coreference_anaphora_resolution_server** and install the coref server:

```{line-numbers: false}
cd python_coreference_anaphora_resolution_server
python setup.py install
```

Once you install the server, you can run it from any directory on your laptop or server using:

```{line-numbers: false}
corefserver
```

I use deep learning models written in Python using TensorFlow or PyTorch in applications I write in Haskell or Common Lisp. While it is possible to directly embed models in Haskell and Common Lisp, I find it much easier and developer friendly to wrap deep learning models I use as REST services as I have done here. Often deep learning models only require about a gigabyte of memory and using pre-trained models has lightweight CPU resource needs so while I am developing on my laptop I might have two or three models running and available as wrapped REST services. For production, I configure both the Python services and my Haskell and Common Lisp applications to start automatically on system startup.

This is not a Python programming book and I will not discuss the simple Python wrapping code but if you are also a Python developer you can easily read and understand the code.

## Understanding the Haskell Coreference Client Code

The code for the library for fetching data from the Python service is in the subdirectory **src** in the file **CorefWebClient.hs**.

We will use techniques for accessing remote web services using the **wreq** library and using the **lens** library for accessing the response from the Python server. Here the response is plain text with pronouns replaced by the nouns that they represent. We don't use the **aeson** library to parse JSON data as we did in the previous chapter.


```haskell{line-numbers: false}
{-# LANGUAGE OverloadedStrings #-}

-- reference: http://www.serpentine.com/wreq/tutorial.html
module CorefWebClient
  ( corefClient
  ) where

import Control.Lens
import Data.ByteString.Lazy.Char8 (unpack)
import Data.Maybe (fromJust)
import Network.URI.Encode (encode)
import Network.Wreq

base_url = "http://127.0.0.1:8000?text="

corefClient :: [Char] -> IO [Char]
corefClient query = do
  putStrLn $ "\n\n***  Processing " ++ (encode query)
  r <- get $ base_url ++ (encode query) ++ "&no_detail=1"
  putStrLn $ "status code: " ++ (show (r ^. responseStatus . statusCode))
  putStrLn $ "content type: " ++ (show (r ^? responseHeader "Content-Type"))
  putStrLn $ "response body: " ++ (unpack (fromJust (r ^? responseBody)))
  return $ unpack (fromJust (r ^? responseBody))
```

This code defines a function `corefClient` which acts as a simple web client to interact with a Coreference Resolution service.

### Code Breakdown

* `base_url`: Stores the base URL of the Coreference Resolution service, assumed to be running locally on port 8000.
* `corefClient`:
    * Takes a text query as input.
    * Prints the encoded query to the console.
    * Constructs the full URL by appending the encoded query and `&no_detail=1` to `base_url`.
    * Makes an HTTP GET request to the constructed URL using `get`.
    * Prints the status code, content type, and response body from the server's response.
    * Returns the response body as a string.

### Key Points

* `OverloadedStrings` language extension is used for convenient string handling.
* `Control.Lens` provides tools for accessing nested data structures (like `r ^. responseStatus . statusCode`).
* `Data.ByteString.Lazy.Char8` is used for efficient handling of the response body.
* `Data.Maybe` provides `fromJust` for safely extracting values from `Maybe` types.
* `Network.URI.Encode` is used for URL-encoding the query.
* `Network.Wreq` is a simple HTTP client library. 


The code for the main application is in the subdirectory **app** in the file **Main.hs**.

```haskell{line-numbers: false}
module Main where

import CorefWebClient

main :: IO ()
main = do
  putStrLn "Enter text (all on one line)"
  s <- getLine
  response <- corefClient s
  putStr "response from coreference server:\t"
  putStrLn $ show response
  main
```

This Haskell code creates a basic interactive console application that:

1. Prompts the user to input a line of text.
2. Sends the text to a Coreference Resolution service using the `corefClient` function.
3. Prints the response from the service.
4. Repeats the process, allowing continuous interaction.

## Key Points

* `corefClient` (imported from `CorefWebClient`) is assumed to handle communication with the Coreference Resolution service.
* The code uses `getLine` for user input, `putStrLn` for output, and `show` to convert the response to a printable format.
* The recursive call to `main` creates an infinite loop, allowing the user to process multiple inputs until they manually terminate the program. 



## Wrap Up for Using the Python Coreference NLP Service

The example in this chapter is fairly simple but shows a technique that I often use for using libraries and frameworks that are not written in Haskell: wrap the service implemented in another programming language is a REST web service. While it is possible to use a foreign function interface (FFI) to call out to code written in other languages I find for my own work that I prefer calling out to a separate service, especially when I run other services on remote servers so I do not need to run them on my development laptop. For production it is also useful to be able to easily scale horizontally across servers.
