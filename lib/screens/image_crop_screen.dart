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
      
      print('=== 変換行列デバッグ ===');
      print('変換行列: $matrix');
      print('変換行列の各成分:');
      print('  平行移動X: ${matrix.getTranslation().x}');
      print('  平行移動Y: ${matrix.getTranslation().y}');
      print('  スケール: ${matrix.getMaxScaleOnAxis()}');
      
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
    final width = originalImage.width;
    final height = originalImage.height;
    
    // ガイドの円形範囲（画面上での固定値）
    const guideRadius = 250.0; // 500x500の半径
    final screenSize = MediaQuery.of(context).size;
    final screenCenterX = screenSize.width / 2;
    final screenCenterY = screenSize.height / 2;
    
    print('=== 切り取り処理開始 ===');
    print('元画像サイズ: ${width}x${height}');
    print('画面サイズ: ${screenSize.width}x${screenSize.height}');
    print('画面中心（ガイド中心）: (${screenCenterX}, ${screenCenterY})');
    print('ガイド半径: ${guideRadius}');
    
    // InteractiveViewerの変換を正しく解釈
    final scale = transform.getMaxScaleOnAxis();
    final translation = transform.getTranslation();
    
    print('=== 変換情報 ===');
    print('スケール: ${scale}');
    print('平行移動: (${translation.x}, ${translation.y})');
    
    // 画像の表示サイズを計算（fit: BoxFit.contain）
    final imageAspectRatio = width / height;
    final screenAspectRatio = screenSize.width / screenSize.height;
    
    double displayWidth, displayHeight;
    if (imageAspectRatio > screenAspectRatio) {
      // 画像が横長 → 幅を画面幅に合わせる
      displayWidth = screenSize.width;
      displayHeight = screenSize.width / imageAspectRatio;
    } else {
      // 画像が縦長 → 高さを画面高さに合わせる
      displayHeight = screenSize.height;
      displayWidth = screenSize.height * imageAspectRatio;
    }
    
    print('=== 画像表示サイズ（変換前） ===');
    print('表示サイズ: ${displayWidth}x${displayHeight}');
    print('画像アスペクト比: ${imageAspectRatio}');
    print('画面アスペクト比: ${screenAspectRatio}');
    
    // 変換後の表示サイズ
    final scaledDisplayWidth = displayWidth * scale;
    final scaledDisplayHeight = displayHeight * scale;
    
    // 変換なしの場合の画像中心位置
    final originalImageCenterX = screenSize.width / 2;
    final originalImageCenterY = screenSize.height / 2;
    
    // 変換後の画像中心位置
    final transformedImageCenterX = originalImageCenterX + translation.x;
    final transformedImageCenterY = originalImageCenterY + translation.y;
    
    print('=== 変換後の画像中心 ===');
    print('変換後表示サイズ: ${scaledDisplayWidth}x${scaledDisplayHeight}');
    print('変換後画像中心: (${transformedImageCenterX}, ${transformedImageCenterY})');
    
    // ガイド中心から変換後画像中心への相対位置
    final relativeX = screenCenterX - transformedImageCenterX;
    final relativeY = screenCenterY - transformedImageCenterY;
    
    print('=== 相対位置 ===');
    print('ガイド中心からの相対位置: (${relativeX}, ${relativeY})');
    
    // 相対位置を画像座標系に変換
    final imageRelativeX = (relativeX / scaledDisplayWidth) * width;
    final imageRelativeY = (relativeY / scaledDisplayHeight) * height;
    
    // 元画像上でのガイド中心位置
    final imageCenterX = width / 2 + imageRelativeX;
    final imageCenterY = height / 2 + imageRelativeY;
    
    // ガイド半径を元画像座標系に変換
    final imageRadiusX = (guideRadius / scaledDisplayWidth) * width;
    final imageRadiusY = (guideRadius / scaledDisplayHeight) * height;
    final imageRadius = math.min(imageRadiusX, imageRadiusY); // より小さい方を使用
    
    print('=== 元画像座標系での位置 ===');
    print('画像相対位置: (${imageRelativeX}, ${imageRelativeY})');
    print('画像上の中心: (${imageCenterX}, ${imageCenterY})');
    print('画像上の半径: ${imageRadius}');
    
    // 切り取り範囲を計算
    final cropLeft = (imageCenterX - imageRadius).round().clamp(0, width);
    final cropTop = (imageCenterY - imageRadius).round().clamp(0, height);
    final cropRight = (imageCenterX + imageRadius).round().clamp(0, width);
    final cropBottom = (imageCenterY + imageRadius).round().clamp(0, height);
    
    final cropWidth = cropRight - cropLeft;
    final cropHeight = cropBottom - cropTop;
    
    print('=== 切り取り範囲 ===');
    print('left=${cropLeft}, top=${cropTop}, right=${cropRight}, bottom=${cropBottom}');
    print('width=${cropWidth}, height=${cropHeight}');
    
    // 切り取り範囲が有効かチェック
    if (cropWidth <= 0 || cropHeight <= 0) {
      print('エラー: 切り取り範囲が無効です');
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
    
    print('切り取り完了: ${croppedImage.width}x${croppedImage.height}');
    
    // 正方形にリサイズ（長辺に合わせる）
    final maxSize = math.max(cropWidth, cropHeight);
    final squareImage = img.copyResize(croppedImage, width: maxSize, height: maxSize);
    
    // 円形マスクを適用
    final circularImage = _applyCircularMask(squareImage);
    
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