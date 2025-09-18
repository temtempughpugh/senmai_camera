import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

class ImageCropScreen extends StatefulWidget {
  final String imagePath;

  const ImageCropScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  _ImageCropScreenState createState() => _ImageCropScreenState();
}

class _ImageCropScreenState extends State<ImageCropScreen> {
  final TransformationController _transformationController = TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('範囲を調整'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _resetTransform,
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
          // 背景を黒に
          Container(
            color: Colors.black,
            width: double.infinity,
            height: double.infinity,
          ),
          
          // ズーム・パン可能な画像
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformationController,
              panEnabled: true,
              scaleEnabled: true,
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          
          // 円形ガイド（オーバーレイ）
          Positioned.fill(
            child: IgnorePointer(
              child: OverflowBox(
                maxWidth: double.infinity,
                maxHeight: double.infinity,
                child: Center(
                  child: Container(
                    width: 500,
                    height: 500,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.red,
                        width: 5,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '解析範囲',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 15.0,
                              color: Colors.black,
                              offset: Offset(2.0, 2.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
                      _buildInstructionItem(Icons.pinch_outlined, 'ピンチでズーム'),
                      _buildInstructionItem(Icons.pan_tool_outlined, 'ドラッグで移動'),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '赤い円内の米粒が解析対象になります',
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

  void _resetTransform() {
    _transformationController.value = Matrix4.identity();
  }

  void _confirmCrop() async {
    try {
      // 変換情報を取得
      final matrix = _transformationController.value;
      
      // 元画像を読み込み
      final bytes = await File(widget.imagePath).readAsBytes();
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        Navigator.pop(context, widget.imagePath);
        return;
      }
      
      // 円形範囲を切り取った画像を作成
      final croppedImagePath = await _cropCircularArea(originalImage, matrix);
      
      // 切り取った画像のパスを返す
      Navigator.pop(context, croppedImagePath);
    } catch (e) {
      print('円形切り取りエラー: $e');
      // エラー時は元画像を返す
      Navigator.pop(context, widget.imagePath);
    }
  }
  
  /// 円形範囲を切り取った画像を作成
  Future<String> _cropCircularArea(img.Image originalImage, Matrix4 transform) async {
    // 画面サイズとガイドサイズを取得
    final screenSize = MediaQuery.of(context).size;
    final guideRadius = 250.0; // 500x500の半径
    
    // 変換行列から実際の画像上の円形範囲を計算
    final imageWidth = originalImage.width;
    final imageHeight = originalImage.height;
    
    // 画面中心を画像座標に変換
    final screenCenterX = screenSize.width / 2;
    final screenCenterY = screenSize.height / 2;
    
    // 変換の逆行列を計算
    final inverseTransform = Matrix4.inverted(transform);
    
    // 画面中心を画像座標に変換
    final imageCenter = inverseTransform.transform3(Vector3(screenCenterX, screenCenterY, 0));
    final imageCenterX = imageCenter.x.clamp(0.0, imageWidth.toDouble());
    final imageCenterY = imageCenter.y.clamp(0.0, imageHeight.toDouble());
    
    // スケールファクターを取得
    final scaleX = transform.getMaxScaleOnAxis();
    final imageRadius = guideRadius / scaleX;
    
    // 切り取り範囲を計算
    final cropSize = (imageRadius * 2).round();
    final cropLeft = (imageCenterX - imageRadius).round().clamp(0, imageWidth);
    final cropTop = (imageCenterY - imageRadius).round().clamp(0, imageHeight);
    final cropRight = (imageCenterX + imageRadius).round().clamp(0, imageWidth);
    final cropBottom = (imageCenterY + imageRadius).round().clamp(0, imageHeight);
    
    // 正方形領域を切り取り
    final croppedImage = img.copyCrop(
      originalImage,
      x: cropLeft,
      y: cropTop,
      width: cropRight - cropLeft,
      height: cropBottom - cropTop,
    );
    
    // 500x500にリサイズ
    final resizedImage = img.copyResize(croppedImage, width: 500, height: 500);
    
    // 円形マスクを適用
    final circularImage = _applyCircularMask(resizedImage);
    
    // 一時ファイルに保存
    final directory = await getTemporaryDirectory();
    final fileName = 'cropped_${DateTime.now().millisecondsSinceEpoch}.png';
    final filePath = '${directory.path}/$fileName';
    
    final pngBytes = img.encodePng(circularImage);
    await File(filePath).writeAsBytes(pngBytes);
    
    print('円形切り取り画像を保存: $filePath');
    print('元画像サイズ: ${imageWidth}x${imageHeight}');
    print('切り取り中心: (${imageCenterX.toStringAsFixed(1)}, ${imageCenterY.toStringAsFixed(1)})');
    print('切り取り半径: ${imageRadius.toStringAsFixed(1)}');
    
    return filePath;
  }
  
  /// 円形マスクを適用
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
          // 円形範囲外は透明にする
          maskedImage.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
        }
      }
    }
    
    return maskedImage;
  }
}