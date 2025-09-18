import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/measurement_data.dart';
import '../models/analysis_result.dart';
import '../models/rice_variety.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('rice_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // 測定結果テーブル
    await db.execute('''
      CREATE TABLE measurements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        imagePath TEXT NOT NULL,
        predictedRate REAL NOT NULL,
        actualRate REAL,
        areaPixels INTEGER NOT NULL,
        avgBrightness REAL NOT NULL,
        brightnessStd REAL NOT NULL,
        whiteAreaRatio REAL NOT NULL,
        overallAvgBrightness REAL NOT NULL DEFAULT 0.0,
        riceVariety TEXT,
        polishingRatio INTEGER,
        notes TEXT,
        isLearningData INTEGER NOT NULL DEFAULT 0,
        timestamp INTEGER NOT NULL
      )
    ''');

    // 米品種テーブル（ユーザー追加分）
    await db.execute('''
      CREATE TABLE user_rice_varieties (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL,
        absorptionCharacteristics TEXT
      )
    ''');

    // 精米歩合履歴テーブル
    await db.execute('''
      CREATE TABLE polishing_ratios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ratio INTEGER UNIQUE NOT NULL
      )
    ''');
  }

  // 測定データの保存
  Future<int> insertMeasurement(MeasurementData measurementData) async {
    final db = await instance.database;
    return await db.insert('measurements', measurementData.toMap());
  }

  // 測定データの取得（全件）
  Future<List<MeasurementData>> getAllMeasurements() async {
    final db = await instance.database;
    final result = await db.query(
      'measurements',
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => MeasurementData.fromMap(map)).toList();
  }

  // 学習データのみ取得
  Future<List<MeasurementData>> getLearningData() async {
    final db = await instance.database;
    final result = await db.query(
      'measurements',
      where: 'isLearningData = ? AND actualRate IS NOT NULL',
      whereArgs: [1],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => MeasurementData.fromMap(map)).toList();
  }

  // 品種・精米歩合での絞り込み
  Future<List<MeasurementData>> getMeasurementsByCondition({
    String? riceVariety,
    int? polishingRatio,
  }) async {
    final db = await instance.database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (riceVariety != null && polishingRatio != null) {
      whereClause = 'riceVariety = ? AND polishingRatio = ?';
      whereArgs = [riceVariety, polishingRatio];
    } else if (riceVariety != null) {
      whereClause = 'riceVariety = ?';
      whereArgs = [riceVariety];
    } else if (polishingRatio != null) {
      whereClause = 'polishingRatio = ?';
      whereArgs = [polishingRatio];
    }

    final result = await db.query(
      'measurements',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => MeasurementData.fromMap(map)).toList();
  }

  // 測定データの更新（実測値追加など）
  Future<int> updateMeasurement(MeasurementData measurementData) async {
    final db = await instance.database;
    return await db.update(
      'measurements',
      measurementData.toMap(),
      where: 'id = ?',
      whereArgs: [measurementData.id],
    );
  }

  // 測定データの削除
  Future<int> deleteMeasurement(int id) async {
    final db = await instance.database;
    return await db.delete(
      'measurements',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ユーザー追加品種の保存
  Future<int> insertUserRiceVariety(RiceVariety variety) async {
    final db = await instance.database;
    try {
      return await db.insert('user_rice_varieties', variety.toMap());
    } catch (e) {
      // 重複エラーの場合は無視
      return 0;
    }
  }

  // ユーザー追加品種の取得
  Future<List<RiceVariety>> getUserRiceVarieties() async {
    final db = await instance.database;
    final result = await db.query('user_rice_varieties');
    return result.map((map) => RiceVariety.fromMap(map)).toList();
  }

  // 全品種取得（プリセット + ユーザー追加）
  Future<List<RiceVariety>> getAllRiceVarieties() async {
    final userVarieties = await getUserRiceVarieties();
    final allVarieties = <RiceVariety>[];
    allVarieties.addAll(PredefinedRiceVarieties.varieties);
    allVarieties.addAll(userVarieties);
    return allVarieties;
  }

  // 精米歩合の保存
  Future<void> insertPolishingRatio(int ratio) async {
    final db = await instance.database;
    try {
      await db.insert('polishing_ratios', {'ratio': ratio});
      PolishingRatioManager.addUserRatio(ratio);
    } catch (e) {
      // 重複エラーの場合は無視
    }
  }

  // 保存済み精米歩合の取得
  Future<List<int>> getSavedPolishingRatios() async {
    final db = await instance.database;
    final result = await db.query('polishing_ratios', orderBy: 'ratio ASC');
    return result.map((map) => map['ratio'] as int).toList();
  }

  // データベース初期化
  Future<void> initialize() async {
    await database;
    
    // 保存済み精米歩合をメモリに読み込み
    final savedRatios = await getSavedPolishingRatios();
    PolishingRatioManager.userInputRatios.addAll(savedRatios);
  }

  // データベースを閉じる
  Future close() async {
    final db = _database;
    if (db != null) {
      await db.close();
    }
  }

  // データベースリセット（開発・テスト用）
  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rice_app.db');
    await deleteDatabase(path);
    _database = null;
    await database; // 再作成
  }
}