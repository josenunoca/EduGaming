import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';

class WordSearchWidget extends StatefulWidget {
  final List<String> words;
  final int gridSize;
  final VoidCallback onWin;

  const WordSearchWidget({
    super.key,
    required this.words,
    this.gridSize = 10,
    required this.onWin,
  });

  @override
  State<WordSearchWidget> createState() => _WordSearchWidgetState();
}

class _WordSearchWidgetState extends State<WordSearchWidget> {
  late List<List<String>> _grid;
  late List<String> _targetWords;
  final Set<String> _foundWords = {};
  final Set<Point<int>> _selectedCells = {};
  final Set<Point<int>> _correctCells = {};
  Point<int>? _dragStart;

  @override
  void initState() {
    super.initState();
    _generateGrid();
  }

  void _generateGrid() {
    _targetWords = widget.words.map((w) => w.toUpperCase().replaceAll(' ', '')).toList();
    _grid = List.generate(widget.gridSize, (_) => List.generate(widget.gridSize, (_) => ''));
    
    final random = Random();
    
    for (final word in _targetWords) {
      bool placed = false;
      int attempts = 0;
      while (!placed && attempts < 100) {
        final row = random.nextInt(widget.gridSize);
        final col = random.nextInt(widget.gridSize);
        final direction = random.nextInt(3); // 0: horizontal, 1: vertical, 2: diagonal
        
        if (_canPlace(word, row, col, direction)) {
          _placeWord(word, row, col, direction);
          placed = true;
        }
        attempts++;
      }
    }
    
    // Fill remaining with random letters
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (int r = 0; r < widget.gridSize; r++) {
      for (int c = 0; c < widget.gridSize; c++) {
        if (_grid[r][c] == '') {
          _grid[r][c] = alphabet[random.nextInt(alphabet.length)];
        }
      }
    }
  }

  bool _canPlace(String word, int row, int col, int direction) {
    if (direction == 0 && col + word.length > widget.gridSize) return false;
    if (direction == 1 && row + word.length > widget.gridSize) return false;
    if (direction == 2 && (row + word.length > widget.gridSize || col + word.length > widget.gridSize)) return false;

    for (int i = 0; i < word.length; i++) {
      int r = row + (direction == 0 ? 0 : (direction == 1 ? i : i));
      int c = col + (direction == 1 ? 0 : (direction == 0 ? i : i));
      if (_grid[r][c] != '' && _grid[r][c] != word[i]) return false;
    }
    return true;
  }

  void _placeWord(String word, int row, int col, int direction) {
    for (int i = 0; i < word.length; i++) {
      int r = row + (direction == 0 ? 0 : (direction == 1 ? i : i));
      int c = col + (direction == 1 ? 0 : (direction == 0 ? i : i));
      _grid[r][c] = word[i];
    }
  }

  void _onPanStart(DragStartDetails details, BoxConstraints constraints) {
    _onInteraction(details.localPosition, constraints);
  }

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    _onInteraction(details.localPosition, constraints);
  }

  void _onInteraction(Offset localPos, BoxConstraints constraints) {
    final cellSize = constraints.maxWidth / widget.gridSize;
    final col = (localPos.dx / cellSize).floor().clamp(0, widget.gridSize - 1);
    final row = (localPos.dy / cellSize).floor().clamp(0, widget.gridSize - 1);
    final p = Point(row, col);

    setState(() {
      if (_dragStart == null) {
        _dragStart = p;
        _selectedCells.clear();
      }
      _selectedCells.add(p);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final selectedWord = _selectedCells.map((p) => _grid[p.x][p.y]).join();
    final reversedWord = selectedWord.split('').reversed.join();
    
    if (_targetWords.contains(selectedWord) || _targetWords.contains(reversedWord)) {
      final actualWord = _targetWords.contains(selectedWord) ? selectedWord : reversedWord;
      setState(() {
        _foundWords.add(actualWord);
        _correctCells.addAll(_selectedCells);
      });
      if (_foundWords.length == _targetWords.length) {
        widget.onWin();
      }
    }
    
    setState(() {
      _selectedCells.clear();
      _dragStart = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _targetWords.map((w) {
            final found = _foundWords.contains(w);
            return Chip(
              label: Text(w, style: TextStyle(
                color: found ? Colors.white : Colors.white70,
                decoration: found ? TextDecoration.lineThrough : null,
                fontSize: 10,
              )),
              backgroundColor: found ? Colors.green.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final size = constraints.maxWidth;
          return GestureDetector(
            onPanStart: (d) => _onPanStart(d, constraints),
            onPanUpdate: (d) => _onPanUpdate(d, constraints),
            onPanEnd: _onPanEnd,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: widget.gridSize,
                ),
                itemCount: widget.gridSize * widget.gridSize,
                itemBuilder: (context, index) {
                  final r = index ~/ widget.gridSize;
                  final c = index % widget.gridSize;
                  final p = Point(r, c);
                  final isSelected = _selectedCells.contains(p);
                  final isCorrect = _correctCells.contains(p);

                  return Container(
                    margin: const EdgeInsets.all(1),
                    decoration: BoxDecoration(
                      color: isCorrect 
                          ? Colors.green.withValues(alpha: 0.4) 
                          : (isSelected ? Colors.blue.withValues(alpha: 0.4) : Colors.transparent),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _grid[r][c],
                      style: TextStyle(
                        color: isCorrect ? Colors.white : Colors.white70,
                        fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                      ),
                    ).animate(target: isCorrect ? 1 : 0).scale(end: const Offset(1.2, 1.2)).then().shake(),
                  );
                },
              ),
            ),
          );
        }),
      ],
    );
  }
}
