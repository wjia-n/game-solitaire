import 'package:flutter/material.dart';
import '../engine/solitaire_engine.dart';
import '../theme/solitaire_themes.dart';

/// Pseudo-3D physical playing cards: real card stock, beveled edges, soft
/// drop shadows, painted backs. Suits use the classic unicode glyphs
/// (♠♥♦♣) — typographic pips, not emoji.
class PlayingCardWidget extends StatelessWidget {
  final PlayingCard card;
  final FeltThemeDef theme;
  final String backId;
  final double width;
  final bool elevated; // lifted look while selected

  const PlayingCardWidget({
    super.key,
    required this.card,
    required this.theme,
    required this.backId,
    required this.width,
    this.elevated = false,
  });

  double get _height => width * 1.42;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: _height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.09),
        boxShadow: [
          BoxShadow(
            color: theme.shadow.withValues(alpha: elevated ? 0.65 : 0.45),
            offset: Offset(0, elevated ? 8 : 3),
            blurRadius: elevated ? 14 : 7,
            spreadRadius: 0,
          ),
          // top bevel highlight — the "card stock" edge catching light
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.35),
            offset: const Offset(0, -1),
            blurRadius: 1,
            spreadRadius: -1,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: card.faceUp
          ? _CardFace(card: card, theme: theme)
          : _CardBack(backId: backId, width: width),
    );
  }
}

class _CardFace extends StatelessWidget {
  final PlayingCard card;
  final FeltThemeDef theme;
  const _CardFace({required this.card, required this.theme});

  Color get _ink => isRedSuit(card.suit)
      ? const Color(0xFFC0202E)
      : const Color(0xFF1E1E28);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardFace,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF9A8F7A).withValues(alpha: 0.55),
          width: 1,
        ),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF3EEE2)],
          stops: [0.0, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // corner indices
          Positioned(
            top: 3,
            left: 5,
            child: _Corner(rank: card.rankLabel, suit: card.suitGlyph, ink: _ink),
          ),
          Positioned(
            bottom: 3,
            right: 5,
            child: Transform.rotate(
              angle: 3.14159265,
              child: _Corner(rank: card.rankLabel, suit: card.suitGlyph, ink: _ink),
            ),
          ),
          // center art
          Center(
            child: card.rank >= 11
                ? _CourtCard(rank: card.rankLabel, suit: card.suitGlyph, ink: _ink)
                : Text(
                    card.suitGlyph,
                    style: TextStyle(
                      fontSize: card.rank == 1 ? 44 : 34,
                      color: _ink,
                      shadows: const [
                        Shadow(
                            color: Color(0x22000000),
                            offset: Offset(1, 2),
                            blurRadius: 2)
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  final String rank;
  final String suit;
  final Color ink;
  const _Corner({required this.rank, required this.suit, required this.ink});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(rank,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: ink)),
        Text(suit, style: TextStyle(fontSize: 13, color: ink)),
      ],
    );
  }
}

/// Ornamental medallion for J / Q / K.
class _CourtCard extends StatelessWidget {
  final String rank;
  final String suit;
  final Color ink;
  const _CourtCard(
      {required this.rank, required this.suit, required this.ink});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ink.withValues(alpha: 0.85), width: 2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ink.withValues(alpha: 0.10),
            ink.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(rank,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: ink,
                  fontFamily: 'serif')),
          Text(suit, style: TextStyle(fontSize: 20, color: ink)),
        ],
      ),
    );
  }
}

/// Painted card back. Ten geometric styles keyed by [backId]; everything is
/// drawn with canvas primitives — physical card-stock patterns, no AI art.
class _CardBack extends StatelessWidget {
  final String backId;
  final double width;
  const _CardBack({required this.backId, required this.width});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CardBackPainter(backId),
      child: Container(),
    );
  }
}

class CardBackPainter extends CustomPainter {
  final String backId;
  CardBackPainter(this.backId);

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(size.width * 0.09));
    final style = CardBackStyle.byId(backId);
    final base = _baseColor(style.id);
    canvas.drawRRect(r, Paint()..color = base);

    // inner white margin line — classic card-back border
    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.07, size.height * 0.05,
          size.width * 0.86, size.height * 0.90),
      Radius.circular(size.width * 0.06),
    );
    canvas.drawRRect(inner,
        Paint()..color = const Color(0xFFF6F1E4)..style = PaintingStyle.stroke..strokeWidth = 2);

    final clip = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.075, size.height * 0.055,
          size.width * 0.85, size.height * 0.89),
      Radius.circular(size.width * 0.055),
    );
    canvas.save();
    canvas.clipRRect(clip);
    final pat = _patternColor(style.id, base);
    switch (style.id) {
      case 'classic':
        _weave(canvas, size, pat);
        break;
      case 'royal':
      case 'forest':
        _diamonds(canvas, size, pat, dense: style.id == 'forest');
        break;
      case 'burgundy':
        _scrolls(canvas, size, pat);
        break;
      case 'ebony':
        _medallion(canvas, size, pat);
        break;
      case 'ivory':
        _filigree(canvas, size, pat);
        break;
      case 'teal':
        _harlequin(canvas, size, pat);
        break;
      case 'copper':
        _herringbone(canvas, size, pat);
        break;
      case 'plum':
        _damask(canvas, size, pat);
        break;
      case 'slate':
        _check(canvas, size, pat);
        break;
      default:
        _weave(canvas, size, pat);
    }
    canvas.restore();

    // subtle top sheen so the card reads as physical stock
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height * 0.35),
          Radius.circular(size.width * 0.09)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.14), Colors.transparent],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.35)),
    );
  }

  Color _baseColor(String id) {
    switch (id) {
      case 'classic':
        return const Color(0xFF8C1E24);
      case 'royal':
        return const Color(0xFF1E3A8C);
      case 'forest':
        return const Color(0xFF1E5C34);
      case 'burgundy':
        return const Color(0xFF5C1E2E);
      case 'ebony':
        return const Color(0xFF1A1A20);
      case 'ivory':
        return const Color(0xFFE8DFC8);
      case 'teal':
        return const Color(0xFF14606E);
      case 'copper':
        return const Color(0xFF8C5A2A);
      case 'plum':
        return const Color(0xFF4E2A5C);
      case 'slate':
        return const Color(0xFF3A4550);
      default:
        return const Color(0xFF8C1E24);
    }
  }

  Color _patternColor(String id, Color base) {
    if (id == 'ivory') return const Color(0xFFB8A87E);
    if (id == 'ebony') return const Color(0xFFC9A227);
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness((hsl.lightness + 0.16).clamp(0.0, 1.0))
        .toColor();
  }

  void _weave(Canvas c, Size s, Color p) {
    final paint = Paint()
      ..color = p.withValues(alpha: 0.55)
      ..strokeWidth = 1.4;
    const step = 9.0;
    for (double x = -s.height; x < s.width + s.height; x += step) {
      c.drawLine(Offset(x, 0), Offset(x + s.height, s.height), paint);
      c.drawLine(Offset(x + s.height, 0), Offset(x, s.height), paint);
    }
  }

  void _diamonds(Canvas c, Size s, Color p, {bool dense = false}) {
    final paint = Paint()
      ..color = p.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final step = dense ? 12.0 : 17.0;
    for (double y = 0; y < s.height + step; y += step) {
      for (double x = 0; x < s.width + step; x += step) {
        final cx = x + ((y / step) % 2 == 0 ? 0 : step / 2);
        final path = Path()
          ..moveTo(cx, y)
          ..lineTo(cx + step / 2, y + step / 2)
          ..lineTo(cx, y + step)
          ..lineTo(cx - step / 2, y + step / 2)
          ..close();
        c.drawPath(path, paint);
      }
    }
  }

  void _scrolls(Canvas c, Size s, Color p) {
    final paint = Paint()
      ..color = p.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const step = 22.0;
    for (double y = 0; y < s.height + step; y += step) {
      for (double x = 0; x < s.width + step; x += step) {
        c.drawArc(Rect.fromCircle(center: Offset(x, y), radius: 9), 0,
            4.4, false, paint);
        c.drawArc(Rect.fromCircle(center: Offset(x + 11, y + 11), radius: 6),
            3.14, 4.4, false, paint);
      }
    }
  }

  void _medallion(Canvas c, Size s, Color p) {
    final paint = Paint()
      ..color = p.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final center = Offset(s.width / 2, s.height / 2);
    c.drawCircle(center, s.width * 0.26, paint);
    c.drawCircle(center, s.width * 0.20,
        paint..strokeWidth = 1.2);
    final path = Path()
      ..moveTo(center.dx, center.dy - s.width * 0.26)
      ..lineTo(center.dx + s.width * 0.26, center.dy)
      ..lineTo(center.dx, center.dy + s.width * 0.26)
      ..lineTo(center.dx - s.width * 0.26, center.dy)
      ..close();
    c.drawPath(path, Paint()..color = p.withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 1.2);
  }

  void _filigree(Canvas c, Size s, Color p) {
    final paint = Paint()
      ..color = p.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    const step = 16.0;
    for (double y = step / 2; y < s.height; y += step) {
      for (double x = step / 2; x < s.width; x += step) {
        c.drawCircle(Offset(x, y), 3.2, paint);
        c.drawLine(Offset(x - 6, y), Offset(x + 6, y), paint);
        c.drawLine(Offset(x, y - 6), Offset(x, y + 6), paint);
      }
    }
  }

  void _harlequin(Canvas c, Size s, Color p) {
    final paint = Paint()..color = p.withValues(alpha: 0.5);
    const step = 16.0;
    for (double y = 0; y < s.height; y += step) {
      for (double x = 0; x < s.width + step; x += step * 2) {
        final off = ((y / step) % 2 == 0) ? 0.0 : step;
        final tri = Path()
          ..moveTo(x + off, y)
          ..lineTo(x + off + step, y)
          ..lineTo(x + off + step / 2, y + step)
          ..close();
        c.drawPath(tri, paint);
      }
    }
  }

  void _herringbone(Canvas c, Size s, Color p) {
    final paint = Paint()
      ..color = p.withValues(alpha: 0.5)
      ..strokeWidth = 3;
    const step = 14.0;
    for (double y = 0; y < s.height + step; y += step) {
      for (double x = -step; x < s.width + step; x += step) {
        final up = ((y / step) % 2 == 0);
        c.drawLine(Offset(x, y),
            Offset(x + step / 2, y + (up ? -step / 2 : step / 2)), paint);
      }
    }
  }

  void _damask(Canvas c, Size s, Color p) {
    final paint = Paint()
      ..color = p.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const step = 24.0;
    for (double y = 0; y < s.height + step; y += step) {
      for (double x = 0; x < s.width + step; x += step) {
        final cx = x + (((y / step) % 2 == 0) ? 0 : step / 2);
        final path = Path()
          ..moveTo(cx, y - 7)
          ..quadraticBezierTo(cx + 7, y, cx, y + 7)
          ..quadraticBezierTo(cx - 7, y, cx, y - 7)
          ..close();
        c.drawPath(path, paint);
      }
    }
  }

  void _check(Canvas c, Size s, Color p) {
    final paint = Paint()..color = p.withValues(alpha: 0.35);
    const step = 12.0;
    for (double y = 0; y < s.height; y += step) {
      for (double x = 0; x < s.width; x += step) {
        if (((x / step) + (y / step)) % 2 == 0) {
          c.drawRect(Rect.fromLTWH(x, y, step, step), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CardBackPainter old) =>
      old.backId != backId;
}

/// Empty pile slot: recessed felt well with a brass rim.
class EmptySlot extends StatelessWidget {
  final FeltThemeDef theme;
  final double width;
  final String? glyph; // foundation suit marker or recycle icon
  const EmptySlot(
      {super.key, required this.theme, required this.width, this.glyph});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 1.42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.09),
        color: theme.placeholder.withValues(alpha: 0.55),
        border: Border.all(
            color: theme.accent.withValues(alpha: 0.55), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            offset: const Offset(0, 2),
            blurRadius: 4,
            spreadRadius: -1,
          ),
        ],
      ),
      child: glyph == null
          ? null
          : Center(
              child: Text(
                glyph!,
                style: TextStyle(
                  fontSize: width * 0.42,
                  color: theme.accent.withValues(alpha: 0.5),
                ),
              ),
            ),
    );
  }
}
