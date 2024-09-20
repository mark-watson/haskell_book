# Haskell Program to Play the Blackjack Card Game

For much of my work using Haskell I deal mostly with pure code with smaller bits of impure code for network and file IO, etc. Realizing that my use case for using Haskell (mostly pure code) may not be typical, I wanted the last example "cookbook recipe" in this book to be an example dealing with changing state, a program to play the Blackjack card game.

The game state is maintained in the type **Table** that holds information on a randomized deck of cards, the number of players in addition to the game user and the card dealer, the cards in the current hand, and the number of betting chips that all players own. Table data is immutable so all of the major game playing functions take a table and any other required inputs, and generate a new table as the function result.

This example starts by asking how many players, besides the card dealer and the game user, should play a simulated Blackjack game. The game user controls when they want another card while the dealer and any other simulated players play automatically (they always hit when their card score is less than 17).

I define the types for playing cards and an entire card deck in the file *Card.hs*:

```haskell{line-numbers: true}
module Card (Card, Rank, Suit, orderedCardDeck, cardValue) where

import Data.Maybe (fromMaybe)
import Data.List (elemIndex)
import Data.Map (fromList, lookup, keys)

data Card = Card { rank :: Rank
                 , suit :: Suit }
                 deriving (Eq, Show)
                 
data Suit = Hearts | Diamonds | Clubs | Spades
          deriving (Eq, Show, Enum, Ord)

data Rank = Two | Three | Four
          | Five | Six | Seven | Eight
          | Nine | Ten | Jack  | Queen | King | Ace
          deriving (Eq, Show, Enum, Ord)

rankMap = fromList [(Two,2), (Three,3), (Four,4), (Five,5),
                    (Six,6), (Seven,7), (Eight,8), (Nine,9),
                    (Ten,10), (Jack,10), (Queen,10),
                    (King,10), (Ace,11)]

orderedCardDeck :: [Card]
orderedCardDeck = [Card rank suit | rank <- keys rankMap,
                                    suit <- [Hearts .. Clubs]]

cardValue :: Card -> Int
cardValue aCard =
  case (Data.Map.lookup (rank aCard) rankMap) of
    Just n -> n
    Nothing -> 0 -- should never happen
```

This module defines essential components for representing and working with playing cards.

**Data Types**

* `Card`: A record type with two fields: 
    * `rank :: Rank` - Represents the card's rank (e.g., Two, Queen, Ace).
    * `suit :: Suit` - Represents the card's suit (e.g., Hearts, Spades).

* `Suit`: An enumeration defining the four card suits: Hearts, Diamonds, Clubs, Spades. It derives `Eq` (equality), `Show` (string representation), `Enum` (enumeration capabilities), and `Ord` (ordering) for convenience.

* `Rank`: An enumeration listing the thirteen card ranks, from Two to Ace. It also derives `Eq`, `Show`, `Enum`, and `Ord`.

**Functions and Values**

* `rankMap`: A `Data.Map` that associates each `Rank` with its corresponding numerical value in games like Blackjack.

* `orderedCardDeck`: A list comprehension that generates a standard 52-card deck, sorted by rank within each suit.

* `cardValue`: A function that takes a `Card` and returns its numerical value based on the `rankMap`. It uses pattern matching to handle the `Maybe` type returned by `Data.Map.lookup`.

**Explanation**

1.  **`Card` Data Type**: The core of the module. It defines a playing card as a combination of a `Rank` and a `Suit`.

2.  **`Suit` and `Rank` Enumerations**: These provide a clear and type-safe representation of suits and ranks. Deriving `Enum` and `Ord` allows easy iteration and comparison.

3.  **`rankMap`**: This map is crucial for assigning numerical values to cards, particularly in games where card values matter (e.g., Blackjack).

4.  **`orderedCardDeck`**: This function generates a standard 52-card deck. It uses list comprehension to iterate over all `Rank` values (obtained from the keys of `rankMap`) and all `Suit` values (from `Hearts` to `Clubs`), creating a `Card` for each combination.

5.  **`cardValue`**: This function retrieves the numerical value of a given card. It uses `Data.Map.lookup` to find the value associated with the card's rank in `rankMap`. The `case` expression handles the possibility of `lookup` returning `Nothing` (which should ideally never happen in this context).

**Key Points**

* The code provides a well-structured representation of playing cards in Haskell.
* The use of enumerations enhances type safety and readability.
* `Data.Map` is employed for efficient lookup of card values.
* The `orderedCardDeck` function conveniently generates a standard deck of cards.

As usual, the best way to understand this code is to go to the GHCi repl:

```haskell{line-numbers: true}
*Main Card RandomizedList Table> :l Card
[1 of 1] Compiling Card             ( Card.hs, interpreted )
Ok, modules loaded: Card.
*Card> :t orderedCardDeck
orderedCardDeck :: [Card]
*Card> orderedCardDeck
[Card {rank = Two, suit = Hearts},Card {rank = Two, suit = Diamonds},Card {rank = Two, suit = Clubs},Card {rank = Three, suit = Hearts},Card {rank = Three,
    ...
*Card> head orderedCardDeck
Card {rank = Two, suit = Hearts}
*Card> cardValue $ head orderedCardDeck
2
```

So, we have a sorted deck of cards and a utility function for returning the numerical value of a card (we always count ace cards as 11 points, deviating from standard Blackjack rules).

The next thing we need to get is randomly shuffled lists. The [Haskell Wiki](https://wiki.haskell.org/Random_shuffle) has a good writeup on randomizing list elements and we are borrowing their function **randomizedList** (you can see the source code in the file *RandomizedList.hs*). Here is a sample use:

```haskell{line-numbers: true}
*Card> :l RandomizedList.hs 
[1 of 1] Compiling RandomizedList   ( RandomizedList.hs, interpreted )
Ok, modules loaded: RandomizedList.
*RandomizedList> import Card
*RandomizedList Card> randomizedList orderedCardDeck
[Card {rank = Queen, suit = Hearts},Card {rank = Six, suit = Diamonds},Card {rank = Five, suit = Clubs},Card {rank = Five, suit = Diamonds},Card {rank = Seven, suit = Clubs},Card {rank = Three, suit = Hearts},Card {rank = Four, suit = Diamonds},Card {rank = Ace, suit = Hearts},
  ...
```

Much of the complexity in this example is implemented in *Table.hs* which defines the type **Table** and several functions to deal and score hands of dealt cards:

- createNewTable :: Players -> Table. Players is the integer number of other players at the table.
- setPlayerBet :: Int -> Table -> Table. Given a new value to bet and a table, generate a new modified table.
- showTable :: Table -> [Char]. Given a table, generate a string describing the table (in a format useful for development)
- initialDeal :: [Card] -> Table -> Int -> Table. Given a randomized deck of cards, a table, and the number of other players, generate a new table.
- changeChipStack :: Int -> Int -> Table -> Table. Given a player index (index order: user, dealer, and other players), a new number of betting chips for the player, and a table, then generate a new modified table.
- setCardDeck :: [Card] -> Table -> Table. Given a randomized card deck and a table, generate a new table containing the new randomized card list; all other table data is unchanged.
- dealCards :: Table -> [Int] -> Table. Given a table and a list of player indices for players wanting another card, generate a new modified table.
- resetTable :: [Card] -> Table -> Int -> Table. Given a new randomized card deck, a table, and a new number of other players, generate a new table.
- scoreHands :: Table -> Table. Given a table, score all dealt hands and generate a new table with these scores. There is no table type score data, rather, we "score" by changing the number of chips all of the players (inclding the dealer) has.
- dealCardToUser :: Table -> Int -> Table. For the game user, always deal a card. For the dealer and other players, deal another card if their hand score is less than 17.
- handOver :: Table -> Bool. Determine if the current hand is over.
- setPlayerPasses :: Table -> Table. Call this function when the payer passes. Other players and dealer are then played out automatically.

The implementation in the file *Table.hs* is fairly simple, with the exception of the use of Haskell lenses to access nested data in the table type. I will discuss the use of lenses after the program listing, but: as you are reading the code look out for variables starting with the underscore character **\_** that alerts the *Lens* system that it should create data accessors for these variables.

This code defines a module named `Table` which provides data structures and functions to simulate a simplified table in a card game, potentially Blackjack. 

**Core Components**

* **`Table` data type:** 
    - Represents the state of the table, storing information like:
        - Number of players
        - Chip stacks for each player
        - Cards dealt to each player (including the dealer)
        - Current player's bet
        - Whether the user has passed their turn
        - The remaining card deck

* **Functions:**
    - `createNewTable`: Creates a new table with the specified number of players and initial chip stacks.
    - `resetTable`: Resets the table for a new round, clearing dealt cards and optionally changing the card deck.
    - `setCardDeck`: Sets a new card deck for the table.
    - `dealCards`: Deals cards to specified players.
    - `initialDeal`: Performs the initial deal at the beginning of a round.
    - `showTable`: Generates a string representation of the table's current state.
    - `scoreHands`: Calculates and updates chip stacks based on player and dealer scores.
    - `setPlayerBet`: Sets the current player's bet.
    - `setPlayerPasses`: Simulates the player passing their turn, dealing additional cards to other players and the dealer.
    - `changeChipStack`: Modifies a specific player's chip stack.
    - `score`: Calculates the score of a player's hand.
    - `dealCardToUser`: Deals a card to a specified player, with special handling for the user and dealer.
    - `handOver`: Checks if the user has passed their turn.

**Lenses**

The code uses lenses (`makeLenses ''Table`) to provide convenient access and modification of the `Table` data type's fields.

**Game Logic (Simplified)**

* The code seems to implement a basic version of a card game where players and the dealer are dealt cards.
* `scoreHands` calculates scores and updates chip stacks based on win/loss conditions.
* `dealCardToUser` handles dealing cards, ensuring the dealer keeps drawing until their score is at least 17.
* `setPlayerPasses` simulates the user passing, triggering the dealer and other players to finish their turns.


```haskell{line-numbers: true}
{-# LANGUAGE TemplateHaskell #-}  -- for makeLens

module Table (Table (..), createNewTable, setPlayerBet, showTable, initialDeal,
              changeChipStack, setCardDeck, dealCards, resetTable, scoreHands,
              dealCardToUser, handOver, setPlayerPasses) where
  -- note: export dealCardToUser only required for ghci development

import Control.Lens

import Card
import Data.Bool
import Data.Maybe (fromMaybe)

data Table = Table { _numPlayers :: Int
                   , _chipStacks :: [Int] -- number of chips,
                                          -- indexed by player index
                   , _dealtCards :: [[Card]] -- dealt cards for user,
                                             -- dealer, and other players
                   , _currentPlayerBet :: Int
                   , _userPasses       :: Bool
                   , _cardDeck         :: [Card]
                   }
           deriving (Show)
           
type Players = Int
             
createNewTable :: Players -> Table
createNewTable n =
  Table n
        [500 | _ <- [1 .. n]] -- give each player (incuding dealer) 10 chips
        [[] | _ <- [0..n]] -- dealt cards for user and other players
                           -- (we don't track dealer's chips)
        20 -- currentPlayerBet number of betting chips
        False
        [] -- placeholder for random shuffled card deck
 
resetTable :: [Card] -> Table -> Int -> Table
resetTable cardDeck aTable numberOfPlayers =
  Table numberOfPlayers
        (_chipStacks aTable)       -- using Lens accessor
        [[] | _ <- [0..numberOfPlayers]]
        (_currentPlayerBet aTable) -- using Lens accessor
        False
        cardDeck
     
     -- Use lens extensions for type Table:
            
makeLenses ''Table
 
showDealtCards :: [[Card]] -> String
showDealtCards dc =
  (show [map cardValue hand | hand <- dc])

setCardDeck :: [Card] -> Table -> Table
setCardDeck newDeck =
  over cardDeck (\_ -> newDeck)  -- change value to new card deck

dealCards :: Table -> [Int] -> Table
dealCards aTable playerIndices =
  last $ scanl dealCardToUser aTable playerIndices
 
initialDeal cardDeck aTable numberOfPlayers =
  dealCards
    (dealCards (resetTable cardDeck aTable numberOfPlayers)
               [0 .. numberOfPlayers])
    [0 .. numberOfPlayers]
    
showTable :: Table -> [Char]
showTable aTable =
  "\nCurrent table data:\n" ++
  "  Chipstacks: " ++
  "\n    Player: " ++ (show (head (_chipStacks aTable))) ++
  "\n    Other players: " ++ (show (tail (_chipStacks aTable))) ++
  "\n  User cards: " ++ (show (head (_dealtCards aTable))) ++
  "\n  Dealer cards: " ++ (show ((_dealtCards aTable) !! 1)) ++
  "\n  Other player's cards: " ++ (show (tail (tail(_dealtCards aTable)))) ++
  -- "\n  Dealt cards: " ++ (show (_dealtCards aTable)) ++
  "\n  Dealt card values: " ++ (showDealtCards (_dealtCards aTable)) ++
  "\n  Current player bet: " ++
  (show (_currentPlayerBet aTable)) ++
  "\n  Player pass: " ++
  (show (_userPasses aTable)) ++ "\n"
  
clipScore aTable playerIndex =
  let s = score aTable playerIndex in
    if s < 22 then s else 0
      
scoreHands aTable =
  let chipStacks2 = _chipStacks aTable
      playerScore = clipScore aTable 0
      dealerScore = clipScore aTable 1
      otherScores = map (clipScore aTable) [2..]
      newPlayerChipStack = if playerScore > dealerScore then
                             (head chipStacks2) + (_currentPlayerBet aTable)
                           else
                             if playerScore < dealerScore then
                                (head chipStacks2) - (_currentPlayerBet aTable)
                             else (head chipStacks2)
      newOtherChipsStacks =
        map (\(x,y) -> if x > dealerScore then
                         y + 20
                       else
                         if x < dealerScore then
                           y - 20
                         else y) 
            (zip otherScores (tail chipStacks2))
      newChipStacks  = newPlayerChipStack:newOtherChipsStacks
  in
    over chipStacks (\_ -> newChipStacks) aTable
     
setPlayerBet :: Int -> Table -> Table
setPlayerBet newBet =
  over currentPlayerBet (\_ -> newBet)  

setPlayerPasses :: Table -> Table
setPlayerPasses aTable =
  let numPlayers = _numPlayers aTable
      playerIndices = [1..numPlayers]
      t1 = over userPasses (\_ -> True) aTable
      t2 = dealCards t1 playerIndices
      t3 = dealCards t2 playerIndices
      t4 = dealCards t3 playerIndices
  in
    t4
    
    
changeChipStack :: Int -> Int -> Table -> Table
changeChipStack playerIndex newValue =
  over chipStacks (\a -> a & element playerIndex .~ newValue)

scoreOLD aTable playerIndex =
  let scores = map cardValue ((_dealtCards aTable) !! playerIndex)
      totalScore = sum scores in
    if totalScore < 22 then totalScore else 0

score aTable playerIndex =
  let scores = map cardValue ((_dealtCards aTable) !! playerIndex)
      totalScore = sum scores in
    totalScore
  
dealCardToUser' :: Table -> Int -> Table
dealCardToUser' aTable playerIndex =
  let nextCard = head $ _cardDeck aTable
      playerCards = nextCard : ((_dealtCards aTable) !! playerIndex)
      newTable = over cardDeck (\cd -> tail cd) aTable in
    over dealtCards (\a -> a & element playerIndex .~ playerCards) newTable

dealCardToUser :: Table -> Int -> Table
dealCardToUser aTable playerIndex
  | playerIndex == 0  = dealCardToUser' aTable playerIndex -- user
  | otherwise         = if (score aTable playerIndex) < 17 then
                             dealCardToUser' aTable playerIndex
                        else aTable
  
handOver :: Table -> Bool
handOver aTable =
  _userPasses aTable
```

In line 48 we use the function **makeLenses** to generate access functions for the type **Table**. We will look in some detail at lines 54-56 where we use the lense **over** function to modify a nested value in a table, returning a new table:

```haskell{line-numbers: true}
setCardDeck :: [Card] -> Table -> Table
setCardDeck newDeck =
  over cardDeck (\_ -> newDeck)
```

The expression in line 3 evaluates to a partial function that takes another argument, a table, and returns a new table with the card deck modified. Function **over** expects a function as its second argument. In this example, the inline function ignores the argument it is called with, which would be the old card deck value, and returns the new card deck value which is placed in the table value.

Using lenses can greatly simplify the code to manipulate complex types.

Another place where I am using lenses is in the definition of function **scoreHands** (lines 88-109). On line 109 we are using the **over** function to replace the old player betting chip counts with the new value we have just calculated:

```haskell{line-numbers: true}
  over chipStacks (\_ -> newChipStacks) aTable
```

Similarly, we use **over** in line 113 to change the current player bet. In function **handOver** on line 157, notice how I am using the generated function **_userPasses** to extract the value of the user passes boolean flag from a table.

The function **main**, defined in the file *Main.hs*, uses the code we have just seen to represent a table and modify a table, is fairly simple. A main game loop repetitively accepts game user input, and calls the appropriate functions to modify the current table, producing a new table. Remember that the table data is immutable: we always generate a new table from the old table when we need to modify it.

```haskell{line-numbers: true}
module Main where

import Card   -- pure code
import Table  -- pure code
import RandomizedList  -- impure code

printTable :: Table -> IO ()
printTable aTable =
  putStrLn $ showTable aTable
  
randomDeck =
  randomizedList orderedCardDeck

gameLoop :: Table -> Int -> IO b
gameLoop aTable numberOfPlayers = do
  printTable aTable
  cardDeck <- randomDeck
  if (handOver aTable) then
    do
      putStrLn "\nHand over. State of table at the end of the game:\n"
      printTable aTable
      putStrLn "\nNewly dealt hand:\n"
      gameLoop (initialDeal cardDeck (scoreHands aTable)
                                     numberOfPlayers)
                                     numberOfPlayers
  else
    do
      putStrLn "Enter command:"
      putStrLn "  h)it or set bet to 10, 20, 30; any other key to stay:"
      command <- getLine
      if elem command ["10", "20", "30"] then
        gameLoop (setPlayerBet (read command) aTable) numberOfPlayers
      else
        if command == "h" then
          gameLoop (dealCards aTable [0 .. numberOfPlayers]) numberOfPlayers
        else
          gameLoop (setPlayerPasses (dealCards aTable [1 .. numberOfPlayers]))
                    numberOfPlayers 
             -- player stays (no new cards)
  
main :: IO b
main = do
  putStrLn "Start a game of Blackjack. Besides yourself, how many other"
  putStrLn "players do you want at the table?"
  s <- getLine
  let num = (read s :: Int) + 1
  cardDeck <- randomDeck
  let aTable = initialDeal cardDeck (createNewTable num) num
  gameLoop aTable num
```

This module combines the previously defined `Card` and `Table` modules with an impure `RandomizedList` module to implement the main game loop of a simplified Blackjack-like card game.

**Core Functions**

* `printTable`: Prints the current state of the table using the `showTable` function from the `Table` module.

* `randomDeck`: Generates a randomized version of the `orderedCardDeck` using the `randomizedList` function (assumed to be from the `RandomizedList` module).

* `gameLoop`: The core recursive function that drives the game:
    - Prints the current table state.
    - Generates a random card deck.
    - If the hand is over (user has passed), prints the final table state, scores hands, and starts a new game with the updated chip stacks.
    - Otherwise, prompts the user for a command:
        - If the command is "10", "20", or "30", sets the player's bet.
        - If the command is "h", deals cards to all players (including the user).
        - If any other command is entered, sets the user as passed and deals cards to the dealer and other players until they stand.
    - Recursively calls itself with the updated table state.

* `main`:
    - Prompts the user for the number of additional players.
    - Creates a new table with the specified number of players and an initial deal.
    - Starts the `gameLoop`.

**Key Points**

- The code demonstrates a basic interactive text-based card game implementation.
- It combines pure modules (`Card`, `Table`) with an impure module (`RandomizedList`) for randomization.
- The `gameLoop` function handles user input and game state transitions.
- The game logic is likely simplified for this example, and a full Blackjack implementation would require additional rules and features.

**Remember:** The `RandomizedList` module is assumed to provide a function `randomizedList` for shuffling the card deck, introducing impurity into the game logic.



I encourage you to try playing the game yourself, but if you don't here is a sample game:

```haskell{line-numbers: true}
*Main Card RandomizedList Table> main
Start a game of Blackjack. Besides yourself, how many other
players do you want at the table?
1

Current table data:
  Chipstacks: 
    Player: 500
    Other players: [500]
  User cards: [Card {rank = Three, suit = Clubs},Card {rank = Two, suit = Hearts}]
  Dealer cards: [Card {rank = Queen, suit = Diamonds},Card {rank = Seven, suit = Clubs}]
  Other player's cards: [[Card {rank = King, suit = Hearts},Card {rank = Six, suit = Diamonds}]]
  Dealt card values: [[3,2],[10,7],[10,6]]
  Current player bet: 20
  Player pass: False

Enter command: h)it or set bet to 10, 20, 30; any other key to stay:
h

Current table data:
  Chipstacks: 
    Player: 500
    Other players: [500]
  User cards: [Card {rank = Six, suit = Hearts},Card {rank = Three, suit = Clubs},Card {rank = Two, suit = Hearts}]
  Dealer cards: [Card {rank = Queen, suit = Diamonds},Card {rank = Seven, suit = Clubs}]
  Other player's cards: [[Card {rank = Eight, suit = Hearts},Card {rank = King, suit = Hearts},Card {rank = Six, suit = Diamonds}]]
  Dealt card values: [[6,3,2],[10,7],[8,10,6]]
  Current player bet: 20
  Player pass: False

Enter command: h)it or set bet to 10, 20, 30; any other key to stay:
h

Current table data:
  Chipstacks: 
    Player: 500
    Other players: [500]
  User cards: [Card {rank = King, suit = Clubs},Card {rank = Six, suit = Hearts},Card {rank = Three, suit = Clubs},Card {rank = Two, suit = Hearts}]
  Dealer cards: [Card {rank = Queen, suit = Diamonds},Card {rank = Seven, suit = Clubs}]
  Other player's cards: [[Card {rank = Eight, suit = Hearts},Card {rank = King, suit = Hearts},Card {rank = Six, suit = Diamonds}]]
  Dealt card values: [[10,6,3,2],[10,7],[8,10,6]]
  Current player bet: 20
  Player pass: False

Enter command: h)it or set bet to 10, 20, 30; any other key to stay:

Current table data:
  Chipstacks: 
    Player: 500
    Other players: [500]
  User cards: [Card {rank = King, suit = Clubs},Card {rank = Six, suit = Hearts},Card {rank = Three, suit = Clubs},Card {rank = Two, suit = Hearts}]
  Dealer cards: [Card {rank = Queen, suit = Diamonds},Card {rank = Seven, suit = Clubs}]
  Other player's cards: [[Card {rank = Eight, suit = Hearts},Card {rank = King, suit = Hearts},Card {rank = Six, suit = Diamonds}]]
  Dealt card values: [[10,6,3,2],[10,7],[8,10,6]]
  Current player bet: 20
  Player pass: True

Hand over. State of table at the end of the game:

Current table data:
  Chipstacks: 
    Player: 520
    Other players: [520]
  User cards: [Card {rank = King, suit = Clubs},Card {rank = Six, suit = Hearts},Card {rank = Three, suit = Clubs},Card {rank = Two, suit = Hearts}]
  Dealer cards: [Card {rank = Queen, suit = Diamonds},Card {rank = Seven, suit = Clubs}]
  Other player's cards: [[Card {rank = Eight, suit = Hearts},Card {rank = King, suit = Hearts},Card {rank = Six, suit = Diamonds}]]
  Dealt card values: [[10,6,3,2],[10,7],[8,10,6]]
  Current player bet: 20
  Player pass: True
```

Here the game user has four cards with values of [10,6,3,2] for a winning score of 21. The dealer has [10,7] for a score of 17 and the other player has [8,10,6], a value greater than 21 so the player went "bust."

I hope that you enjoyed this last example that demonstrates a reasonable approach for managing state when using immutable data.

