import 'package:equatable/equatable.dart';
import 'analysis_result.dart';
import 'rice_variety.dart';

class MeasurementData extends Equatable {
  final int? id;
  final AnalysisResult analysisResult;
  final RiceVariety? riceVariety;
  final String? notes;
  final bool isLearningData;
  
  const MeasurementData({
    this.id,
    required this.analysisResult,
    this.riceVariety,
    this.notes,
    this.isLearningData = false,
  });
  
  MeasurementData copyWith({
    int? id,
    AnalysisResult? analysisResult,
    RiceVariety? riceVariety,
    String? notes,
    bool? isLearningData,
  }) {
    return MeasurementData(
      id: id ?? this.id,
      analysisResult: analysisResult ?? this.analysisResult,
      riceVariety: riceVariety ?? this.riceVariety,
      notes: notes ?? this.notes,
      isLearningData: isLearningData ?? this.isLearningData,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': analysisResult.imagePath,
      'predictedRate': analysisResult.predictedRate,
      'actualRate': analysisResult.actualRate,
      'areaPixels': analysisResult.areaPixels,
      'avgBrightness': analysisResult.avgBrightness,
      'brightnessStd': analysisResult.brightnessStd,
      'whiteAreaRatio': analysisResult.whiteAreaRatio,
      'overallAvgBrightness': analysisResult.overallAvgBrightness,
      'riceVariety': riceVariety?.name,
      'polishingRatio': analysisResult.polishingRatio,
      'notes': notes,
      'isLearningData': isLearningData ? 1 : 0,
      'timestamp': analysisResult.timestamp.millisecondsSinceEpoch,
    };
  }
  
  factory MeasurementData.fromMap(Map<String, dynamic> map) {
    final analysisResult = AnalysisResult(
      imagePath: map['imagePath'],
      predictedRate: map['predictedRate'],
      actualRate: map['actualRate'],
      areaPixels: map['areaPixels'],
      avgBrightness: map['avgBrightness'],
      brightnessStd: map['brightnessStd'],
      whiteAreaRatio: map['whiteAreaRatio'],
      overallAvgBrightness: map['overallAvgBrightness'] ?? 0.0,
      polishingRatio: map['polishingRatio'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
    
    RiceVariety? riceVariety;
    if (map['riceVariety'] != null) {
      riceVariety = PredefinedRiceVarieties.varieties
          .firstWhere((variety) => variety.name == map['riceVariety']);
    }
    
    return MeasurementData(
      id: map['id'],
      analysisResult: analysisResult,
      riceVariety: riceVariety,
      notes: map['notes'],
      isLearningData: map['isLearningData'] == 1,
    );
  }
  
  @override
  List<Object?> get props => [
    id,
    analysisResult,
    riceVariety,
    notes,
    isLearningData,
  ];
}