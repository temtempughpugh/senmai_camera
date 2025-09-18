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
  // 円形ガイドの状態
  double _circleRadius = 150.0; // 初期半径
  Offset _circleCenter = Offset(0, 0); // 初期位置（画面中央からの相対位置）
  double _baseScale = 1.0; // スケール調整用のベース値
  
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenCenterX = screenSize.width / 2;
    final screenCenterY = screenSize.height / 2;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('範囲を調整'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _resetCircle,
            child: Text(
              'リセット',
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: _confirmCrop,
            child: Text(
              '決定',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Stack(
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
              onScaleStart: (details) {
                // スケール開始時にベース値をリセット
                _baseScale = 1.0;
              },
              onScaleUpdate: (details) {
                setState(() {
                  // 移動処理（1本指でも動作）
                  _circleCenter = Offset(
                    _circleCenter.dx + details.focalPointDelta.dx,
                    _circleCenter.dy + details.focalPointDelta.dy,
                  );
                  
                  // 拡大縮小処理（感度を下げて安定化）
                  if (details.scale != 1.0) {
                    final scaleDelta = details.scale - _baseScale;
                    final newRadius = _circleRadius + (scaleDelta * 50); // 感度を調整
                    _circleRadius = newRadius.clamp(50.0, 300.0);
                    _baseScale = details.scale;
                  }
                });
              },
              child: CustomPaint(
                painter: CircleGuidePainter(
                  center: Offset(screenCenterX + _circleCenter.dx, screenCenterY + _circleCenter.dy),
                  radius: _circleRadius,
                ),
              ),
            ),
          ),
          
          // サイズ調整ボタン
          Positioned(
            right: 20,
            top: 200,
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
                Text(
                  '${_circleRadius.round()}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 5.0,
                        color: Colors.black,
                        offset: Offset(1.0, 1.0),
                      ),
                    ],
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
          
          // 操作説明
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '操作方法',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInstructionItem(Icons.touch_app, 'ドラッグで移動'),
                      _buildInstructionItem(Icons.pinch_outlined, 'ピンチで拡大縮小'),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '円内の範囲が解析対象になります',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }

  void _resetCircle() {
    setState(() {
      _circleRadius = 150.0;
      _circleCenter = Offset(0, 0);
    });
  }

  void _confirmCrop() async {
    try {
      print('=== 円形切り取り開始 ===');
      print('円の中心相対位置: ${_circleCenter}');
      print('円の半径: ${_circleRadius}');
      
      // 元画像を読み込み
      final bytes = await File(widget.imagePath).readAsBytes();
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        Navigator.pop(context, widget.imagePath);
        return;
      }
      
      // 円形範囲を切り取った画像を作成
      final croppedImagePath = await _cropCircularArea(originalImage);
      
      // 切り取った画像のパスを返す
      Navigator.pop(context, croppedImagePath);
    } catch (e) {
      print('円形切り取りエラー: $e');
      Navigator.pop(context, widget.imagePath);
    }
  }
  
  Future<String> _cropCircularArea(img.Image originalImage) async {
    final screenSize = MediaQuery.of(context).size;
    final appBarHeight = AppBar().preferredSize.height + MediaQuery.of(context).padding.top;
    final availableHeight = screenSize.height - appBarHeight;
    
    final imageWidth = originalImage.width;
    final imageHeight = originalImage.height;
    
    print('=== 切り取り計算開始 ===');
    print('元画像サイズ: ${imageWidth}x${imageHeight}');
    print('画面サイズ: ${screenSize.width}x${screenSize.height}');
    print('AppBar高さ: ${appBarHeight}');
    print('利用可能高さ: ${availableHeight}');
    
    // 画像の表示サイズを計算（BoxFit.contain）
    final imageAspectRatio = imageWidth / imageHeight;
    final availableAspectRatio = screenSize.width / availableHeight;
    
    double displayWidth, displayHeight;
    if (imageAspectRatio > availableAspectRatio) {
      displayWidth = screenSize.width;
      displayHeight = screenSize.width / imageAspectRatio;
    } else {
      displayHeight = availableHeight;
      displayWidth = availableHeight * imageAspectRatio;
    }
    
    print('画像表示サイズ: ${displayWidth}x${displayHeight}');
    
    // 画面上の円の中心位置
    final screenCenterX = screenSize.width / 2;
    final screenCenterY = screenSize.height / 2;
    final circleCenterX = screenCenterX + _circleCenter.dx;
    final circleCenterY = screenCenterY + _circleCenter.dy;
    
    print('画面上の円の中心: (${circleCenterX}, ${circleCenterY})');
    print('円の半径: ${_circleRadius}');
    
    // 表示画像の左上位置を計算（AppBarを考慮）
    final displayLeft = (screenSize.width - displayWidth) / 2;
    final displayTop = appBarHeight + (availableHeight - displayHeight) / 2;
    
    print('表示画像の位置: left=${displayLeft}, top=${displayTop}');
    
    // 円の中心を画像座標系に変換
    final imageRelativeX = (circleCenterX - displayLeft) / displayWidth;
    final imageRelativeY = (circleCenterY - displayTop) / displayHeight;
    
    final imageCenterX = imageRelativeX * imageWidth;
    final imageCenterY = imageRelativeY * imageHeight;
    
    // 円の半径を画像座標系に変換
    final imageRadius = (_circleRadius / displayWidth) * imageWidth;
    
    print('=== 画像座標系での円 ===');
    print('画像上の円の中心: (${imageCenterX}, ${imageCenterY})');
    print('画像上の円の半径: ${imageRadius}');
    
    // 切り取り範囲を計算
    final cropLeft = (imageCenterX - imageRadius).round().clamp(0, imageWidth);
    final cropTop = (imageCenterY - imageRadius).round().clamp(0, imageHeight);
    final cropRight = (imageCenterX + imageRadius).round().clamp(0, imageWidth);
    final cropBottom = (imageCenterY + imageRadius).round().clamp(0, imageHeight);
    
    final cropWidth = cropRight - cropLeft;
    final cropHeight = cropBottom - cropTop;
    
    print('=== 切り取り範囲 ===');
    print('left=${cropLeft}, top=${cropTop}, right=${cropRight}, bottom=${cropBottom}');
    print('width=${cropWidth}, height=${cropHeight}');
    
    if (cropWidth <= 0 || cropHeight <= 0) {
      throw Exception('Invalid crop area');
    }
    
    // 正方形領域を切り取り
    final croppedImage = img.copyCrop(
      originalImage,
      x: cropLeft,
      y: cropTop,
      width: cropWidth,
      height: cropHeight,
    );
    
    // 正方形にリサイズ
    final targetSize = math.max(cropWidth, cropHeight).clamp(200, 800);
    final squareImage = img.copyResize(croppedImage, width: targetSize, height: targetSize);
    
    // 円形マスクを適用
    final circularImage = _applyCircularMask(squareImage, imageCenterX - cropLeft, imageCenterY - cropTop, imageRadius);
    
    // 一時ファイルに保存
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
  
  img.Image _applyCircularMask(img.Image image, double centerX, double centerY, double radius) {
    final width = image.width;
    final height = image.height;
    final maskedImage = img.Image.from(image);
    
    // 切り取り後の画像での円の中心位置を再計算
    final circleCenterX = width / 2;
    final circleCenterY = height / 2;
    final circleRadius = math.min(width, height) / 2;
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final distance = math.sqrt(
          math.pow(x - circleCenterX, 2) + math.pow(y - circleCenterY, 2)
        );
        
        if (distance > circleRadius) {
          // 円形範囲外は透明にする
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