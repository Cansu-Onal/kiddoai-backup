import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'paint_page.dart';

class DrawPage extends StatefulWidget {
  const DrawPage({super.key});

  @override
  State<DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends State<DrawPage> {
  final List<DrawPoint?> _points = [];
  final GlobalKey _canvasKey = GlobalKey();

  Color _selectedColor = Colors.black;
  double _strokeWidth = 6;
  bool _isEraser = false;
  bool _showColors = false;
  bool _saving = false;

  final List<Color> _colors = [
    Colors.black,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.teal,
    Colors.blue,
    Colors.indigo,
    Colors.purple,
    Colors.pink,
    Colors.brown,
    Colors.grey,
  ];

  Offset _getLocalPosition(Offset globalPosition) {
    final RenderBox box =
        _canvasKey.currentContext!.findRenderObject() as RenderBox;
    return box.globalToLocal(globalPosition);
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _clearCanvas() {
    setState(() {
      _points.clear();
    });
  }

  void _selectPen() {
    setState(() {
      _isEraser = false;
    });
  }

  void _selectEraser() {
    setState(() {
      _isEraser = true;
    });
  }

  void _toggleColors() {
    setState(() {
      _showColors = !_showColors;
      _isEraser = false;
    });
  }

  void _selectColor(Color color) {
    setState(() {
      _selectedColor = color;
      _isEraser = false;
    });
  }

  void _addPoint(Offset globalPosition) {
    final localPosition = _getLocalPosition(globalPosition);

    setState(() {
      _points.add(
        DrawPoint(
          offset: localPosition,
          color: _isEraser ? Colors.white : _selectedColor,
          strokeWidth: _isEraser ? _strokeWidth + 8 : _strokeWidth,
        ),
      );
    });
  }

  Future<void> _saveDrawingToParentPanel() async {
    if (_points.whereType<DrawPoint>().isEmpty) {
      _showMessage("Önce bir çizim yapmalısın.");
      return;
    }

    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final boundary = _canvasKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;

      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw Exception("Görsel oluşturulamadı.");
      }

      final Uint8List imageBytes = byteData.buffer.asUint8List();

      final now = DateTime.now();
      final title =
          "Serbest çizim ${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}";

      final current = List<ParentSavedPainting>.from(
        ParentSavedPaintingsStore.paintings.value,
      );

      current.insert(
        0,
        ParentSavedPainting(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  title: title,
  imageBytes: imageBytes,
  savedAt: DateTime.now(),
),
      );

      ParentSavedPaintingsStore.paintings.value = current;

      _showMessage("Çizim ebeveyn paneline kaydedildi ✅");
    } catch (e) {
      _showMessage("Çizim kaydedilemedi: $e");
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7E6),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Çizim",
          style: TextStyle(
            color: Color(0xFF5B3A00),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF5B3A00)),
      ),
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                child: RepaintBoundary(
                  key: _canvasKey,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 10,
                          offset: Offset(0, 4),
                          color: Color(0x14000000),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (details) =>
                            _addPoint(details.globalPosition),
                        onPanUpdate: (details) =>
                            _addPoint(details.globalPosition),
                        onPanEnd: (_) {
                          setState(() {
                            _points.add(null);
                          });
                        },
                        child: CustomPaint(
                          painter: DrawingPainter(points: _points),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 12, 12, 12),
              child: Container(
                width: 78,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 8,
                      offset: Offset(0, 3),
                      color: Color(0x12000000),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    children: [
                      _toolButton(
                        icon: Icons.edit,
                        isSelected: !_isEraser,
                        onTap: _selectPen,
                      ),
                      const SizedBox(height: 12),
                      _toolButton(
                        icon: Icons.auto_fix_off,
                        isSelected: _isEraser,
                        onTap: _selectEraser,
                      ),
                      const SizedBox(height: 12),
                      _rainbowButton(onTap: _toggleColors),
                      if (_showColors) ...[
                        const SizedBox(height: 12),
                        ..._colors.map((color) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _colorCircle(
                              color: color,
                              isSelected:
                                  !_isEraser && _selectedColor == color,
                              onTap: () => _selectColor(color),
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 12),
                      _toolButton(
                        icon: Icons.camera_alt_rounded,
                        isSelected: false,
                        onTap: _saveDrawingToParentPanel,
                      ),
                      const SizedBox(height: 12),
                      _toolButton(
                        icon: Icons.delete_outline,
                        isSelected: false,
                        onTap: _clearCanvas,
                      ),
                      if (_saving) ...[
                        const SizedBox(height: 12),
                        const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    return Material(
      color: isSelected ? const Color(0xFFFFD54F) : Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(
            icon,
            size: 24,
            color: const Color(0xFF5B3A00),
          ),
        ),
      ),
    );
  }

  Widget _rainbowButton({required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                Colors.red,
                Colors.orange,
                Colors.yellow,
                Colors.green,
                Colors.blue,
                Colors.purple,
                Colors.red,
              ],
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.palette,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _colorCircle({
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: isSelected ? 42 : 36,
        height: isSelected ? 42 : 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.black : Colors.white,
            width: isSelected ? 3 : 2,
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 4,
              color: Color(0x22000000),
            ),
          ],
        ),
      ),
    );
  }
}

class DrawPoint {
  final Offset offset;
  final Color color;
  final double strokeWidth;

  DrawPoint({
    required this.offset,
    required this.color,
    required this.strokeWidth,
  });
}

class DrawingPainter extends CustomPainter {
  final List<DrawPoint?> points;

  DrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      if (current != null && next != null) {
        final paint = Paint()
          ..color = current.color
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..strokeWidth = current.strokeWidth;

        canvas.drawLine(current.offset, next.offset, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}