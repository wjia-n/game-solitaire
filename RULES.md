# Solitaire — Rules (Klondike)

The authoritative rules for this game. If the implementation ever conflicts
with this document, fix the implementation.

## 1. Objective

Build all four suits from Ace to King on the four foundation piles.

## 2. Setup

- A standard 52-card deck, shuffled.
- Seven tableau columns: column *i* (1–7) receives *i* cards; the top card of
  each column is face-up, the rest face-down.
- The remaining 24 cards form the stock, face-down.
- Four empty foundations (one per suit, in fixed suit order
  ♠ ♥ ♦ ♣) and an empty waste pile.

## 3. Turn order

Single-player; the player acts freely. There are no turns — every state must
always offer a legal forward action (draw, move, flip-reveal, undo, or new
deal).

## 4. Legal moves

- **Tableau builds:** place a face-up card (or a valid stack) on a tableau
  column whose top card is the opposite color and exactly one rank higher
  (e.g. red 7 on black 8).
- **Stack moves:** any face-up descending alternating-color sequence may move
  together as a stack.
- **Empty columns:** only a King (with its stack) may start an empty column.
- **Foundations:** build up by suit from the Ace (A→2→…→K). Double-tap (or
  smart-tap) sends a card to its foundation when legal.
- **Stock:** tap to draw (Draw-1: one card; Draw-3: three cards) onto the
  waste, face-up.
- **Waste:** the top waste card may move to a tableau column or a foundation.
- **Foundation → tableau:** a foundation top card may move back to a legal
  tableau column (−15 points).
- **Undo:** restores the exact previous board (up to 120 steps).

## 5. Illegal moves

- Placing a card on a same-color or non-descending tableau card.
- Starting an empty column with anything but a King.
- Foundation placements out of suit order.
- Drawing from an empty stock with an empty waste.
- Recycling the stock in Draw-3 mode (one pass only).
- Moving face-down cards.
- Any move while the deal animation, auto-complete, pause, or win sequence
  is running.

## 6. Captures

Not applicable — no captures in Klondike.

## 7. Special rules

- **Draw-1:** unlimited stock recycles. **Draw-3:** a single pass through the
  stock; no recycles.
- **Auto-complete:** offered when the stock and waste are empty and every
  tableau card is face-up; the engine then plays cards to the foundations
  automatically.
- **Timed mode:** a clock runs during play; a time bonus is added on a win:
  `max(0, 1200 − 2 × seconds)`.
- **Daily deal:** the shuffle is seeded by the calendar date, so everyone
  gets the same deal that day.

## 8. Scoring (standard Klondike)

| Action | Points |
|---|---|
| Waste → tableau | +5 |
| Waste → foundation | +10 |
| Tableau → foundation | +10 |
| Flip a tableau card face-up | +5 |
| Foundation → tableau | −15 (floor 0) |
| Timed win bonus | up to +1200 |

## 9. Winning conditions

All four foundations hold 13 cards each (A→K of every suit).

## 10. Draw conditions

There are no draws. A deal with no legal moves is a lost deal: the game
says so plainly, records the loss, and offers a new deal.

## 11. AI strategy

No opponents — single-player. The hint system suggests moves in this order:
1. Safe foundation moves (Ace/2, or cards whose lower opposite-color cards
   are already buried — "safe" rule).
2. Waste → tableau builds.
3. Tableau stack moves that reveal a face-down card.
4. Drawing from the stock.

## 12. Edge cases

- Undo during deal/auto-complete/win is ignored (only in `playing` phase).
- Pause freezes deal, auto-complete, and clock timers; resume continues
  them exactly.
- App backgrounding pauses the engine; the watchdog restarts any animated
  phase found without a live timer, so the game can never freeze mid-deal.
- A win mid-auto-complete stops the timer and shows the win panel once.
- Legacy settings keys migrate to the single-JSON profile on first load.

## 13. Test cases

1. New game deals 28 cards (7 columns, tops face-up) and 24 to stock.
2. Only Kings start empty columns; only Aces start foundations.
3. Red-on-black descending stacks move as a unit; invalid stacks rejected.
4. Draw-1 recycles waste→stock preserving order; Draw-3 refuses recycle.
5. Undo restores score, moves, and every pile exactly.
6. Auto-complete triggers only when stock + waste are empty and all tableau
   cards are face-up; it ends in a win.
7. Timed win adds the time bonus; relaxed win adds none.
8. Win records stats once (games, wins, streak, best score/time, daily).
9. Stuck deal (no legal moves, no stock) shows the "no more moves" notice.
10. Killing the deal timer mid-deal is repaired by the watchdog.
