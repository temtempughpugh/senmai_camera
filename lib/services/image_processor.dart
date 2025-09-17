import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/analysis_result.dart';

class ImageProcessorService {
  static final ImageProcessorService instance = ImageProcessorService._init();
  ImageProcessorService._init();

  /// 画像を解析して吸水率を予測（相対比較版）
  Future<AnalysisResult> analyzeImage(String imagePath) async {
    try {
      // 画像ファイルを読み込み
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      
      // 画像をデコード
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('画像の読み込みに失敗しました');
      }

      // 処理しやすいサイズに調整
      final resizedImage = img.copyResize(image, width: 512, height: 512);
      
      // 実際の画像解析を実行
      final analysisData = await _performRealImageAnalysis(resizedImage, imagePath);
      
      // 吸水率を計算
      final predictedRate = _calculateAbsorptionRate(analysisData);
      
      // 解析結果を作成
      return AnalysisResult(
        imagePath: imagePath,
        predictedRate: predictedRate,
        areaPixels: analysisData['ricePixels'],
        avgBrightness: analysisData['avgBrightness'],
        brightnessStd: analysisData['brightnessStd'],
        whiteAreaRatio: analysisData['whiteAreaRatio'],
        timestamp: DateTime.now(),
      );
    } catch (e) {
      throw Exception('画像解析エラー: $e');
    }
  }

  /// 実際の画像解析処理（相対比較アプローチ）
  Future<Map<String, dynamic>> _performRealImageAnalysis(img.Image image, String originalPath) async {
    final width = image.width;
    final height = image.height;
    
    // 解析結果保存用の画像を作成
    final debugImage = img.Image.from(image);
    
    var totalBrightness = 0.0;
    var ricePixelCount = 0;
    final brightnessList = <double>[];
    
    // Phase 1: 米粒領域を抽出（元の方法）
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final brightness = (0.299 * r + 0.587 * g + 0.114 * b);
        
        // 基本的な米粒判定（元の方法）
        if (brightness > 80 && _isRicePixel(r, g, b)) {
          ricePixelCount++;
          totalBrightness += brightness;
          brightnessList.add(brightness);
        } else {
          // 背景を緑でマーク
          debugImage.setPixel(x, y, img.ColorRgb8(0, 100, 0));
        }
      }
    }
    
    print('米粒抽出完了: $ricePixelCount ピクセル');
    
    // Phase 2: 個々の米粒を分離・解析
    final riceGrains = _extractIndividualGrains(image);
    var whitePixelCount = 0;
    
    print('個別米粒数: ${riceGrains.length}個検出');
    
    for (int i = 0; i < riceGrains.length; i++) {
      final grain = riceGrains[i];
      final grainAnalysis = _analyzeIndividualGrain(image, grain);
      
      // 各米粒の結果をデバッグ画像に反映
      for (final point in grain) {
        if (grainAnalysis['isWhiteTurbid']) {
          whitePixelCount++;
          debugImage.setPixel(point.x, point.y, img.ColorRgb8(255, 0, 0)); // 白濁
        } else {
          debugImage.setPixel(point.x, point.y, img.ColorRgb8(0, 0, 255)); // 透明
        }
      }
    }
    
    // デバッグ画像を保存
    await _saveDebugImage(debugImage, originalPath);
    
    // 統計計算
    final avgBrightness = ricePixelCount > 0 ? totalBrightness / ricePixelCount : 0.0;
    final brightnessStd = _calculateStandardDeviation(brightnessList, avgBrightness);
    final whiteAreaRatio = ricePixelCount > 0 ? (whitePixelCount / ricePixelCount) * 100 : 0.0;
    
    print('=== 相対比較解析結果 ===');
    print('米粒ピクセル数: $ricePixelCount');
    print('個別米粒数: ${riceGrains.length}');
    print('白濁ピクセル数: $whitePixelCount');
    print('白濁率: ${whiteAreaRatio.toStringAsFixed(1)}%');
    
    return {
      'ricePixels': ricePixelCount,
      'avgBrightness': avgBrightness,
      'brightnessStd': brightnessStd,
      'whiteAreaRatio': whiteAreaRatio,
      'whitePixelCount': whitePixelCount,
    };
  }

  /// 個々の米粒を抽出（改良版：より厳密な分離）
  List<List<Point>> _extractIndividualGrains(img.Image image) {
    final width = image.width;
    final height = image.height;
    final visited = List.generate(height, (i) => List.filled(width, false));
    final grains = <List<Point>>[];
    
    print('米粒分離開始 - 画像サイズ: ${width}x${height}');
    
    // 連結成分を見つけて個別の米粒を分離（より厳密な条件）
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (visited[y][x]) continue;
        
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final brightness = (0.299 * r + 0.587 * g + 0.114 * b);
        
        // 米粒判定（より厳密な条件）
        if (brightness > 120 && _isRicePixel(r, g, b)) { // 閾値を80→120に上げる
          final grain = <Point>[];
          _strictFloodFill(image, x, y, visited, grain);
          
          // サイズ制限をより厳密に（1粒の米のサイズ範囲）
          if (grain.length > 100 && grain.length < 8000) { // 大きすぎる塊を除外
            grains.add(grain);
          } else if (grain.length >= 8000) {
            print('大きすぎる領域を除外: ${grain.length}ピクセル');
          }
        }
      }
    }
    
    print('分離完了: ${grains.length}個の米粒を検出');
    return grains;
  }

  /// より厳密なフラッドフィル（米粒の境界を適切に検出）
  void _strictFloodFill(img.Image image, int startX, int startY, List<List<bool>> visited, List<Point> grain) {
    final startPixel = image.getPixel(startX, startY);
    final startBrightness = (0.299 * startPixel.r + 0.587 * startPixel.g + 0.114 * startPixel.b);
    
    final stack = <Point>[Point(startX, startY)];
    
    while (stack.isNotEmpty) {
      final point = stack.removeLast();
      final x = point.x;
      final y = point.y;
      
      if (x < 0 || y < 0 || x >= image.width || y >= image.height) continue;
      if (visited[y][x]) continue;
      
      final pixel = image.getPixel(x, y);
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      final brightness = (0.299 * r + 0.587 * g + 0.114 * b);
      
      // より厳密な条件：明度の差が大きすぎる場合は別の米粒とみなす
      if (brightness < 120 || !_isRicePixel(r, g, b)) continue;
      if ((brightness - startBrightness).abs() > 50) continue; // 明度差制限を追加
      
      visited[y][x] = true;
      grain.add(Point(x, y));
      
      // 4近傍のみ探索（8近傍→4近傍に変更でより厳密に分離）
      for (final dir in [[0, 1], [1, 0], [0, -1], [-1, 0]]) {
        stack.add(Point(x + dir[0], y + dir[1]));
      }
    }
  }

  /// 個別米粒の解析（明度ベース改良版）
  Map<String, dynamic> _analyzeIndividualGrain(img.Image image, List<Point> grain) {
    if (grain.isEmpty) {
      return {'isWhiteTurbid': false, 'avgBrightness': 0.0, 'brightnessVariance': 0.0};
    }
    
    // 米粒内の明度分布を取得
    final brightnesses = <double>[];
    for (final point in grain) {
      final pixel = image.getPixel(point.x, point.y);
      final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
      brightnesses.add(brightness);
    }
    
    brightnesses.sort();
    final avgBrightness = brightnesses.reduce((a, b) => a + b) / brightnesses.length;
    
    // 明度の分散を計算
    final variance = brightnesses.map((b) => (b - avgBrightness) * (b - avgBrightness))
        .reduce((a, b) => a + b) / brightnesses.length;
    
    // 明度の上位percentileを計算（明るい部分の割合）
    final top25Index = (brightnesses.length * 0.75).round();
    final top25Brightness = brightnesses[math.min(top25Index, brightnesses.length - 1)];
    
    print('米粒解析 - サイズ: ${grain.length}, 平均明度: ${avgBrightness.toStringAsFixed(1)}, 上位25%明度: ${top25Brightness.toStringAsFixed(1)}');
    
    // 明度ベースの白濁判定
    // 平均明度が高い OR 明るい部分が多い → 白濁
    final isWhiteTurbid = avgBrightness > 200.0 || top25Brightness > 220.0;
    
    print('  判定: ${isWhiteTurbid ? "白濁" : "透明"} (平均明度閾値: 200, 上位25%閾値: 220)');
    
    return {
      'isWhiteTurbid': isWhiteTurbid,
      'avgBrightness': avgBrightness,
      'brightnessVariance': variance,
    };
  }

  /// 米粒ピクセルかどうかを判定
  bool _isRicePixel(int r, int g, int b) {
    // 米粒は通常、白〜黄色系
    final maxChannel = math.max(r, math.max(g, b));
    final minChannel = math.min(r, math.min(g, b));
    final saturation = maxChannel > 0 ? (maxChannel - minChannel) / maxChannel : 0;
    
    // 彩度が低く（白っぽい）、ある程度明るいピクセルを米粒と判定
    return saturation < 0.3 && maxChannel > 100;
  }

  /// デバッグ画像を保存
  Future<void> _saveDebugImage(img.Image debugImage, String originalPath) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final debugDir = Directory('${directory.path}/debug_images');
      if (!await debugDir.exists()) {
        await debugDir.create(recursive: true);
      }
      
      final fileName = 'debug_${DateTime.now().millisecondsSinceEpoch}.png';
      final debugPath = '${debugDir.path}/$fileName';
      
      final pngBytes = img.encodePng(debugImage);
      await File(debugPath).writeAsBytes(pngBytes);
      
      print('デバッグ画像を保存: $debugPath');
    } catch (e) {
      print('デバッグ画像保存エラー: $e');
    }
  }

  /// 吸水率計算
  double _calculateAbsorptionRate(Map<String, dynamic> data) {
    final avgBrightness = data['avgBrightness'] as double;
    final whiteAreaRatio = data['whiteAreaRatio'] as double;
    final brightnessStd = data['brightnessStd'] as double;
    
    var absorptionRate = 0.0;
    
    // 明度ベース（30%の重み）
    absorptionRate += (avgBrightness / 255.0) * 30;
    
    // 白濁面積ベース（60%の重み）
    absorptionRate += (whiteAreaRatio / 100.0) * 60;
    
    // ばらつきベース（10%の重み）
    absorptionRate += (brightnessStd / 100.0) * 10;
    
    // 15-45%の範囲に調整
    absorptionRate = math.max(15.0, math.min(45.0, absorptionRate));
    
    return double.parse(absorptionRate.toStringAsFixed(1));
  }

  /// 標準偏差計算
  double _calculateStandardDeviation(List<double> values, double mean) {
    if (values.isEmpty) return 0.0;
    
    var sumSquaredDiff = 0.0;
    for (final value in values) {
      final diff = value - mean;
      sumSquaredDiff += diff * diff;
    }
    
    return math.sqrt(sumSquaredDiff / values.length);
  }
}

class Point {
  final int x;
  final int y;
  
  Point(this.x, this.y);
}