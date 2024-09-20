# Natural Language Processing Tools

The tools developed in this chapter are modules you can reuse in your programs. We will develop a command line program that reads a line of text from STDIN and writes semantic information as output to STDOUT. I have used this in a Ruby program by piping input text data to a forked process and reading the output which is a semantic representation of the input text.

*Note: we previously saw a small application of the OpenAI completion LLMs to find place names in input text. We could replace most of the examples in this chapter with calls to a LLM completion API with NLP specific prompts.*

We will be using this example as an external dependency to a later example in the chapter **Knowledge Graph Creator**.

A few of the data files I provide in this example are fairly large. As an example the file *PeopleDbPedia.hs* which builds a map from people's names to the Wikipedia/DBPedia URI for information about them, is 2.5 megabytes in size. The first time you run *stack build* in the project directory it will take a while, so you might want to start building the project in the directory *NlpTool* and let it run while you read this chapter.

Here are three examples using the NlpTool command line application developed in this chapter:

```{line-numbers: false}
Enter text (all on one line)
Canada and England signed a trade deal.
category:	economics
summary:	Canada and England signed a trade deal. 
countries:	[["Canada","<http://dbpedia.org/resource/Canada>"],
             ["England","<http://dbpedia.org/resource/England>"]]
Enter text (all on one line)
President George W Bush asked Congress for permission to invade Iraq.
category:	news_war
summary:	President George W Bush asked Congress for permission to invade Iraq. 
people:	[["George W Bush","<http://dbpedia.org/resource/George_W._Bush>"]]
countries:	[["Iraq",""]]
Enter text (all on one line)
The British government is facing criticism from business groups over statements suggesting the U.K. is heading for a hard divorce from the European Union — and pressure from lawmakers who want Parliament to have a vote on the proposed exit terms. The government's repeated emphasis on controlling immigration sent out "signs that the door is being closed, to an extent, on the open economy, that has helped fuel investment," the head of employers' group the Confederation of British Industry, Carolyn Fairbairn, said in comments published Monday. Prime Minister Theresa May said last week that Britain would seek to retain a close relationship with the 28-nation bloc, with continued free trade in goods and services. But she said the U.K. wouldn't cede control over immigration, a conflict with the EU's principle of free movement among member states.
category:	economics
summary:	Prime Minister Theresa May said last week that Britain would seek to retain a close relationship with the 28-nation bloc, with continued free trade in goods and services. 
```

*credit: news text from abcnews.com*


## Resolve Entities in Text to DBPedia URIs

The code for this application is in the directory *NlpTool*.

The software and data in this chapter can be used under the terms of either the GPL version 3 license or the Apache 2 license.

There are several automatically generated Haskell formatted data files that I created using Ruby scripts operating the Wikipedia data. For the purposes of this book I include these data-specific files for your use and enjoyment but we won't spend much time discussing them. These files are:

- BroadcastNetworkNamesDbPedia.hs
- CityNamesDbpedia.hs
- CompanyNamesDbpedia.hs
- CountryNamesDbpedia.hs
- PeopleDbPedia.hs
- PoliticalPartyNamesDbPedia.hs
- TradeUnionNamesDbPedia.hs
- UniversityNamesDbPedia.hs

As an example, let's look at a small sample of data in *PeopleDbPedia.hs*:

```haskell{line-numbers: true}
module PeopleDbPedia (peopleMap) where

import qualified Data.Map as M

peopleMap = M.fromList [
  ("Aaron Sorkin", "<http://dbpedia.org/resource/Aaron_Sorkin>"),
  ("Bill Clinton", "<http://dbpedia.org/resource/Bill_Clinton>"),
  ("George W Bush", "<http://dbpedia.org/resource/George_W_Bush>"),
```

There are 35,146 names in the file *PeopleDbPedia.hs*. I have built for eight different types of entity names: Haskell maps that take entity names (String) and maps the entity names into relevant DBPedia URIs. Simple in principle, but a lot of work preparing the data. As I mentioned, we will use these data-specific files to resolve entity references in text.

The next listing shows the file *Entities.hs*. In lines 5-7 I import the entity mapping files I just described. In this example and later code I make heavy use of the **Data.Map** and **Data.Set** modules in the *collections* library (see the NlpTools.cabal file).

The operator **`isSubsetOf`** defined in line 39 tests to see if a value is contained in a collection. The built-in function **all** applies a function or operator to all elements in a collection and returns a true value if the function or operator returns true applied to each element in the collection.

The local utility function **namesHelper** defined in lines 41-53 is simpler than it looks. The function **filter** in line 42 applies the inline function in lines 43-45 (this function returns true for **Maybe** values that contain data) to a second list defined in lines 48-55. This second list is calculated by mapping an inline function over the input argument **ngrams**. The inline function looks up an ngram in a DBPedia map (passed as the second function argument) and returns the lookup value if it is not empty and if it is empty looks up the same ngram  in a word map (last argument to this function).

The utility function **namesHelper** is then used to define functions to recognize company names, country names, people names, city names, broadcast network names, political party names, trade union names, and university names:

```haskell{line-numbers: true}
-- Copyright 2014 by Mark Watson. All rights reserved. The software and data in this project can be used under the terms of either the GPL version 3 license or the Apache 2 license.

module Entities (companyNames, peopleNames,
                 countryNames, cityNames, broadcastNetworkNames,
                 politicalPartyNames, tradeUnionNames, universityNames) where

import qualified Data.Map as M
import qualified Data.Set as S
import Data.Char (toLower)
import Data.List (sort, intersect, intersperse)
import Data.Set (empty)
import Data.Maybe (isJust)

import Utils (splitWords, bigram, bigram_s, splitWordsKeepCase,
              trigram, trigram_s, removeDuplicates)

import FirstNames (firstNames)
import LastNames (lastNames)
import NamePrefixes (namePrefixes)

import PeopleDbPedia (peopleMap)

import CountryNamesDbpedia (countryMap)
import CountryNames (countryNamesOneWord, countryNamesTwoWords, countryNamesThreeWords)

import CompanyNamesDbpedia (companyMap)
import CompanyNames (companyNamesOneWord, companyNamesTwoWords, companyNamesThreeWords)
import CityNamesDbpedia (cityMap)
 
import BroadcastNetworkNamesDbPedia (broadcastNetworkMap)
import PoliticalPartyNamesDbPedia (politicalPartyMap)
import TradeUnionNamesDbPedia (tradeUnionMap)
import UniversityNamesDbPedia (universityMap)

xs `isSubsetOf` ys = all (`elem` ys) xs
    
namesHelper ngrams dbPediaMap wordMap =
  filter 
    (\x -> case x of
         (_, Just x) -> True
         _ -> False) $
    map (\ngram -> (ngram,
                let v = M.lookup ngram dbPediaMap in
                if isJust v
                   then return (ngram, v)
                   else if S.member ngram wordMap
                           then Just (ngram, Just "")
                           else Nothing))
        ngrams   

helperNames1W = namesHelper

helperNames2W wrds = namesHelper (bigram_s wrds)
    
helperNames3W wrds =  namesHelper (trigram_s wrds)

companyNames wrds =
  let cns = removeDuplicates $ sort $
              helperNames1W wrds companyMap companyNamesOneWord ++
              helperNames2W wrds companyMap companyNamesTwoWords ++
              helperNames3W wrds companyMap companyNamesThreeWords in
  map (\(s, Just (a,Just b)) -> (a,b)) cns
  
countryNames wrds =
  let cns = removeDuplicates $ sort $
              helperNames1W wrds countryMap countryNamesOneWord ++
              helperNames2W wrds countryMap countryNamesTwoWords ++
              helperNames3W wrds countryMap countryNamesThreeWords in
  map (\(s, Just (a,Just b)) -> (a,b)) cns

peopleNames wrds =
  let cns = removeDuplicates $ sort $
              helperNames1W wrds peopleMap Data.Set.empty ++
              helperNames2W wrds peopleMap Data.Set.empty ++
              helperNames3W wrds peopleMap Data.Set.empty in
  map (\(s, Just (a,Just b)) -> (a,b)) cns

cityNames wrds =
  let cns = removeDuplicates $ sort $
              helperNames1W wrds cityMap Data.Set.empty ++
              helperNames2W wrds cityMap Data.Set.empty ++
              helperNames3W wrds cityMap Data.Set.empty in
  map (\(s, Just (a,Just b)) -> (a,b)) cns

broadcastNetworkNames wrds =
  let cns = removeDuplicates $ sort $
              helperNames1W wrds broadcastNetworkMap Data.Set.empty ++
              helperNames2W wrds broadcastNetworkMap Data.Set.empty ++
              helperNames3W wrds broadcastNetworkMap Data.Set.empty in
  map (\(s, Just (a,Just b)) -> (a,b)) cns

politicalPartyNames wrds =
  let cns = removeDuplicates $ sort $
              helperNames1W wrds politicalPartyMap Data.Set.empty ++
              helperNames2W wrds politicalPartyMap Data.Set.empty ++
              helperNames3W wrds politicalPartyMap Data.Set.empty in
  map (\(s, Just (a,Just b)) -> (a,b)) cns

tradeUnionNames wrds =
  let cns = removeDuplicates $ sort $
              helperNames1W wrds tradeUnionMap Data.Set.empty ++
              helperNames2W wrds tradeUnionMap Data.Set.empty ++
              helperNames3W wrds tradeUnionMap Data.Set.empty in
  map (\(s, Just (a,Just b)) -> (a,b)) cns

universityNames wrds =
  let cns = removeDuplicates $ sort $
             helperNames1W wrds universityMap Data.Set.empty ++
             helperNames2W wrds universityMap Data.Set.empty ++
             helperNames3W wrds universityMap Data.Set.empty in
  map (\(s, Just (a,Just b)) -> (a,b)) cns


main = do
    let s = "As read in the San Francisco Chronicle, the company is owned by John Smith, Bill Clinton, Betty Sanders, and Dr. Ben Jones. Ben Jones and Mr. John Smith are childhood friends who grew up in Brazil, Canada, Buenos Aires, and the British Virgin Islands. Apple Computer relased a new version of OS X yesterday. Brazil Brazil Brazil. John Smith bought stock in ConocoPhillips, Heinz, Hasbro, and General Motors, Fox Sports Radio. I listen to B J Cole. Awami National Party is a political party. ALAEA is a trade union. She went to Brandeis University."
    --print $ humanNames s
    print $ peopleNames $ splitWordsKeepCase s
    print $ countryNames $ splitWordsKeepCase s
    print $ companyNames $ splitWordsKeepCase s
    print $ cityNames $ splitWordsKeepCase s
    print $ broadcastNetworkNames $ splitWordsKeepCase s
    print $ politicalPartyNames $ splitWordsKeepCase s
    print $ tradeUnionNames $ splitWordsKeepCase s
    print $ universityNames $ splitWordsKeepCase s
```

The following output is generated by running the test **main** function defined at the bottom of the file *app/NlpTool.hs*:

```{line-numbers: false}
$ stack build --fast --exec NlpTool-exe
Building all executables for `NlpTool' once. After a successful build of all of them, only specified executables will be rebuilt.
NlpTool> build (lib + exe)
Preprocessing library for NlpTool-0.1.0.0..
Building library for NlpTool-0.1.0.0..
Preprocessing executable 'NlpTool-exe' for NlpTool-0.1.0.0..
Building executable 'NlpTool-exe' for NlpTool-0.1.0.0..
[1 of 2] Compiling Main
[2 of 2] Compiling Paths_NlpTool
Linking .stack-work/dist/x86_64-osx/Cabal-2.4.0.1/build/NlpTool-exe/NlpTool-exe ...
NlpTool> copy/register
Installing library in /Users/markw/GITHUB/haskell_tutorial_cookbook_examples_private_new_edition/NlpTool/.stack-work/install/x86_64-osx/7a2928fbf8188dcb20f165f77b37045a5c413cc7f63913951296700a6b7e292d/8.6.5/lib/x86_64-osx-ghc-8.6.5/NlpTool-0.1.0.0-DXKbucyA0S0AKOAcZGDl2H
Installing executable NlpTool-exe in /Users/markw/GITHUB/haskell_tutorial_cookbook_examples_private_new_edition/NlpTool/.stack-work/install/x86_64-osx/7a2928fbf8188dcb20f165f77b37045a5c413cc7f63913951296700a6b7e292d/8.6.5/bin
Registering library for NlpTool-0.1.0.0..
Enter text (all on one line)
As read in the San Francisco Chronicle, the company is owned by John Smith, Bill Clinton, Betty Sanders, and Dr. Ben Jones. Ben Jones and Mr. John Smith are childhood friends who grew up in Brazil, Canada, Buenos Aires, and the British Virgin Islands. Apple Computer relased a new version of OS X yesterday. Brazil Brazil Brazil. John Smith bought stock in ConocoPhillips, Heinz, Hasbro, and General Motors, Fox Sports Radio. I listen to B J Cole. Awami National Party is a political party. ALAEA is a trade union. She went to Brandeis University.
category:	news_politics
summary:	ALAEA is a trade union. Apple Computer relased a new version of OS X yesterday.
people:	[["B J Cole","<http://dbpedia.org/resource/B._J._Cole>"]]
companies:	[["Apple","<http://dbpedia.org/resource/Apple>"],["ConocoPhillips","<http://dbpedia.org/resource/ConocoPhillips>"],["Hasbro","<http://dbpedia.org/resource/Hasbro>"],["Heinz","<http://dbpedia.org/resource/Heinz>"],["San Francisco Chronicle","<http://dbpedia.org/resource/San_Francisco_Chronicle>"]]
countries:	[["Brazil","<http://dbpedia.org/resource/Brazil>"],["Canada","<http://dbpedia.org/resource/Canada>"]]
Enter text (all on one line)
```

Note that entities that are not recognized as Wikipedia objects don't get recognized.

## Bag of Words Classification Model

The file *Categorize.hs* contains a simple bag of words classification model. To prepare the classification models, I collected a large set of labelled text. Labels were "chemistry", "computers", etc. I ranked words based on how often they appeared in training texts for a classification category, normalized by how often they appeared in all training texts. This example uses two auto-generated and data-specific Haskell files, one for single words and the other for two adjacent word pairs:

- Category1Gram.hs 
- Category2Gram.hs

In NLP work, single words are sometimes called 1grams and two word adjacent pairs are referred to as 2grams. Here is a small amount of data from *Category1Gram.hs*:

```haskell{line-numbers: true}
module Category1Gram (**onegrams**) where

import qualified Data.Map as M

chemistry = M.fromList [("chemical", 1.15), ("atoms", 6.95),
                        ("reaction", 6.7), ("energy", 6.05),
                          ... ]
computers = M.fromList [("software", 4.6), ("network", 4.65),
                        ("linux", 3.6), ("device", 3.55), ("computers", 3.05),
                        ("storage", 2.7), ("disk", 2.3),
                          ... ]
etc.                          
```

Here is a small amount of data from *Category2Gram.hs*:

```haskell{line-numbers: true}
module Category2Gram (**twograms**) where

import qualified Data.Map as M

chemistry = M.fromList [("chemical reaction", 1.55),
                        ("atoms molecules", 0.6), 
                        ("periodic table", 0.5),
                        ("chemical reactions", 0.5),
                        ("carbon atom", 0.5),
                         ... ]
computers = M.fromList [("computer system", 0.9),
                        ("operating system", 0.75),
                        ("random memory", 0.65),
                        ("computer science", 0.65),
                        ("computer program", 0.6),
                         ... ]
etc.
```

It is very common to use term frequencies for single words for classification models. One problem with using single words is that the evidence that any word gives for a classification is independent of the surrounding words in text being evaluated. By also using word pairs (two word combinations are often called 2grams or two-grams) we pick up patterns like "not good" giving evidence for negative sentiment even with the word "good" in text being evaluated. For my own work, I have a huge corpus of 1gram, 2gram, 3gram, and 4gram data sets. For the purposes of the following example program, I am only using 1gram and 2gram data.

The following listing shows the file *Categorize.hs*. Before looking at the entire example, let's focus in on some of the functions I have defined for using the word frequency data to categorized text.

```haskell{line-numbers: false}
*Categorize> :t stemWordsInString
stemWordsInString :: String -> [Char]
*Categorize> stemWordsInString "Banking industry is sometimes known for fraud."
"bank industri is sometim known for fraud"
```

**stemScoredWordList** is used to create a 1gram to word relevance score for each category. The keys are word stems.

```haskell{line-numbers: false}
*Categorize> stemScoredWordList onegrams 
[("chemistri",fromList [("acid",1.15),("acids",0.8),("alcohol",0.95),("atom",4.45)
```

Notice that "chemistri" is the stemmed version of "chemistry", "bank" for "banks", etc. **stem2** is a 2gram frequency score by category mapping where the keys are word stems:

```haskell{line-numbers: false}
*Categorize> stem2
[("chemistry",fromList [("atom molecul",0.6),("carbon atom",0.5),("carbon carbon",0.5),
```

**stem1** is like **stem2**, but for stemmed 1grams, not 2grams:

```haskell{line-numbers: false}
*Categorize> stem1
[("chemistry",fromList [("acid",0.8),("chang",1.05),("charg",0.95),("chemic",1.15),("chemistri",1.45),
```

**score** is called with a list or words and a word value mapping. Here is an example:

```haskell{line-numbers: false}
*Categorize> :t score
score
  :: (Enum t, Fractional a, Num t, Ord a, Ord k) =>
     [k] -> [(t1, M.Map k a)] -> [(t, a)]
*Categorize> score ["atom", "molecule"] onegrams 
[(0,8.2),(25,2.4)]
```

This output is more than a little opaque. The pair (0, 8.2) means that the input words ["atom", "molecule"] have a score of 8.2 for category indexed at 0 and the pair (25,2.4) means that the input words have a score of 2.4 for the category at index 25. The category at index 0 is chemistry and the category at index 25 is physics as we can see by using the higher level function **bestCategories1** that caluculates categories for a word sequence using 1gram word data:

```haskell{line-numbers: false}
*Categorize> :t bestCategories1
bestCategories1 :: [[Char]] -> [([Char], Double)]
*Categorize> bestCategories1 ["atom", "molecule"]
[("chemistry",8.2),("physics",2.4)]
```

The top level function **bestCategories** uses 1gram data. Here is an example for using it:

```haskell{line-numbers: false}
*Categorize> splitWords "The chemist made a periodic table and explained a chemical reaction"
["the","chemist","made","a","periodic","table","and","explained","a","chemical","reaction"]
*Categorize> bestCategories1 $ splitWords "The chemist made a periodic table and explained a chemical reaction"
[("chemistry",11.25),("health_nutrition",1.2)]
```

Notice that these words were also classified as category "health_nutrition" but with a low score of 1.2. The score for "chemistry" is almost an order of magnitude larger. **bestCategories** sorts return values in "best first" order.

**splitWords** is used to split a string into word tokens before calling **bestCategories**.

Here is the entire example in file *Categorize.hs*:

```haskell{line-numbers: true}
module Categorize (bestCategories, splitWords, bigram) where

import qualified Data.Map as M
import Data.List (sortBy)

import Category1Gram (onegrams)
import Category2Gram (twograms)

import Sentence (segment)

import Stemmer (stem)

import Utils (splitWords, bigram, bigram_s)

catnames1 = map fst onegrams
catnames2 = map fst twograms

stemWordsInString s = init $ concatMap ((++ " ") . stem) (splitWords s)

stemScoredWordList = map (\(str,score) -> (stemWordsInString str, score))

stem2 = map (\(category, swl) ->
              (category, M.fromList (stemScoredWordList (M.toList swl))))
			twograms

stem1 = map (\(category, swl) ->
              (category, M.fromList (stemScoredWordList (M.toList swl))))
		    onegrams

scoreCat wrds amap =
  sum $ map (\x ->  M.findWithDefault 0.0 x amap) wrds

score wrds amap =
 filter (\(a, b) -> b > 0.9) $ zip [0..] $ map (\(s, m) -> scoreCat wrds m) amap
 
cmpScore (a1, b1) (a2, b2) = compare b2 b1
                              
bestCategoriesHelper wrds ngramMap categoryNames=
  let tg = bigram_s wrds in
    map (first (categoryNames !!)) $ sortBy cmpScore $ score wrds ngramMap
       
bestCategories1 wrds =
  take 3 $ bestCategoriesHelper wrds onegrams catnames1

bestCategories2 wrds =
  take 3 $ bestCategoriesHelper (bigram_s wrds) twograms catnames2
       
bestCategories1stem wrds =
  take 3 $ bestCategoriesHelper wrds stem1 catnames1

bestCategories2stem wrds =
  take 3 $ bestCategoriesHelper (bigram_s wrds) stem2 catnames2

bestCategories :: [String] -> [(String, Double)]
bestCategories wrds =
  let sum1 = M.unionWith (+) (M.fromList $ bestCategories1 wrds) ( M.fromList $ bestCategories2 wrds)
      sum2 = M.unionWith (+) (M.fromList $ bestCategories1stem wrds) ( M.fromList $ bestCategories2stem wrds) 
  in sortBy cmpScore $ M.toList $ M.unionWith (+) sum1 sum2
      
main = do
    let s = "The sport of hocky is about 100 years old by ahdi dates. American Football is a newer sport. Programming is fun. Congress passed a new budget that might help the economy. The frontier initially was a value path. The ai research of john mccarthy."
    print $ bestCategories1 (splitWords s)    
    print $ bestCategories1stem (splitWords s)
    print $ score (splitWords s) onegrams
    print $ score (bigram_s (splitWords s)) twograms
    print $ bestCategories2 (splitWords s)
    print $ bestCategories2stem (splitWords s)
    print $ bestCategories (splitWords s)
```

Here is the output:

```{line-numbers: true}
$ stack ghci
:l Categorize.hs
*Categorize> main
[("computers_ai",17.900000000000002),("sports",9.75),("computers_ai_search",6.2)]
[("computers_ai",18.700000000000003),("computers_ai_search",8.1),("computers_ai_learning",5.7)]
[(2,17.900000000000002),(3,1.75),(4,5.05),(6,6.2),(9,1.1),(10,1.2),(21,2.7),(26,1.1),(28,1.6),(32,9.75)]
[(2,2.55),(6,1.0),(32,2.2)]
[("computers_ai",2.55),("sports",2.2),("computers_ai_search",1.0)]
[("computers_ai",1.6)]
[("computers_ai",40.75000000000001),("computers_ai_search",15.3),("sports",11.95),("computers_ai_learning",5.7)]
```

Given that the variable **s** contains some test text, line 4 of this output was generated by evaluating **bestCategories1 (splitWords s)**, lines 5-6 by evaluating **bestCategories1stem (splitWords s)**, lines 7-8 from **score (splitWords s) onegrams**, line 9 from **core (bigram_s (splitWords s)) twograms**, line 10 from **bestCategories2 (splitWords s)**, line 11 from **bestCategories2stem (splitWords s)**, and lines 12-13 from **bestCategories (splitWords s)**.

I called all of the utility fucntions in function **main** to demonstrate what they do but in practice I just call function **bestCategories** in my applications.


## Text Summarization

This application uses both the *Categorize.hs* code and the 1gram data from the last section. The algorithm I devised for this example is based on a simple idea: we categorize text and keep track of which words provide the strongest evidence for the highest ranked categories. We then return a few sentences from the original text that contain the largest numbers of these important words.

```haskell{line-numbers: false}
module Summarize (summarize, summarizeS) where

import qualified Data.Map as M
import Data.List.Utils (replace)
import Data.Maybe (fromMaybe)

import Categorize (bestCategories)
import Sentence (segment)
import Utils (splitWords, bigram_s, cleanText)

import Category1Gram (onegrams)
import Category2Gram (twograms)

scoreSentenceHelper words scoreMap = -- just use 1grams for now
  sum $ map (\word ->  M.findWithDefault 0.0 word scoreMap) words

safeLookup key alist =
  fromMaybe 0 $ lookup key alist
 
scoreSentenceByBestCategories words catDataMaps bestCategories =
  map (\(category, aMap) -> 
        (category, safeLookup category bestCategories * 
                   scoreSentenceHelper words aMap)) catDataMaps

scoreForSentence words catDataMaps bestCategories =  
  sum $ map snd $ scoreSentenceByBestCategories words catDataMaps bestCategories

summarize s =
  let words = splitWords $ cleanText s
      bestCats = bestCategories words
      sentences = segment s
      result1grams = map (\sentence ->
                           (sentence,
                            scoreForSentence (splitWords sentence)
                                             onegrams bestCats)) 
                         sentences
      result2grams = map (\sentence ->
                           (sentence,
                            scoreForSentence (bigram_s (splitWords sentence))
                                             twograms bestCats)) 
                         sentences
      mergedResults = M.toList $ M.unionWith (+)
                      (M.fromList result1grams) (M.fromList result1grams)
      c400 = filter (\(sentence, score) -> score > 400) mergedResults
      c300 = filter (\(sentence, score) -> score > 300) mergedResults
      c200 = filter (\(sentence, score) -> score > 200) mergedResults
      c100 = filter (\(sentence, score) -> score > 100) mergedResults
      c000 = mergedResults in
  if not (null c400) then c400 else if not (null c300) then c300 else if not (null c200) then c200 else if not (null c100) then c100 else c000

summarizeS s =
  let a = replace "\"" "'" $ concatMap (\x -> fst x ++ " ") $ summarize s in
  if not (null a) then a else safeFirst $ segment s where
    safeFirst x 
      | length x > 1 = head x ++ x !! 1
      | not (null x)   = head x
      | otherwise    = ""
      
main = do     
  let s = "Plunging European stocks, wobbly bonds and grave concerns about the health of Portuguese lender Banco Espirito Santo SA made last week feel like a rerun of the euro crisis, but most investors say it was no more than a blip for a resurgent region. Banco Espirito Santo has been in investors’ sights since December, when The Wall Street Journal first reported on accounting irregularities at the complex firm. Nerves frayed on Thursday when Banco Espirito Santo's parent company said it wouldn't be able to meet some short-term debt obligations."
  print $ summarize s
  print $ summarizeS s
```

Lazy evaluation allows us in function **summarize** to define summaries of various numbers of sentences, but not all of these possible summaries are calculated.

```{line-numbers: false}
$ stack ghci
*Main ... > :l Summarize.hs
*Summarize> main
[("Nerves frayed on Thursday when Banco Espirito Santo's parent company said it wouldn't be able to meet some short-term debt obligations.",193.54500000000002)]
"Nerves frayed on Thursday when Banco Espirito Santo's parent company said it wouldn't be able to meet some short-term debt obligations. "
```

## Part of Speech Tagging

We close out this chapter with the Haskell version of my part of speech (POS) tagger that I originally wrote in Common Lisp, then converted to Ruby and Java. The file *LexiconData.hs* is similar to the lexical data files seen earlier: I am defining a map where keys a words and map values are POS tokens like *NNP* (proper noun), *RB* (adverb), etc. The file *README.md* contains a complete list of POS tag definitions.

The example code and data for this section is in the directory *FastTag*.

This listing shows a tiny representative part of the POS definitions in *LexiconData.hs*:

```haskell{line-numbers: false}
lexicon = M.fromList [("AARP", "NNP"), ("Clinic", "NNP"), ("Closed", "VBN"),
                      ("Robert", "NNP"), ("West-German", "JJ"),
                      ("afterwards", "RB"), ("arises", "VBZ"),
					  ("attacked", "VBN"), ...]
```

Before looking at the code example listing, let's see how the functions defined in *fasttag.hs* work in a GHCi repl:

```haskell{line-numbers: false}
*Main LexiconData> bigram ["the", "dog", "ran",
                           "around", "the", "tree"]
[["the","dog"],["dog","ran"],["ran","around"],
 ["around","the"],["the","tree"]]
*Main LexiconData> tagHelper "car"
["car","NN"]
*Main LexiconData> tagHelper "run"
["run","VB"]
*Main LexiconData> substitute ["the", "dog", "ran", "around",
                               "the", "tree"]
[[["the","DT"],["dog","NN"]],[["dog","NN"],["ran","VBD"]],
 [["ran","VBD"],["around","IN"]],[["around","IN"],["the","DT"]],
 [["the","DT"],["tree","NN"]]]
*Main LexiconData> fixTags $  substitute ["the", "dog", "ran", 
                                          "around", "the", "tree"]
["NN","VBD","IN","DT","NN"]
```

Function **bigram** takes a list or words and returns a list of word pairs. We need the word pairs because parts of the tagging algorithm needs to see a word with its preceding word. In an imperative language, I would loop over the words and for a word at index **i** I would have the word at index **i - 1**. In a functional language, we avoid using loops and in this case create a list of adjacent word pairs to avoid having to use an explicit loop. I like this style of functional programming but if you come from years of using imperative language like Java and C++ it takes some getting used to.

**tagHelper** converts a word into a list of the word and its likely tag. **substitute** applies **tagHelper** to a list of words, getting the most probable tag for each word. The function **fixTags** will occasionally override the default word tags based on a few rules that are derived from Eric Brill's paper [A Simple Rule-Based Part of Speech Tagger](http://aclweb.org/anthology/A92-1021).

Here is the entire example:

```haskell{line-numbers: true}
module Main where

import qualified Data.Map as M
import Data.Strings (strEndsWith, strStartsWith)
import Data.List (isInfixOf)

import LexiconData (lexicon)

bigram :: [a] -> [[a]]
bigram [] = []
bigram [_] = []
bigram xs = take 2 xs : bigram (tail xs)

containsString word substring = isInfixOf substring word

fixTags twogramList =
  map
  -- in the following inner function, [last,current] might be bound,
  -- for example, to [["dog","NN"],["ran","VBD"]]
  (\[last, current] ->
    -- rule 1: DT, {VBD | VBP} --> DT, NN
    if last !! 1 == "DT" && (current !! 1 == "VBD" ||
                             current !! 1 == "VB" ||
                             current !! 1 == "VBP")
    then "NN" 
    else
      -- rule 2: convert a noun to a number (CD) if "." appears in the word
      if (current !! 1) !! 0 == 'N' && containsString (current !! 0) "."
      then "CD"
      else
        -- rule 3: convert a noun to a past participle if
        --         words.get(i) ends with "ed"
        if (current !! 1) !! 0 == 'N' && strEndsWith (current !! 0) "ed"
        then "VBN"
        else
          -- rule 4: convert any type to adverb if it ends in "ly"
          if strEndsWith (current !! 0) "ly"
          then "RB"
          else
            -- rule 5: convert a common noun (NN or NNS) to an
            --         adjective if it ends with "al"
            if strStartsWith (current !! 1) "NN" &&
               strEndsWith (current !! 1) "al"
            then "JJ"
            else
              -- rule 6: convert a noun to a verb if the preceeding
              --         word is "would"
              if strStartsWith (current !! 1) "NN" &&
                 (last !! 0) == "would" -- should be case insensitive
              then "VB"
              else
                -- rule 7: if a word has been categorized as a
                --         common noun and it ends with "s",
                --         then set its type to plural common noun (NNS)
                if strStartsWith (current !! 1) "NN" &&
                   strEndsWith (current !! 0) "s"
                then "NNS"
                else
                  -- rule 8: convert a common noun to a present
                  --         participle verb (i.e., a gerand)
                  if strStartsWith (current !! 1) "NN" &&
                     strEndsWith (current !! 0) "ing"
                  then "VBG"
                  else (current !! 1))
 twogramList
  
substitute tks = bigram $ map tagHelper tks

tagHelper token =
  let tags = M.findWithDefault [] token lexicon in
  if tags == [] then [token, "NN"] else [token, tags]

tag tokens = fixTags $ substitute ([""] ++ tokens)


main = do
  let tokens = ["the", "dog", "ran", "around", "the", "tree", "while",
                "the", "cat", "snaked", "around", "the", "trunk",
                "while", "banking", "to", "the", "left"]
  print $ tag tokens
  print $ zip tokens $ tag tokens
```

```haskell{line-numbers: false}
*Main LexiconData> main
["DT","NN","VBD","IN","DT","NN","IN","DT","NN","VBD","IN","DT",
 "NN","IN","VBG","TO","DT","VBN"]
[("the","DT"),("dog","NN"),("ran","VBD"),("around","IN"),
 ("the","DT"),("tree","NN"),("while","IN"),("the","DT"),
 ("cat","NN"),("snaked","VBD"),("around","IN"),("the","DT"),
 ("trunk","NN"),("while","IN"),("banking","VBG"),("to","TO"),
 ("the","DT"),("left","VBN")]
```

The README.md file contains definitions of the POS definitions. Here are the ones used in this example:

```{line-numbers: false}
DT Determiner               the,some
NN noun                     dog,cat,road
VBD verb, past tense        ate,ran
IN Preposition              of,in,by
```


## Natural Language Processing Wrap Up

NLP is a large topic. I have attempted to show you just the few tricks that I use often and are simple to implement. I hope that you reuse the code in this chapter in your own projects when you need to detect entities, classify text, summarize text, and assign part of speech tags to words in text.

