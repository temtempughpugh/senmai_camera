import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageCropScreen extends StatefulWidget {
  final String imagePath;

  const ImageCropScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  _ImageCropScreenState createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  // 円形ガイドの状態（画面表示座標系）
  double _circleRadius = 150.0;
  Offset _circleCenter = Offset(0, 0); // 画面中央からの相対位置
  
  // 画像情報
  img.Image? _originalImage;
  Size? _imageDisplaySize;
  Offset? _imageDisplayOffset;
  
  @override
  void initState() {
    super.initState();
    _loadImageInfo();
  }
  
  Future<void> _loadImageInfo() async {
    // 元画像を読み込み
    final bytes = await File(widget.imagePath).readAsBytes();
    _originalImage = img.decodeImage(bytes);
    
    if (_originalImage != null) {
      print('元画像サイズ: ${_originalImage!.width}x${_originalImage!.height}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final appBarHeight = AppBar().preferredSize.height + MediaQuery.of(context).padding.top;
    final availableHeight = screenSize.height - appBarHeight;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('範囲を調整'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _resetCircle,
            child: Text('リセット', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: _confirmCrop,
            child: Text('決定', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // 画像表示情報を計算
          _calculateImageDisplayInfo(constraints);
          
          return Stack(
            children: [
              // 背景画像
              Positioned.fill(
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.contain,
                ),
              ),
              
              // 調整可能な円形ガイド
              Positioned.fill(
                child: GestureDetector(
                  onScaleStart: (details) {},
                  onScaleUpdate: (details) {
                    setState(() {
                      // 移動処理
                      _circleCenter = Offset(
                        _circleCenter.dx + details.focalPointDelta.dx,
                        _circleCenter.dy + details.focalPointDelta.dy,
                      );
                      
                      // 拡大縮小処理
                      if (details.scale != 1.0) {
                        final scaleDelta = (details.scale - 1.0) * 50;
                        _circleRadius = (_circleRadius + scaleDelta).clamp(50.0, 300.0);
                      }
                    });
                  },
                  child: CustomPaint(
                    painter: CircleGuidePainter(
                      center: Offset(
                        constraints.maxWidth / 2 + _circleCenter.dx,
                        constraints.maxHeight / 2 + _circleCenter.dy,
                      ),
                      radius: _circleRadius,
                    ),
                  ),
                ),
              ),
              
              // サイズ調整ボタン
              Positioned(
                right: 20,
                top: 100,
                child: Column(
                  children: [
                    FloatingActionButton(
                      mini: true,
                      onPressed: () {
                        setState(() {
                          _circleRadius = (_circleRadius + 20).clamp(50.0, 300.0);
                        });
                      },
                      child: Icon(Icons.add),
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_circleRadius.round()}',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    SizedBox(height: 8),
                    FloatingActionButton(
                      mini: true,
                      onPressed: () {
                        setState(() {
                          _circleRadius = (_circleRadius - 20).clamp(50.0, 300.0);
                        });
                      },
                      child: Icon(Icons.remove),
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                    ),
                  ],
                ),
              ),
              
              // デバッグ情報表示
              if (_imageDisplaySize != null && _imageDisplayOffset != null)
                Positioned(
                  left: 20,
                  top: 100,
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('表示: ${_imageDisplaySize!.width.round()}x${_imageDisplaySize!.height.round()}',
                             style: TextStyle(color: Colors.white, fontSize: 10)),
                        Text('位置: (${_imageDisplayOffset!.dx.round()}, ${_imageDisplayOffset!.dy.round()})',
                             style: TextStyle(color: Colors.white, fontSize: 10)),
                        Text('ガイド: (${_circleCenter.dx.round()}, ${_circleCenter.dy.round()})',
                             style: TextStyle(color: Colors.white, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
  
  void _calculateImageDisplayInfo(BoxConstraints constraints) {
    if (_originalImage == null) return;
    
    final imageWidth = _originalImage!.width.toDouble();
    final imageHeight = _originalImage!.height.toDouble();
    final containerWidth = constraints.maxWidth;
    final containerHeight = constraints.maxHeight;
    
    // BoxFit.containの計算
    final imageAspectRatio = imageWidth / imageHeight;
    final containerAspectRatio = containerWidth / containerHeight;
    
    if (imageAspectRatio > containerAspectRatio) {
      // 横長画像: 幅がコンテナ幅に合う
      _imageDisplaySize = Size(containerWidth, containerWidth / imageAspectRatio);
      _imageDisplayOffset = Offset(0, (containerHeight - _imageDisplaySize!.height) / 2);
    } else {
      // 縦長画像: 高さがコンテナ高さに合う
      _imageDisplaySize = Size(containerHeight * imageAspectRatio, containerHeight);
      _imageDisplayOffset = Offset((containerWidth - _imageDisplaySize!.width) / 2, 0);
    }
  }

  void _resetCircle() {
    setState(() {
      _circleRadius = 150.0;
      _circleCenter = Offset(0, 0);
    });
  }

  void _confirmCrop() async {
    if (_originalImage == null || _imageDisplaySize == null || _imageDisplayOffset == null) {
      Navigator.pop(context, widget.imagePath);
      return;
    }
    
    try {
      print('=== 直接切り取り開始 ===');
      
      // 画面表示座標系 → 元画像座標系の変換
      final croppedImagePath = await _cropFromOriginalImage();
      
      Navigator.pop(context, croppedImagePath);
      
    } catch (e) {
      print('切り取りエラー: $e');
      Navigator.pop(context, widget.imagePath);
    }
  }
  
  Future<String> _cropFromOriginalImage() async {
    final screenSize = MediaQuery.of(context).size;
    final appBarHeight = AppBar().preferredSize.height + MediaQuery.of(context).padding.top;
    final availableHeight = screenSize.height - appBarHeight;
    
    // 画面表示座標系でのガイド位置
    final screenGuideX = screenSize.width / 2 + _circleCenter.dx;
    final screenGuideY = availableHeight / 2 + _circleCenter.dy;
    
    print('=== 座標変換情報 ===');
    print('画面ガイド位置: (${screenGuideX.toStringAsFixed(1)}, ${screenGuideY.toStringAsFixed(1)})');
    print('画面ガイド半径: ${_circleRadius.toStringAsFixed(1)}');
    print('画像表示サイズ: ${_imageDisplaySize!.width.toStringAsFixed(1)}x${_imageDisplaySize!.height.toStringAsFixed(1)}');
    print('画像表示位置: (${_imageDisplayOffset!.dx.toStringAsFixed(1)}, ${_imageDisplayOffset!.dy.toStringAsFixed(1)})');
    
    // 画像表示エリア内での相対座標（0.0-1.0）
    final relativeX = (screenGuideX - _imageDisplayOffset!.dx) / _imageDisplaySize!.width;
    final relativeY = (screenGuideY - _imageDisplayOffset!.dy) / _imageDisplaySize!.height;
    final relativeRadius = _circleRadius / math.min(_imageDisplaySize!.width, _imageDisplaySize!.height);
    
    print('相対座標: (${relativeX.toStringAsFixed(3)}, ${relativeY.toStringAsFixed(3)})');
    print('相対半径: ${relativeRadius.toStringAsFixed(3)}');
    
    // 元画像座標系での位置
    final imageGuideX = relativeX * _originalImage!.width;
    final imageGuideY = relativeY * _originalImage!.height;
    final imageRadius = relativeRadius * math.min(_originalImage!.width, _originalImage!.height);
    
    print('元画像ガイド位置: (${imageGuideX.toStringAsFixed(1)}, ${imageGuideY.toStringAsFixed(1)})');
    print('元画像ガイド半径: ${imageRadius.toStringAsFixed(1)}');
    
    // 切り取り範囲を計算
    final cropLeft = (imageGuideX - imageRadius).round().clamp(0, _originalImage!.width);
    final cropTop = (imageGuideY - imageRadius).round().clamp(0, _originalImage!.height);
    final cropRight = (imageGuideX + imageRadius).round().clamp(0, _originalImage!.width);
    final cropBottom = (imageGuideY + imageRadius).round().clamp(0, _originalImage!.height);
    
    final cropWidth = cropRight - cropLeft;
    final cropHeight = cropBottom - cropTop;
    
    print('=== 切り取り範囲 ===');
    print('left=$cropLeft, top=$cropTop, right=$cropRight, bottom=$cropBottom');
    print('width=$cropWidth, height=$cropHeight');
    
    if (cropWidth <= 0 || cropHeight <= 0) {
      throw Exception('切り取り範囲が無効');
    }
    
    // 元画像から切り取り
    final croppedImage = img.copyCrop(
      _originalImage!,
      x: cropLeft,
      y: cropTop,
      width: cropWidth,
      height: cropHeight,
    );
    
    // 解析用サイズにリサイズ
    final targetSize = 512;
    final resizedImage = img.copyResize(croppedImage, width: targetSize, height: targetSize);
    
    // 円形マスクを適用
    final circularImage = _applyCircularMask(resizedImage);
    
    // 保存
    final directory = await getTemporaryDirectory();
    final fileName = 'cropped_${DateTime.now().millisecondsSinceEpoch}.png';
    final filePath = '${directory.path}/$fileName';
    
    final pngBytes = img.encodePng(circularImage);
    await File(filePath).writeAsBytes(pngBytes);
    
    print('=== 保存完了 ===');
    print('ファイルパス: $filePath');
    print('最終画像サイズ: ${circularImage.width}x${circularImage.height}');
    
    return filePath;
  }
  
  img.Image _applyCircularMask(img.Image image) {
    final width = image.width;
    final height = image.height;
    final centerX = width / 2;
    final centerY = height / 2;
    final radius = math.min(width, height) / 2;
    
    final maskedImage = img.Image.from(image);
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final distance = math.sqrt(
          math.pow(x - centerX, 2) + math.pow(y - centerY, 2)
        );
        
        if (distance > radius) {
          maskedImage.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
        }
      }
    }
    
    return maskedImage;
  }
}

class CircleGuidePainter extends CustomPainter {
  final Offset center;
  final double radius;
  
  CircleGuidePainter({required this.center, required this.radius});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    // 円形ガイドを描画
    canvas.drawCircle(center, radius, paint);
    
    // 中心点を描画
    final centerPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, 5.0, centerPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}