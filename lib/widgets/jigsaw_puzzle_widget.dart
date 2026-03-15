import 'dart:math' as math;
import 'package:flutter/material.dart';

class JigsawPuzzleWidget extends StatefulWidget {
  final String imageUrl;
  final int gridRows;
  final int gridCols;
  final VoidCallback onWin;

  const JigsawPuzzleWidget({
    super.key,
    required this.imageUrl,
    this.gridRows = 3,
    this.gridCols = 3,
    required this.onWin,
  });

  @override
  State<JigsawPuzzleWidget> createState() => _JigsawPuzzleWidgetState();
}

class _JigsawPuzzleWidgetState extends State<JigsawPuzzleWidget> {
  List<_PuzzlePiece>? _pieces;
  bool _initialized = false;

  void _initializePuzzle(Size size) {
    if (_initialized) return;
    final pieceWidth = size.width / widget.gridCols;
    final pieceHeight = size.height / widget.gridRows;

    _pieces = [];
    for (int r = 0; r < widget.gridRows; r++) {
      for (int c = 0; c < widget.gridCols; c++) {
        _pieces!.add(
          _PuzzlePiece(
            id: r * widget.gridCols + c,
            correctRow: r,
            correctCol: c,
            currentPos: Offset(
              math.Random().nextDouble() * (size.width - pieceWidth),
              math.Random().nextDouble() * (size.height - pieceHeight),
            ),
            rotation: (math.Random().nextInt(4)) * 90.0,
            width: pieceWidth,
            height: pieceHeight,
          ),
        );
      }
    }
    _initialized = true;
    setState(() {});
  }

  void _checkWin() {
    bool allCorrect = true;
    for (var piece in _pieces!) {
      final correctX = piece.correctCol * piece.width;
      final correctY = piece.correctRow * piece.height;
      final dist = (piece.currentPos - Offset(correctX, correctY)).distance;

      if (dist > 20 || (piece.rotation % 360) != 0) {
        allCorrect = false;
        break;
      }
    }
    if (allCorrect) {
      widget.onWin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final boardWidth = constraints.maxWidth;
      final boardHeight = boardWidth * 0.75; // Aspect ratio for board

      return Container(
        width: boardWidth,
        height: boardHeight,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Stack(
          children: [
            // Target background (faint)
            Opacity(
              opacity: 0.1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.cover,
                  width: boardWidth,
                  height: boardHeight,
                ),
              ),
            ),
            if (_pieces != null)
              ..._pieces!.map((piece) {
                return Positioned(
                  left: piece.currentPos.dx,
                  top: piece.currentPos.dy,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        piece.currentPos += details.delta;
                      });
                    },
                    onPanEnd: (_) => _checkWin(),
                    onTap: () {
                      setState(() {
                        piece.rotation = (piece.rotation + 90) % 360;
                      });
                      _checkWin();
                    },
                    child: Transform.rotate(
                      angle: piece.rotation * math.pi / 180,
                      child: Container(
                        width: piece.width,
                        height: piece.height,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24, width: 0.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment(
                              (piece.correctCol / (widget.gridCols - 1)) * 2 -
                                  1,
                              (piece.correctRow / (widget.gridRows - 1)) * 2 -
                                  1,
                            ),
                            widthFactor: 1 / widget.gridCols,
                            heightFactor: 1 / widget.gridRows,
                            child: Image.network(
                              widget.imageUrl,
                              fit: BoxFit.cover,
                              width: boardWidth,
                              height: boardHeight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            // Initialization trigger
            if (!_initialized)
              Opacity(
                opacity: 0,
                child: Image.network(
                  widget.imageUrl,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _initializePuzzle(Size(boardWidth, boardHeight));
                      });
                      return child;
                    }
                    return const SizedBox();
                  },
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _PuzzlePiece {
  final int id;
  final int correctRow;
  final int correctCol;
  Offset currentPos;
  double rotation;
  final double width;
  final double height;

  _PuzzlePiece({
    required this.id,
    required this.correctRow,
    required this.correctCol,
    required this.currentPos,
    required this.rotation,
    required this.width,
    required this.height,
  });
}
