import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const SolitaireApp());

class SolitaireApp extends StatelessWidget {
  const SolitaireApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Solitaire',
      tagline: 'The timeless Klondike classic. Stack it up, chill out, feel like a genius!',
      emoji: '🃏',
      slug: 'solitaire',
      howToPlay:
          '• Tap the deck to flip a card. Build each column down in alternating colors.\n• Stack every suit from Ace to King on the 4 foundation piles up top.\n• Tap a card, then tap where it should go. Fill all 4 foundations to win!\n• Stuck? Hit undo. Feeling spicy? Smash that auto-complete button. ✨',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => SolitaireScreen(players: players, callbacks: cb),
    );
  }
}
