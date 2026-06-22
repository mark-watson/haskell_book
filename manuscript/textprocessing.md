# Text Processing

In my work in data science and machine learning, processing text is a core activity. I am a practitioner, not a research scientist, and in a practical sense, I spend a fair amount of time collecting data (e.g., web scraping and using semantic web/linked data sources), cleaning it, and converting it to different formats.

We will cover three useful techniques: parsing and using CSV (comma separated values) spreadsheet files, parsing and using JSON data, and cleaning up natural language text that contains noise characters.

## CSV Spreadsheet Files

The comma separated values (CSV) format is a plain text format that all spreadsheet applications support. The following example illustrates two techniques that we haven't covered yet:

- Handling the **Either** type with pattern matching.
- Using destructuring to concisely extract parts of a list.

The **Either** type *Either a b* contains either a *Left a* or a *Right b* value and is usually used to return an error in **Left** or a value in **Right**. The **Text.CSV.parseCSVFromFile** function reads a CSV file and returns a **Left** error or the data in the spreadsheet in a list as the **Right** value. We use a **case** expression to pattern match on the result.

![Text Processing Pipeline Architecture](FIG_TextProcessing.jpg)

The destructuring trick in line 21 in the following listing lets us separate the head and rest of a list in one operation; for example:

```haskell{line-numbers: false}
*TestCSV> let z = [1,2,3,4,5]
*TestCSV> z
[1,2,3,4,5]
*TestCSV> let x:xs = z
*TestCSV> x
1
*TestCSV> xs
[2,3,4,5]
```

Here is how to read a CSV file:

```haskell{line-numbers: true}
module Main where

import Text.CSV (parseCSVFromFile, CSV)

readCsvFile :: FilePath -> IO CSV
readCsvFile fname = do
  c <- parseCSVFromFile fname
  case c of
    Left err -> do
      putStrLn $ "CSV parse error: " ++ show err
      return []
    Right csv -> return csv

main :: IO ()
main = do
  c <- readCsvFile "test.csv"
  print  c
  print $ map head c
  case c of
    [] -> putStrLn "Warning: CSV file is empty, no header or rows."
    (header:rows) -> do
      print header
      print rows
```

Function **readCsvFile** reads from a file and returns an **IO CSV**. It uses a **case** expression to handle the **Either** value returned by **parseCSVFromFile**: if parsing fails (a **Left** error), we print the error and return an empty list; on success (a **Right** csv), we return the parsed data. What is a **CSV** type? You could search the web for documentation, but dear reader, if you have worked this far learning Haskell, by now you know to rely on the GHCi repl:

```haskell{line-numbers: false}
*TestCSV> :i CSV
type CSV = [Text.CSV.Record] 	-- Defined in ‘Text.CSV’
*TestCSV> :i Text.CSV.Record
type Text.CSV.Record = [Text.CSV.Field] 	-- Defined in ‘Text.CSV’
*TestCSV> :i Text.CSV.Field
type Text.CSV.Field = String 	-- Defined in ‘Text.CSV’
```

So, a **CSV** is a list of records (rows in the spreadsheet file), each record is a list of fields (i.e., a string value).

The output when reading the CVS file *test.csv* is:

```haskell{line-numbers: false}
Prelude> :l TestCSV
[1 of 1] Compiling TestCSV          ( TestCSV.hs, interpreted )
Ok, modules loaded: TestCSV.
*TestCSV> main
[["name"," email"," age"],["John Smith"," jsmith@acmetools.com"," 41"],["June Jones"," jj@acmetools.com"," 38"]]
["name","John Smith","June Jones"]
["name"," email"," age"]
[["John Smith"," jsmith@acmetools.com"," 41"],["June Jones"," jj@acmetools.com"," 38"]]
```


## JSON Data

JSON is the native data format for the Javascript language and JSON has become a popular serialization format for exchanging data between programs on a network. In this section I will demonstrate serializing a Haskell type to a string with JSON encoding and then perform the opposite operation of deserializing a string containing JSON encoded data back to an object.

The first example uses the module **Text.JSON.Generic** (from the *json* library) and the second example uses module **Data.Aeson** (from the *aeson* library).

In the first example, we set the language type to include DeriveDataTypeable so a new type definition can simply derive *Typeable* which allows the compiler to generate appropriate **encodeJSON** and **decodeJSON** functions for the type **Person** we define in the example:

```haskell{line-numbers: true}
{-# LANGUAGE DeriveDataTypeable #-}

module Main where

-- NOTE: Text.JSON.Generic is deprecated. Consider using Data.Aeson
-- (from the 'aeson' package) with DeriveGeneric for new projects.
import Text.JSON.Generic

data Person = Person {name::String, email::String } deriving (Show, Data, Typeable)

main :: IO ()
main = do
  let a = encodeJSON $ Person "Sam" "sam@a.com"
  print a
  --let d = (decodeJSON a :: Person)
  let d = (decodeJSON a)
  print d
  print $ name d
  print $ email d
```

Notice that we call **decodeJSON** without specifying the expected type — the Haskell GHC compiler can infer it from context. The Haskell compiler wrote the **name** and **email** functions for me and I use these functions in lines 18 and 19 to extract these fields. Also note the deprecation comment: **Text.JSON.Generic** is deprecated in favor of **Data.Aeson** which we use in the next example. Here is the output from running this example:

```haskell{line-numbers: false}
Prelude> :l TestTextJSON.hs 
[1 of 1] Compiling TestTextJSON     ( TestTextJSON.hs, interpreted )
Ok, modules loaded: TestTextJSON.
*TestTextJSON> main
"{\"name\":\"Sam\",\"email\":\"sam@a.com\"}"
Person {name = "Sam", email = "sam@a.com"}
"Sam"
"sam@a.com"
```

The next example uses the *Aeson* library and is similar to this example.

Using *Aeson*, we set a language type *DeriveGeneric*  and in this case have the **Person** class derive **Generic**. The School of Haskell has an [excellent Aeson tutorial](https://www.schoolofhaskell.com/school/starting-with-haskell/libraries-and-frameworks/text-manipulation/json) that shows a trick I use in this example: letting the compiler generate required functions for types **FromJSON** and **ToJSON** as seen in lines 12-13.

```haskell{line-numbers: true}
{-# LANGUAGE DeriveGeneric #-}

module Main where

import Data.Aeson
import GHC.Generics
import Data.Maybe

data Person = Person {name::String, email::String } deriving (Show, Generic)

-- nice trick from School Of Haskell tutorial on Aeson:
instance FromJSON Person  -- DeriveGeneric language setting allows
instance ToJSON Person    -- automatic generation of instance of
                          -- types deriving Generic.

main :: IO ()
main = do
  let a = encode $ Person "Sam" "sam@a.com"
  print a
  case decode a :: Maybe Person of
    Nothing -> putStrLn "Error: failed to decode JSON back to Person"
    Just d  -> do
      print d
      print $ name d
      print $ email d
```

We use a **case** expression to safely handle the **Maybe** result returned from **decode** (which the compiler wrote automatically for the type **FromJSON**). If decoding fails, we print an error message; if it succeeds, we unwrap the **Just** value and use it.

Here is the output from running this example:

```haskell{line-numbers: true}
Prelude> :l TestAESON.hs 
[1 of 1] Compiling TestJSON         ( TestAESON.hs, interpreted )
Ok, modules loaded: TestJSON.
*TestJSON> main
"{\"email\":\"sam@a.com\",\"name\":\"Sam\"}"
Person {name = "Sam", email = "sam@a.com"}
"Sam"
"sam@a.com"
```

Line 5 shows the result of printing the JSON encoded string value created by the call to **encode** in line 17 of the last code example. Line 6 shows the decoded value of type **Person**, and lines 7 and 8 show the inner wrapped values in the **Person** data.


## Cleaning Natural Language Text

I spend a lot of time working with text data because I have worked on NLP (natural language processing) projects for over 25 years. We will jump into some interesting NLP applications in the next chapter. I will finish this chapter with strategies for cleaning up text which is often a precursor to performing NLP.

You might be asking why we would need to clean up text. Here are a few common use cases:

- Text fetched from the web frequently contains garbage characters.
- Some types of punctuation need to be removed.
- Stop words (e.g., the, a, but, etc.) need to be removed.
- Special unicode characters are not desired.
- Sometimes we want white space around punctuation to make tokenizing text easier.

In line 6 we import **intercalate** which constructs a string from a space character and an [String]  (i.e., a list of strings); here is an example where instead of adding a space character between the strings joined together, I add "*" characters:

```haskell{line-numbers: false}
*CleanText> intercalate "*" ["the", "black", "cat"]
"the*black*cat"
```

The function **cleanText** removes garbage characters and makes sure that any punctuation characters are surrounded by white space (this makes it easier, for example, to determine sentence boundaries). Function **removeStopWords** removes common words like "a", "the", etc. from text.

```haskell{line-numbers: true}
--  {-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.List.Split (splitOn)
import Data.List (intercalate)
import Data.Char as C
import Data.List.Utils (replace)

noiseCharacters :: [Char]
noiseCharacters = ['[', ']', '{', '}', '\n', '\t', '&', '^', 
                   '@', '%', '$', '#']

substituteNoiseCharacters :: [Char] -> [Char]
substituteNoiseCharacters =
  map (\x -> if elem x noiseCharacters then ' ' else x)

cleanText :: String -> String
cleanText s = 
  intercalate
   " " $
   filter
     (\x -> length x > 0) $
     splitOn " " $ substituteNoiseCharacters $
       (replace "." " . "
        (replace "," " , " 
         (replace ";" " ; " s)))

stopWords :: [String]
stopWords = ["a", "the", "that", "of", "an", "and"]

toLower' :: String -> String
toLower' = map C.toLower

removeStopWords :: String -> [Char]
removeStopWords s =
  intercalate
     " " $
    filter
      (\x -> notElem (toLower' x) stopWords) $
      words s

main :: IO ()
main = do
  let ct = cleanText "The[]@] cat, and all the dogs, escaped&^. They were caught."
  print ct
  let nn = removeStopWords ct
  print nn
```

This example should be extended with additional noise characters and stop words, depending on your application. The function **cleanText** simply uses substring replacements.

Let's look more closely at **removeStopWords** that takes a single argument **s**, which is expected to be a string. **removeStopWords** uses a combination of several functions to remove stop words from the input string. The function **words** is used to split the input string **s** into a list of words.
Then, the function **filter** is used to remove any words that match a specific condition. Here the condition is defined as a lambda function, which is passed as the first argument to the filter function. The lambda function takes a single argument **x** and returns a Boolean value indicating whether the word should be included in the output or not. The lambda function uses function **notElem** to check whether the lowercased version of the word **x** is present in a predefined list of stop words. Finally, we use the function **intercalate** to join the remaining words back into a single string. The first argument to function ** intercalate** is the separator that should be used to join the words, in this case, it's a single space.

Here is the output from this example:

```haskell{line-numbers: false}
*Main> :l CleanText.hs 
[1 of 1] Compiling Main             ( CleanText.hs, interpreted )
Ok, modules loaded: Main.
*Main> main
"The cat , all the dogs , escaped . They were caught ."
"cat , dogs , escaped . They were caught ."
```

We will continue working with text in the next chapter.


## Optional Practice Problems

1. Implement a configuration parser using the Megaparsec parser combinators library to parse key-value configurations with sections.
2. Write a text processing utility that counts the frequency of words in a document, ignoring word capitalization and filtering out common stop words.
