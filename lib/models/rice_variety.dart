import 'package:equatable/equatable.dart';

class RiceVariety extends Equatable {
  final String name;
  final String absorptionCharacteristics;
  
  const RiceVariety({
    required this.name,
    required this.absorptionCharacteristics,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'absorptionCharacteristics': absorptionCharacteristics,
    };
  }
  
  factory RiceVariety.fromMap(Map<String, dynamic> map) {
    return RiceVariety(
      name: map['name'],
      absorptionCharacteristics: map['absorptionCharacteristics'],
    );
  }
  
  @override
  List<Object?> get props => [name, absorptionCharacteristics];
}

// 事前定義された米品種リスト
class PredefinedRiceVarieties {
  static const List<RiceVariety> varieties = [
    RiceVariety(
      name: '山田錦',
      absorptionCharacteristics: '吸水が早く、均一に吸水する',
    ),
    RiceVariety(
      name: '五百万石',
      absorptionCharacteristics: '吸水速度は中程度、安定した吸水',
    ),
    RiceVariety(
      name: '美山錦',
      absorptionCharacteristics: '吸水がやや遅め、時間をかけて吸水',
    ),
    RiceVariety(
      name: '雄町',
      absorptionCharacteristics: '吸水が早く、注意深い管理が必要',
    ),
    RiceVariety(
      name: 'その他',
      absorptionCharacteristics: '品種により異なる',
    ),
  ];
}

// 精米歩合の管理クラス
class PolishingRatioManager {
  // よく使われる精米歩合のプリセット
  static const List<int> commonRatios = [35, 40, 45, 50, 55, 60, 65, 70, 80, 90];
  
  // ユーザーが入力した精米歩合の履歴を管理
  static List<int> userInputRatios = [];
  
  // 全ての精米歩合を取得（プリセット + ユーザー入力）
  static List<int> getAllRatios() {
    final allRatios = <int>{};
    allRatios.addAll(commonRatios);
    allRatios.addAll(userInputRatios);
    final sortedRatios = allRatios.toList()..sort();
    return sortedRatios;
  }
  
  // ユーザー入力の精米歩合を追加
  static void addUserRatio(int ratio) {
    if (!userInputRatios.contains(ratio) && !commonRatios.contains(ratio)) {
      userInputRatios.add(ratio);
    }
  }
  
  // 精米歩合のバリデーション
  static bool isValidRatio(int ratio) {
    return ratio >= 10 && ratio <= 100;
  }
}