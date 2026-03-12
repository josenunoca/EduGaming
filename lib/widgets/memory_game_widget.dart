import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MemoryGameWidget extends StatefulWidget {
  final List<Map<String, String>> pairs;
  final VoidCallback onWin;

  const MemoryGameWidget({
    super.key,
    required this.pairs,
    required this.onWin,
  });

  @override
  State<MemoryGameWidget> createState() => _MemoryGameWidgetState();
}

class _MemoryGameWidgetState extends State<MemoryGameWidget> {
  late List<_MemoryCard> _cards;
  int? _firstFlippedIndex;
  bool _isProcessing = false;
  int _matchesFound = 0;

  @override
  void initState() {
    super.initState();
    _setupGame();
  }

  void _setupGame() {
    _cards = [];
    for (int i = 0; i < widget.pairs.length; i++) {
      _cards.add(_MemoryCard(content: widget.pairs[i]['a']!, pairId: i));
      _cards.add(_MemoryCard(content: widget.pairs[i]['b']!, pairId: i));
    }
    _cards.shuffle();
  }

  void _onCardTap(int index) {
    if (_isProcessing || _cards[index].isFlipped || _cards[index].isMatched) return;

    setState(() {
      _cards[index].isFlipped = true;
    });

    if (_firstFlippedIndex == null) {
      _firstFlippedIndex = index;
    } else {
      _isProcessing = true;
      final firstCard = _cards[_firstFlippedIndex!];
      final secondCard = _cards[index];

      if (firstCard.pairId == secondCard.pairId) {
        setState(() {
          firstCard.isMatched = true;
          secondCard.isMatched = true;
          _matchesFound++;
          _firstFlippedIndex = null;
          _isProcessing = false;
        });
        if (_matchesFound == widget.pairs.length) {
          widget.onWin();
        }
      } else {
        Timer(const Duration(seconds: 1), () {
          if (!mounted) return;
          setState(() {
            firstCard.isFlipped = false;
            secondCard.isFlipped = false;
            _firstFlippedIndex = null;
            _isProcessing = false;
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final crossAxisCount = widget.pairs.length > 6 ? 4 : 3;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _cards.length,
        itemBuilder: (context, index) {
          final card = _cards[index];
          return GestureDetector(
            onTap: () => _onCardTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: card.isFlipped || card.isMatched
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFF7B61FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: card.isMatched ? Colors.greenAccent : Colors.white10,
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8),
              child: card.isFlipped || card.isMatched
                  ? Text(
                      card.content,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().scale().fadeIn()
                  : const Icon(Icons.help_outline, color: Colors.white54, size: 30),
            ).animate(target: card.isMatched ? 1 : 0).shimmer(duration: 1.seconds, color: Colors.white24).scale(end: const Offset(1.05, 1.05)),
          );
        },
      );
    });
  }
}

class _MemoryCard {
  final String content;
  final int pairId;
  bool isFlipped = false;
  bool isMatched = false;

  _MemoryCard({
    required this.content,
    required this.pairId,
  });
}
