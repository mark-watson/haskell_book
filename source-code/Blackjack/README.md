# Blackjack Card Game

**Book:** [Haskell Tutorial and Cookbook](https://leanpub.com/haskell-cookbook) by Mark Watson — [read free online](https://leanpub.com/haskell-cookbook/read)

**Book Chapter:** [Haskell Program to Play the Blackjack Card Game](https://leanpub.com/read/haskell-cookbook/haskell-program-to-play-the-blackjack-card-game)

A command-line Blackjack game that demonstrates functional state management without using a State Monad. Instead, the game maintains a read-only `Table` value — functions take a `Table` and return a modified `Table`, following the "Game Loop" pattern described in the book.

## Limitations

- Aces always count as 11 points (instead of 11 or 1).
- The command line interface does not hide "down cards" because it is intended to show the internal state of the game.

## How to Play

```bash
stack build --exec Blackjack
```

or:

```bash
cabal run Blackjack
```

1. Enter the number of players (besides yourself) at the table (a good value is 1).
2. In the main game loop:
   - Type a number (`10`, `20`, `30`) to change your bet.
   - Type `h` to hit — you get dealt a card; the dealer and other players hit if they have < 17.
   - Press Enter (blank line) to pass — other players and the dealer keep hitting until they have > 16 or bust (> 21).
3. After a pass, start a new hand by pressing `h` again.

Each player starts with 10 chips.

## Source Files

| File | Description |
|------|-------------|
| `Main.hs` | Entry point and game loop |
| `Table.hs` | `Table` data type and state transformation functions |
| `Card.hs` | Card, Rank, and Suit types |
| `TUI.hs` | Text user interface helpers |
| `RandomizedList.hs` | Deck shuffling |

## License

Apache 2.0 — Copyright 2016-2026 Mark Watson. All rights reserved.
