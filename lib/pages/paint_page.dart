import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'parent_saved_paintings_store.dart';

class PaintItem {
  final String title;
  final String previewPath;
  final String paintPath;

  const PaintItem({
    required this.title,
    required this.previewPath,
    required this.paintPath,
  });
}

class PaintPage extends StatefulWidget {
  const PaintPage({super.key});

  @override
  State<PaintPage> createState() => _PaintPageState();
}

class _PaintPageState extends State<PaintPage> {
  final List<PaintItem> _paintItems = const [
    PaintItem(
      title: '1',
      previewPath: 'assets/paint/resim1.jpg',
      paintPath: 'assets/paint/resim1.jpg',
    ),
    PaintItem(
      title: '2',
      previewPath: 'assets/paint/resim2.jpg',
      paintPath: 'assets/paint/resim2.jpg',
    ),
    PaintItem(
      title: '3',
      previewPath: 'assets/paint/resim3.jpg',
      paintPath: 'assets/paint/resim3.jpg',
    ),
    PaintItem(
      title: '4',
      previewPath: 'assets/paint/resim4.jpg',
      paintPath: 'assets/paint/resim4.jpg',
    ),
    PaintItem(
      title: '5',
      previewPath: 'assets/paint/resim5.jpg',
      paintPath: 'assets/paint/resim5.jpg',
    ),
    PaintItem(
      title: '6',
      previewPath: 'assets/paint/resim6.jpg',
      paintPath: 'assets/paint/resim6.jpg',
    ),
    PaintItem(
      title: '7',
      previewPath: 'assets/paint/resim7.jpg',
      paintPath: 'assets/paint/resim7.jpg',
    ),
    PaintItem(
      title: '8',
      previewPath: 'assets/paint/resim8.jpg',
      paintPath: 'assets/paint/resim8.jpg',
    ),
      
    PaintItem(
      title: '9',
      previewPath: 'assets/paint/resim9.jpg',
      paintPath: 'assets/paint/resim9.jpg',
    ),
      
    PaintItem(
      title: '10',
      previewPath: 'assets/paint/resim10.jpg',
      paintPath: 'assets/paint/resim10.jpg',
    ),
  ];
  

  final Map<String, Uint8List> _savedPaintingPngByPath = {};

  bool _isPaintingMode = false;
  PaintItem? _selectedItem;

  final GlobalKey _canvasKey = GlobalKey();

  Color _selectedColor = Colors.red;
  double _strokeWidth = 14;
  bool _showColors = false;
  bool _showBrushSizes = false;
  bool _isEraser = false;

  final List<Color> _colors = const [
    Colors.red,
    Colors.redAccent,
    Colors.deepOrange,
    Colors.orange,
    Colors.amber,
    Colors.yellow,
    Colors.lime,
    Colors.lightGreen,
    Colors.green,
    Colors.teal,
    Colors.cyan,
    Colors.lightBlue,
    Colors.blue,
    Colors.indigo,
    Colors.deepPurple,
    Colors.purple,
    Colors.pink,
    Colors.brown,
    Colors.blueGrey,
    Colors.grey,
    Colors.black,
    Colors.white,
  ];

  final List<double> _brushSizes = const [8, 14, 22, 32];

  ui.Image? _displayUiImage;
  Uint8List? _originalRgbaBytes;
  Uint8List? _workingRgbaBytes;

  int _imageWidth = 0;
  int _imageHeight = 0;

  bool _isLoadingBitmap = false;
  bool _isSavingParentCopy = false;

  Uint8List? _selectedRegionMask;
  bool _isDrawing = false;
  math.Point<int>? _lastPaintPixel;

  bool _refreshScheduled = false;

  bool get _hasSelectedRegion => _selectedRegionMask != null;

  @override
  void initState() {
    super.initState();
    ParentSavedPaintingsStore.startAutoCleanup();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Offset _getLocalPosition(Offset globalPosition) {
    final RenderBox box =
        _canvasKey.currentContext!.findRenderObject() as RenderBox;
    return box.globalToLocal(globalPosition);
  }

  void _toggleColors() {
    setState(() {
      _showColors = !_showColors;
      _showBrushSizes = false;
      _isEraser = false;
    });
  }

  void _toggleBrushSizes() {
    setState(() {
      _showBrushSizes = !_showBrushSizes;
      _showColors = false;
    });
  }

  void _selectColor(Color color) {
    setState(() {
      _selectedColor = color;
      _isEraser = false;
    });
  }

  void _selectBrushSize(double size) {
    setState(() {
      _strokeWidth = size;
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
      _showColors = false;
    });
  }

  Future<void> _openCustomColorPicker() async {
    int red = _selectedColor.red;
    int green = _selectedColor.green;
    int blue = _selectedColor.blue;

    final result = await showDialog<Color>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final preview = Color.fromARGB(255, red, green, blue);

            return AlertDialog(
              title: const Text('Özel renk seç'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: preview,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black12, width: 2),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _rgbSlider(
                      label: 'Kırmızı',
                      value: red.toDouble(),
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setDialogState(() {
                          red = value.round();
                        });
                      },
                    ),
                    _rgbSlider(
                      label: 'Yeşil',
                      value: green.toDouble(),
                      activeColor: Colors.green,
                      onChanged: (value) {
                        setDialogState(() {
                          green = value.round();
                        });
                      },
                    ),
                    _rgbSlider(
                      label: 'Mavi',
                      value: blue.toDouble(),
                      activeColor: Colors.blue,
                      onChanged: (value) {
                        setDialogState(() {
                          blue = value.round();
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      Color.fromARGB(255, red, green, blue),
                    );
                  },
                  child: const Text('Seç'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      _selectColor(result);
    }
  }

  Widget _rgbSlider({
    required String label,
    required double value,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.round()}'),
        Slider(
          value: value,
          min: 0,
          max: 255,
          activeColor: activeColor,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Future<void> _clearCanvas() async {
    if (_originalRgbaBytes == null) return;

    _workingRgbaBytes = Uint8List.fromList(_originalRgbaBytes!);
    _selectedRegionMask = null;
    _lastPaintPixel = null;
    _isDrawing = false;

    await _refreshDisplayNow();
    await _persistCurrentPainting();
  }

  void _clearSelectedRegion() {
    setState(() {
      _selectedRegionMask = null;
    });
  }

  Future<void> _openPainting(PaintItem item) async {
    setState(() {
      _selectedItem = item;
      _isPaintingMode = true;
      _showColors = false;
      _showBrushSizes = false;
      _isEraser = false;
      _selectedColor = Colors.red;
      _strokeWidth = 14;

      _displayUiImage = null;
      _originalRgbaBytes = null;
      _workingRgbaBytes = null;
      _imageWidth = 0;
      _imageHeight = 0;
      _selectedRegionMask = null;
      _lastPaintPixel = null;
      _isDrawing = false;
    });

    await _loadBitmap(item);
  }

  Future<void> _backToGallery() async {
    await _persistCurrentPainting();

    if (!mounted) return;

    setState(() {
      _selectedItem = null;
      _isPaintingMode = false;
      _showColors = false;
      _showBrushSizes = false;
      _isEraser = false;

      _displayUiImage = null;
      _originalRgbaBytes = null;
      _workingRgbaBytes = null;
      _imageWidth = 0;
      _imageHeight = 0;
      _selectedRegionMask = null;
      _lastPaintPixel = null;
      _isDrawing = false;
    });
  }

  Future<_DecodedBitmap> _decodeImageBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    if (rgba == null) {
      throw Exception('Resim çözümlenemedi.');
    }

    return _DecodedBitmap(
      image: image,
      rgbaBytes: Uint8List.fromList(rgba.buffer.asUint8List()),
      width: image.width,
      height: image.height,
    );
  }

  Future<void> _loadBitmap(PaintItem item) async {
    setState(() {
      _isLoadingBitmap = true;
    });

    try {
      final originalData = await rootBundle.load(item.paintPath);
      final originalBytes = originalData.buffer.asUint8List();
      final originalDecoded = await _decodeImageBytes(originalBytes);

      final savedPng = _savedPaintingPngByPath[item.paintPath];
      final workingSourceBytes = savedPng ?? originalBytes;
      final workingDecoded = await _decodeImageBytes(workingSourceBytes);

      if (!mounted) return;

      setState(() {
        _originalRgbaBytes = originalDecoded.rgbaBytes;
        _workingRgbaBytes = Uint8List.fromList(workingDecoded.rgbaBytes);
        _imageWidth = workingDecoded.width;
        _imageHeight = workingDecoded.height;
        _displayUiImage = workingDecoded.image;
        _isLoadingBitmap = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingBitmap = false;
      });

      _showMessage("Resim yüklenemedi: $e");
    }
  }

  Rect _calculateImageRect(Size canvasSize) {
    const double padding = 16;

    final availableRect = Rect.fromLTWH(
      padding,
      padding,
      canvasSize.width - padding * 2,
      canvasSize.height - padding * 2,
    );

    if (_imageWidth == 0 || _imageHeight == 0) {
      return availableRect;
    }

    final fitted = applyBoxFit(
      BoxFit.contain,
      Size(_imageWidth.toDouble(), _imageHeight.toDouble()),
      availableRect.size,
    );

    final dx =
        availableRect.left + (availableRect.width - fitted.destination.width) / 2;
    final dy =
        availableRect.top + (availableRect.height - fitted.destination.height) / 2;

    return Rect.fromLTWH(
      dx,
      dy,
      fitted.destination.width,
      fitted.destination.height,
    );
  }

  math.Point<int>? _mapCanvasPointToImagePixel(
    Offset localPosition,
    Size canvasSize,
  ) {
    if (_imageWidth == 0 || _imageHeight == 0) return null;

    final imageRect = _calculateImageRect(canvasSize);
    if (!imageRect.contains(localPosition)) return null;

    final normalizedX = (localPosition.dx - imageRect.left) / imageRect.width;
    final normalizedY = (localPosition.dy - imageRect.top) / imageRect.height;

    final pixelX = (normalizedX * _imageWidth).floor().clamp(0, _imageWidth - 1);
    final pixelY =
        (normalizedY * _imageHeight).floor().clamp(0, _imageHeight - 1);

    return math.Point<int>(pixelX, pixelY);
  }

  int _pixelIndex(int x, int y) => (y * _imageWidth + x) * 4;

  bool _isBarrierFromOriginal(int x, int y) {
    final original = _originalRgbaBytes;
    if (original == null) return true;

    final i = _pixelIndex(x, y);
    final r = original[i];
    final g = original[i + 1];
    final b = original[i + 2];
    final a = original[i + 3];

    if (a < 10) return false;

    return r < 55 && g < 55 && b < 55;
  }

  void _writeWorking(int x, int y, _Rgba color) {
    final bytes = _workingRgbaBytes!;
    final i = _pixelIndex(x, y);
    bytes[i] = color.r;
    bytes[i + 1] = color.g;
    bytes[i + 2] = color.b;
    bytes[i + 3] = color.a;
  }

  Future<void> _selectRegionAt({
    required int startX,
    required int startY,
  }) async {
    if (_workingRgbaBytes == null || _originalRgbaBytes == null) return;
    if (startX < 0 ||
        startX >= _imageWidth ||
        startY < 0 ||
        startY >= _imageHeight) {
      return;
    }

    if (_isBarrierFromOriginal(startX, startY)) return;

    final mask = Uint8List(_imageWidth * _imageHeight);
    final visited = Uint8List(_imageWidth * _imageHeight);

    int maskIndex(int x, int y) => y * _imageWidth + x;

    final queue = Queue<math.Point<int>>();
    queue.add(math.Point<int>(startX, startY));

    while (queue.isNotEmpty) {
      final p = queue.removeFirst();
      final x = p.x;
      final y = p.y;

      if (x < 0 || x >= _imageWidth || y < 0 || y >= _imageHeight) continue;

      final mi = maskIndex(x, y);
      if (visited[mi] == 1) continue;

      visited[mi] = 1;

      if (_isBarrierFromOriginal(x, y)) continue;

      mask[mi] = 1;

      queue.add(math.Point<int>(x + 1, y));
      queue.add(math.Point<int>(x - 1, y));
      queue.add(math.Point<int>(x, y + 1));
      queue.add(math.Point<int>(x, y - 1));
    }

    if (!mounted) return;

    setState(() {
      _selectedRegionMask = mask;
    });
  }

  bool _isInsideSelectedRegion(int x, int y) {
    final mask = _selectedRegionMask;
    if (mask == null) return false;
    if (x < 0 || x >= _imageWidth || y < 0 || y >= _imageHeight) return false;
    return mask[y * _imageWidth + x] == 1;
  }

  void _paintBrushStamp({
    required int centerX,
    required int centerY,
    required double radiusPixels,
  }) {
    if (_workingRgbaBytes == null || _selectedRegionMask == null) return;

    final color = _isEraser
        ? const _Rgba(255, 255, 255, 255)
        : _Rgba(
            _selectedColor.red,
            _selectedColor.green,
            _selectedColor.blue,
            255,
          );

    final r = math.max(1, radiusPixels.round());
    final rSquared = r * r;

    for (int dy = -r; dy <= r; dy++) {
      for (int dx = -r; dx <= r; dx++) {
        if (dx * dx + dy * dy > rSquared) continue;

        final x = centerX + dx;
        final y = centerY + dy;

        if (x < 0 || x >= _imageWidth || y < 0 || y >= _imageHeight) continue;
        if (_isBarrierFromOriginal(x, y)) continue;
        if (!_isInsideSelectedRegion(x, y)) continue;

        _writeWorking(x, y, color);
      }
    }
  }

  void _paintInterpolatedLine({
    required math.Point<int> from,
    required math.Point<int> to,
    required double radiusPixels,
  }) {
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    final steps = math.max(dx.abs(), dy.abs());

    if (steps == 0) {
      _paintBrushStamp(
        centerX: from.x,
        centerY: from.y,
        radiusPixels: radiusPixels,
      );
      return;
    }

    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = (from.x + dx * t).round();
      final y = (from.y + dy * t).round();

      _paintBrushStamp(
        centerX: x,
        centerY: y,
        radiusPixels: radiusPixels,
      );
    }
  }

  double _brushRadiusInImagePixels(Size canvasSize) {
    final imageRect = _calculateImageRect(canvasSize);
    if (imageRect.width <= 0 || imageRect.height <= 0) return 4;

    final scaleX = _imageWidth / imageRect.width;
    final scaleY = _imageHeight / imageRect.height;
    final scale = (scaleX + scaleY) / 2;

    return (_strokeWidth / 2) * scale;
  }

  Future<void> _handleTapDown(Offset globalPosition, Size canvasSize) async {
    final local = _getLocalPosition(globalPosition);
    final pixel = _mapCanvasPointToImagePixel(local, canvasSize);
    if (pixel == null) return;

    await _selectRegionAt(
      startX: pixel.x,
      startY: pixel.y,
    );
  }

  Future<void> _handlePanStart(Offset globalPosition, Size canvasSize) async {
    final local = _getLocalPosition(globalPosition);
    final pixel = _mapCanvasPointToImagePixel(local, canvasSize);
    if (pixel == null) return;

    if (!_hasSelectedRegion || !_isInsideSelectedRegion(pixel.x, pixel.y)) {
      await _selectRegionAt(
        startX: pixel.x,
        startY: pixel.y,
      );
    }

    if (!_hasSelectedRegion) return;
    if (!_isInsideSelectedRegion(pixel.x, pixel.y)) return;

    _isDrawing = true;
    _lastPaintPixel = pixel;

    final radiusPixels = _brushRadiusInImagePixels(canvasSize);

    _paintBrushStamp(
      centerX: pixel.x,
      centerY: pixel.y,
      radiusPixels: radiusPixels,
    );

    _scheduleDisplayRefresh();
    if (mounted) setState(() {});
  }

  void _handlePanUpdate(Offset globalPosition, Size canvasSize) {
    if (!_isDrawing) return;
    if (_workingRgbaBytes == null || _selectedRegionMask == null) return;

    final local = _getLocalPosition(globalPosition);
    final pixel = _mapCanvasPointToImagePixel(local, canvasSize);
    if (pixel == null) return;

    final last = _lastPaintPixel;
    final radiusPixels = _brushRadiusInImagePixels(canvasSize);

    if (last == null) {
      _paintBrushStamp(
        centerX: pixel.x,
        centerY: pixel.y,
        radiusPixels: radiusPixels,
      );
    } else {
      _paintInterpolatedLine(
        from: last,
        to: pixel,
        radiusPixels: radiusPixels,
      );
    }

    _lastPaintPixel = pixel;
    _scheduleDisplayRefresh();
  }

  Future<void> _handlePanEnd() async {
    _isDrawing = false;
    _lastPaintPixel = null;
    await _refreshDisplayNow();
    await _persistCurrentPainting();
  }

  void _scheduleDisplayRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;

    Timer(const Duration(milliseconds: 16), () async {
      _refreshScheduled = false;
      await _refreshDisplayNow();
    });
  }

  Future<void> _refreshDisplayNow() async {
    if (_workingRgbaBytes == null || _imageWidth == 0 || _imageHeight == 0) {
      return;
    }

    final image = await _rgbaToUiImage(
      _workingRgbaBytes!,
      _imageWidth,
      _imageHeight,
    );

    if (!mounted) return;

    setState(() {
      _displayUiImage = image;
    });
  }

  Future<ui.Image> _rgbaToUiImage(Uint8List rgba, int width, int height) {
    final completer = Completer<ui.Image>();

    ui.decodeImageFromPixels(
      rgba,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (ui.Image image) {
        completer.complete(image);
      },
    );

    return completer.future;
  }

  Future<Uint8List?> _encodeCurrentPaintingToPngBytes() async {
    if (_workingRgbaBytes == null || _imageWidth == 0 || _imageHeight == 0) {
      return null;
    }

    final image = await _rgbaToUiImage(
      Uint8List.fromList(_workingRgbaBytes!),
      _imageWidth,
      _imageHeight,
    );

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    return byteData.buffer.asUint8List();
  }

  Future<void> _persistCurrentPainting() async {
    if (_selectedItem == null) return;

    final pngBytes = await _encodeCurrentPaintingToPngBytes();
    if (pngBytes == null) return;

    _savedPaintingPngByPath[_selectedItem!.paintPath] = pngBytes;
  }

  Future<void> _saveToParentPanel() async {
    if (_selectedItem == null || _isSavingParentCopy) return;

    setState(() {
      _isSavingParentCopy = true;
    });

    try {
      await _persistCurrentPainting();

      final pngBytes = await _encodeCurrentPaintingToPngBytes();
      if (pngBytes == null) {
        _showMessage("Resim kaydedilemedi.");
        return;
      }

      final now = DateTime.now();

      final dateText =
          "${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year} "
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      final imageBase64 = base64Encode(pngBytes);

      await ParentSavedPaintingsStore.save(
        imageBase64: imageBase64,
        title: "${_selectedItem!.title} - $dateText",
      );

      _showMessage("Resim ebeveyn paneline kaydedildi 📸 $dateText");
    } catch (e) {
      _showMessage("Resim kaydedilemedi: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSavingParentCopy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    ParentSavedPaintingsStore.stopAutoCleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF7E6),
        elevation: 0,
        centerTitle: true,
        title: Text(
          _isPaintingMode
              ? (_selectedItem?.title ?? 'Boyama')
              : 'Boyama Resimleri',
          style: const TextStyle(
            color: Color(0xFF5B3A00),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF5B3A00)),
        leading: IconButton(
          onPressed: () async {
            if (_isPaintingMode) {
              await _backToGallery();
            } else {
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: _isPaintingMode ? _buildPaintingView() : _buildGalleryView(),
      ),
    );
  }

  Widget _buildGalleryView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        itemCount: _paintItems.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.82,
        ),
        itemBuilder: (context, index) {
          final item = _paintItems[index];
          final savedPreview = _savedPaintingPngByPath[item.paintPath];

          return GestureDetector(
            onTap: () => _openPainting(item),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 10,
                    offset: Offset(0, 4),
                    color: Color(0x14000000),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: const Color(0xFFF9F9F9),
                          alignment: Alignment.center,
                          child: savedPreview != null
                              ? Image.memory(
                                  savedPreview,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                )
                              : Image.asset(
                                  item.previewPath,
                                  fit: BoxFit.contain,
                                ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3CD),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF5B3A00),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaintingView() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            child: Container(
              key: _canvasKey,
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final canvasSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (details) => _handleTapDown(
                              details.globalPosition,
                              canvasSize,
                            ),
                            onPanStart: (details) => _handlePanStart(
                              details.globalPosition,
                              canvasSize,
                            ),
                            onPanUpdate: (details) => _handlePanUpdate(
                              details.globalPosition,
                              canvasSize,
                            ),
                            onPanEnd: (_) => _handlePanEnd(),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 72),
                              child: _isLoadingBitmap
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : (_displayUiImage == null
                                      ? const Center(
                                          child: Text(
                                            'Resim yüklenemedi',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        )
                                      : RawImage(
                                          image: _displayUiImage,
                                          fit: BoxFit.contain,
                                          filterQuality: FilterQuality.none,
                                        )),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 16,
                          child: _InfoBubble(
                            text: _hasSelectedRegion
                                ? 'Bölge seçildi. Şimdi çizerek boya 🖌️'
                                : 'Önce boyamak istediğin alanın içine dokun 🌈',
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Center(
                            child: Material(
                              color: const Color(0xFFFFD54F),
                              borderRadius: BorderRadius.circular(28),
                              elevation: 3,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(28),
                                onTap: _isSavingParentCopy
                                    ? null
                                    : _saveToParentPanel,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _isSavingParentCopy
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.photo_camera_rounded,
                                              color: Color(0xFF5B3A00),
                                            ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Ebeveyn paneline kaydet',
                                        style: TextStyle(
                                          color: Color(0xFF5B3A00),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 12, 12),
          child: Container(
            width: 96,
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
                    ..._colors.map(
                      (color) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _colorCircle(
                          color: color,
                          isSelected: !_isEraser && _selectedColor == color,
                          onTap: () => _selectColor(color),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 10),
                      child: _toolButton(
                        icon: Icons.tune_rounded,
                        isSelected: false,
                        onTap: _openCustomColorPicker,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _toolButton(
                    icon: Icons.line_weight_rounded,
                    isSelected: false,
                    onTap: _toggleBrushSizes,
                  ),
                  if (_showBrushSizes) ...[
                    const SizedBox(height: 12),
                    ..._brushSizes.map(
                      (size) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _brushSizeButton(
                          size: size,
                          isSelected: _strokeWidth == size,
                          onTap: () => _selectBrushSize(size),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _toolButton(
                    icon: Icons.layers_clear_rounded,
                    isSelected: false,
                    onTap: _clearSelectedRegion,
                  ),
                  const SizedBox(height: 12),
                  _toolButton(
                    icon: Icons.delete_outline,
                    isSelected: false,
                    onTap: _clearCanvas,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
                Colors.pink,
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
        width: isSelected ? 44 : 38,
        height: isSelected ? 44 : 38,
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

  Widget _brushSizeButton({
    required double size,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final dotSize = size + 2;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFD54F) : Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              blurRadius: 4,
              color: Color(0x22000000),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: const BoxDecoration(
              color: Color(0xFF5B3A00),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBubble extends StatelessWidget {
  final String text;

  const _InfoBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF5B3A00),
          ),
        ),
      ),
    );
  }
}

class _Rgba {
  final int r;
  final int g;
  final int b;
  final int a;

  const _Rgba(this.r, this.g, this.b, this.a);
}

class _DecodedBitmap {
  final ui.Image image;
  final Uint8List rgbaBytes;
  final int width;
  final int height;

  const _DecodedBitmap({
    required this.image,
    required this.rgbaBytes,
    required this.width,
    required this.height,
  });
}