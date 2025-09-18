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

  /// 画像を解析して吸水率を予測（ガイド準拠版）
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

      // ガイドに準拠した円形範囲内の画像解析を実行
      final analysisData = await _performGuideBasedAnalysis(image, imagePath);
      
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

  /// ガイドに準拠した画像解析処理
  Future<Map<String, dynamic>> _performGuideBasedAnalysis(img.Image image, String originalPath) async {
    final width = image.width;
    final height = image.height;
    final centerX = width / 2;
    final centerY = height / 2;
    
    // 500x500の円形範囲（半径250ピクセル）- ガイドと同じサイズ
    const guideRadius = 250.0;
    
    print('=== ガイド準拠解析開始 ===');
    print('画像サイズ: ${width}x${height}');
    print('解析範囲: 中心(${centerX.toStringAsFixed(1)}, ${centerY.toStringAsFixed(1)}) 半径${guideRadius}px');
    
    // 解析結果保存用の画像を作成
    final debugImage = img.Image.from(image);
    
    var totalBrightness = 0.0;
    var ricePixelCount = 0;
    final brightnessList = <double>[];
    
    // Step 1: ガイド範囲内での背景削除 & 米粒エリアの特定
    final ricePixels = <Point>[];
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // ガイド範囲内かチェック（500x500の円形）
        final distanceFromCenter = math.sqrt(
          math.pow(x - centerX, 2) + math.pow(y - centerY, 2)
        );
        
        if (distanceFromCenter > guideRadius) {
          // ガイド範囲外は灰色でマーク
          debugImage.setPixel(x, y, img.ColorRgb8(64, 64, 64));
          continue;
        }
        
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
    
    print('=== Step 1: ガイド範囲内背景削除完了 ===');
    print('ガイド範囲内米粒ピクセル数: $ricePixelCount');
    
    // Step 2: 境界から一律で境界部分を除外
    final boundaryFilteredPixels = _removeBoundaryPixels(ricePixels, width, height);
    
    print('=== Step 2: 境界除外完了 ===');
    print('境界除外前: ${ricePixels.length} → 境界除外後: ${boundaryFilteredPixels.length} ピクセル');
    
    // Step 3: 米粒を1粒ずつ分離
    final individualGrains = _extractIndividualGrains(image, boundaryFilteredPixels);
    
    print('=== Step 3: 米粒分離完了 ===');
    print('検出された米粒数: ${individualGrains.length}個');
    
    // 各米粒の中心点を取得
    final grainCenters = <Point>[];
    for (final grain in individualGrains) {
      final center = _calculateCentroid(grain);
      grainCenters.add(center);
    }
    
    // Step 4: 各米粒の平均明度を計算
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
    
    // Step 5: 明度による詳細グループ分け（5段階）
    final grainGroups = _classifyGrainsByBrightness(individualGrains, grainBrightnesses);
    
    print('=== Step 5: 詳細グループ分け完了 ===');
    print('最明るい米: ${grainGroups['brightest']?.length ?? 0}個');
    print('明るい米: ${grainGroups['bright']?.length ?? 0}個');
    print('中間米: ${grainGroups['medium']?.length ?? 0}個');
    print('暗い米: ${grainGroups['dark']?.length ?? 0}個');
    print('最暗い米: ${grainGroups['darkest']?.length ?? 0}個');
    
    // Step 6: 全グループで解析（黒も含む）
    var totalAbsorptionPixels = 0;
    var totalGrainPixels = 0;
    
    // 全グループを解析対象に
    final analysisGroupNames = ['brightest', 'bright', 'medium', 'dark', 'darkest'];
    final groupColors = [
      img.ColorRgb8(255, 255, 255), // 最明るい=白
      img.ColorRgb8(255, 255, 0),   // 明るい=黄
      img.ColorRgb8(0, 255, 0),     // 中間=緑
      img.ColorRgb8(128, 0, 128),   // 暗い=紫
      img.ColorRgb8(0, 0, 0),       // 最暗い=黒
    ];
    
    for (int groupIndex = 0; groupIndex < analysisGroupNames.length; groupIndex++) {
      final groupName = analysisGroupNames[groupIndex];
      final grains = grainGroups[groupName] ?? [];
      
      if (grains.isEmpty) continue;
      
      print('=== ${groupName}グループの解析開始 (${grains.length}個) ===');
      
      for (int i = 0; i < grains.length; i++) {
        final grain = grains[i];
        List<Map<String, dynamic>> pixelResults;
        
        if (groupName == 'darkest') {
          // 黒グループは45%基準
          pixelResults = _analyzeGrainBlackGroup(image, grain);
        } else {
          // その他のグループは80%基準
          pixelResults = _analyzeGrainUniform(image, grain);
        }
        
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
    
    print('=== ガイド範囲内の全グループ解析完了 ===');
    
    // 除外された境界部分をグレーでマーク
    _markExcludedBoundaries(debugImage, ricePixels, boundaryFilteredPixels);
    
    // ガイド範囲の境界線を描画
    _drawGuideBoundary(debugImage, centerX, centerY, guideRadius);
    
    // メイン解析画像を保存（白濁判定結果）
    await _saveDebugImage(debugImage, originalPath);
    
    // 分類画像を保存（グループ別色分け）
    await _saveClassificationImage(image, grainGroups, groupColors, grainCenters, originalPath, centerX, centerY, guideRadius);
    
    // 統計計算
    final avgBrightness = ricePixelCount > 0 ? totalBrightness / ricePixelCount : 0.0;
    final brightnessStd = _calculateStandardDeviation(brightnessList, avgBrightness);
    final whiteAreaRatio = totalGrainPixels > 0 ? (totalAbsorptionPixels / totalGrainPixels) * 100 : 0.0;
    
    print('=== 最終結果（ガイド範囲内） ===');
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

  /// ガイド境界線を描画
  void _drawGuideBoundary(img.Image debugImage, double centerX, double centerY, double radius) {
    final width = debugImage.width;
    final height = debugImage.height;
    
    // 円周上の点を計算して描画
    for (double angle = 0; angle < 2 * math.pi; angle += 0.01) {
      final x = (centerX + radius * math.cos(angle)).round();
      final y = (centerY + radius * math.sin(angle)).round();
      
      if (x >= 0 && y >= 0 && x < width && y < height) {
        debugImage.setPixel(x, y, img.ColorRgb8(255, 255, 255)); // 白色の境界線
      }
    }
  }

  /// 背景境界から一律でピクセルを除外
  List<Point> _removeBoundaryPixels(List<Point> ricePixels, int width, int height) {
    const boundaryPixels = 1; // 境界から1ピクセル分を除外
    
    // 米粒ピクセルをマップ化
    final ricePixelMap = List.generate(height, (i) => List.filled(width, false));
    for (final point in ricePixels) {
      ricePixelMap[point.y][point.x] = true;
    }
    
    final filteredPixels = <Point>[];
    
    // 各米粒ピクセルについて、背景との距離をチェック
    for (final point in ricePixels) {
      bool shouldKeep = true;
      
      // boundaryPixels範囲内に背景があるかチェック
      for (int dy = -boundaryPixels; dy <= boundaryPixels; dy++) {
        for (int dx = -boundaryPixels; dx <= boundaryPixels; dx++) {
          final checkX = point.x + dx;
          final checkY = point.y + dy;
          
          // 範囲外または背景ピクセルが見つかったら除外
          if (checkX < 0 || checkY < 0 || checkX >= width || checkY >= height || 
              !ricePixelMap[checkY][checkX]) {
            shouldKeep = false;
            break;
          }
        }
        if (!shouldKeep) break;
      }
      
      if (shouldKeep) {
        filteredPixels.add(point);
      }
    }
    
    return filteredPixels;
  }

  /// 除外された境界部分をデバッグ画像にマーク
  void _markExcludedBoundaries(img.Image debugImage, List<Point> originalPixels, List<Point> filteredPixels) {
    // フィルタされたピクセルをセットに変換（高速検索用）
    final filteredPixelSet = filteredPixels.toSet();
    
    // 除外されたピクセルをグレーでマーク
    for (final pixel in originalPixels) {
      if (!filteredPixelSet.contains(pixel)) {
        debugImage.setPixel(pixel.x, pixel.y, img.ColorRgb8(128, 128, 128)); // 除外部分=グレー
      }
    }
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
      if (grain.length > 50 && grain.length < 2000) { // サイズ範囲を調整
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
    final minDistance = 2.0; // 最低距離を下げて、より多くの中心を検出
    
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

  /// 一律判定による米粒解析（明度差のみで判断）
  List<Map<String, dynamic>> _analyzeGrainUniform(img.Image image, List<Point> grain) {
    final results = <Map<String, dynamic>>[];
    
    // 米粒内の明度分布を取得
    final brightnesses = grain.map((p) {
      final pixel = image.getPixel(p.x, p.y);
      return (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
    }).toList()..sort();
    
    if (brightnesses.isEmpty) return results;
    
    // 統計値計算
    final median = brightnesses[brightnesses.length ~/ 2];
    final top80Threshold = brightnesses[(brightnesses.length * 0.45).round()];
    final maxBrightness = brightnesses.last;
    final minBrightness = brightnesses.first;
    final range = maxBrightness - minBrightness;
    
    // 各ピクセルを解析（一律判定）
    for (final point in grain) {
      final pixel = image.getPixel(point.x, point.y);
      final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
      
      bool isAbsorbed = false;
      
      // 明度差のみで一律判定
      if (range > 20) {
        // 明度差がある場合：上位80%を吸水と判定
        isAbsorbed = brightness >= top80Threshold;
      } else if (range <= 10) {
        // 明度が均一な場合：中央値+5で判定
        isAbsorbed = brightness >= median + 5;
      } else {
        // 中間の場合：上位80%基準を使用
        isAbsorbed = brightness >= top80Threshold;
      }
      
      results.add({'point': point, 'isAbsorbed': isAbsorbed});
    }
    
    return results;
  }

  /// 黒グループ専用解析（45%が吸水になるよう調整）
  List<Map<String, dynamic>> _analyzeGrainBlackGroup(img.Image image, List<Point> grain) {
    final results = <Map<String, dynamic>>[];
    
    // 米粒内の明度分布を取得
    final brightnesses = grain.map((p) {
      final pixel = image.getPixel(p.x, p.y);
      return (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
    }).toList()..sort();
    
    if (brightnesses.isEmpty) return results;
    
    // 45%が吸水になるよう設定（上位45%）
    final top45Threshold = brightnesses[(brightnesses.length * 0.45).round()];
    
    // 各ピクセルを解析
    for (final point in grain) {
      final pixel = image.getPixel(point.x, point.y);
      final brightness = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
      
      // 上位45%を吸水と判定
      final isAbsorbed = brightness >= top45Threshold;
      
      results.add({'point': point, 'isAbsorbed': isAbsorbed});
    }
    
    return results;
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

  /// 分類画像を保存（グループ別色分け + 中心点プロット + ガイド境界）
  Future<void> _saveClassificationImage(img.Image originalImage, Map<String, List<List<Point>>> grainGroups, 
                                      List<img.Color> groupColors, List<Point> grainCenters, String originalPath, 
                                      double centerX, double centerY, double guideRadius) async {
    try {
      final classificationImage = img.Image.from(originalImage);
      
      // 背景を緑に
      for (int y = 0; y < classificationImage.height; y++) {
        for (int x = 0; x < classificationImage.width; x++) {
          classificationImage.setPixel(x, y, img.ColorRgb8(0, 100, 0));
        }
      }
      
      // ガイド範囲外をグレーに
      for (int y = 0; y < classificationImage.height; y++) {
        for (int x = 0; x < classificationImage.width; x++) {
          final distanceFromCenter = math.sqrt(
            math.pow(x - centerX, 2) + math.pow(y - centerY, 2)
          );
          
          if (distanceFromCenter > guideRadius) {
            classificationImage.setPixel(x, y, img.ColorRgb8(64, 64, 64));
          }
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
      
      // 中心点を小さく赤でプロット（3x3ピクセル）
      for (final center in grainCenters) {
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final plotX = center.x + dx;
            final plotY = center.y + dy;
            if (plotX >= 0 && plotY >= 0 && plotX < classificationImage.width && plotY < classificationImage.height) {
              classificationImage.setPixel(plotX, plotY, img.ColorRgb8(255, 0, 0)); // 赤色
            }
          }
        }
      }
      
      // 各米粒の境界線を白で描画
      _drawGrainBoundaries(classificationImage, grainGroups);
      
      // ガイド境界線を描画
      _drawGuideBoundary(classificationImage, centerX, centerY, guideRadius);
      
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
      print('中心点${grainCenters.length}個をプロット');
      print('ガイド境界線を描画 (中心: ${centerX.toStringAsFixed(1)}, ${centerY.toStringAsFixed(1)}, 半径: ${guideRadius.toStringAsFixed(1)})');
    } catch (e) {
      print('分類画像保存エラー: $e');
    }
  }

  /// 各米粒の境界線を描画
  void _drawGrainBoundaries(img.Image image, Map<String, List<List<Point>>> grainGroups) {
    final groupNames = ['brightest', 'bright', 'medium', 'dark', 'darkest'];
    
    for (final groupName in groupNames) {
      final grains = grainGroups[groupName] ?? [];
      
      for (final grain in grains) {
        // 各米粒の境界ピクセルを検出
        for (final point in grain) {
          // 8近傍をチェック
          bool isBoundary = false;
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              
              final checkX = point.x + dx;
              final checkY = point.y + dy;
              
              // 範囲外か、この米粒に属さないピクセルがあれば境界
              if (checkX < 0 || checkY < 0 || checkX >= image.width || checkY >= image.height ||
                  !grain.contains(Point(checkX, checkY))) {
                isBoundary = true;
                break;
              }
            }
            if (isBoundary) break;
          }
          
          // 境界ピクセルを白で描画
          if (isBoundary) {
            image.setPixel(point.x, point.y, img.ColorRgb8(255, 255, 255)); // 白色
          }
        }
      }
    }
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