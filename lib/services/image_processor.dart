import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/analysis_result.dart';

class Point {
  final int x;
  final int y;
  
  Point(this.x, this.y);
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Point && other.x == x && other.y == y;
  }
  
  @override
  int get hashCode => x.hashCode ^ y.hashCode;
}

class ImageProcessorService {
  static final ImageProcessorService instance = ImageProcessorService._init();
  ImageProcessorService._init();

  /// 画像を解析して吸水率を予測（実際の画像処理版）
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

  /// 実際の画像解析処理（米粒分離→グループ分け→勾配解析版）
  Future<Map<String, dynamic>> _performRealImageAnalysis(img.Image image, String originalPath) async {
    final width = image.width;
    final height = image.height;
    
    // 解析結果保存用の画像を作成
    final debugImage = img.Image.from(image);
    
    var totalBrightness = 0.0;
    var ricePixelCount = 0;
    final brightnessList = <double>[];
    
    // Step 1: 背景削除 & 米粒エリアの特定
    final ricePixels = <Point>[];
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        
        // RGB値を取得
        final r = pixel.r.round();
        final g = pixel.g.round();
        final b = pixel.b.round();
        
        // 明度を計算
        final brightness = (0.299 * r + 0.587 * g + 0.114 * b);
        
        // 米粒判定（背景を除外）
        if (brightness > 80 && _isRicePixel(r, g, b)) {
          ricePixelCount++;
          totalBrightness += brightness;
          brightnessList.add(brightness);
          ricePixels.add(Point(x, y));
        } else {
          // 背景を緑でマーク
          debugImage.setPixel(x, y, img.ColorRgb8(0, 100, 0));
        }
      }
    }
    
    print('=== Step 1: 背景削除完了 ===');
    print('米粒ピクセル数: $ricePixelCount');
    
    // Step 2: 米粒を1粒ずつ分離
    final individualGrains = _extractIndividualGrains(image, ricePixels);
    
    print('=== Step 2: 米粒分離完了 ===');
    print('検出された米粒数: ${individualGrains.length}個');
    
    // Step 3: 各米粒の平均明度を計算
    final grainBrightnesses = <double>[];
    for (final grain in individualGrains) {
      final avgBrightness = _calculateGrainAverageBrightness(image, grain);
      grainBrightnesses.add(avgBrightness);
    }
    
    // 中央値計算
    final sortedGrainBrightnesses = List<double>.from(grainBrightnesses)..sort();
    final medianBrightness = sortedGrainBrightnesses.isNotEmpty 
        ? sortedGrainBrightnesses[sortedGrainBrightnesses.length ~/ 2] 
        : 0.0;
    
    // Step 4: 明度による詳細グループ分け（5段階）
    final grainGroups = _classifyGrainsByBrightness(individualGrains, grainBrightnesses);
    
    print('=== Step 4: 詳細グループ分け完了 ===');
    print('最明るい米: ${grainGroups['brightest']?.length ?? 0}個');
    print('明るい米: ${grainGroups['bright']?.length ?? 0}個');
    print('中間米: ${grainGroups['medium']?.length ?? 0}個');
    print('暗い米: ${grainGroups['dark']?.length ?? 0}個');
    print('最暗い米: ${grainGroups['darkest']?.length ?? 0}個');
    
    // Step 5: グループ別に各米粒内のピクセル単位解析
    var totalAbsorptionPixels = 0;
    var totalGrainPixels = 0;
    
    // 各グループごとに異なるロジックで解析
    final groupNames = ['brightest', 'bright', 'medium', 'dark', 'darkest'];
    final groupColors = [
      img.ColorRgb8(255, 255, 255), // 最明るい=白
      img.ColorRgb8(255, 255, 0),   // 明るい=黄
      img.ColorRgb8(0, 255, 0),     // 中間=緑
      img.ColorRgb8(128, 0, 128),   // 暗い=紫
      img.ColorRgb8(0, 0, 0),       // 最暗い=黒
    ];
    
    for (int groupIndex = 0; groupIndex < groupNames.length; groupIndex++) {
      final groupName = groupNames[groupIndex];
      final grains = grainGroups[groupName] ?? [];
      
      if (grains.isEmpty) continue;
      
      print('=== ${groupName}グループの解析開始 (${grains.length}個) ===');
      
      for (int i = 0; i < grains.length; i++) {
        final grain = grains[i];
        final pixelResults = _analyzeGrainByGroup(image, grain, groupIndex);
        
        // ピクセルごとに色分け
        for (final pixelResult in pixelResults) {
          final point = pixelResult['point'] as Point;
          final isAbsorbed = pixelResult['isAbsorbed'] as bool;
          
          if (isAbsorbed) {
            totalAbsorptionPixels++;
            debugImage.setPixel(point.x, point.y, img.ColorRgb8(255, 0, 0)); // 吸水=赤
          } else {
            debugImage.setPixel(point.x, point.y, img.ColorRgb8(0, 0, 255)); // 未吸水=青
          }
          totalGrainPixels++;
        }
        
        final grainAbsorptionRate = pixelResults.where((p) => p['isAbsorbed']).length / pixelResults.length;
        print('${groupName}米${i + 1}: 吸水率 ${(grainAbsorptionRate * 100).toStringAsFixed(1)}%');
      }
    }
    
    // メイン解析画像を保存（白濁判定結果）
    await _saveDebugImage(debugImage, originalPath);
    
    // 分類画像を保存（グループ別色分け）
    await _saveClassificationImage(image, grainGroups, groupColors, originalPath);
    
    // 統計計算
    final avgBrightness = ricePixelCount > 0 ? totalBrightness / ricePixelCount : 0.0;
    final brightnessStd = _calculateStandardDeviation(brightnessList, avgBrightness);
    final whiteAreaRatio = totalGrainPixels > 0 ? (totalAbsorptionPixels / totalGrainPixels) * 100 : 0.0;
    
    print('=== 最終結果 ===');
    print('総吸水ピクセル数: $totalAbsorptionPixels');
    print('総米粒ピクセル数: $totalGrainPixels');
    print('白濁面積率: ${whiteAreaRatio.toStringAsFixed(1)}%');
    
    return {
      'ricePixels': ricePixelCount,
      'avgBrightness': avgBrightness,
      'brightnessStd': brightnessStd,
      'whiteAreaRatio': whiteAreaRatio,
      'grainCount': individualGrains.length,
      'medianBrightness': medianBrightness,
    };
  }

  /// 米粒を1粒ずつ分離（距離変換 + ローカルマキシマ版）
  List<List<Point>> _extractIndividualGrains(img.Image image, List<Point> ricePixels) {
    final width = image.width;
    final height = image.height;
    
    print('=== 距離変換による米粒分離開始 ===');
    
    // Step 1: 米粒エリアをマップ化
    final ricePixelMap = List.generate(height, (i) => List.filled(width, false));
    for (final point in ricePixels) {
      ricePixelMap[point.y][point.x] = true;
    }
    
    // Step 2: 距離変換（境界からの距離を計算）
    final distanceMap = _calculateDistanceTransform(ricePixelMap, width, height);
    
    // Step 3: ローカルマキシマ検出（各米粒の中心候補）
    final centers = _findLocalMaxima(distanceMap, ricePixelMap, width, height);
    
    print('検出された中心点数: ${centers.length}個');
    
    // Step 4: 各中心からボロノイ分割で米粒領域を決定
    final grains = _segmentGrainsByVoronoi(centers, ricePixels, width, height);
    
    // Step 5: サイズフィルタリング
    final filteredGrains = <List<Point>>[];
    for (final grain in grains) {
      if (grain.length > 30 && grain.length < 3000) { // サイズ調整
        filteredGrains.add(grain);
      }
    }
    
    print('フィルタリング後の米粒数: ${filteredGrains.length}個');
    
    return filteredGrains;
  }

  /// 距離変換を計算（境界からの距離）
  List<List<double>> _calculateDistanceTransform(List<List<bool>> riceMap, int width, int height) {
    final distanceMap = List.generate(height, (i) => List.filled(width, 0.0));
    
    // 境界ピクセルを0、内部ピクセルを無限大で初期化
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (!riceMap[y][x]) {
          distanceMap[y][x] = 0.0; // 背景
        } else {
          // 境界チェック（8近傍に背景があるか）
          bool isBoundary = false;
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              final nx = x + dx;
              final ny = y + dy;
              if (nx < 0 || ny < 0 || nx >= width || ny >= height || !riceMap[ny][nx]) {
                isBoundary = true;
                break;
              }
            }
            if (isBoundary) break;
          }
          
          distanceMap[y][x] = isBoundary ? 0.0 : 9999.0;
        }
      }
    }
    
    // 距離変換（簡易版）
    // 前方パス
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        if (riceMap[y][x]) {
          final candidates = [
            distanceMap[y-1][x-1] + 1.414, // 斜め
            distanceMap[y-1][x] + 1.0,     // 上
            distanceMap[y-1][x+1] + 1.414, // 斜め
            distanceMap[y][x-1] + 1.0,     // 左
          ];
          distanceMap[y][x] = math.min(distanceMap[y][x], candidates.reduce(math.min));
        }
      }
    }
    
    // 後方パス
    for (int y = height - 2; y > 0; y--) {
      for (int x = width - 2; x > 0; x--) {
        if (riceMap[y][x]) {
          final candidates = [
            distanceMap[y][x+1] + 1.0,     // 右
            distanceMap[y+1][x-1] + 1.414, // 斜め
            distanceMap[y+1][x] + 1.0,     // 下
            distanceMap[y+1][x+1] + 1.414, // 斜め
          ];
          distanceMap[y][x] = math.min(distanceMap[y][x], candidates.reduce(math.min));
        }
      }
    }
    
    return distanceMap;
  }

  /// ローカルマキシマ検出（米粒の中心候補）
  List<Point> _findLocalMaxima(List<List<double>> distanceMap, List<List<bool>> riceMap, int width, int height) {
    final centers = <Point>[];
    final minDistance = 3.0; // 最低距離（小さすぎる米粒は除外）
    
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        if (!riceMap[y][x] || distanceMap[y][x] < minDistance) continue;
        
        // 8近傍すべてより大きいかチェック
        bool isLocalMaxima = true;
        final centerValue = distanceMap[y][x];
        
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            if (distanceMap[y + dy][x + dx] >= centerValue) {
              isLocalMaxima = false;
              break;
            }
          }
          if (!isLocalMaxima) break;
        }
        
        if (isLocalMaxima) {
          centers.add(Point(x, y));
        }
      }
    }
    
    return centers;
  }

  /// ボロノイ分割による米粒セグメンテーション
  List<List<Point>> _segmentGrainsByVoronoi(List<Point> centers, List<Point> ricePixels, int width, int height) {
    if (centers.isEmpty) {
      return [ricePixels]; // 中心が見つからない場合は全体を1つの米粒として返す
    }
    
    // 各中心に対応する米粒リストを作成
    final grains = List.generate(centers.length, (i) => <Point>[]);
    
    // 各米粒ピクセルを最も近い中心に割り当て
    for (final pixel in ricePixels) {
      var minDistance = double.infinity;
      var nearestCenterIndex = 0;
      
      for (int i = 0; i < centers.length; i++) {
        final center = centers[i];
        final distance = math.sqrt(
          math.pow(pixel.x - center.x, 2) + math.pow(pixel.y - center.y, 2)
        );
        
        if (distance < minDistance) {
          minDistance = distance;
          nearestCenterIndex = i;
        }
      }
      
      grains[nearestCenterIndex].add(pixel);
    }
    
    // 空の米粒を除去
    return grains.where((grain) => grain.isNotEmpty).toList();
  }

  /// 米粒の平均明度を計算
  double _calculateGrainAverageBrightness(img.Image image, List<Point> grain) {
    if (grain.isEmpty) return 0.0;
    
    var totalBrightness = 0.0;
    for (final point in grain) {
      final pixel = image.getPixel(point.x, point.y);
      final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
      totalBrightness += brightness;
    }
    
    return totalBrightness / grain.length;
  }

  /// 明度による詳細グループ分け（5段階）
  Map<String, List<List<Point>>> _classifyGrainsByBrightness(List<List<Point>> grains, List<double> brightnesses) {
    if (brightnesses.isEmpty) {
      return {
        'brightest': [],
        'bright': [],
        'medium': [],
        'dark': [],
        'darkest': [],
      };
    }
    
    // 明度の分布から閾値を計算
    final sortedBrightnesses = List<double>.from(brightnesses)..sort();
    final percentile20 = sortedBrightnesses[(sortedBrightnesses.length * 0.2).round()];
    final percentile40 = sortedBrightnesses[(sortedBrightnesses.length * 0.4).round()];
    final percentile60 = sortedBrightnesses[(sortedBrightnesses.length * 0.6).round()];
    final percentile80 = sortedBrightnesses[(sortedBrightnesses.length * 0.8).round()];
    
    final groups = {
      'brightest': <List<Point>>[],
      'bright': <List<Point>>[],
      'medium': <List<Point>>[],
      'dark': <List<Point>>[],
      'darkest': <List<Point>>[],
    };
    
    for (int i = 0; i < grains.length; i++) {
      final grain = grains[i];
      final brightness = brightnesses[i];
      
      if (brightness >= percentile80) {
        groups['brightest']!.add(grain);
      } else if (brightness >= percentile60) {
        groups['bright']!.add(grain);
      } else if (brightness >= percentile40) {
        groups['medium']!.add(grain);
      } else if (brightness >= percentile20) {
        groups['dark']!.add(grain);
      } else {
        groups['darkest']!.add(grain);
      }
    }
    
    return groups;
  }

  /// グループ別の解析ロジック（全て相対判定に統一）
  List<Map<String, dynamic>> _analyzeGrainByGroup(img.Image image, List<Point> grain, int groupIndex) {
    // グループに関係なく、全て相対判定で統一
    return _analyzeGrainRelative(image, grain);
  }

  /// 相対判定による米粒解析（全グループ統一）
  List<Map<String, dynamic>> _analyzeGrainRelative(img.Image image, List<Point> grain) {
    final results = <Map<String, dynamic>>[];
    
    // 米粒内の明度分布を取得
    final brightnesses = grain.map((p) {
      final pixel = image.getPixel(p.x, p.y);
      return (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
    }).toList()..sort();
    
    if (brightnesses.isEmpty) return results;
    
    // 統計値計算（より多くを白濁判定するよう調整）
    final median = brightnesses[brightnesses.length ~/ 2];
    final top50Threshold = brightnesses[(brightnesses.length * 0.5).round()];  // 30% → 50%に変更
    final maxBrightness = brightnesses.last;
    final minBrightness = brightnesses.first;
    final range = maxBrightness - minBrightness;
    
    // 各ピクセルを相対判定
    for (final point in grain) {
      final pixel = image.getPixel(point.x, point.y);
      final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
      
      bool isAbsorbed = false;
      
      // 相対判定ロジック（より寛容に調整）
      if (range > 20) {  // 30 → 20に変更（より敏感に）
        // 明度差がある場合：上位50%を吸水と判定（より多く判定）
        isAbsorbed = brightness >= top50Threshold;
      } else {
        // 明度が均一な場合：中央値+閾値で判定（閾値を下げる）
        isAbsorbed = brightness >= median + 5;  // 10 → 5に変更
      }
      
      results.add({'point': point, 'isAbsorbed': isAbsorbed});
    }
    
    return results;
  }

  /// 重心を計算
  Point _calculateCentroid(List<Point> grain) {
    var sumX = 0.0;
    var sumY = 0.0;
    for (final point in grain) {
      sumX += point.x;
      sumY += point.y;
    }
    return Point((sumX / grain.length).round(), (sumY / grain.length).round());
  }

  /// 重心からの距離を計算
  double _calculateDistanceFromCenter(Point point, Point center) {
    return math.sqrt(math.pow(point.x - center.x, 2) + math.pow(point.y - center.y, 2));
  }

  /// 分類画像を保存（グループ別色分け）
  Future<void> _saveClassificationImage(img.Image originalImage, Map<String, List<List<Point>>> grainGroups, 
                                       List<img.Color> groupColors, String originalPath) async {
    try {
      final classificationImage = img.Image.from(originalImage);
      
      // 背景を緑に
      for (int y = 0; y < classificationImage.height; y++) {
        for (int x = 0; x < classificationImage.width; x++) {
          classificationImage.setPixel(x, y, img.ColorRgb8(0, 100, 0));
        }
      }
      
      // 各グループを色分け
      final groupNames = ['brightest', 'bright', 'medium', 'dark', 'darkest'];
      for (int i = 0; i < groupNames.length; i++) {
        final grains = grainGroups[groupNames[i]] ?? [];
        final color = groupColors[i];
        
        for (final grain in grains) {
          for (final point in grain) {
            classificationImage.setPixel(point.x, point.y, color);
          }
        }
      }
      
      final directory = await getApplicationDocumentsDirectory();
      final debugDir = Directory('${directory.path}/debug_images');
      if (!await debugDir.exists()) {
        await debugDir.create(recursive: true);
      }
      
      final fileName = 'classification_${DateTime.now().millisecondsSinceEpoch}.png';
      final classificationPath = '${debugDir.path}/$fileName';
      
      final pngBytes = img.encodePng(classificationImage);
      await File(classificationPath).writeAsBytes(pngBytes);
      
      print('分類画像を保存: $classificationPath');
    } catch (e) {
      print('分類画像保存エラー: $e');
    }
  }

  /// エッジ強度を計算（8近傍との明度差）
  double _calculateEdgeStrength(img.Image image, Point point) {
    final centerPixel = image.getPixel(point.x, point.y);
    final centerBrightness = (0.299 * centerPixel.r + 0.587 * centerPixel.g + 0.114 * centerPixel.b);
    
    var maxDiff = 0.0;
    
    // 8近傍をチェック
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        
        final nx = point.x + dx;
        final ny = point.y + dy;
        
        if (nx >= 0 && ny >= 0 && nx < image.width && ny < image.height) {
          final neighborPixel = image.getPixel(nx, ny);
          final neighborBrightness = (0.299 * neighborPixel.r + 0.587 * neighborPixel.g + 0.114 * neighborPixel.b);
          final diff = (centerBrightness - neighborBrightness).abs();
          
          if (diff > maxDiff) {
            maxDiff = diff;
          }
        }
      }
    }
    
    return maxDiff;
  }

  /// 重心からの最大距離を計算
  double _calculateMaxDistance(List<Point> grain, double centerX, double centerY) {
    var maxDistance = 0.0;
    
    for (final point in grain) {
      final distance = math.sqrt(
        math.pow(point.x - centerX, 2) + math.pow(point.y - centerY, 2)
      );
      if (distance > maxDistance) {
        maxDistance = distance;
      }
    }
    
    return maxDistance;
  }

  /// 米粒ピクセルかどうかを判定
  bool _isRicePixel(int r, int g, int b) {
    // 米粒は通常、白〜黄色系
    // 極端に青い、赤い、緑いピクセルは背景として除外
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