import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/solitaire_themes.dart';

/// Solitaire PRO: Free-vs-Pro comparison, real purchase, restore, tip jar.
/// All prices come from the store — never hardcoded, never placeholders.
class ProScreen extends StatefulWidget {
  final TableAudio audio;
  final SolitaireSettings settings;
  final StoreService store;

  const ProScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.store,
  });

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  FeltThemeDef get _t => FeltThemes.byId(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    widget.store.proPurchased.addListener(_onPro);
    widget.store.lastThanks.addListener(_onThanks);
  }

  void _onPro() {
    if (widget.store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      widget.audio.win();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PRO unlocked — enjoy the full table!',
              style: TextStyle(fontFamily: 'serif')),
          backgroundColor: _t.railDeep,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.store.proPurchased.value = false;
    }
  }

  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(msg, style: const TextStyle(fontFamily: 'serif')),
        backgroundColor: _t.railDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.store.lastThanks.value = null;
  }

  @override
  void dispose() {
    widget.store.proPurchased.removeListener(_onPro);
    widget.store.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.accentLight),
          onPressed: () {
            widget.audio.click();
            Navigator.of(context).pop();
          },
        ),
        title: Text('Solitaire PRO',
            style: TextStyle(
                color: t.ink,
                fontFamily: 'serif',
                fontWeight: FontWeight.w800,
                fontSize: 22)),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.5),
            radius: 1.3,
            colors: [t.feltLight, t.feltDark],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Column(
                children: [
                  _panel(t, [
                    Text('Free vs PRO',
                        style: TextStyle(
                            color: t.ink,
                            fontFamily: 'serif',
                            fontWeight: FontWeight.w800,
                            fontSize: 20)),
                    const SizedBox(height: 4),
                    Text('One purchase. Yours forever.',
                        style: TextStyle(
                            color: t.ink.withValues(alpha: 0.7),
                            fontSize: 13)),
                    const SizedBox(height: 12),
                    _headerRow(t),
                    const Divider(height: 14),
                    ...const [
                      ('Complete Klondike game', true, true),
                      ('Draw-1 & Draw-3 modes', true, true),
                      ('Relaxed & Timed play', true, true),
                      ('Daily deal', true, true),
                      ('Unlimited undo', true, true),
                      ('Hints', true, true),
                      ('Renameable player', true, true),
                      ('Music & card sounds', true, true),
                      ('Table felts', '4', '14 + custom'),
                      ('Card back styles', '3', '10'),
                      ('Custom felt creator', false, true),
                    ].map((r) => _row(t, r.$1, r.$2, r.$3)),
                    if (s.isPro)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: t.accent.withValues(alpha: 0.25),
                            border: Border.all(color: t.accentLight),
                          ),
                          child: Text('✦ PRO ACTIVE ✦',
                              style: TextStyle(
                                  color: t.accentLight,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2)),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  _panel(t, [
                    Text('Unlock PRO',
                        style: TextStyle(
                            color: t.ink,
                            fontFamily: 'serif',
                            fontWeight: FontWeight.w800,
                            fontSize: 20)),
                    const SizedBox(height: 8),
                    if (s.isPro)
                      Text('You already own PRO — thank you!',
                          style:
                              TextStyle(color: t.ink, fontSize: 14),
                          textAlign: TextAlign.center)
                    else if (!store.storeReady)
                      Text(
                        store.error ?? 'Available after store setup.',
                        style: TextStyle(
                            color: t.ink.withValues(alpha: 0.7),
                            fontSize: 14),
                        textAlign: TextAlign.center,
                      )
                    else if (store.proProduct != null) ...[
                      Text(
                        store.proProduct!.description.isNotEmpty
                            ? store.proProduct!.description
                            : 'Every felt, every card back, and the custom creator — forever.',
                        style: TextStyle(color: t.ink, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<bool>(
                        valueListenable: store.purchaseInProgress,
                        builder: (_, busy, _) => GestureDetector(
                          onTap: busy
                              ? () {}
                              : () {
                                  widget.audio.click();
                                  store.buyPro();
                                },
                          child: Container(
                            width: 260,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: t.accent.withValues(alpha: 0.95),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.45),
                                    offset: const Offset(0, 4),
                                    blurRadius: 10),
                              ],
                            ),
                            child: Text(
                              busy
                                  ? 'Working…'
                                  : 'Get PRO — ${store.proProduct!.price}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: t.railDeep,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                    ValueListenableBuilder<String?>(
                      valueListenable: store.purchaseError,
                      builder: (_, err, _) => err == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding:
                                  const EdgeInsets.only(top: 10),
                              child: Text(err,
                                  style: const TextStyle(
                                      color: Color(0xFFE08A8A),
                                      fontSize: 13),
                                  textAlign: TextAlign.center),
                            ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        widget.audio.click();
                        store.restore();
                      },
                      child: Text('Restore purchases',
                          style: TextStyle(
                              color: t.accentLight,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _panel(t, [
                    Text('Tip the Maker',
                        style: TextStyle(
                            color: t.ink,
                            fontFamily: 'serif',
                            fontWeight: FontWeight.w800,
                            fontSize: 20)),
                    const SizedBox(height: 8),
                    Text(
                      'Solitaire is free forever. A small tip keeps new games coming!',
                      style: TextStyle(color: t.ink, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    if (!store.storeReady)
                      Text(
                        store.error ?? 'Available after store setup.',
                        style: TextStyle(
                            color: t.ink.withValues(alpha: 0.6),
                            fontSize: 13),
                        textAlign: TextAlign.center,
                      )
                    else
                      Builder(builder: (_) {
                        final tips = [
                          store.coffeeProduct,
                          store.chocolateProduct,
                        ].whereType<ProductDetails>().toList();
                        if (tips.isEmpty) {
                          return Text('Tips coming soon.',
                              style: TextStyle(
                                  color: t.ink.withValues(alpha: 0.6),
                                  fontSize: 13));
                        }
                        return Wrap(
                          spacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final p in tips)
                              GestureDetector(
                                onTap: () {
                                  widget.audio.click();
                                  store.buyTip(p);
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 3, vertical: 3),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(18),
                                    color: Colors.black
                                        .withValues(alpha: 0.3),
                                    border: Border.all(
                                        color: t.accent.withValues(
                                            alpha: 0.6),
                                        width: 1.5),
                                  ),
                                  child: Text(
                                    '${p.id == StoreService.chocolateId ? '🍫' : '☕'} ${p.price}',
                                    style: TextStyle(
                                        color: t.accentLight,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                          ],
                        );
                      }),
                  ]),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(FeltThemeDef t, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.30),
        border: Border.all(color: t.accent, width: 1.5),
      ),
      child: Column(children: children),
    );
  }

  Widget _headerRow(FeltThemeDef t) {
    final hs = TextStyle(
        color: t.accentLight,
        fontWeight: FontWeight.w800,
        fontSize: 12,
        letterSpacing: 1);
    return Row(
      children: [
        const Expanded(flex: 5, child: SizedBox()),
        Expanded(
            flex: 2,
            child: Text('FREE', style: hs, textAlign: TextAlign.center)),
        Expanded(
            flex: 2,
            child: Text('PRO', style: hs, textAlign: TextAlign.center)),
      ],
    );
  }

  Widget _row(FeltThemeDef t, String label, Object free, Object pro) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
              flex: 5,
              child: Text(label,
                  style: TextStyle(color: t.ink, fontSize: 13))),
          Expanded(flex: 2, child: _cell(t, free)),
          Expanded(flex: 2, child: _cell(t, pro)),
        ],
      ),
    );
  }

  Widget _cell(FeltThemeDef t, Object v) {
    if (v is bool) {
      return Text(v ? '✓' : '—',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 15,
              color: v
                  ? t.accentLight
                  : t.ink.withValues(alpha: 0.4)));
    }
    return Text(v as String,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: t.accentLight,
            fontWeight: FontWeight.w700,
            fontSize: 12));
  }
}
