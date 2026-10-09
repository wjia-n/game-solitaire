import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import '../engine/solitaire_engine.dart';
import '../main.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/solitaire_themes.dart';
import '../widgets/cards.dart';

/// The card table. Every card on the board lives in ONE stack of
/// [AnimatedPositioned] widgets keyed by card id, so deals, draws, moves and
/// the auto-complete all glide smoothly — the engine changes pile contents,
/// the UI just re-targets positions. No instant state jumps, ever.
class GameScreen extends StatefulWidget {
  final TableAudio audio;
  final SolitaireSettings settings;
  final DateTime? daily; // non-null for the daily challenge deal

  const GameScreen({
    super.key,
    required this.audio,
    required this.settings,
    this.daily,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late SolitaireEngine _engine;
  FeltThemeDef get _t => FeltThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  // card id -> last rendered offset (drives AnimatedPositioned flights)
  final Map<String, Offset> _pos = {};
  Map<String, Offset> _targets = {};

  CardLocation? _selected; // selected tableau stack root / waste card
  CardLocation? _hint; // hint highlight (source), _hintDest (target)
  CardLocation? _hintDest;
  Timer? _hintTimer;

  bool _manualPause = false;
  bool _winRecorded = false;
  bool _stuckShown = false;
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    final seed = widget.daily != null
        ? widget.daily!.year * 10000 +
            widget.daily!.month * 100 +
            widget.daily!.day
        : Random().nextInt(1 << 31);
    _engine = SolitaireEngine(seed: seed);
    _engine.addEngineListener(_onEngineEvent);
    _engine.addListener(_onEngineChanged);
    SolitaireAppState.pauseEngine = _onAppPaused;
    SolitaireAppState.resumeEngine = _onAppResumed;
    widget.audio.startGameMusic();
    // Let the first frame lay out, then deal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _engine.newGame(
        drawCount: widget.settings.drawCount,
        timed: widget.settings.timed,
        daily: widget.daily,
      );
      widget.audio.gameStart();
      setState(() => _starting = false);
    });
  }

  @override
  void dispose() {
    SolitaireAppState.pauseEngine = null;
    SolitaireAppState.resumeEngine = null;
    _hintTimer?.cancel();
    _engine.removeEngineListener(_onEngineEvent);
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    super.dispose();
  }

  void _onAppPaused() {
    _engine.setPaused(true);
  }

  void _onAppResumed() {
    if (!_manualPause) _engine.setPaused(false);
  }

  // ------------------------------------------------------------ engine i/o
  void _onEngineEvent(EngineEvent e) {
    final a = widget.audio;
    switch (e) {
      case EngineEvent.dealCard:
        a.cardDeal();
        break;
      case EngineEvent.drawCard:
        a.cardFlip();
        break;
      case EngineEvent.recycleStock:
        a.cardDeal();
        break;
      case EngineEvent.flipCard:
        a.cardFlip();
        break;
      case EngineEvent.moveCard:
        a.cardMove();
        break;
      case EngineEvent.invalidMove:
        a.invalid();
        break;
      case EngineEvent.undo:
        a.undo();
        break;
      case EngineEvent.autoStep:
        a.cardFoundation();
        break;
      case EngineEvent.winCascade:
        a.winCascade();
        break;
      case EngineEvent.gameWon:
        a.win();
        _onWin();
        break;
      case EngineEvent.dealStuck:
        a.lose();
        _onStuck();
        break;
    }
  }

  void _onWin() {
    if (_winRecorded) return;
    _winRecorded = true;
    widget.settings.recordGame(
      won: true,
      score: _engine.score,
      seconds: _engine.elapsedSeconds,
      daily: widget.daily,
    );
    // Gentle review nudge after a satisfying win — silent when not from Play.
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      try {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await review.requestReview();
        }
      } catch (_) {}
    });
  }

  void _onStuck() {
    if (_stuckShown || _engine.phase != SolitairePhase.playing) return;
    _stuckShown = true;
    widget.settings.recordGame(
        won: false, score: _engine.score, seconds: _engine.elapsedSeconds);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'No more moves on this deal — nice try, ${widget.settings.playerName}!',
          style: const TextStyle(fontFamily: 'serif'),
        ),
        backgroundColor: _t.railDeep,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'New deal',
          textColor: _t.accentLight,
          onPressed: _newDeal,
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _onEngineChanged() {
    // Re-target every visible card; brand-new cards start at the stock pile
    // so they fly in, then a post-frame pass retargets them to their home.
    final targets = _computeTargets();
    var needsIntro = false;
    for (final id in targets.keys) {
      if (!_pos.containsKey(id)) {
        _pos[id] = _stockAnchor();
        needsIntro = true;
      }
    }
    // drop cards that left the visible set (shouldn't happen, but be safe)
    _pos.removeWhere((id, _) => !targets.containsKey(id));
    _targets = targets;
    if (mounted) setState(() {});
    if (needsIntro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _targets = _computeTargets();
        setState(() {});
      });
    }
    // keep positions in sync after the animation lands
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pos.addAll(_targets);
    });
  }

  // ---------------------------------------------------------------- layout
  double get _pad => 10;
  double get _gap => 6;

  double _cardW(BoxConstraints c) =>
      (c.maxWidth - _pad * 2 - _gap * 6) / 7;

  double _cardH(double w) => w * 1.42;

  Offset _stockAnchor() => Offset(_pad, _topY(1));

  double _topY(double cardW) => _pad + 56; // below the HUD

  /// Compute every visible card's board offset.
  Map<String, Offset> _computeTargets() {
    // NOTE: called from listener before layout exists on the very first
    // tick; guard with MediaQuery via a cached size.
    final size = _lastSize;
    if (size == null) return {};
    final w = _cardW(BoxConstraints.tight(size));
    final h = _cardH(w);
    final topY = _topY(w);
    final targets = <String, Offset>{};

    // stock (top card only)
    if (_engine.stock.isNotEmpty) {
      targets[_engine.stock.last.id] = Offset(_pad, topY);
    }
    // waste: fan of up to 3
    final waste = _engine.waste;
    final showWaste = waste.length > 3 ? waste.sublist(waste.length - 3) : waste;
    for (int i = 0; i < showWaste.length; i++) {
      final x = _pad + (w + _gap) + i * w * 0.28;
      targets[showWaste[i].id] = Offset(x, topY);
    }
    // foundations
    for (int f = 0; f < 4; f++) {
      final pile = _engine.foundations[f];
      if (pile.isNotEmpty) {
        final x = _pad + (w + _gap) * (3 + f);
        targets[pile.last.id] = Offset(x, topY);
      }
    }
    // tableau: shrink overlap so tall columns fit
    final tabY = topY + h + 14;
    final availH = size.height - tabY - 90; // room for bottom bar
    for (int col = 0; col < 7; col++) {
      final pile = _engine.tableau[col];
      final x = _pad + col * (w + _gap);
      final down = pile.where((c) => !c.faceUp).length;
      final up = pile.length - down;
      double downGap = w * 0.16;
      double upGap = w * 0.30;
      final need = down * downGap + up * upGap + h;
      if (need > availH && pile.length > 1) {
        final s = (availH - h) / (down * 0.16 + up * 0.30) / w;
        downGap = w * 0.16 * s.clamp(0.35, 1.0);
        upGap = w * 0.30 * s.clamp(0.35, 1.0);
      }
      double y = tabY;
      for (final card in pile) {
        targets[card.id] = Offset(x, y);
        y += card.faceUp ? upGap : downGap;
      }
    }
    return targets;
  }

  Size? _lastSize;

  // ----------------------------------------------------------------- input
  void _tapStock() {
    if (_engine.phase != SolitairePhase.playing) return;
    _clearSelection();
    _engine.tryDraw();
  }

  void _tapWaste() {
    if (_engine.phase != SolitairePhase.playing ||
        _engine.waste.isEmpty) {
      return;
    }
    final loc = const CardLocation(PileKind.waste, -1, -1);
    if (_selected == loc) {
      _clearSelection();
    } else {
      setState(() => _selected = loc);
      widget.audio.click();
    }
  }

  /// Empty column tapped: only meaningful as a destination for a
  /// selected card/stack (rules: only a King may start an empty column).
  void _tapTableauEmpty(int col) {
    if (_engine.phase != SolitairePhase.playing) return;
    if (_engine.tableau[col].isNotEmpty) return; // covered by card taps
    final sel = _selected;
    if (sel == null) return;
    bool ok = false;
    if (sel.kind == PileKind.waste) {
      ok = _engine.tryMoveWasteTo(0, col);
    } else if (sel.kind == PileKind.tableau && sel.index != col) {
      ok = _engine.tryMoveTableauStack(sel.index, sel.cardIndex, col);
    } else if (sel.kind == PileKind.foundation) {
      ok = _engine.tryMoveFoundationToTableau(sel.index, col);
    }
    if (ok) {
      _clearSelection();
    } else {
      widget.audio.invalid();
    }
  }

  void _tapFoundation(int f) {
    if (_engine.phase != SolitairePhase.playing) return;
    final sel = _selected;
    if (sel == null) return;
    bool ok = false;
    if (sel.kind == PileKind.tableau) {
      // Foundations only ever take the exposed top card of a column —
      // never a buried stack root.
      final pile = _engine.tableau[sel.index];
      if (sel.cardIndex != pile.length - 1 || !pile.last.faceUp) {
        widget.audio.invalid();
        return;
      }
      ok = _engine.tryMoveTableauToFoundation(sel.index, f);
    } else if (sel.kind == PileKind.waste) {
      ok = _engine.tryMoveWasteTo(1, f);
    }
    if (ok) _clearSelection();
  }

  void _tapTableauCard(int col, int cardIndex) {
    if (_engine.phase != SolitairePhase.playing) return;
    final pile = _engine.tableau[col];
    if (cardIndex >= pile.length) return;
    final card = pile[cardIndex];

    final sel = _selected;
    final sameSpot = sel != null &&
        sel.kind == PileKind.tableau &&
        sel.index == col &&
        sel.cardIndex == cardIndex;
    // A card on another column (or waste/foundation) is a destination for
    // the current selection; a card on the SAME column re-selects it.
    final fromElsewhere = sel != null &&
        (sel.kind == PileKind.waste ||
            sel.kind == PileKind.foundation ||
            (sel.kind == PileKind.tableau && sel.index != col));

    if (fromElsewhere) {
      bool ok = false;
      if (sel.kind == PileKind.waste) {
        ok = _engine.tryMoveWasteTo(0, col);
      } else if (sel.kind == PileKind.tableau) {
        ok = _engine.tryMoveTableauStack(sel.index, sel.cardIndex, col);
      } else {
        ok = _engine.tryMoveFoundationToTableau(sel.index, col);
      }
      if (ok) _clearSelection();
      return;
    }

    if (sameSpot) {
      // second tap on the same stack = smart move to foundation
      _engine.tryAutoFoundation(sel);
      _clearSelection();
      return;
    }

    if (!card.faceUp) {
      // Face-down card: only selectable if it's the exposed top.
      if (cardIndex == pile.length - 1) {
        widget.audio.invalid();
      }
      return;
    }
    setState(() => _selected = CardLocation(PileKind.tableau, col, cardIndex));
    widget.audio.click();
  }

  void _tapFoundationCard(int f) {
    if (_engine.phase != SolitairePhase.playing) return;
    if (_engine.foundations[f].isEmpty) return;
    final loc = CardLocation(PileKind.foundation, f, -1);
    if (_selected == loc) {
      _clearSelection();
    } else {
      setState(() => _selected = loc);
      widget.audio.click();
    }
  }

  void _doubleTapCard(CardLocation loc) {
    if (_engine.phase != SolitairePhase.playing) return;
    if (_engine.tryAutoFoundation(loc)) _clearSelection();
  }

  void _clearSelection() {
    if (_selected != null) setState(() => _selected = null);
  }

  void _showHint() {
    final hint = _engine.findHint();
    if (hint == null) {
      widget.audio.invalid();
      return;
    }
    widget.audio.click();
    setState(() {
      _hint = hint.from;
      _hintDest = hint.to;
    });
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _hint = _hintDest = null);
    });
  }

  void _newDeal() {
    _stuckShown = false;
    _winRecorded = false;
    _clearSelection();
    _pos.clear();
    _targets = {};
    _engine.newGame(
      drawCount: widget.settings.drawCount,
      timed: widget.settings.timed,
      daily: widget.daily,
    );
    widget.audio.gameStart();
  }

  String _fmtTime(int s) {
    final m = s ~/ 60;
    return '${m.toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.25,
            colors: [t.feltLight, t.feltDark],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _lastSize = Size(constraints.maxWidth, constraints.maxHeight);
              final w = _cardW(constraints);
              final h = _cardH(w);
              return Stack(
                children: [
                  Column(
                    children: [
                      _hud(t),
                      Expanded(child: _board(t, w, h)),
                      _bottomBar(t),
                    ],
                  ),
                  if (_engine.paused || _manualPause) _pauseOverlay(t),
                  if (_engine.phase == SolitairePhase.won) _winOverlay(t),
                  if (_starting) _dealingVeil(t),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _hud(FeltThemeDef t) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () {
              widget.audio.click();
              widget.audio.startMenuMusic();
              Navigator.of(context).pop();
            },
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _engine,
              builder: (_, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _hudChip(t, 'Score', '${_engine.score}'),
                  const SizedBox(width: 8),
                  _hudChip(t, 'Moves', '${_engine.moves}'),
                  if (widget.settings.timed) ...[
                    const SizedBox(width: 8),
                    _hudChip(t, 'Time',
                        _fmtTime(_engine.elapsedSeconds)),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.undo, color: t.accentLight),
            tooltip: 'Undo',
            onPressed: () {
              if (_engine.canUndo) {
                _clearSelection();
                _engine.undo();
              } else {
                widget.audio.invalid();
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.lightbulb_outline, color: t.accentLight),
            tooltip: 'Hint',
            onPressed: _showHint,
          ),
          IconButton(
            icon: Icon(Icons.pause, color: t.accentLight),
            tooltip: 'Pause',
            onPressed: () {
              widget.audio.click();
              setState(() => _manualPause = true);
              _engine.setPaused(true);
            },
          ),
        ],
      ),
    );
  }

  Widget _hudChip(FeltThemeDef t, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black.withValues(alpha: 0.35),
        border: Border.all(color: t.accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(fontSize: 9, color: t.ink.withValues(alpha: 0.7))),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: t.accentLight)),
        ],
      ),
    );
  }

  Widget _board(FeltThemeDef t, double w, double h) {
    return ListenableBuilder(
      listenable: _engine,
      builder: (_, _) {
        final children = <Widget>[];
        final topY = _topY(w);

        // stock slot
        children.add(Positioned(
          left: _pad,
          top: topY,
          child: GestureDetector(
            onTap: _tapStock,
            child: _engine.stock.isEmpty
                ? EmptySlot(
                    theme: t,
                    width: w,
                    glyph: _engine.waste.isEmpty ? null : '↻',
                  )
                : const SizedBox.shrink(),
          ),
        ));
        // waste slot marker (cards fly above it)
        children.add(Positioned(
          left: _pad + w + _gap,
          top: topY,
          child: EmptySlot(theme: t, width: w),
        ));
        // foundation slots
        for (int f = 0; f < 4; f++) {
          final x = _pad + (w + _gap) * (3 + f);
          final suitGlyph = ['♠', '♥', '♦', '♣'][f];
          children.add(Positioned(
            left: x,
            top: topY,
            child: GestureDetector(
              onTap: () => _tapFoundation(f),
              child: EmptySlot(theme: t, width: w, glyph: suitGlyph),
            ),
          ));
        }
        // tableau slot markers (tappable destinations for empty columns)
        final tabY = topY + h + 14;
        for (int col = 0; col < 7; col++) {
          children.add(Positioned(
            left: _pad + col * (w + _gap),
            top: tabY,
            child: GestureDetector(
              onTap: () => _tapTableauEmpty(col),
              child: EmptySlot(theme: t, width: w),
            ),
          ));
        }

        // all cards, keyed by id, animated between positions
        for (final entry in _targets.entries) {
          final card = _findCard(entry.key);
          if (card == null) continue;
          final p = _pos[entry.key] ?? entry.value;
          final selected = _isSelectedCard(card);
          final hinted = _isHintedCard(card);
          children.add(
            AnimatedPositioned(
              key: ValueKey('card_${card.id}'),
              left: p.dx,
              top: p.dy - (selected ? 8 : 0),
              width: w,
              height: h,
              duration: const Duration(milliseconds: 230),
              curve: Curves.easeOutCubic,
              child: GestureDetector(
                onTap: () => _tapCard(card),
                onDoubleTap: () {
                  final loc = _locate(card);
                  if (loc != null) _doubleTapCard(loc);
                },
                child: Container(
                  decoration: hinted
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(w * 0.09),
                          border: Border.all(
                              color: t.accentLight, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: t.accent.withValues(alpha: 0.55),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        )
                      : selected
                          ? BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(w * 0.09),
                              border: Border.all(
                                  color: t.accentLight, width: 2),
                            )
                          : null,
                  child: PlayingCardWidget(
                    card: card,
                    theme: t,
                    backId: widget.settings.cardBackId,
                    width: w,
                    elevated: selected,
                  ),
                ),
              ),
            ),
          );
        }
        return Stack(children: children);
      },
    );
  }

  PlayingCard? _findCard(String id) {
    for (final t in _engine.tableau) {
      for (final c in t) {
        if (c.id == id) return c;
      }
    }
    for (final f in _engine.foundations) {
      for (final c in f) {
        if (c.id == id) return c;
      }
    }
    for (final c in _engine.waste) {
      if (c.id == id) return c;
    }
    for (final c in _engine.stock) {
      if (c.id == id) return c;
    }
    return null;
  }

  CardLocation? _locate(PlayingCard card) {
    for (int col = 0; col < 7; col++) {
      final pile = _engine.tableau[col];
      final i = pile.indexOf(card);
      if (i >= 0) return CardLocation(PileKind.tableau, col, i);
    }
    for (int f = 0; f < 4; f++) {
      if (_engine.foundations[f].contains(card)) {
        return CardLocation(PileKind.foundation, f, -1);
      }
    }
    if (_engine.waste.contains(card)) {
      return const CardLocation(PileKind.waste, -1, -1);
    }
    if (_engine.stock.contains(card)) {
      return const CardLocation(PileKind.stock, -1, -1);
    }
    return null;
  }

  bool _isSelectedCard(PlayingCard card) {
    final sel = _selected;
    if (sel == null) return false;
    if (sel.kind == PileKind.tableau) {
      final pile = _engine.tableau[sel.index];
      final i = pile.indexOf(card);
      return i >= sel.cardIndex && i >= 0;
    }
    if (sel.kind == PileKind.waste) {
      return _engine.waste.isNotEmpty && _engine.waste.last.id == card.id;
    }
    if (sel.kind == PileKind.foundation) {
      final pile = _engine.foundations[sel.index];
      return pile.isNotEmpty && pile.last.id == card.id;
    }
    return false;
  }

  bool _isHintedCard(PlayingCard card) {
    bool match(CardLocation? loc) {
      if (loc == null) return false;
      if (loc.kind == PileKind.tableau) {
        final pile = _engine.tableau[loc.index];
        return loc.cardIndex < pile.length &&
            pile[loc.cardIndex].id == card.id;
      }
      if (loc.kind == PileKind.waste) {
        return _engine.waste.isNotEmpty &&
            _engine.waste.last.id == card.id;
      }
      if (loc.kind == PileKind.stock) return false;
      return false;
    }

    return match(_hint) || match(_hintDest);
  }

  void _tapCard(PlayingCard card) {
    final loc = _locate(card);
    if (loc == null) return;
    switch (loc.kind) {
      case PileKind.tableau:
        _tapTableauCard(loc.index, loc.cardIndex);
        break;
      case PileKind.waste:
        // waste top: select; tap destination via tableau/foundation taps
        _tapWaste();
        break;
      case PileKind.foundation:
        _tapFoundationCard(loc.index);
        break;
      case PileKind.stock:
        _tapStock();
        break;
    }
  }

  Widget _bottomBar(FeltThemeDef t) {
    return ListenableBuilder(
      listenable: _engine,
      builder: (_, _) => Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _barBtn(t, Icons.add, 'New', _newDeal),
            if (_engine.canAutoComplete)
              _barBtn(t, Icons.auto_awesome, 'Finish', () {
                widget.audio.click();
                _engine.startAutoComplete();
              }),
            _barBtn(t, Icons.lightbulb_outline, 'Hint', _showHint),
            _barBtn(t, Icons.undo, 'Undo', () {
              if (_engine.canUndo) {
                _clearSelection();
                _engine.undo();
              } else {
                widget.audio.invalid();
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _barBtn(
      FeltThemeDef t, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: t.rail.withValues(alpha: 0.85),
          border: Border.all(color: t.accent.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                offset: const Offset(0, 2),
                blurRadius: 5),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: t.accentLight),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: t.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _pauseOverlay(FeltThemeDef t) {
    return Container(
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: t.railDeep,
            border: Border.all(color: t.accent, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: t.ink,
                      fontFamily: 'serif')),
              const SizedBox(height: 6),
              Text('The cards are waiting…',
                  style: TextStyle(
                      color: t.ink.withValues(alpha: 0.7), fontSize: 13)),
              const SizedBox(height: 20),
              _menuBtn(t, 'Resume', () {
                widget.audio.click();
                setState(() => _manualPause = false);
                _engine.setPaused(false);
              }),
              const SizedBox(height: 10),
              _menuBtn(t, 'New deal', () {
                widget.audio.click();
                setState(() => _manualPause = false);
                _engine.setPaused(false);
                _newDeal();
              }, outlined: true),
              const SizedBox(height: 10),
              _menuBtn(t, 'Quit to menu', () {
                widget.audio.click();
                widget.audio.startMenuMusic();
                Navigator.of(context).pop();
              }, outlined: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _winOverlay(FeltThemeDef t) {
    return Container(
      color: Colors.black.withValues(alpha: 0.68),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: t.railDeep,
            border: Border.all(color: t.accent, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: t.accent.withValues(alpha: 0.25),
                  blurRadius: 30,
                  spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉',
                  style: TextStyle(fontSize: 44)),
              const SizedBox(height: 8),
              Text('You win!',
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: t.accentLight,
                      fontFamily: 'serif')),
              const SizedBox(height: 6),
              Text(
                  '${widget.settings.playerName} cleared the table!',
                  style: TextStyle(
                      color: t.ink.withValues(alpha: 0.85), fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 14),
              _statRow(t, 'Score', '${_engine.score}'),
              _statRow(t, 'Moves', '${_engine.moves}'),
              if (widget.settings.timed)
                _statRow(
                    t, 'Time', _fmtTime(_engine.elapsedSeconds)),
              const SizedBox(height: 20),
              _menuBtn(t, 'New deal', () {
                widget.audio.click();
                _newDeal();
              }),
              const SizedBox(height: 10),
              _menuBtn(t, 'Menu', () {
                widget.audio.click();
                widget.audio.startMenuMusic();
                Navigator.of(context).pop();
              }, outlined: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(FeltThemeDef t, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style:
                  TextStyle(color: t.ink.withValues(alpha: 0.7), fontSize: 14)),
          Text(v,
              style: TextStyle(
                  color: t.accentLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _menuBtn(FeltThemeDef t, String label, VoidCallback onTap,
      {bool outlined = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: outlined
              ? Colors.transparent
              : t.accent.withValues(alpha: 0.9),
          border: Border.all(color: t.accent, width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: outlined ? t.accentLight : t.railDeep,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _dealingVeil(FeltThemeDef t) {
    return Container(
      color: Colors.black.withValues(alpha: 0.25),
      child: Center(
        child: Text('Dealing…',
            style: TextStyle(
                color: t.accentLight,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'serif')),
      ),
    );
  }
}
