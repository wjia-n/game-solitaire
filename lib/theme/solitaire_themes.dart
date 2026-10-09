import 'package:flutter/material.dart';

/// One felt theme for Solitaire: the whole table identity.
///
/// Free-tier covers the first four (Classic Felt, Midnight Blue, Emerald,
/// Walnut); the rest are PRO. `id == 'custom'` is the player-built theme.
class FeltThemeDef {
  final String id;
  final String name;
  final Color feltLight; // table top / card area highlight
  final Color feltDark; // table edges
  final Color rail; // wooden / leather rail
  final Color railDeep;
  final Color accent; // gold/brass trim
  final Color accentLight;
  final Color ink; // text on felt
  final Color cardFace; // playing card face
  final Color cardInk; // text on cards (unused, pips own their color)
  final Color placeholder; // empty-slot tint
  final Color shadow;
  final bool pro;

  const FeltThemeDef({
    required this.id,
    required this.name,
    required this.feltLight,
    required this.feltDark,
    required this.rail,
    required this.railDeep,
    required this.accent,
    required this.accentLight,
    required this.ink,
    required this.cardFace,
    required this.cardInk,
    required this.placeholder,
    required this.shadow,
    this.pro = false,
  });
}

/// The full felt catalog: 14 built-in + the custom slot.
class FeltThemes {
  static const List<FeltThemeDef> all = [
    FeltThemeDef(
      id: 'classic',
      name: 'Classic Felt',
      feltLight: Color(0xFF0E7A48),
      feltDark: Color(0xFF05422A),
      rail: Color(0xFF5A3820),
      railDeep: Color(0xFF2E1A0C),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      ink: Color(0xFFF5EFE0),
      cardFace: Color(0xFFFFFEF8),
      cardInk: Color(0xFF1B1B1B),
      placeholder: Color(0xFF083B25),
      shadow: Color(0xFF000000),
    ),
    FeltThemeDef(
      id: 'midnight',
      name: 'Midnight Blue',
      feltLight: Color(0xFF1E4D8C),
      feltDark: Color(0xFF0B2447),
      rail: Color(0xFF2C2C34),
      railDeep: Color(0xFF121218),
      accent: Color(0xFFD8D8E4),
      accentLight: Color(0xFFF2F2FA),
      ink: Color(0xFFF0F4FA),
      cardFace: Color(0xFFFFFEF8),
      cardInk: Color(0xFF1B1B1B),
      placeholder: Color(0xFF10294E),
      shadow: Color(0xFF000000),
    ),
    FeltThemeDef(
      id: 'emerald',
      name: 'Emerald Hall',
      feltLight: Color(0xFF146B5A),
      feltDark: Color(0xFF083A32),
      rail: Color(0xFF4A2F18),
      railDeep: Color(0xFF241204),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFF0DA8A),
      ink: Color(0xFFF3EEDC),
      cardFace: Color(0xFFFFFEF8),
      cardInk: Color(0xFF1B1B1B),
      placeholder: Color(0xFF0B3A30),
      shadow: Color(0xFF000000),
    ),
    FeltThemeDef(
      id: 'walnut',
      name: 'Walnut Table',
      feltLight: Color(0xFF6B4A2A),
      feltDark: Color(0xFF3A2410),
      rail: Color(0xFF3A2410),
      railDeep: Color(0xFF1D0F04),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      ink: Color(0xFFF7EEDD),
      cardFace: Color(0xFFFFFEF8),
      cardInk: Color(0xFF1B1B1B),
      placeholder: Color(0xFF40290F),
      shadow: Color(0xFF000000),
    ),
    // --- PRO themes -----------------------------------------------------
    FeltThemeDef(
      id: 'burgundy',
      name: 'Burgundy Club',
      feltLight: Color(0xFF7A2436),
      feltDark: Color(0xFF420E1B),
      rail: Color(0xFF2E1A0C),
      railDeep: Color(0xFF140802),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFF0DA8A),
      ink: Color(0xFFF7EAE2),
      cardFace: Color(0xFFFFFEF8),
      cardInk: Color(0xFF1B1B1B),
      placeholder: Color(0xFF4A1020),
      shadow: Color(0xFF000000),
      pro: true,
    ),
    FeltThemeDef(
      id: 'ivory',
      name: 'Ivory Salon',
      feltLight: Color(0xFFE8DCC0),
      feltDark: Color(0xFFB3A480),
      rail: Color(0xFF5A3820),
      railDeep: Color(0xFF2E1A0C),
      accent: Color(0xFF8A6D1A),
      accentLight: Color(0xFFC9A227),
      ink: Color(0xFF2E2010),
      cardFace: Color(0xFFFFFEF8),
      cardInk: Color(0xFF1B1B1B),
      placeholder: Color(0xFFC4B48E),
      shadow: Color(0xFF2A2012),
      pro: true,
    ),
    FeltThemeDef(
      id: 'charcoal',
      name: 'Charcoal Room',
      feltLight: Color(0xFF3A3F45),
      feltDark: Color(0xFF16181C),
      rail: Color(0xFF23262B),
      railDeep: Color(0xFF0C0D10),
      accent: Color(0xFFB08D3E),
      accentLight: Color(0xFFE0BE6E),
      ink: Color(0xFFEDEFF2),
      cardFace: Color(0xFFFFFEF8),
      cardInk: Color(0xFF1B1B1B),
      placeholder: Color(0xFF20242A),
      shadow: Color(0xFF000000),
      pro: true,
    ),
    FeltThemeDef(
      id: 'forest',
      name: 'Deep Forest',
      feltLight: Color(0xFF1F5C2E),
      feltDark: Color(0xFF0C2E16),
      rail: Color(0xFF3E2A14),
      railDeep: Color(0xFF1C1004),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFF0DA8A),
      ink: Color(0xFFF0F3E4),
      cardFace: Color(0xFFFFFEF8),
      cardInk: Color(0xFF1B1B1B),
      placeholder: Color(0xFF0F3419),
      shadow: Color(0xFF000000),
      pro: true,
    ),
    FeltThemeDef(
      id: 'royal',
      name: 'Royal Purple',
      feltLight: Color(0xFF5C2E8C),
      feltDark: Color(0xFF2E1247),
      rail: Color(0xFF2C1A3E),
      railDeep: Color(0xFF140A20),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFF0DA8A),
      ink: Color(0xFFF2EAF7),
      cardFace: Color(0xFFFFFEF8),
      cardInk: Color(0xFF1B1B1B),
      placeholder: Color(0xFF331452),
      shadow: Color(0xFF000000),
      pro: true,
    ),
    FeltThemeDef(
      id: 'crimson',
      name: 'Crimson Parlor',
      feltLight: Color(0xFF8C1E2E),
      feltDark: Color(0xFF470812),
      rail: Color(0xFF2E1A0C),
      railDeep: Color(0xFF140802),
      accent: Color(0xFFE8CE7A),
      accentLight: Color(0xFFF6E5A8),
      ink: Color(0xFFF7EAE2),
      cardFace: Color(0xFFFFFEF8),
      cardInk: Color(0xFF1B1B1B),
      placeholder: Color(0xFF520A14),
      shadow: Color(0xFF000000),
      pro: true,
    ),
    FeltThemeDef(
      id: 'teal',
      name: 'Teal Harbor',
      feltLight: Color(0xFF14607A),
      feltDark: Color(0xFF08303F),
      rail: Color(0xFF3E2A14),
      railDeep: Color(0xFF1C1004),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFF0DA8A),
      ink: Color(0xFFEDF6F8),
      cardFace: Color(0xFFFFFEF8),
      cardInk: Color(0xFF1B1B1B),
      placeholder: Color(0xFF0B3646),
      shadow: Color(0xFF000000),
      pro: true,
    ),
    FeltThemeDef(
      id: 'sepia',
      name: 'Sepia Study',
      feltLight: Color(0xFF8C6E3E),
      feltDark: Color(0xFF47320F),
      rail: Color(0xFF33210C),
      railDeep: Color(0xFF180E02),
      accent: Color(0xFF5C3A10),
      accentLight: Color(0xFF9C7430),
      ink: Color(0xFFFBF4E2),
      cardFace: Color(0xFFFBF6E8),
      cardInk: Color(0xFF241A08),
      placeholder: Color(0xFF50380F),
      shadow: Color(0xFF2A1E0C),
      pro: true,
    ),
    FeltThemeDef(
      id: 'slate',
      name: 'Slate Casino',
      feltLight: Color(0xFF4E5E6B),
      feltDark: Color(0xFF232D36),
      rail: Color(0xFF1C232B),
      railDeep: Color(0xFF0C1014),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      ink: Color(0xFFF0F4F6),
      cardFace: Color(0xFFFFFEF8),
      cardInk: Color(0xFF1B1B1B),
      placeholder: Color(0xFF2B3540),
      shadow: Color(0xFF000000),
      pro: true,
    ),
    FeltThemeDef(
      id: 'copper',
      name: 'Copper Room',
      feltLight: Color(0xFF8C5A2E),
      feltDark: Color(0xFF472A0E),
      rail: Color(0xFF2E1A0C),
      railDeep: Color(0xFF140802),
      accent: Color(0xFFF0C878),
      accentLight: Color(0xFFFBE0A8),
      ink: Color(0xFFF9F0E2),
      cardFace: Color(0xFFFFFEF8),
      cardInk: Color(0xFF1B1B1B),
      placeholder: Color(0xFF52300E),
      shadow: Color(0xFF000000),
      pro: true,
    ),
  ];

  static FeltThemeDef byId(String id, {FeltThemeDef? custom}) {
    if (id == 'custom' && custom != null) return custom;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  static bool isProTheme(String id) => byId(id).pro;

  static const int freeCount = 4;
}

/// Card-back style catalog: 8+ styles, first three free, the rest PRO.
/// Rendering itself lives in [CardBackPainter] (widgets/cards.dart) keyed by
/// [id], so a theme switch never touches widget code.
class CardBackStyle {
  final String id;
  final String name;
  final bool pro;
  const CardBackStyle(this.id, this.name, {this.pro = false});

  static const List<CardBackStyle> all = [
    CardBackStyle('classic', 'Classic Red Weave'),
    CardBackStyle('royal', 'Royal Blue Diamond'),
    CardBackStyle('forest', 'Forest Lattice'),
    CardBackStyle('burgundy', 'Burgundy Scroll', pro: true),
    CardBackStyle('ebony', 'Ebony & Gold', pro: true),
    CardBackStyle('ivory', 'Ivory Filigree', pro: true),
    CardBackStyle('teal', 'Teal Harlequin', pro: true),
    CardBackStyle('copper', 'Copper Herringbone', pro: true),
    CardBackStyle('plum', 'Plum Damask', pro: true),
    CardBackStyle('slate', 'Slate Check', pro: true),
  ];

  static CardBackStyle byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return all.first;
  }
}
