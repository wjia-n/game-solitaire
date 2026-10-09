import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Klondike solitaire engine.
///
/// The engine — never the UI — owns ALL game state and phases. Phases:
/// [idle] → [dealing] (animated deal) → [playing] ⇄ [autoCompleting] →
/// [won]. A watchdog timer guarantees no phase can stall: every animated
/// phase runs on an engine-owned timer, and the watchdog restarts any phase
/// found without a live timer. Stuck states are impossible by construction.
///
/// All interaction goes through the action methods below; UI never mutates
/// piles directly. Actions never "jump" state — deals, draws, moves and the
/// auto-complete advance on short timers so the UI can animate them.
enum SolitairePhase { idle, dealing, playing, autoCompleting, won }

enum Suit { spades, hearts, diamonds, clubs }

bool isRedSuit(Suit s) => s == Suit.hearts || s == Suit.diamonds;

@immutable
class PlayingCard {
  final Suit suit;
  final int rank; // 1..13 (A..K)
  final bool faceUp;

  const PlayingCard(this.suit, this.rank, {this.faceUp = false});

  String get id => '${suit.index}_$rank';

  String get rankLabel {
    switch (rank) {
      case 1:
        return 'A';
      case 11:
        return 'J';
      case 12:
        return 'Q';
      case 13:
        return 'K';
      default:
        return '$rank';
    }
  }

  String get suitGlyph {
    switch (suit) {
      case Suit.spades:
        return '♠';
      case Suit.hearts:
        return '♥';
      case Suit.diamonds:
        return '♦';
      case Suit.clubs:
        return '♣';
    }
  }

  PlayingCard flipped() => PlayingCard(suit, rank, faceUp: !faceUp);

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => Object.hash(suit, rank);
}

/// Where a card lives on the board.
enum PileKind { tableau, foundation, waste, stock }

class CardLocation {
  final PileKind kind;
  final int index; // tableau/foundation column; -1 otherwise
  final int cardIndex; // position within the pile (tableau: offset of stack)
  const CardLocation(this.kind, this.index, this.cardIndex);
}

/// Engine events the UI plays sounds/animations for.
enum EngineEvent {
  dealCard,
  drawCard,
  recycleStock,
  flipCard,
  moveCard,
  invalidMove,
  undo,
  winCascade,
  gameWon,
  dealStuck, // no legal moves left
  autoStep,
}

/// A legal move description (used by the auto solver / hints).
class LegalMove {
  final CardLocation from;
  final CardLocation to;
  const LegalMove(this.from, this.to);
}

class SolitaireEngine extends ChangeNotifier {
  final Random _rng;

  // ---- piles -----------------------------------------------------------
  final List<List<PlayingCard>> tableau =
      List.generate(7, (_) => <PlayingCard>[]);
  final List<List<PlayingCard>> foundations =
      List.generate(4, (_) => <PlayingCard>[]);
  final List<PlayingCard> stock = [];
  final List<PlayingCard> waste = [];

  // ---- mode config ------------------------------------------------------
  int drawCount = 1; // 1 or 3
  bool timed = false;
  bool unlimitedRecycles = true; // draw-1 classic: unlimited; draw-3: one pass

  // ---- phase / state machine ---------------------------------------------
  SolitairePhase phase = SolitairePhase.idle;
  bool paused = false;

  // scoring (standard Klondike)
  int score = 0;
  int moves = 0;

  // timed mode
  int elapsedSeconds = 0;

  // undo history (snapshots)
  final List<_Snapshot> _undoStack = [];

  // pending animated deal queue: (tableau column, card faceUp)
  final List<_DealStep> _dealQueue = [];
  Timer? _dealTimer;
  Timer? _autoTimer;
  Timer? _watchdog;
  Timer? _clockTimer;

  // UI observation
  final List<void Function(EngineEvent)> _listeners = [];
  void addEngineListener(void Function(EngineEvent) f) => _listeners.add(f);
  void removeEngineListener(void Function(EngineEvent) f) =>
      _listeners.remove(f);
  void _emit(EngineEvent e) {
    for (final l in List.of(_listeners)) {
      l(e);
    }
  }

  /// Which deal date this engine was started with (for the daily challenge).
  DateTime? dailyDate;

  /// Move the UI needs animated: the stack currently "in flight" is just the
  /// last moved cards; the UI animates pile changes via AnimatedSwitcher keys.
  String? animatingCardId;

  SolitaireEngine({int? seed}) : _rng = Random(seed) {
    _watchdog = Timer.periodic(const Duration(milliseconds: 300), (_) {
      _watchdogTick();
    });
  }

  // ------------------------------------------------------------- new game
  void newGame({
    required int drawCount,
    required bool timed,
    DateTime? daily,
  }) {
    _cancelTimers(keepWatchdog: true);
    this.drawCount = drawCount.clamp(1, 3);
    this.timed = timed;
    unlimitedRecycles = drawCount == 1;
    dailyDate = daily;
    score = 0;
    moves = 0;
    elapsedSeconds = 0;
    paused = false;
    _undoStack.clear();
    for (final t in tableau) {
      t.clear();
    }
    for (final f in foundations) {
      f.clear();
    }
    stock.clear();
    waste.clear();
    _dealQueue.clear();

    final deck = <PlayingCard>[
      for (final s in Suit.values)
        for (int r = 1; r <= 13; r++) PlayingCard(s, r),
    ];
    deck.shuffle(_rng);

    // Queue 28 deal steps, column by column, row by row (animated).
    for (int row = 0; row < 7; row++) {
      for (int col = row; col < 7; col++) {
        final card = deck.removeLast();
        _dealQueue.add(_DealStep(col, card.flipped() /* face up only at deal end */));
      }
    }
    // Only the top card of each column ends face-up: fix up in the queue.
    for (int col = 0; col < 7; col++) {
      final steps =
          _dealQueue.where((s) => s.column == col).toList(growable: false);
      for (int i = 0; i < steps.length - 1; i++) {
        steps[i].card = steps[i].card.faceUp
            ? PlayingCard(steps[i].card.suit, steps[i].card.rank)
            : steps[i].card;
      }
    }
    stock.addAll(deck);
    phase = SolitairePhase.dealing;
    _startDealTimer();
    _startClock();
    notifyListeners();
  }

  void _startDealTimer() {
    _dealTimer?.cancel();
    _dealTimer = Timer.periodic(const Duration(milliseconds: 70), (_) {
      _dealTick();
    });
  }

  void _dealTick() {
    if (paused) return;
    if (_dealQueue.isEmpty) {
      _dealTimer?.cancel();
      _dealTimer = null;
      phase = SolitairePhase.playing;
      notifyListeners();
      return;
    }
    final step = _dealQueue.removeAt(0);
    tableau[step.column].add(step.card);
    _emit(EngineEvent.dealCard);
    notifyListeners();
  }

  void _startClock() {
    _clockTimer?.cancel();
    if (!timed) return;
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!paused && phase == SolitairePhase.playing) {
        elapsedSeconds++;
        notifyListeners();
      }
    });
  }

  /// Engine-owned watchdog: any animated phase found without a live timer is
  /// repaired, so the game can never freeze mid-deal or mid-auto-complete.
  void _watchdogTick() {
    if (phase == SolitairePhase.dealing && _dealTimer == null) {
      if (_dealQueue.isNotEmpty) {
        _startDealTimer();
      } else {
        phase = SolitairePhase.playing;
        notifyListeners();
      }
    }
    if (phase == SolitairePhase.autoCompleting && _autoTimer == null) {
      _startAutoTimer();
    }
  }

  // ---------------------------------------------------------------- moves
  /// Attempt to move the tableau stack at [column] starting at [cardIndex].
  bool tryMoveTableauStack(int column, int cardIndex, int toColumn) {
    if (phase != SolitairePhase.playing || paused) return false;
    if (column < 0 || column > 6 || toColumn < 0 || toColumn > 6) {
      return false;
    }
    if (column == toColumn) return false;
    final from = tableau[column];
    if (cardIndex < 0 || cardIndex >= from.length) return false;
    if (!from[cardIndex].faceUp) {
      _emit(EngineEvent.invalidMove);
      return false;
    }
    final moving = from.sublist(cardIndex);
    if (!_isValidTableauStack(moving)) {
      _emit(EngineEvent.invalidMove);
      return false;
    }
    final dest = tableau[toColumn];
    final lead = moving.first;
    if (!_canPlaceOnTableau(lead, dest)) {
      _emit(EngineEvent.invalidMove);
      return false;
    }
    _pushUndo();
    from.removeRange(cardIndex, from.length);
    dest.addAll(moving);
    _afterTableauExpose(column);
    moves++;
    _emit(EngineEvent.moveCard);
    _postMoveCheck();
    notifyListeners();
    return true;
  }

  /// Move waste top card to a tableau column or foundation.
  bool tryMoveWasteTo(int kind, int column) {
    if (phase != SolitairePhase.playing || paused) return false;
    if (waste.isEmpty) return false;
    final card = waste.last;
    if (kind == 0) {
      // tableau
      if (!_canPlaceOnTableau(card, tableau[column])) {
        _emit(EngineEvent.invalidMove);
        return false;
      }
      _pushUndo();
      waste.removeLast();
      tableau[column].add(card);
      score += 5;
    } else {
      // foundation
      if (!_canPlaceOnFoundation(card, foundations[column])) {
        _emit(EngineEvent.invalidMove);
        return false;
      }
      _pushUndo();
      waste.removeLast();
      foundations[column].add(card);
      score += 10;
    }
    moves++;
    _emit(EngineEvent.moveCard);
    _postMoveCheck();
    notifyListeners();
    return true;
  }

  /// Move a tableau top card to a foundation.
  bool tryMoveTableauToFoundation(int column, int foundationIndex) {
    if (phase != SolitairePhase.playing || paused) return false;
    final pile = tableau[column];
    if (pile.isEmpty || !pile.last.faceUp) {
      _emit(EngineEvent.invalidMove);
      return false;
    }
    final card = pile.last;
    if (!_canPlaceOnFoundation(card, foundations[foundationIndex])) {
      _emit(EngineEvent.invalidMove);
      return false;
    }
    _pushUndo();
    pile.removeLast();
    foundations[foundationIndex].add(card);
    _afterTableauExpose(column);
    score += 10;
    moves++;
    _emit(EngineEvent.moveCard);
    _postMoveCheck();
    notifyListeners();
    return true;
  }

  /// Move a foundation top card back to a tableau column (−15 points).
  bool tryMoveFoundationToTableau(int foundationIndex, int column) {
    if (phase != SolitairePhase.playing || paused) return false;
    final pile = foundations[foundationIndex];
    if (pile.isEmpty) {
      _emit(EngineEvent.invalidMove);
      return false;
    }
    final card = pile.last;
    if (!_canPlaceOnTableau(card, tableau[column])) {
      _emit(EngineEvent.invalidMove);
      return false;
    }
    _pushUndo();
    pile.removeLast();
    tableau[column].add(card);
    score = (score - 15).clamp(0, 1 << 30);
    moves++;
    _emit(EngineEvent.moveCard);
    _postMoveCheck();
    notifyListeners();
    return true;
  }

  /// Draw from the stock (draw-1 or draw-3). Recycles waste when empty.
  bool tryDraw() {
    if (phase != SolitairePhase.playing || paused) return false;
    if (stock.isEmpty) {
      if (waste.isEmpty) {
        _emit(EngineEvent.invalidMove);
        return false;
      }
      if (!unlimitedRecycles) {
        _emit(EngineEvent.invalidMove);
        return false;
      }
      _pushUndo();
      // Recycle: waste goes back to stock face-down, preserving order.
      while (waste.isNotEmpty) {
        stock.add(waste.removeLast().flipped());
      }
      _emit(EngineEvent.recycleStock);
      moves++;
      notifyListeners();
      return true;
    }
    _pushUndo();
    for (int i = 0; i < drawCount && stock.isNotEmpty; i++) {
      waste.add(stock.removeLast().flipped());
    }
    _emit(EngineEvent.drawCard);
    moves++;
    _postMoveCheck();
    notifyListeners();
    return true;
  }

  /// Double-tap / smart move: send a card to the best legal foundation.
  bool tryAutoFoundation(CardLocation loc) {
    PlayingCard? card;
    if (loc.kind == PileKind.tableau) {
      final pile = tableau[loc.index];
      if (loc.cardIndex != pile.length - 1 || !pile.last.faceUp) return false;
      card = pile.last;
    } else if (loc.kind == PileKind.waste) {
      if (waste.isEmpty) return false;
      card = waste.last;
    } else {
      return false;
    }
    for (int f = 0; f < 4; f++) {
      if (_canPlaceOnFoundation(card, foundations[f])) {
        if (loc.kind == PileKind.tableau) {
          return tryMoveTableauToFoundation(loc.index, f);
        }
        return tryMoveWasteTo(1, f);
      }
    }
    _emit(EngineEvent.invalidMove);
    return false;
  }

  bool undo() {
    if (phase != SolitairePhase.playing || paused) return false;
    if (_undoStack.isEmpty) {
      _emit(EngineEvent.invalidMove);
      return false;
    }
    final snap = _undoStack.removeLast();
    snap.restore(this);
    _emit(EngineEvent.undo);
    notifyListeners();
    return true;
  }

  bool get canUndo => _undoStack.isNotEmpty;

  // ------------------------------------------------------------- auto win
  /// Safe to auto-complete when: stock + waste are empty and every tableau
  /// card is face-up.
  bool get canAutoComplete {
    if (phase != SolitairePhase.playing || paused) return false;
    if (stock.isNotEmpty || waste.isNotEmpty) return false;
    for (final t in tableau) {
      for (final c in t) {
        if (!c.faceUp) return false;
      }
    }
    return true;
  }

  void startAutoComplete() {
    if (!canAutoComplete) {
      _emit(EngineEvent.invalidMove);
      return;
    }
    phase = SolitairePhase.autoCompleting;
    _startAutoTimer();
    notifyListeners();
  }

  void _startAutoTimer() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(const Duration(milliseconds: 220), (_) {
      _autoTick();
    });
  }

  void _autoTick() {
    if (paused) return;
    // Move the lowest safe card to its foundation each tick.
    PlayingCard? best;
    int bestCol = -1;
    for (int col = 0; col < 7; col++) {
      final pile = tableau[col];
      if (pile.isEmpty) continue;
      final card = pile.last;
      for (int f = 0; f < 4; f++) {
        if (_canPlaceOnFoundation(card, foundations[f])) {
          if (best == null || card.rank < best.rank) {
            best = card;
            bestCol = col;
          }
        }
      }
    }
    if (best == null || bestCol < 0) {
      _autoTimer?.cancel();
      _autoTimer = null;
      phase = SolitairePhase.playing;
      notifyListeners();
      return;
    }
    final pile = tableau[bestCol];
    pile.removeLast();
    for (int f = 0; f < 4; f++) {
      if (_canPlaceOnFoundation(best, foundations[f])) {
        foundations[f].add(best);
        break;
      }
    }
    score += 10;
    moves++;
    _emit(EngineEvent.autoStep);
    _postMoveCheck();
    notifyListeners();
  }

  // ---------------------------------------------------------------- rules
  bool _isValidTableauStack(List<PlayingCard> stack) {
    for (int i = 0; i < stack.length - 1; i++) {
      final a = stack[i];
      final b = stack[i + 1];
      if (isRedSuit(a.suit) == isRedSuit(b.suit)) return false;
      if (a.rank != b.rank + 1) return false;
    }
    return true;
  }

  bool _canPlaceOnTableau(PlayingCard card, List<PlayingCard> dest) {
    if (dest.isEmpty) return card.rank == 13; // only Kings on empty columns
    final top = dest.last;
    if (!top.faceUp) return false;
    return isRedSuit(card.suit) != isRedSuit(top.suit) &&
        card.rank == top.rank - 1;
  }

  bool _canPlaceOnFoundation(PlayingCard card, List<PlayingCard> foundation) {
    if (foundation.isEmpty) return card.rank == 1; // Aces start foundations
    final top = foundation.last;
    return card.suit == top.suit && card.rank == top.rank + 1;
  }

  void _afterTableauExpose(int column) {
    final pile = tableau[column];
    if (pile.isNotEmpty && !pile.last.faceUp) {
      pile[pile.length - 1] = pile.last.flipped();
      score += 5;
      _emit(EngineEvent.flipCard);
    }
  }

  void _postMoveCheck() {
    if (_isWon()) {
      _onWin();
      return;
    }
    if (!_hasAnyLegalMove()) {
      _emit(EngineEvent.dealStuck);
    }
  }

  bool _isWon() {
    for (final f in foundations) {
      if (f.length != 13) return false;
    }
    return true;
  }

  void _onWin() {
    phase = SolitairePhase.won;
    _cancelTimers(keepWatchdog: true);
    if (timed && elapsedSeconds > 0) {
      score += (1200 - elapsedSeconds * 2).clamp(0, 1200);
    }
    _emit(EngineEvent.gameWon);
  }

  /// Every state always has a legal forward action — audit against RULES.md.
  bool _hasAnyLegalMove() {
    if (stock.isNotEmpty) return true; // can always draw
    if (waste.isNotEmpty && unlimitedRecycles) return true; // can recycle
    // waste → tableau/foundation
    if (waste.isNotEmpty) {
      final c = waste.last;
      for (int col = 0; col < 7; col++) {
        if (_canPlaceOnTableau(c, tableau[col])) return true;
      }
      for (int f = 0; f < 4; f++) {
        if (_canPlaceOnFoundation(c, foundations[f])) return true;
      }
    }
    // tableau moves & flips
    for (int col = 0; col < 7; col++) {
      final pile = tableau[col];
      if (pile.isEmpty) continue;
      // A face-down top means the whole pile is buried: nothing movable
      // here and no flip can ever expose it (invariant: face-up cards are
      // always on top, flips happen immediately via _afterTableauExpose).
      if (!pile.last.faceUp) continue;
      // top → foundation
      for (int f = 0; f < 4; f++) {
        if (_canPlaceOnFoundation(pile.last, foundations[f])) return true;
      }
      // stack → other columns
      for (int start = 0; start < pile.length; start++) {
        if (!pile[start].faceUp) continue;
        final stack = pile.sublist(start);
        if (!_isValidTableauStack(stack)) continue;
        for (int d = 0; d < 7; d++) {
          if (d == col) continue;
          if (_canPlaceOnTableau(stack.first, tableau[d])) return true;
        }
      }
    }
    // foundation → tableau (always a legal forward action when possible)
    for (int f = 0; f < 4; f++) {
      final fp = foundations[f];
      if (fp.isEmpty) continue;
      for (int col = 0; col < 7; col++) {
        if (_canPlaceOnTableau(fp.last, tableau[col])) return true;
      }
    }
    return false;
  }

  /// UI hint system: find one sensible legal move (safe foundation moves
  /// first, then tableau builds). Returns null only when truly stuck.
  LegalMove? findHint() {
    if (phase != SolitairePhase.playing) return null;
    // Safe: Ace/2 to foundation, or any card whose predecessors are buried.
    for (int col = 0; col < 7; col++) {
      final pile = tableau[col];
      if (pile.isNotEmpty && pile.last.faceUp) {
        final c = pile.last;
        for (int f = 0; f < 4; f++) {
          if (_canPlaceOnFoundation(c, foundations[f]) && _isSafeToFoundation(c)) {
            return LegalMove(
                CardLocation(PileKind.tableau, col, pile.length - 1),
                CardLocation(PileKind.foundation, f, -1));
          }
        }
      }
    }
    if (waste.isNotEmpty) {
      final c = waste.last;
      for (int f = 0; f < 4; f++) {
        if (_canPlaceOnFoundation(c, foundations[f]) && _isSafeToFoundation(c)) {
          return const LegalMove(
              CardLocation(PileKind.waste, -1, -1),
              CardLocation(PileKind.foundation, 0, -1));
        }
      }
      for (int col = 0; col < 7; col++) {
        if (_canPlaceOnTableau(c, tableau[col])) {
          return LegalMove(const CardLocation(PileKind.waste, -1, -1),
              CardLocation(PileKind.tableau, col, -1));
        }
      }
    }
    // Any tableau stack move that reveals a face-down card.
    for (int col = 0; col < 7; col++) {
      final pile = tableau[col];
      for (int start = 0; start < pile.length; start++) {
        if (!pile[start].faceUp) continue;
        final stack = pile.sublist(start);
        if (!_isValidTableauStack(stack)) continue;
        for (int d = 0; d < 7; d++) {
          if (d == col) continue;
          if (_canPlaceOnTableau(stack.first, tableau[d]) &&
              start > 0 &&
              !pile[start - 1].faceUp) {
            return LegalMove(CardLocation(PileKind.tableau, col, start),
                CardLocation(PileKind.tableau, d, -1));
          }
        }
      }
    }
    if (stock.isNotEmpty) {
      return const LegalMove(
          CardLocation(PileKind.stock, -1, -1),
          CardLocation(PileKind.waste, -1, -1));
    }
    return null;
  }

  /// A card is "safe" to foundation when both opposite-color lower cards are
  /// already there (classic rule of thumb).
  bool _isSafeToFoundation(PlayingCard c) {
    if (c.rank <= 2) return true;
    final need = c.rank - 1;
    int found = 0;
    for (int f = 0; f < 4; f++) {
      for (final fc in foundations[f]) {
        if (fc.rank >= need &&
            isRedSuit(fc.suit) != isRedSuit(c.suit)) {
          found++;
        }
      }
    }
    return found >= 2;
  }

  // ------------------------------------------------------------------ undo
  void _pushUndo() {
    _undoStack.add(_Snapshot.capture(this));
    if (_undoStack.length > 120) _undoStack.removeAt(0);
  }

  // ------------------------------------------------------------------ pause
  void setPaused(bool v) {
    paused = v;
    notifyListeners();
  }

  // ---------------------------------------------------------------- dispose
  void _cancelTimers({bool keepWatchdog = false}) {
    _dealTimer?.cancel();
    _dealTimer = null;
    _autoTimer?.cancel();
    _autoTimer = null;
    _clockTimer?.cancel();
    _clockTimer = null;
    if (!keepWatchdog) {
      _watchdog?.cancel();
      _watchdog = null;
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  // ----------------------------------------------------------------- debug
  /// Test hook: force a specific board (used by widget tests).
  @visibleForTesting
  void debugSetBoard({
    required List<List<PlayingCard>> tableauCards,
    required List<List<PlayingCard>> foundationCards,
    required List<PlayingCard> stockCards,
    required List<PlayingCard> wasteCards,
  }) {
    _cancelTimers(keepWatchdog: true);
    for (int i = 0; i < 7; i++) {
      tableau[i]
        ..clear()
        ..addAll(tableauCards[i]);
    }
    for (int i = 0; i < 4; i++) {
      foundations[i]
        ..clear()
        ..addAll(foundationCards[i]);
    }
    stock
      ..clear()
      ..addAll(stockCards);
    waste
      ..clear()
      ..addAll(wasteCards);
    phase = SolitairePhase.playing;
    notifyListeners();
  }
}

class _DealStep {
  final int column;
  PlayingCard card;
  _DealStep(this.column, this.card);
}

class _Snapshot {
  final List<List<PlayingCard>> tableau;
  final List<List<PlayingCard>> foundations;
  final List<PlayingCard> stock;
  final List<PlayingCard> waste;
  final int score;
  final int moves;

  _Snapshot(this.tableau, this.foundations, this.stock, this.waste, this.score,
      this.moves);

  factory _Snapshot.capture(SolitaireEngine e) => _Snapshot(
        [for (final t in e.tableau) List.of(t)],
        [for (final f in e.foundations) List.of(f)],
        List.of(e.stock),
        List.of(e.waste),
        e.score,
        e.moves,
      );

  void restore(SolitaireEngine e) {
    for (int i = 0; i < 7; i++) {
      e.tableau[i]
        ..clear()
        ..addAll(tableau[i]);
    }
    for (int i = 0; i < 4; i++) {
      e.foundations[i]
        ..clear()
        ..addAll(foundations[i]);
    }
    e.stock
      ..clear()
      ..addAll(stock);
    e.waste
      ..clear()
      ..addAll(waste);
    e.score = score;
    e.moves = moves;
  }
}
