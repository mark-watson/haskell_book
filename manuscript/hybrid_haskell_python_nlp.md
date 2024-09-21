# Hybrid Haskell and Python Natural Language Processing

Here we will write a Haskell client for using a Natural Language Processing (NLP) server written in Python. There is some common material in this chapter and the next chapter *Hybrid Haskell and Python For Coreference Resolution* because I wanted both chapters to be self contained.

## Example Use of the Haskell NLP Client

Before learning how to use the Python NLP server code and to understand the code for the Haskell client code, let's look at an example of running the client code so you understand the type of processing that we are performing:

```{line-numbers: true}
$ stack build --fast --exec HybridHaskellPythonNlp-exe
Enter text (all on one line)
John Smith went to Mexico to see the Pepsi plant
response from NLP server:
NlpResponse {entities = ["John Smith/PERSON","Mexico/GPE","Pepsi/ORG"],
             tokens = ["John","Smith","went","to","Mexico","to","see",
                       "the","Pepsi","plant"]}
Enter text (all on one line)
```

Notice on line 5 that each of the three entities is tagged with the entity type. **GPE** is the tag for a country and the tag **ORG** can refer to an entity that is a company or a non-profit organization.

There is some overlap in functionality between the Python SpaCy NLP library and my pure Haskell code in the **NLP** **Tools** chapter. SpaCy has the advantage of using state of the art deep learning models.

## Setting up the Python NLP Server

I assume that you have some familiarity with using Python. If not, you will still be able to follow these directions assuming that you have the utilities **pip**, and **python** installed. I recommend installing Python and Pip using [Anaconda](https://anaconda.org/anaconda/conda).

The server code is in the subdirectory **HybridHaskellPythonNlp/python_spacy_nlp_server** where you will work when performing a one time initialization. After the server is installed you can then run it from the command line from any directory on your laptop.

I recommend that you use virtual Python environments when using Python applications to separate the dependencies required for each application or development project. Here I assume that you are running in a Python version 3.6 (or higher) version environment. First install the dependencies:

```{line-numbers: false}
pip install -U spacy
python -m spacy download en
pip install falcon
```

Then change directory to the subdirectory **HybridHaskellPythonNlp/python_spacy_nlp_server** and install the NLP server:

```{line-numbers: false}
cd HybridHaskellPythonNlp/python_spacy_nlp_server
python setup.py install
```

Once you install the server, you can run it from any directory on your laptop or server using:

```{line-numbers: false}
spacynlpserver
```

I use deep learning models written in Python using TensorFlow or PyTorch in applications I write in Haskell or Common Lisp. While it is possible to directly embed models in Haskell and Common Lisp, I find it much easier and developer friendly to wrap deep learning models I use a REST services as I have done here. Often deep learning models only require about a gigabyte of memory and using pre-trained models has lightweight CPU resource needs so while I am developing on my laptop I might have two or three models running and available as wrapped REST services. For production, I configure both the Python services and my Haskell and Common Lisp applications to start automatically on system startup.

This is not a Python programming book and I will not discuss the simple Python wrapping code but if you are also a Python developer you can easily read and understand the code.


## Understanding the Haskell NLP Client Code

The Python server returns JSON file. We saw earlier the use of the Haskell **aeson** library for parsing JSON data stored as a string into Haskell native data. We also used the **wreq** library to access remote web services. We use both of these libraries here:


```haskell{line-numbers: false}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveDataTypeable #-}

-- reference: http://www.serpentine.com/wreq/tutorial.html
module NlpWebClient
  ( nlpClient, NlpResponse
  ) where

import Control.Lens
import Data.ByteString.Lazy.Char8 (unpack)
import Data.Maybe (fromJust)
import Network.URI.Encode as E -- encode is also in Data.Aeson
import Network.Wreq

import Text.JSON.Generic

data NlpResponse = NlpResponse {entities::[String], tokens::[String]} deriving (Show, Data, Typeable)

base_url = "http://127.0.0.1:8008?text="

nlpClient :: [Char] -> IO NlpResponse
nlpClient query = do
  putStrLn $ "\n\n***  Processing " ++ query
  r <- get $ base_url ++ (E.encode query) ++ "&no_detail=1"
  let ret = (decodeJSON (unpack (fromJust (r ^? responseBody)))) :: NlpResponse
  return ret
```

This Haskell code snippet defines a simple web client (`nlpClient`) that interacts with an NLP (Natural Language Processing) service. 

* It sends a query text to the NLP service.
* It receives a JSON response containing entities and tokens extracted from the query.
* It parses the JSON response and returns the structured data.

### Code Explanation

**1. Language Extensions**

* `OverloadedStrings`: Allows using string literals (`"like this"`) as both `String` and `Text` types, making string handling more convenient.
* `DeriveDataTypeable`:  Automatically generates instances of the `Data` and `Typeable` classes for the `NlpResponse` data type.  This enables easy serialization/deserialization and runtime type checking.

**2. Imports**

* `Control.Lens`: Used for concisely accessing nested data structures (like `r ^? responseBody`).
* `Data.ByteString.Lazy.Char8`: Handles lazy ByteStrings, which are efficient for processing large responses.
* `Data.Maybe`: Provides the `fromJust` function to safely extract values from `Maybe` types.
* `Network.URI.Encode`: Used for URL-encoding the query text.
* `Network.Wreq`: A simple HTTP client library for making requests.
* `Text.JSON.Generic`: For generic JSON parsing.

**3. `NlpResponse` Data Type**

* Represents the structured data returned by the NLP service.
* Has two fields:
    * `entities`: A list of strings representing the identified entities.
    * `tokens`:  A list of strings representing the tokens in the query.

**4. `base_url`**

* The base URL of the NLP service.
* Assumes the service runs locally (`127.0.0.1`) on port 8008.
* Takes the query text as a parameter (`?text=`).
* Appends `&no_detail=1` to request a simplified response.

**5. `nlpClient` Function**

* Takes a query text (`[Char]`) as input.
* Prints a log message indicating the query being processed.
* Constructs the full URL by:
    * Appending the base URL.
    * URL-encoding the query using `E.encode`.
    * Adding the `&no_detail=1` parameter.
* Makes an HTTP GET request to the constructed URL using `get`.
* Extracts the response body from the result using `r ^? responseBody`.
* Decodes the JSON response using `decodeJSON` and `unpack`.
* Returns the parsed `NlpResponse`.

This code provides a basic way to interact with an NLP service from Haskell. It sends queries, handles the response, and extracts relevant information in a structured format.

The main command line program for using the client library:

```haskell{line-numbers: false}
module Main where

import NlpWebClient
    
main :: IO ()
main = do
  putStrLn "Enter text (all on one line)"
  s <- getLine
  response <- (nlpClient s) :: IO NlpResponse
  putStr "response from NLP server:\n"
  putStrLn $ show response
  main
```

This code snippet defines a simple interactive application that:

1. Prompts the user to enter a line of text.
2. Sends the entered text to an NLP (Natural Language Processing) service using the `nlpClient` function from the `NlpWebClient` module.
3. Prints the response received from the NLP service.
4. Repeats the process (allowing the user to enter another query).

### Explanation

* **Imports:**
   * `NlpWebClient`: Imports the `nlpClient` function and the `NlpResponse` data type, presumably defined in another module.

* **`main` Function:**
   * **`putStrLn "Enter text (all on one line)"`**: Prints a prompt to the user.
   * **`s <- getLine`**: Reads a line of input from the user and stores it in the `s` variable.
   * **`response <- (nlpClient s) :: IO NlpResponse`**: 
      * Calls the `nlpClient` function with the user's input (`s`).
      * The `:: IO NlpResponse` type annotation ensures that the result of `nlpClient s` is treated as an `IO` action that produces an `NlpResponse`.
      * The result of this action (the `NlpResponse` value) is bound to the `response` variable.
   * **`putStr "response from NLP server:\n"`**: Prints a label for the response.
   * **`putStrLn $ show response`**: 
      * Uses `show` to convert the `NlpResponse` value to a string representation.
      * Prints the string representation of the response.
   * **`main`**: Recursively calls the `main` function, creating an infinite loop that allows the user to enter multiple queries.

### Key Points

* **Interaction:** The code interacts with the user through the console, taking input and displaying output.
* **NLP Processing:** It relies on the `nlpClient` function from the `NlpWebClient` module to communicate with an NLP service and process the user's input.
* **Infinite Loop:** The recursive call to `main` at the end creates a continuous loop, allowing the user to enter multiple queries until they manually terminate the program. 


## Wrap Up for Using the Python SpaCy NLP Service

The example in this chapter shows a technique that I often use for using libraries and frameworks that are not written in Haskell: wrap the service implemented in another programming language is a REST web service. While it is possible to use a foreign function interface (FFI) to call out to code written in other languages I find for my own work that I prefer calling out to a separate service especially when I run other services on remote servers so I do not need to run them on my development laptop. For production it is also useful to be able to easily scale horizontally across servers.

