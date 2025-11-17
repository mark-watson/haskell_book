# Using the OpenAI Large Language Model APIs in Haskell

Here we will use the library **openai-hs** written by Alexander Thiemann. The GitHub repository for his library is [https://github.com/agrafix/openai-hs/tree/main/openai-hs](https://github.com/agrafix/openai-hs/tree/main/openai-hs).

We will start by writing client code to call the OpenAI completion API for an arbitrary input text. We will then use this completion client code for a specialized application: finding all the place names in input text and returning them as a list of strings.

In the development of practical AI systems, LLMs like those provided by OpenAI, Anthropic, and Hugging Face have emerged as pivotal tools for numerous applications including natural language processing, generation, and understanding. These models, powered by deep learning architectures, encapsulate a wealth of knowledge and computational capabilities. As a Haskell enthusiast embarking on the journey of intertwining the elegance of Haskell with the power of these modern language models, you might also want to experiment with the OpenAI Python examples that are much more complete than what we look at here.

OpenAI provides an API for developers to access models like GPT-4o. The OpenAI API is designed with simplicity and ease of use in mind, making it a common choice for developers. It provides endpoints for different types of interactions, be it text completion, translation, or semantic search among others. We will use the text completion API in this chapter. The robustness and versatility of the OpenAI API make it a valuable asset for anyone looking to integrate advanced language understanding and generation capabilities into their applications.

While we use the GPT-4o model here, you can substitute the following models:

- GPT-5 - expensive to run, for complex multi-step tasks
- GPT-5-mini - inexpensive to run, for simpler tasks (this is the default model I use)
- o1 - very expensive to run, most capable model that has massive knowledge of the real world and can solve complex multi-step reasoning problems.
- o1-mini - slightly less expensive to run than o1-preview, less real world knowledge and simpler reasoning capabilities.

## Example Client Code

This Haskell program demonstrates how to interact with the OpenAI ChatCompletion API using the Openai-hs library. The code sends a prompt to the OpenAI API and prints the assistant’s response to the console. It’s a practical example of how to set up an OpenAI client, create a request, handle the response, and manage potential errors in a Haskell application.

Firstly, the code imports necessary modules and libraries. It imports **OpenAI.Client** for interacting with the OpenAI API and **Network.HTTP.Client** along with **Network.HTTP.Client.TLS** for handling HTTP requests over TLS. The **System.Environment** module is used to access environment variables, specifically to retrieve the OpenAI API key. Additionally, **Data.Text** is imported for efficient text manipulation, and **Data.Maybe** is used for handling optional values.

The core of the program is the **completionRequestToString** function. This function takes a String argument **prompt** and returns an IO String, representing the assistant’s response.

What is an **IO String**? In Haskell, IO String represents an action that, when executed, produces a String, whereas String is simply a value.

- IO String: A computation in the IO monad that will produce a String when executed.
- String: A pure value, just a sequence of characters.

You can’t directly extract a String from IO String; you need to perform the IO action (e.g., using main or inside the do notation) to get the result.

Inside function **completionRequestToString**, an HTTP manager with TLS support is created using **newManager tlsManagerSettings**. Then, it retrieves the OpenAI API key from the OPENAI_KEY environment variable using getEnv "OPENAI_KEY" and packs it into a **Text type** with **T.pack**.

An OpenAI client is instantiated using **makeOpenAIClient**, passing the API key, the HTTP manager, and an integer 4, which represents a maximum number of retries. The code then constructs a **ChatCompletionRequest**, specifying the model to use (in this case, **ModelId** "gpt-4o") and the messages to send. The messages consist of a single **ChatMessage** with the user’s prompt, setting **chmContent** to **Just (T.pack prompt)** and **chmRole** to "user". All other optional parameters in the request are left as Nothing, implying default values will be used.

The function then sends the chat completion request using **completeChat** client request and pattern matches on the result to handle both success and failure cases. If the request fails **(Left failure)**, it returns a string representation of the failure. On success **(Right success)**, it extracts the assistant’s reply from the **chrChoices** field. It unpacks the content from Text to String, handling the case where content might be absent by providing a default message “No content”.

Finally, the function **main** serves as the entry point of the program. It calls **completionRequestToString** with the prompt "Write a hello world program in Haskell" and prints the assistant’s response using **putStrLn**. This demonstrates how to use the function in a real-world scenario, providing a complete example of sending a prompt to the OpenAI API and displaying the result.

```haskell
{-# LANGUAGE OverloadedStrings #-}
import OpenAI.Client

import Network.HTTP.Client
import Network.HTTP.Client.TLS
import System.Environment (getEnv)
import qualified Data.Text as T
import Data.Maybe (fromMaybe)
import Data.Text (splitOn)

-- Example using openai-hs for chat completions
-- Requires `OPENAI_KEY` in your environment (e.g., `export OPENAI_KEY=sk-...`)

-- Sends a chat prompt and returns the assistant's text as String
completionRequestToString :: String -> IO String
completionRequestToString prompt = do
    -- Create an HTTPS-capable connection manager
    manager <- newManager tlsManagerSettings
    -- Read your OpenAI API key from the environment
    apiKey <- T.pack <$> getEnv "OPENAI_KEY"
    -- Build a client; the last argument (4) retries on transient network errors
    let client = makeOpenAIClient apiKey manager 4
    -- Describe the chat request to send
    let request = ChatCompletionRequest
                 { chcrModel = ModelId "gpt-5-mini"  -- model to use
                 , chcrMessages =
                    [ ChatMessage
                        { chmContent = Just (T.pack prompt)  -- user prompt
                        , chmRole = "user"
                        , chmFunctionCall = Nothing
                        , chmName = Nothing
                        }
                    ]
                 , chcrFunctions = Nothing
                 , chcrTemperature = Nothing
                 , chcrTopP = Nothing
                 , chcrN = Nothing
                 , chcrStream = Nothing
                 , chcrStop = Nothing
                 , chcrMaxTokens = Nothing
                 , chcrPresencePenalty = Nothing
                 , chcrFrequencyPenalty = Nothing
                 , chcrLogitBias = Nothing
                 , chcrUser = Nothing
                 }
    -- Perform the API call
    result <- completeChat client request
    -- Unpack the result and extract the text content from the first choice
    case result of
        Left failure -> return (show failure)
        Right success ->
            case chrChoices success of
                (ChatChoice {chchMessage = ChatMessage {chmContent = content}} : _) ->
                    return $ fromMaybe "No content" $ T.unpack <$> content
                _ -> return "No choices returned"

-- find place names
-- Extracts place names from `text` (comma-separated) using the chat model
findPlaces :: String -> IO [String]
findPlaces text = do
    -- Construct the extraction prompt
    let prompt = "Extract only the place names separated by commas from the following text:\n\n" ++ text
    response <- completionRequestToString prompt 
    -- Convert Text to String using T.unpack before filtering
    let places = filter (not . null) $ map T.unpack $ splitOn "," (T.pack response) 
    -- Strip leading and trailing whitespace from each place name
    return $ map (T.unpack . T.strip . T.pack) places

-- Extracts person names from `text` (comma-separated) using the chat model
findPeople :: String -> IO [String]
findPeople text = do
    let prompt = "Extract only the person names separated by commas from the following text:\n\n" ++ text
    response <- completionRequestToString prompt
    let people = filter (not . null) $ map T.unpack $ splitOn "," (T.pack response)
    return $ map (T.unpack . T.strip . T.pack) people

-- Demo: generate text, then extract places and people
main :: IO ()
main = do
    -- Generic text generation
    response <- completionRequestToString "Write a hello world program in Haskell"
    putStrLn response

    -- Extract place names
    places <- findPlaces "I visited London, Paris, and New York last year."
    print places

    -- Extract person names
    people <- findPeople "John Smith met with Sarah Johnson and Michael Brown at the conference."
    print people
```

Here is sample output generated by the **gpt-5-mini** OpenAI model:

```text
$ cabal build
Build profile: -w ghc-9.8.1 -O1
$ cabal run  
Sure! Here is a simple "Hello, World!" program in Haskell:

  main :: IO ()
  main = putStrLn "Hello, World!"

Explanation:
- `main :: IO ()` declares that `main` is an I/O action that returns no meaningful value (indicated by `()`).
- `putStrLn "Hello, World!"` is the I/O action that outputs the string "Hello, World!" followed by a newline.

To run this program:
1. Save the code in a file, for example, `hello.hs`.
2. Open a terminal.
3. Navigate to the directory containing `hello.hs`.
4. Run the program using the Haskell compiler/interpreter (GHC). You can do this by running:

   runhaskell hello.hs

or by compiling it and then running the executable:

   ghc -o hello hello.hs
   ./hello
```
    
For completeness, here is a partial listing of the OpenAiApiClient.cabal file:

```haskell
name:                OpenAiApiClient
version:             0.1.0.0
author:              Mark watson and the author of OpenAI Client library Alexander Thiemann
build-type:          Simple
cabal-version:       >=1.10

executable GenText
  hs-source-dirs:      .
  main-is:             GenText.hs
  default-language:    Haskell2010
  build-depends:       base >= 4.7 && < 5, mtl >= 2.2.2, text, http-client >= 0.7.13.1, openai-hs, http-client-tls
```

## Adding a Simple Application: Find Place Names in Input Text

The example file **GenText.hs** contains a small application example that uses the function **completionRequestToString prompt** that we defined in the last section.

Here we define a new function:

```haskell
findPlaces :: String -> IO [String]
findPlaces text = do
    let prompt = "Extract only the place names separated by commas from the following text:\n\n" ++ text
    response <- completionRequestToString prompt 
    -- Convert Text to String using T.unpack before filtering
    let places = filter (not . null) $ map T.unpack $ splitOn "," (T.pack response) 
    -- Strip leading and trailing whitespace from each place name
    return $ map (T.unpack . T.strip . T.pack) places
```

The function **findPlaces** extracts a list of place names from a given text using an LLM (Large Language Model).

- It constructs a prompt instructing the LLM to extract only comma-separated place names.
- It sends this prompt to the LLM using the **completionRequestToString** function.
- It processes the LLM's response, splitting it into a list of potential place names, filtering out empty entries, and stripping leading/trailing whitespace.
- It returns the final list of extracted place names.

You should use the function **findPlaces** as a template for prompting the OpenAI completion models like GPT-4o to perform specific tasks.

Given the example code:

```haskell
main :: IO ()
main = do
    places <- findPlaces "I visited London, Paris, and New York last year."
    print places 
```

The output would look like:

```
["London","Paris","New York"]
```