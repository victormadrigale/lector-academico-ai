import 'package:flutter/material.dart';

class KaraokeText extends StatefulWidget {
  final List<String> sentences;
  final int currentIndex;
  final int wordStart;
  final int wordEnd;

  const KaraokeText({
    super.key,
    required this.sentences,
    required this.currentIndex,
    required this.wordStart,
    required this.wordEnd,
  });

  @override
  State<KaraokeText> createState() => _KaraokeTextState();
}

class _KaraokeTextState extends State<KaraokeText> {
  List<GlobalKey> _keys = const [];

  @override
  void initState() {
    super.initState();
    _syncKeys();
    _scheduleFollow();
  }

  @override
  void didUpdateWidget(covariant KaraokeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sentences.length != widget.sentences.length) _syncKeys();
    if (oldWidget.currentIndex != widget.currentIndex) _scheduleFollow();
  }

  void _syncKeys() {
    _keys = List.generate(widget.sentences.length, (_) => GlobalKey());
  }

  void _scheduleFollow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.currentIndex < 0 || widget.currentIndex >= _keys.length) return;
      final context = _keys[widget.currentIndex].currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.35,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 190),
      children: List.generate(widget.sentences.length, (index) {
        final active = index == widget.currentIndex;
        return AnimatedContainer(
          key: _keys[index],
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: active ? _activeSentence(context, widget.sentences[index]) : _plainSentence(context, widget.sentences[index]),
        );
      }),
    );
  }

  Widget _plainSentence(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
      );

  Widget _activeSentence(BuildContext context, String text) {
    final start = widget.wordStart.clamp(0, text.length).toInt();
    final end = widget.wordEnd.clamp(start, text.length).toInt();
    final base = Theme.of(context).textTheme.bodyLarge?.copyWith(
          height: 1.55,
          fontWeight: FontWeight.w600,
        );
    if (end <= start) return Text(text, style: base);

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: TextStyle(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}
