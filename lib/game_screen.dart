import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

const _suits = ['♠', '♥', '♦', '♣'];
bool _isRed(int s) => s == 1 || s == 2;
String _rankStr(int r) => r == 1 ? 'A' : r == 11 ? 'J' : r == 12 ? 'Q' : r == 13 ? 'K' : '$r';

class _Card {
  final int suit, rank;
  bool faceUp;
  _Card(this.suit, this.rank, {this.faceUp = false});
  int get code => suit * 32 + rank + (faceUp ? 512 : 0);
  static _Card from(int c) => _Card((c % 512) ~/ 32, (c % 512) % 32, faceUp: c >= 512);
}

/// kind: 0 = waste top, 1 = foundation top, 2 = tableau run
class _Sel {
  final int kind, pile, start;
  _Sel(this.kind, this.pile, [this.start = 0]);
}

class SolitaireScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const SolitaireScreen({super.key, required this.players, required this.callbacks});

  @override
  State<SolitaireScreen> createState() => _SolitaireScreenState();
}

class _SolitaireScreenState extends State<SolitaireScreen> {
  late List<_Card> stock, waste;
  late List<List<_Card>> found, tab;
  _Sel? sel;
  List<List<int>>? undoSnap;
  int moves = 0, secs = 0;
  Timer? timer;
  bool over = false, celebrate = false, finished = false;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _newGame() {
    final deck = [for (var s = 0; s < 4; s++) for (var r = 1; r <= 13; r++) _Card(s, r)]..shuffle();
    tab = List.generate(7, (_) => <_Card>[]);
    for (var c = 0; c < 7; c++) {
      for (var k = 0; k <= c; k++) {
        final card = deck.removeLast();
        card.faceUp = k == c;
        tab[c].add(card);
      }
    }
    stock = deck;
    waste = [];
    found = List.generate(4, (_) => <_Card>[]);
    setState(() {
      sel = null;
      undoSnap = null;
      moves = 0;
      secs = 0;
      over = false;
      celebrate = false;
      finished = false;
    });
    timer?.cancel();
  }

  void _tick() {
    timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!over && mounted) setState(() => secs++);
    });
  }

  List<List<_Card>> get _piles => [stock, waste, ...found, ...tab];

  void _pushUndo() {
    undoSnap = _piles.map((p) => p.map((c) => c.code).toList()).toList();
  }

  void _restoreUndo() {
    if (undoSnap == null || over) return;
    final s = undoSnap!;
    setState(() {
      stock = s[0].map(_Card.from).toList();
      waste = s[1].map(_Card.from).toList();
      found = [for (var i = 0; i < 4; i++) s[2 + i].map(_Card.from).toList()];
      tab = [for (var i = 0; i < 7; i++) s[6 + i].map(_Card.from).toList()];
      undoSnap = null;
      sel = null;
      moves++;
    });
    Sfx.tap();
  }

  void _afterMove() {
    setState(() {
      moves++;
      sel = null;
    });
    Sfx.move();
    _checkWin();
  }

  void _tapStock() {
    if (over) return;
    _tick();
    _pushUndo();
    setState(() {
      if (stock.isNotEmpty) {
        final c = stock.removeLast()..faceUp = true;
        waste.add(c);
      } else if (waste.isNotEmpty) {
        stock = waste.reversed.map((c) => c..faceUp = false).toList();
        waste = [];
      } else {
        undoSnap = null;
        return;
      }
      moves++;
      sel = null;
    });
    Sfx.tap();
  }

  /// Cards currently selected (the moving run).
  List<_Card> _selCards() {
    final s = sel!;
    if (s.kind == 0) return [waste.last];
    if (s.kind == 1) return [found[s.pile].last];
    return tab[s.pile].sublist(s.start);
  }

  bool _runOk(int col, int start) {
    final p = tab[col];
    for (var i = start; i < p.length; i++) {
      if (!p[i].faceUp) return false;
      if (i > start) {
        if (p[i].rank != p[i - 1].rank - 1 || _isRed(p[i].suit) == _isRed(p[i - 1].suit)) return false;
      }
    }
    return true;
  }

  void _removeSel() {
    final s = sel!;
    if (s.kind == 0) {
      waste.removeLast();
    } else if (s.kind == 1) {
      found[s.pile].removeLast();
    } else {
      final p = tab[s.pile];
      p.removeRange(s.start, p.length);
      if (p.isNotEmpty && !p.last.faceUp) p.last.faceUp = true;
    }
  }

  bool _toFoundation(int fi) {
    if (sel == null || _selCards().length != 1) return false;
    final c = _selCards().first;
    if (c.suit != fi) return false;
    final f = found[fi];
    if (!((f.isEmpty && c.rank == 1) || (f.isNotEmpty && c.rank == f.last.rank + 1))) return false;
    _pushUndo();
    _removeSel();
    f.add(c);
    _afterMove();
    return true;
  }

  bool _toTableau(int col) {
    if (sel == null) return false;
    final moving = _selCards();
    // dropping back onto its own pile = deselect
    if (sel!.kind == 2 && sel!.pile == col) {
      setState(() => sel = null);
      return true;
    }
    final t = tab[col];
    final bottom = moving.first;
    final ok = t.isEmpty
        ? bottom.rank == 13
        : _isRed(t.last.suit) != _isRed(bottom.suit) && t.last.rank == bottom.rank + 1;
    if (!ok) return false;
    _pushUndo();
    _removeSel();
    t.addAll(moving);
    _afterMove();
    return true;
  }

  void _tapWaste() {
    if (over || waste.isEmpty) return;
    _tick();
    if (sel != null) {
      setState(() => sel = null);
      Sfx.tap();
      return;
    }
    setState(() => sel = _Sel(0, 0));
    Sfx.tap();
  }

  void _tapFoundation(int i) {
    if (over) return;
    _tick();
    if (sel != null) {
      if (!_toFoundation(i)) setState(() => sel = null);
      return;
    }
    if (found[i].isNotEmpty) {
      setState(() => sel = _Sel(1, i));
      Sfx.tap();
    }
  }

  void _tapTableau(int col, int idx) {
    if (over) return;
    _tick();
    final p = tab[col];
    if (sel != null) {
      if (!_toTableau(col)) setState(() => sel = null);
      return;
    }
    if (idx < 0 || idx >= p.length || !p[idx].faceUp) return;
    if (_runOk(col, idx)) {
      setState(() => sel = _Sel(2, col, idx));
      Sfx.tap();
    }
  }

  bool get _canAuto => !over && tab.every((c) => c.every((x) => x.faceUp));

  void _autoComplete() {
    if (!_canAuto) return;
    var moved = true;
    var guard = 0;
    while (moved && guard++ < 200) {
      moved = false;
      // waste top
      if (waste.isNotEmpty) {
        sel = _Sel(0, 0);
        if (_toFoundation(waste.last.suit)) {
          moved = true;
          continue;
        }
        sel = null;
      }
      for (var c = 0; c < 7 && !moved; c++) {
        if (tab[c].isEmpty) continue;
        sel = _Sel(2, c, tab[c].length - 1);
        if (_toFoundation(tab[c].last.suit)) moved = true;
        sel = null;
      }
    }
    sel = null;
    _checkWin();
  }

  void _checkWin() {
    if (over || !found.every((f) => f.length == 13)) return;
    setState(() {
      over = true;
      celebrate = true;
    });
    Sfx.win();
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (!mounted || finished) return;
      finished = true;
      final p = widget.players[0];
      p.score = moves;
      widget.callbacks.refreshHud();
      final mm = (secs ~/ 60).toString().padLeft(2, '0');
      final ss = (secs % 60).toString().padLeft(2, '0');
      widget.callbacks.finish(
        headline: 'Solitaire cleared! 🏆',
        subline: 'Absolute legend. $moves moves in $mm:$ss — the cards bow to you. 🃏',
      );
    });
  }

  String get _time =>
      '${(secs ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    return LayoutBuilder(builder: (ctx, box) {
      final pad = 10.0;
      final gap = 7.0;
      final cw = (box.maxWidth - pad * 2 - gap * 6) / 7;
      final ch = cw * 1.42;
      return Stack(
        children: [
          Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              children: [
                _statsBar(t),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _slot(t, cw, ch, _pileFace(t, cw, ch, stock.isEmpty ? null : stock.last, onTap: _tapStock, back: stock.isNotEmpty, badge: stock.isEmpty && waste.isNotEmpty ? '↺' : (stock.isEmpty ? '' : '${stock.length}'))),
                    SizedBox(width: gap),
                    _slot(t, cw, ch, _pileFace(t, cw, ch, waste.isEmpty ? null : waste.last, onTap: _tapWaste, selected: sel?.kind == 0)),
                    SizedBox(width: gap * 2),
                    for (var i = 0; i < 4; i++) ...[
                      _slot(t, cw, ch,
                          _pileFace(t, cw, ch, found[i].isEmpty ? null : found[i].last,
                              onTap: () => _tapFoundation(i),
                              selected: sel?.kind == 1 && sel!.pile == i,
                              ghost: _suits[i]),
                          key: ValueKey('f$i')),
                      if (i < 3) SizedBox(width: gap),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(builder: (_, cbox) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var c = 0; c < 7; c++) ...[
                          _tableauCol(t, c, cw, ch, cbox.maxHeight),
                          if (c < 6) SizedBox(width: gap),
                        ],
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 8),
                _buttons(t),
              ],
            ),
          ),
          if (celebrate) _cascade(t),
        ],
      );
    });
  }

  Widget _statsBar(GameTheme t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: t.surface, borderRadius: t.radius),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _stat(t, '⏱️', _time),
            _stat(t, '👆', '$moves moves'),
            _stat(t, '🎯', '${found.fold(0, (a, f) => a + f.length)}/52'),
          ],
        ),
      );

  Widget _stat(GameTheme t, String e, String v) => Row(children: [
        Text(e, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(v, style: TextStyle(color: t.text, fontWeight: FontWeight.w800, fontSize: 15)),
      ]);

  Widget _buttons(GameTheme t) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _miniBtn(t, '↩️ Undo', undoSnap != null && !over, _restoreUndo),
          const SizedBox(width: 10),
          _miniBtn(t, '✨ Auto', _canAuto, _autoComplete),
          const SizedBox(width: 10),
          _miniBtn(t, '🔁 New', true, () {
            Sfx.click();
            _newGame();
          }),
        ],
      );

  Widget _miniBtn(GameTheme t, String label, bool on, VoidCallback fn) => GestureDetector(
        onTap: on ? fn : null,
        child: Opacity(
          opacity: on ? 1 : 0.35,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              gradient: on ? t.headerGradient : null,
              color: on ? null : t.surface,
              borderRadius: t.radius,
            ),
            child: Text(label,
                style: TextStyle(
                    color: on ? Colors.white : t.muted, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
      );

  Widget _slot(GameTheme t, double w, double h, Widget child, {Key? key}) => SizedBox(
        key: key,
        width: w,
        height: h,
        child: Container(
          decoration: BoxDecoration(
            color: t.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.primary.withValues(alpha: 0.25)),
          ),
          child: child,
        ),
      );

  Widget _pileFace(GameTheme t, double w, double h, _Card? card,
      {VoidCallback? onTap, bool back = false, bool selected = false, String badge = '', String? ghost}) {
    return GestureDetector(
      onTap: onTap,
      child: card == null && !back
          ? Center(child: Text(ghost ?? '', style: TextStyle(fontSize: 22, color: t.muted.withValues(alpha: 0.5))))
          : _cardFace(t, w, h, card, back: back, selected: selected, badge: badge),
    );
  }

  Widget _cardFace(GameTheme t, double w, double h, _Card? card,
      {bool back = false, bool selected = false, String badge = ''}) {
    final body = Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: back
            ? LinearGradient(colors: [t.primary, t.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: back ? null : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? t.accent : Colors.black12, width: selected ? 3 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: back
          ? Center(child: Text('🃏', style: TextStyle(fontSize: w * 0.42)))
          : Padding(
              padding: EdgeInsets.all(w * 0.08),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_rankStr(card!.rank),
                      style: TextStyle(
                          fontSize: w * 0.30,
                          fontWeight: FontWeight.w900,
                          color: _isRed(card.suit) ? Colors.red.shade700 : Colors.grey.shade900,
                          height: 1)),
                  Text(_suits[card.suit],
                      style: TextStyle(
                          fontSize: w * 0.30,
                          color: _isRed(card.suit) ? Colors.red.shade700 : Colors.grey.shade900,
                          height: 1)),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(_suits[card.suit],
                        style: TextStyle(
                            fontSize: w * 0.34,
                            color: (_isRed(card.suit) ? Colors.red.shade700 : Colors.grey.shade900)
                                .withValues(alpha: 0.85))),
                  ),
                ],
              ),
            ),
    );
    return Stack(children: [
      body,
      if (badge.isNotEmpty)
        Positioned(
          right: 2,
          bottom: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
            child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ),
    ]);
  }

  Widget _tableauCol(GameTheme t, int col, double cw, double ch, double maxH) {
    final p = tab[col];
    final n = p.length;
    double dy = ch * 0.30;
    if (n > 1) dy = min(dy, (maxH - ch) / (n - 1));
    dy = max(dy, ch * 0.14);
    return SizedBox(
      width: cw,
      height: maxH,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _tapTableau(col, -1),
        child: Stack(
          children: [
            _slot(t, cw, ch, const SizedBox.shrink()),
            for (var i = 0; i < n; i++)
              Positioned(
                top: i * dy,
                child: GestureDetector(
                  onTap: () => _tapTableau(col, i),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.85, end: 1.0),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.elasticOut,
                    builder: (_, s, child) => Transform.scale(scale: s, child: child),
                    child: _cardFace(t, cw, ch, p[i],
                        back: !p[i].faceUp,
                        selected: sel?.kind == 2 && sel!.pile == col && i >= sel!.start),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cascade(GameTheme t) {
    final rnd = Random(7);
    return IgnorePointer(
      child: Container(
        color: Colors.black54,
        child: Stack(children: [
          for (var i = 0; i < 26; i++)
            Builder(builder: (_) {
              final x = rnd.nextDouble();
              final delay = (rnd.nextDouble() * 900).round();
              final card = _Card(rnd.nextInt(4), 1 + rnd.nextInt(13), faceUp: true);
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: -0.2, end: 1.25),
                duration: Duration(milliseconds: 1500 + rnd.nextInt(800)),
                curve: Curves.easeIn,
                builder: (_, v, _) => Positioned(
                  left: x * 340,
                  top: v * 700 - delay * 0.2,
                  child: Opacity(
                    opacity: (1 - v).clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: x * 6,
                      child: _cardFace(t, 44, 62, card),
                    ),
                  ),
                ),
              );
            }),
          const Center(
              child: Text('🏆', style: TextStyle(fontSize: 90))),
        ]),
      ),
    );
  }
}
