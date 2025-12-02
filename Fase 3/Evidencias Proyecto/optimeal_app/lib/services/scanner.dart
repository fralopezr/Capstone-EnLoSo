// lib/scanner.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class Scanner extends StatefulWidget {
  const Scanner({super.key});

  @override
  State<Scanner> createState() => _ScannerState();
}

class _ScannerState extends State<Scanner> with SingleTickerProviderStateMixin {
  late CameraController _cameraController;
  Future<void>? _initializeControllerFuture;

  final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  bool _isProcessing = false;
  int _frameSkip = 0;
  String _status = 'Buscando tabla nutricional…';
  bool _detected = false;

  String _lastSnippet = '';
  int _detectionConfidence = 0;

  Rect? _roiImageSpace;
  Rect? _prevRoiImageSpace;
  int _stableFrames = 0;
  bool _autoCaptured = false;

  CameraImage? _lastFrame;

  late final AnimationController _laserCtrl;

  static const int _STABLE_N = 3;
  static const double _TOL_PX = 35.0;

  @override
  void initState() {
    super.initState();
    _laserCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _initializeCamera();
  }

  @override
  void dispose() {
    try {
      if (_cameraController.value.isStreamingImages) {
        _cameraController.stopImageStream();
      }
    } catch (_) {}
    _cameraController.dispose();
    _textRecognizer.close();
    _laserCtrl.dispose();
    super.dispose();
  }

  InputImageRotation _rotationFromSensor(int rotationDegrees) {
    switch (rotationDegrees) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final int yRowStride = yPlane.bytesPerRow;
    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

    final int ySize = width * height;
    final int uvSize = (width * height) >> 1;
    final Uint8List out = Uint8List(ySize + uvSize);

    final Uint8List yBytes = yPlane.bytes;
    int outIndex = 0;
    for (int row = 0; row < height; row++) {
      final int srcOffset = row * yRowStride;
      out.setRange(outIndex, outIndex + width, yBytes, srcOffset);
      outIndex += width;
    }

    final Uint8List uBytes = uPlane.bytes;
    final Uint8List vBytes = vPlane.bytes;

    int uvOutOffset = ySize;
    final int halfH = height >> 1;
    final int halfW = width >> 1;

    for (int row = 0; row < halfH; row++) {
      for (int col = 0; col < halfW; col++) {
        final int uIndex = row * uvRowStride + col * uvPixelStride;
        final int vIndex = row * uvRowStride + col * uvPixelStride;
        out[uvOutOffset++] = vBytes[vIndex];
        out[uvOutOffset++] = uBytes[uIndex];
      }
    }
    return out;
  }

  img.Image _yuv420ToRgbImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    final int yRowStride = yPlane.bytesPerRow;
    final int uRowStride = uPlane.bytesPerRow;
    final int vRowStride = vPlane.bytesPerRow;

    final int uPixelStride = uPlane.bytesPerPixel ?? 1;
    final int vPixelStride = vPlane.bytesPerPixel ?? 1;

    final Uint8List y = yPlane.bytes;
    final Uint8List u = uPlane.bytes;
    final Uint8List v = vPlane.bytes;

    final img.Image out = img.Image(width: width, height: height);

    for (int yRow = 0; yRow < height; yRow++) {
      final int uvRow = yRow >> 1;
      for (int x = 0; x < width; x++) {
        final int yIndex = yRow * yRowStride + x;
        final int uvCol = x >> 1;
        final int uIndex = uvRow * uRowStride + uvCol * uPixelStride;
        final int vIndex = uvRow * vRowStride + uvCol * vPixelStride;

        final int Y = y[yIndex] & 0xFF;
        final int U = u[uIndex] & 0xFF;
        final int V = v[vIndex] & 0xFF;

        final int c = Y - 16;
        final int d = U - 128;
        final int e = V - 128;

        int r = (298 * c + 409 * e + 128) >> 8;
        int g = (298 * c - 100 * d - 208 * e + 128) >> 8;
        int b = (298 * c + 516 * d + 128) >> 8;

        if (r < 0) r = 0;
        else if (r > 255) r = 255;
        if (g < 0) g = 0;
        else if (g > 255) g = 255;
        if (b < 0) b = 0;
        else if (b > 255) b = 255;

        out.setPixelRgb(x, yRow, r, g, b);
      }
    }
    return out;
  }

  // ========= Heurística de detección =========

  final Set<String> _headerKeywords = {
    'información nutricional',
    'informacion nutricional',
    'nutrition facts',
    'valor nutricional',
    'valores nutricionales',
    'declaración nutricional',
    'tabla nutricional',
    'nutrition information',
  };

  final Set<String> _nutrientKeywords = {
    'energía','energia','energy','calorías','calorias','calories','kcal','kj',
    'proteínas','proteinas','proteins','protein','grasas','grasa','fats','fat',
    'lípidos','lipidos','saturadas','saturada','saturated','monoinsaturadas',
    'monoinsaturada','monoinsat','poliinsaturadas','poliinsaturada','polinsat',
    'trans','carbohidratos','carbohydrates','hidratos','carbs','azúcares',
    'azucares','sugars','sugar','fibra','fiber','fibre','sodio','sodium','sal',
    'salt','colesterol','cholesterol','calcio','calcium','hierro','iron',
    'potasio','potassium','fósforo','fosforo','phosphorus','vitamina','vitamin',
    'porción','porcion','serving',
  };

  final RegExp _numWithUnit = RegExp(
    r'\b\d{1,4}([.,]\d{1,2})?\s?(kcal|kj|g|mg|mcg|µg|%|ml)\b',
    caseSensitive: false,
  );

  bool _isNutritionHeader(String text) {
    final lower = text.toLowerCase().trim();
    return _headerKeywords.any((kw) => lower.contains(kw));
  }

  bool _isNutrient(String text) {
    final lower = text.toLowerCase().trim();
    return _nutrientKeywords.any((kw) => lower.contains(kw));
  }

  bool _hasNutritionalNumber(String text) => _numWithUnit.hasMatch(text);

  int _scoreTextLine(TextLine line) {
    final text = line.text.toLowerCase().trim();
    int score = 0;
    if (_isNutritionHeader(text)) score += 50;
    if (_isNutrient(text)) score += 20;
    if (_hasNutritionalNumber(text)) score += 15;
    if (text.length >= 5 && text.length <= 60) score += 5;
    return score;
  }

  List<_NutritionBlock> _findNutritionBlocks(
    List<TextLine> lines, double frameW, double frameH,
  ) {
    if (lines.isEmpty) return [];

    lines.sort((a, b) => a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy));

    final List<_NutritionBlock> blocks = [];
    _NutritionBlock? currentBlock;

    for (final line in lines) {
      final score = _scoreTextLine(line);
      if (score < 5) continue;

      final rect = line.boundingBox;

      if (currentBlock == null ||
          (currentBlock.bounds != null &&
              (rect.top - currentBlock.bounds!.bottom) > rect.height * 6.0)) {
        currentBlock = _NutritionBlock();
        blocks.add(currentBlock);
      }

      currentBlock.lines.add(line);
      currentBlock.totalScore += score;

      if (currentBlock.bounds == null) {
        currentBlock.bounds = rect;
      } else {
        final b = currentBlock.bounds!;
        currentBlock.bounds = Rect.fromLTRB(
          math.min(b.left, rect.left),
          math.min(b.top, rect.top),
          math.max(b.right, rect.right),
          math.max(b.bottom, rect.bottom),
        );
      }

      if (_isNutritionHeader(line.text)) currentBlock.hasHeader = true;
      if (_isNutrient(line.text)) currentBlock.nutrientCount++;
      if (_hasNutritionalNumber(line.text)) currentBlock.numberCount++;
    }

    return blocks.where((block) {
      if (block.lines.length < 3) return false;
      if (!block.hasHeader && block.nutrientCount < 2) return false;
      if (block.numberCount < 2) return false;
      return true;
    }).toList();
  }

  Rect? _findBestNutritionROI(List<TextLine> lines, double frameW, double frameH) {
    final blocks = _findNutritionBlocks(lines, frameW, frameH);
    if (blocks.isEmpty) return null;

    blocks.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    Rect roi = blocks.first.bounds!;
    final bestBlock = blocks.first;

    double maxBottom = roi.bottom;
    double minLeft = roi.left;
    double maxRight = roi.right;

    for (final line in lines) {
      final r = line.boundingBox;
      if (r.top >= roi.top &&
          (r.top - maxBottom) < (r.height * 5.0) &&
          (_hasNutritionalNumber(line.text) || _isNutrient(line.text))) {
        final overlap = r.right > roi.left && r.left < roi.right;
        if (overlap) {
          maxBottom = math.max(maxBottom, r.bottom);
          minLeft = math.min(minLeft, r.left);
          maxRight = math.max(maxRight, r.right);
        }
      }
    }

    roi = Rect.fromLTRB(minLeft, roi.top, maxRight, maxBottom);

    final double padX = math.max(roi.width * 0.08, 16.0);
    final double padTop = math.max(roi.height * 0.04, 8.0);
    final double padBottom = math.max(roi.height * 0.25, 24.0);

    roi = Rect.fromLTRB(
      (roi.left - padX).clamp(0.0, frameW),
      (roi.top - padTop).clamp(0.0, frameH),
      (roi.right + padX).clamp(0.0, frameW),
      (roi.bottom + padBottom).clamp(0.0, frameH),
    );

    _detectionConfidence =
        ((bestBlock.totalScore / 8) + (bestBlock.lines.length * 2))
            .clamp(0, 100)
            .round();

    return roi;
  }

  // ========================================

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _initializeControllerFuture = _cameraController.initialize();
      await _initializeControllerFuture;
      if (!mounted) return;
      setState(() {});
      _cameraController.startImageStream(_onFrame);
    } catch (e) {
      debugPrint('Error inicializando cámara: $e');
      if (mounted) setState(() => _status = 'Error cámara: $e');
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_isProcessing || _autoCaptured) return;
    _frameSkip = (_frameSkip + 1) % 3;
    if (_frameSkip != 0) return;

    _isProcessing = true;

    try {
      _lastFrame = image;

      final nv21 = _yuv420ToNv21(image);
      final rotationDeg = _cameraController.description.sensorOrientation;

      final double frameW = (rotationDeg == 90 || rotationDeg == 270)
          ? image.height.toDouble()
          : image.width.toDouble();
      final double frameH = (rotationDeg == 90 || rotationDeg == 270)
          ? image.width.toDouble()
          : image.height.toDouble();

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: _rotationFromSensor(rotationDeg),
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: nv21, metadata: metadata);
      final recognized = await _textRecognizer.processImage(inputImage);

      final List<TextLine> lines = [];
      for (final b in recognized.blocks) {
        for (final l in b.lines) {
          lines.add(l);
        }
      }

      final Rect? union = _findBestNutritionROI(lines, frameW, frameH);

      String snippet = recognized.text.replaceAll('\n', ' ');
      if (snippet.length > 100) snippet = '${snippet.substring(0, 100)}…';

      bool stableNow = false;
      if (union != null) {
        if (_prevRoiImageSpace != null) {
          final dx = (union.left - _prevRoiImageSpace!.left).abs();
          final dy = (union.top - _prevRoiImageSpace!.top).abs();
          final dw = (union.width - _prevRoiImageSpace!.width).abs();
          final dh = (union.height - _prevRoiImageSpace!.height).abs();
          stableNow = dx < _TOL_PX && dy < _TOL_PX && dw < _TOL_PX && dh < _TOL_PX;
        }
        _prevRoiImageSpace = union;
        _stableFrames = stableNow ? (_stableFrames + 1) : 0;
      } else {
        _prevRoiImageSpace = null;
        _stableFrames = 0;
        _detectionConfidence = 0;
      }

      if (union != null &&
          _stableFrames >= _STABLE_N &&
          _detectionConfidence >= 60 &&
          !_autoCaptured) {
        _autoCaptured = true;
        _roiImageSpace = union;
        unawaited(_autoCropFromLastFrame(_roiImageSpace!));
      } else {
        if (!mounted) return;
        setState(() {
          _detected = union != null && _detectionConfidence >= 40;

          if (_detected) {
            _status =
                'Tabla detectada ${_detectionConfidence}% (mantén fijo $_stableFrames/$_STABLE_N)';
          } else if (union != null) {
            _status = 'Detectando... ${_detectionConfidence}%';
          } else {
            _status = 'Buscando tabla nutricional…';
          }

          if (_detected && snippet.isNotEmpty) _lastSnippet = snippet;
          _roiImageSpace = union;
        });
      }
    } catch (e) {
      debugPrint('Error procesando frame: $e');
      if (mounted) setState(() => _status = 'Error procesando frame');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _autoCropFromLastFrame(Rect roiImageSpace) async {
    try {
      final frame = _lastFrame;
      if (frame == null) throw Exception('No hay frame para recortar');

      img.Image rgb = _yuv420ToRgbImage(frame);

      final rotationDeg = _cameraController.description.sensorOrientation;
      if (rotationDeg == 90) {
        rgb = img.copyRotate(rgb, angle: 90);
      } else if (rotationDeg == 180) {
        rgb = img.copyRotate(rgb, angle: 180);
      } else if (rotationDeg == 270) {
        rgb = img.copyRotate(rgb, angle: 270);
      }

      final int x = roiImageSpace.left.round().clamp(0, rgb.width - 1);
      final int y = roiImageSpace.top.round().clamp(0, rgb.height - 1);
      final int w = roiImageSpace.width.round().clamp(1, rgb.width - x);
      final int h = roiImageSpace.height.round().clamp(1, rgb.height - y);

      final img.Image cropped = img.copyCrop(rgb, x: x, y: y, width: w, height: h);
      final Uint8List bytes = Uint8List.fromList(img.encodeJpg(cropped, quality: 95));

      if (!mounted) return;
      setState(() => _status = '¡Tabla capturada!');

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Tabla nutricional capturada'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.memory(bytes),
                const SizedBox(height: 12),
                Text('Confianza: $_detectionConfidence%'),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Descartar'),
              onPressed: () {
                Navigator.of(context).pop(); // cierra diálogo
                setState(() {
                  _autoCaptured = false;
                  _stableFrames = 0;
                });
              },
            ),
            FilledButton(
              child: const Text('Usar esta imagen'),
              onPressed: () {
                Navigator.of(context).pop();        // cierra diálogo
                Navigator.of(context).pop(bytes);    // ✔ devuelve bytes al caller
              },
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error al recortar: $e');
      if (mounted) setState(() => _status = 'Error al recortar');
    } finally {
      if (mounted) {
        _autoCaptured = false;
        _stableFrames = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializeControllerFuture == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escáner nutricional'),
        backgroundColor: Colors.black87,
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final preview = GestureDetector(
            onTapDown: (d) {
              final size = MediaQuery.of(context).size;
              final Offset p = Offset(
                d.localPosition.dx / size.width,
                d.localPosition.dy / size.height,
              );
              _cameraController.setFocusPoint(p);
              _cameraController.setExposurePoint(p);
            },
            child: CameraPreview(_cameraController),
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              preview,
              AnimatedBuilder(
                animation: _laserCtrl,
                builder: (_, __) => ScannerOverlay(
                  progress: _laserCtrl.value,
                  confidence: _detectionConfidence,
                  roiPreviewMapper: (Size size) {
                    if (_roiImageSpace == null) return null;

                    final rotationDeg = _cameraController.description.sensorOrientation;
                    final ps = _cameraController.value.previewSize!;
                    final double frameW = (rotationDeg == 90 || rotationDeg == 270)
                        ? ps.height.toDouble()
                        : ps.width.toDouble();
                    final double frameH = (rotationDeg == 90 || rotationDeg == 270)
                        ? ps.width.toDouble()
                        : ps.height.toDouble();

                    final double scaleX = size.width / frameW;
                    final double scaleY = size.height / frameH;

                    final r = _roiImageSpace!;
                    return Rect.fromLTWH(
                      r.left * scaleX,
                      r.top * scaleY,
                      r.width * scaleX,
                      r.height * scaleY,
                    );
                  },
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _detected ? Colors.green.withOpacity(0.9) : Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _detected ? Icons.check_circle : Icons.search,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _status,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_lastSnippet.isNotEmpty)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _lastSnippet,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              if (_roiImageSpace != null && _detectionConfidence >= 40)
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: FloatingActionButton.extended(
                    backgroundColor: Colors.green,
                    onPressed: _autoCaptured
                        ? null
                        : () {
                            final roi = _roiImageSpace;
                            if (roi != null) {
                              _autoCaptured = true;
                              unawaited(_autoCropFromLastFrame(roi));
                            }
                          },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capturar'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NutritionBlock {
  List<TextLine> lines = [];
  Rect? bounds;
  int totalScore = 0;
  bool hasHeader = false;
  int nutrientCount = 0;
  int numberCount = 0;
}

class ScannerOverlay extends StatelessWidget {
  final double progress;
  final int confidence;
  final Rect? Function(Size size) roiPreviewMapper;

  const ScannerOverlay({
    super.key,
    required this.progress,
    required this.confidence,
    required this.roiPreviewMapper,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final boxW = w * 0.80;
        final boxH = boxW * 0.85;
        final left = (w - boxW) / 2;
        final top = (h - boxH) / 2;
        final guide = Rect.fromLTWH(left, top, boxW, boxH);

        final roi = roiPreviewMapper(Size(w, h));

        return CustomPaint(
          size: Size(w, h),
          painter: _ScannerPainter(
            guide: guide,
            roi: roi,
            confidence: confidence,
            progress: progress,
          ),
        );
      },
    );
  }
}

class _ScannerPainter extends CustomPainter {
  final Rect guide;
  final Rect? roi;
  final int confidence;
  final double progress;

  _ScannerPainter({
    required this.guide,
    required this.roi,
    required this.confidence,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = Colors.black.withOpacity(0.5);
    final clear = Paint()..blendMode = BlendMode.clear;

    final layer = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRRect(RRect.fromRectXY(guide, 16, 16));

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawPath(layer, bg);
    canvas.drawPath(hole, clear);
    canvas.restore();

    final border = Paint()
      ..color = const Color(0xFF00E676)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(RRect.fromRectXY(guide, 16, 16), border);

    final y = guide.top + guide.height * progress;
    final laser = Paint()
      ..color = const Color(0xFF00E676).withOpacity(0.8)
      ..strokeWidth = 2.0;
    canvas.drawLine(
      Offset(guide.left + 10, y),
      Offset(guide.right - 10, y),
      laser,
    );

    if (roi != null && confidence >= 40) {
      final Color roiColor = confidence >= 70
          ? const Color(0xFF00E676)
          : confidence >= 55
              ? const Color(0xFFFFC107)
              : Colors.orange;

      final roiPaint = Paint()
        ..color = roiColor.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;

      canvas.drawRRect(RRect.fromRectXY(roi!, 12, 12), roiPaint);

      final double cornerLength = 25.0;
      final cornerPaint = Paint()
        ..color = roiColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round;

      // ❌ SIN const Offset(...) porque cornerLength es variable
      canvas.drawLine(roi!.topLeft,     roi!.topLeft     + Offset(cornerLength, 0),  cornerPaint);
      canvas.drawLine(roi!.topLeft,     roi!.topLeft     + Offset(0, cornerLength),  cornerPaint);
      canvas.drawLine(roi!.topRight,    roi!.topRight    + Offset(-cornerLength, 0), cornerPaint);
      canvas.drawLine(roi!.topRight,    roi!.topRight    + Offset(0, cornerLength),  cornerPaint);

      canvas.drawLine(roi!.bottomLeft,  roi!.bottomLeft  + Offset(cornerLength, 0),  cornerPaint);
      canvas.drawLine(roi!.bottomLeft,  roi!.bottomLeft  + Offset(0, -cornerLength), cornerPaint);
      canvas.drawLine(roi!.bottomRight, roi!.bottomRight + Offset(-cornerLength, 0), cornerPaint);
      canvas.drawLine(roi!.bottomRight, roi!.bottomRight + Offset(0, -cornerLength), cornerPaint);

      if (confidence >= 50) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '$confidence%',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              backgroundColor: roiColor.withOpacity(0.8),
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();

        final textX = roi!.left + 8;
        final textY = roi!.top - 24;

        if (textY > 0) {
          textPainter.paint(canvas, Offset(textX, textY));
        }
      }
    }

    if (roi == null || confidence < 40) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'Apunta a la tabla nutricional',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout(maxWidth: guide.width - 40);

      final textX = guide.left + (guide.width - textPainter.width) / 2;
      final textY = guide.top + (guide.height - textPainter.height) / 2;

      final textBg = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          textX - 12,
          textY - 8,
          textPainter.width + 24,
          textPainter.height + 16,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        textBg,
        Paint()..color = Colors.black.withOpacity(0.6),
      );

      textPainter.paint(canvas, Offset(textX, textY));
    }
  }

  @override
  bool shouldRepaint(covariant _ScannerPainter old) =>
      old.progress != progress ||
      old.guide != guide ||
      old.roi != roi ||
      old.confidence != confidence;
}
