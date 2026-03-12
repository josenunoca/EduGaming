import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MatchingPairsWidget extends StatefulWidget {
  final List<Map<String, String>> pairs;
  final VoidCallback onWin;

  const MatchingPairsWidget({
    super.key,
    required this.pairs,
    required this.onWin,
  });

  @override
  State<MatchingPairsWidget> createState() => _MatchingPairsWidgetState();
}

class _MatchingPairsWidgetState extends State<MatchingPairsWidget> {
  late List<String> _leftItems;
  late List<String> _rightItems;
  final Map<String, String> _matches = {};
  String? _selectedLeft;

  @override
  void initState() {
    super.initState();
    _leftItems = widget.pairs.map((p) => p['a']!).toList()..shuffle();
    _rightItems = widget.pairs.map((p) => p['b']!).toList()..shuffle();
  }

  void _onMatch(String left, String right) {
    // Check if the match is correct according to the original pairs
    bool isCorrect = false;
    for (final pair in widget.pairs) {
      if (pair['a'] == left && pair['b'] == right) {
        isCorrect = true;
        break;
      }
    }

    if (isCorrect) {
      setState(() {
        _matches[left] = right;
        _selectedLeft = null;
      });
      if (_matches.length == widget.pairs.length) {
        widget.onWin();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenta novamente!'), duration: Duration(milliseconds: 500)),
      );
      setState(() => _selectedLeft = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column
        Expanded(
          child: Column(
            children: _leftItems.map((item) {
              final isMatched = _matches.containsKey(item);
              final isSelected = _selectedLeft == item;
              return GestureDetector(
                onTap: isMatched ? null : () => setState(() => _selectedLeft = item),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMatched 
                        ? Colors.green.withValues(alpha: 0.2) 
                        : (isSelected ? const Color(0xFF00D1FF).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isMatched 
                          ? Colors.greenAccent 
                          : (isSelected ? const Color(0xFF00D1FF) : Colors.white10),
                    ),
                  ),
                  child: Text(item, 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isMatched ? Colors.white54 : Colors.white, fontSize: 12)
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 20),
        const Icon(Icons.sync_alt, color: Colors.white24),
        const SizedBox(width: 20),
        // Right Column
        Expanded(
          child: Column(
            children: _rightItems.map((item) {
              final isMatched = _matches.containsValue(item);
              return GestureDetector(
                onTap: (isMatched || _selectedLeft == null) ? null : () => _onMatch(_selectedLeft!, item),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMatched ? Colors.green.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isMatched ? Colors.greenAccent : Colors.white10),
                  ),
                  child: Text(item, 
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isMatched ? Colors.white54 : Colors.white, fontSize: 12)
                  ).animate(target: isMatched ? 1 : 0).fadeOut(duration: 200.ms),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
