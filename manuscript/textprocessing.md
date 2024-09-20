# Text Processing

In my work in data science and machine learning, processing text is a core activity. I am a practitioner, not a research scientist, and in a practical sense, I spend a fair amount of time collecting data (e.g., web scraping and using semantic web/linked data sources), cleaning it, and converting it to different formats.

We will cover three useful techniques: parsing and using CSV (comma separated values) spreadsheet files, parsing and using JSON data, and cleaning up natural language text that contains noise characters.

## CSV Spreadsheet Files

The comma separated values (CSV) format is a plain text format that all spreadsheet applications support. The following example illustrates two techniques that we haven't covered yet:

- Extracting values from the **Either** type.
- Using destructuring to concisely extract parts of a list.

The **Either** type *Either a b* contains either a *Left a* or a *Right b* value and is usually used to return an error in **Left** or a value in **Right**. We will using the **Data.Either.Unwrap** module to unwrap the **Right** part of a call to the **Text.CSV.parseCSVFromFile** function that reads a CSV file and returns a **Left** error or the data in the spreadsheet in a list as the **Right** value.

The destructuring trick in line 15 in the following listing lets us separate the head and rest of a list in one operation; for example:

{lang="haskell",linenos=off}
~~~~~~~~
*TestCSV> let z = [1,2,3,4,5]
*TestCSV> z
[1,2,3,4,5]
*TestCSV> let x:xs = z
*TestCSV> x
1
*TestCSV> xs
[2,3,4,5]
~~~~~~~~

Here is how to read a CSV file:

{lang="haskell",linenos=on}
~~~~~~~~
module TestCSV where

import Text.CSV (parseCSVFromFile, CSV)
import Data.Either.Unwrap (fromRight)

readCsvFile :: FilePath -> CSV
readCsvFile fname = do
  c <- parseCSVFromFile fname
  return $ fromRight c

main = do
  c <- readCsvFile "test.csv"
  print  c  -- includes header and data rows
  print $ map head c  -- print header
  let header:rows = c -- destructure
  print header
  print rows
~~~~~~~~

Function **readCsvFile** reads from a file and returns a **CSV**. What is a **CSV** type? You could search the web for documentation, but dear reader, if you have worked this far learning Haskell, by now you know to rely on the GHCi repl:

{lang="haskell",linenos=off}
~~~~~~~~
*TestCSV> :i CSV
type CSV = [Text.CSV.Record] 	-- Defined in ‘Text.CSV’
*TestCSV> :i Text.CSV.Record
type Text.CSV.Record = [Text.CSV.Field] 	-- Defined in ‘Text.CSV’
*TestCSV> :i Text.CSV.Field
type Text.CSV.Field = String 	-- Defined in ‘Text.CSV’
~~~~~~~~

So, a **CSV** is a list of records (rows in the spreadsheet file), each record is a list of fields (i.e., a string value).

The output when reading the CVS file *test.csv* is:

{lang="haskell",linenos=off}
~~~~~~~~
Prelude> :l TestCSV
[1 of 1] Compiling TestCSV          ( TestCSV.hs, interpreted )
Ok, modules loaded: TestCSV.
*TestCSV> main
[["name"," email"," age"],["John Smith"," jsmith@acmetools.com"," 41"],["June Jones"," jj@acmetools.com"," 38"]]
["name","John Smith","June Jones"]
["name"," email"," age"]
[["John Smith"," jsmith@acmetools.com"," 41"],["June Jones"," jj@acmetools.com"," 38"]]
~~~~~~~~


## JSON Data

JSON is the native data format for the Javascript language and JSON has become a popular serialization format for exchanging data between programs on a network. In this section I will demonstrate serializing a Haskell type to a string with JSON encoding and then perform the opposite operation of deserializing a string containing JSON encoded data back to an object.

The first example uses the module **Text.JSON.Generic** (from the *json* library) and the second example uses module **Data.Aeson** (from the *aeson* library).

In the first example, we set the language type to include DeriveDataTypeable so a new type definition can simply derive *Typeable* which allows the compiler to generate appropriate **encodeJSON** and **decodeJSON** functions for the type **Person** we define in the example:

{lang="haskell",linenos=on}
~~~~~~~~
{-# LANGUAGE DeriveDataTypeable #-}

module TestTextJSON where

import Text.JSON.Generic
          
data Person = Person {name::String, email::String}
                     deriving (Show, Data, Typeable)

main = do
  let a = encodeJSON $ Person "Sam" "sam@a.com"
  print a
  let d = (decodeJSON a :: Person)
  print d
  print $ name d
  print $ email d
~~~~~~~~

Notice that in line 13 that I specified the expected type in the **decodeJSON** call. This is not strictly required, the Haskell GHC compiler knows what to do in this case. I specified the type for code readability. The Haskell compiler wrote the **name** and **email** functions for me and I use these functions in lines 15 and 16 to extract these fields. Here is the output from running this example:

{lang="haskell",linenos=on}
~~~~~~~~
Prelude> :l TestTextJSON.hs 
[1 of 1] Compiling TestTextJSON     ( TestTextJSON.hs, interpreted )
Ok, modules loaded: TestTextJSON.
*TestTextJSON> main
"{\"name\":\"Sam\",\"email\":\"sam@a.com\"}"
Person {name = "Sam", email = "sam@a.com"}
"Sam"
"sam@a.com"
~~~~~~~~

The next example uses the *Aeson* library and is similar to this example.

Using *Aeson*, we set a language type *DeriveGeneric*  and in this case have the **Person** class derive **Generic**. The School of Haskell has an [excellent Aeson tutorial](https://www.schoolofhaskell.com/school/starting-with-haskell/libraries-and-frameworks/text-manipulation/json) that shows a trick I use in this example: letting the compiler generate required functions for types **FromJSON** and **ToJSON** as seen in lines 12-13.

{lang="haskell",linenos=on}
~~~~~~~~
{-# LANGUAGE DeriveGeneric #-}

module TestJSON where

import Data.Aeson
import GHC.Generics
import Data.Maybe

data Person = Person {name::String, email::String } deriving (Show, Generic)

-- nice trick from School Of Haskell tutorial on Aeson:
instance FromJSON Person  -- DeriveGeneric language setting allows
instance ToJSON Person    -- automatic generation of instance of
                          -- types deriving Generic.

main = do
  let a = encode $ Person "Sam" "sam@a.com"
  print a
  let (Just d) = (decode a :: Maybe Person)
  print d
  print $ name d
  print $ email d
~~~~~~~~

I use a short cut in line 19, assuming that the **Maybe** object returned from **decode** (which the compiler wrote automatically for the type **FromJSON**) contains a **Just** value instead of an empty **Nothing** value. So in line 19 I directly unwrap the **Just** value.

Here is the output from running this example:

{lang="haskell",linenos=on}
~~~~~~~~
Prelude> :l TestAESON.hs 
[1 of 1] Compiling TestJSON         ( TestAESON.hs, interpreted )
Ok, modules loaded: TestJSON.
*TestJSON> main
"{\"email\":\"sam@a.com\",\"name\":\"Sam\"}"
Person {name = "Sam", email = "sam@a.com"}
"Sam"
"sam@a.com"
~~~~~~~~

Line 5 shows the result of printing the JSON encoded string value created by the call to **encode** in line 17 of the last code example. Line 6 shows the decoded value of type **Person**, and lines 7 and 8 show the inner wrapped values in the **Person** data.


## Cleaning Natural Language Text

I spend a lot of time working with text data because I have worked on NLP (natural language processing) projects for over 25 years. We will jump into some interesting NLP applications in the next chapter. I will finish this chapter with strategies for cleaning up text which is often a precursor to performing NLP.

You might be asking why we would need to clean up text. Here are a few common use cases:

- Text fetched from the web frequently contains garbage characters.
- Some types of punctuation need to be removed.
- Stop words (e.g., the, a, but, etc.) need to be removed.
- Special unicode characters are not desired.
- Sometimes we want white space around punctuation to make tokenizing text easier.

Notice the **module** statement on line 1 of the following listing: I am exporting functions **cleanText** and **removeStopWords** so they will be visible and available for use by any other modules that import this module. In line 6 we import **intercalate** which constructs a string from a space character and an [String]  (i.e., a list of strings); here is an example where instead of adding a space character between the strings joined together, I add "*" characters:

{lang="haskell",linenos=off}
~~~~~~~~
*CleanText> intercalate "*" ["the", "black", "cat"]
"the*black*cat"
~~~~~~~~

The function **cleanText** removes garbage characters and makes sure that any punctuation characters are surrounded by white space (this makes it easier, for example, to determine sentence boundaries). Function **removeStopWords** removes common words like "a", "the", etc. from text.

{lang="haskell",linenos=on}
~~~~~~~~
module CleanText (cleanText, removeStopWords)  where

import Data.List.Split (splitOn)
import Data.List (intercalate)
import Data.Char as C
import Data.List.Utils (replace)

noiseCharacters = ['[', ']', '{', '}', '\n', '\t', '&', '^', 
                   '@', '%', '$', '#', ',']

substituteNoiseCharacters :: [Char] -> [Char]
substituteNoiseCharacters =
  map (\x -> if elem x noiseCharacters then ' ' else x)

cleanText s =
  intercalate
   " " $
   filter
     (\x -> length x > 0) $
     splitOn " " $ substituteNoiseCharacters $
       (replace "." " . "
        (replace "," " , " 
         (replace ";" " ; " s)))

stopWords = ["a", "the", "that", "of", "an"]

toLower' :: [Char] -> [Char]
toLower' s = map (\x -> if isLower x then x else (C.toLower x)) s

removeStopWords :: String -> [Char]
removeStopWords s =
  intercalate
     " " $
    filter
      (\x -> notElem (toLower' x) stopWords) $
      words s

main = do
  let ct = cleanText "The[]@] cat, and all dog, escaped&^. They were caught."
  print ct
  let nn = removeStopWords ct
  print nn
~~~~~~~~

This example should be extended with additional noise characters and stop words, depending on your application. The function **cleanText** simply uses substring replacements.

Let's look more closely at **removeStopWords** that takes a single argument **s**, which is expected to be a string. **removeStopWords** uses a combination of several functions to remove stop words from the input string. The function **words** is used to split the input string **s** into a list of words.
Then, the function **filter** is used to remove any words that match a specific condition. Here the condition is defined as a lambda function, which is passed as the first argument to the filter function. The lambda function takes a single argument **x** and returns a Boolean value indicating whether the word should be included in the output or not. The lambda function uses function **notElem** to check whether the lowercased version of the word **x** is present in a predefined list of stop words. Finally, we use the function **intercalate** to join the remaining words back into a single string. The first argument to function ** intercalate** is the separator that should be used to join the words, in this case, it's a single space.

Here is the output from this example:

{lang="haskell",linenos=on}
~~~~~~~~
*TestCleanText> :l CleanText.hs 
[1 of 1] Compiling TestCleanText    ( CleanText.hs, interpreted )
Ok, modules loaded: TestCleanText.
*TestCleanText> main
"The cat and all dog escaped . They were caught ."
"cat dog escaped . They were caught ."
~~~~~~~~

We will continue working with text in the next chapter.
