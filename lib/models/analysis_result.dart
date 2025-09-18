import 'package:equatable/equatable.dart';

class AnalysisResult extends Equatable {
  final String imagePath;
  final double predictedRate;
  final double? actualRate;
  final int areaPixels;
  final double avgBrightness;
  final double brightnessStd;
  final double whiteAreaRatio;
  final double overallAvgBrightness; // 背景削除後の全体平均明度
  final String? riceVariety;
  final int? polishingRatio;
  final DateTime timestamp;
  
  const AnalysisResult({
    required this.imagePath,
    required this.predictedRate,
    this.actualRate,
    required this.areaPixels,
    required this.avgBrightness,
    required this.brightnessStd,
    required this.whiteAreaRatio,
    required this.overallAvgBrightness,
    this.riceVariety,
    this.polishingRatio,
    required this.timestamp,
  });
  
  AnalysisResult copyWith({
    String? imagePath,
    double? predictedRate,
    double? actualRate,
    int? areaPixels,
    double? avgBrightness,
    double? brightnessStd,
    double? whiteAreaRatio,
    double? overallAvgBrightness,
    String? riceVariety,
    int? polishingRatio,
    DateTime? timestamp,
  }) {
    return AnalysisResult(
      imagePath: imagePath ?? this.imagePath,
      predictedRate: predictedRate ?? this.predictedRate,
      actualRate: actualRate ?? this.actualRate,
      areaPixels: areaPixels ?? this.areaPixels,
      avgBrightness: avgBrightness ?? this.avgBrightness,
      brightnessStd: brightnessStd ?? this.brightnessStd,
      whiteAreaRatio: whiteAreaRatio ?? this.whiteAreaRatio,
      overallAvgBrightness: overallAvgBrightness ?? this.overallAvgBrightness,
      riceVariety: riceVariety ?? this.riceVariety,
      polishingRatio: polishingRatio ?? this.polishingRatio,
      timestamp: timestamp ?? this.timestamp,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'imagePath': imagePath,
      'predictedRate': predictedRate,
      'actualRate': actualRate,
      'areaPixels': areaPixels,
      'avgBrightness': avgBrightness,
      'brightnessStd': brightnessStd,
      'whiteAreaRatio': whiteAreaRatio,
      'overallAvgBrightness': overallAvgBrightness,
      'riceVariety': riceVariety,
      'polishingRatio': polishingRatio,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
  
  factory AnalysisResult.fromMap(Map<String, dynamic> map) {
    return AnalysisResult(
      imagePath: map['imagePath'],
      predictedRate: map['predictedRate'],
      actualRate: map['actualRate'],
      areaPixels: map['areaPixels'],
      avgBrightness: map['avgBrightness'],
      brightnessStd: map['brightnessStd'],
      whiteAreaRatio: map['whiteAreaRatio'],
      overallAvgBrightness: map['overallAvgBrightness'] ?? 0.0,
      riceVariety: map['riceVariety'],
      polishingRatio: map['polishingRatio'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
  
  @override
  List<Object?> get props => [
    imagePath,
    predictedRate,
    actualRate,
    areaPixels,
    avgBrightness,
    brightnessStd,
    whiteAreaRatio,
    overallAvgBrightness,
    riceVariety,
    polishingRatio,
    timestamp,
  ];
}