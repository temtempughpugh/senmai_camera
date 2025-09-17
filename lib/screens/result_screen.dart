import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/analysis_bloc.dart';
import '../models/analysis_result.dart';
import '../models/rice_variety.dart';
import '../models/measurement_data.dart';
import '../services/database_service.dart';
import '../widgets/result_display.dart';
import 'package:path_provider/path_provider.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;

  const ResultScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  AnalysisResult? _currentResult;
  RiceVariety? _selectedVariety;
  int? _selectedPolishingRatio;
  final TextEditingController _actualValueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 画像解析を開始
    context.read<AnalysisBloc>().add(AnalyzeImageEvent(widget.imagePath));
  }

  @override
  void dispose() {
    print('ResultScreen: dispose() 呼び出し - カメラ画面に戻ります');
    _actualValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('解析結果'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => _retakePhoto(),
          ),
        ],
      ),
      body: BlocListener<AnalysisBloc, AnalysisState>(
        listener: (context, state) {
          if (state is AnalysisCompleteState) {
            setState(() {
              _currentResult = state.result;
            });
          } else if (state is AnalysisSavedState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context);
          } else if (state is AnalysisErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<AnalysisBloc, AnalysisState>(
          builder: (context, state) {
            if (state is AnalysisLoadingState) {
              return _buildLoadingView();
            } else if (state is AnalysisCompleteState) {
              return _buildResultView(state.result);
            } else if (state is AnalysisErrorState) {
              return _buildErrorView(state.error);
            } else {
              return _buildLoadingView();
            }
          },
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blue[800]),
          SizedBox(height: 20),
          Text(
            '画像を解析中...',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          SizedBox(height: 10),
          Text(
            '米粒の抽出と吸水率を計算しています',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 20),
          Text(
            'エラーが発生しました',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('戻る'),
              ),
              ElevatedButton(
                onPressed: () {
                  context.read<AnalysisBloc>().add(AnalyzeImageEvent(widget.imagePath));
                },
                child: Text('再試行'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(AnalysisResult result) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 撮影画像とメイン結果
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // 撮影画像とデバッグ画像を並べて表示
                  Row(
                    children: [
                      // 元画像
                      Expanded(
                        child: Column(
                          children: [
                            Text('元画像', style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Container(
                              height: 150,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(File(widget.imagePath)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      // デバッグ画像
                      Expanded(
                        child: Column(
                          children: [
                            Text('解析結果', style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            _buildDebugImageWidget(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // 凡例
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLegendItem('背景', Colors.green),
                      _buildLegendItem('透明米', Colors.blue),
                      _buildLegendItem('白濁米', Colors.red),
                    ],
                  ),
                  
                  SizedBox(height: 16),
                  
                  // 予測吸水率（メイン表示）
                  ResultDisplay(
                    title: '予測吸水率',
                    value: '${result.predictedRate.toStringAsFixed(1)}%',
                    isMainResult: true,
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // 解析データ詳細
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '解析データ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildDataRow('米粒領域面積', '${result.areaPixels} ピクセル'),
                  _buildDataRow('平均明度', result.avgBrightness.toStringAsFixed(1)),
                  _buildDataRow('明度標準偏差', result.brightnessStd.toStringAsFixed(1)),
                  _buildDataRow('白濁面積率', '${result.whiteAreaRatio.toStringAsFixed(1)}%'),
                  _buildDataRow('解析日時', _formatDateTime(result.timestamp)),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // 実測値入力セクション
          Card(
            elevation: 4,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '学習データとして保存',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  SizedBox(height: 12),
                  
                  // 品種選択
                  _buildVarietySelector(),
                  SizedBox(height: 12),
                  
                  // 精米歩合選択
                  _buildPolishingRatioSelector(),
                  SizedBox(height: 12),
                  
                  // 実測値入力
                  TextField(
                    controller: _actualValueController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '実際の吸水率 (%)',
                      hintText: '重量測定による実際の値を入力',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                    onChanged: (value) {
                      setState(() {}); // 入力時にUIを更新
                      print('実測値入力: $value');
                    },
                  ),
                  
                  SizedBox(height: 16),
                  
                  // 保存ボタン
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canSave() ? _saveData : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        '学習データとして保存',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // 戻るボタン
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue[800],
                side: BorderSide(color: Colors.blue[800]!),
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                '撮影画面に戻る',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildVarietySelector() {
    return FutureBuilder<List<RiceVariety>>(
      future: DatabaseService.instance.getAllRiceVarieties(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }
        
        return DropdownButtonFormField<RiceVariety>(
          value: _selectedVariety,
          decoration: InputDecoration(
            labelText: '米品種',
            border: OutlineInputBorder(),
          ),
          items: snapshot.data!.map((variety) {
            return DropdownMenuItem(
              value: variety,
              child: Text(variety.name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedVariety = value;
            });
          },
        );
      },
    );
  }

  Widget _buildPolishingRatioSelector() {
    final ratios = PolishingRatioManager.getAllRatios();
    
    return DropdownButtonFormField<int>(
      value: _selectedPolishingRatio,
      decoration: InputDecoration(
        labelText: '精米歩合 (%)',
        border: OutlineInputBorder(),
      ),
      items: ratios.map((ratio) {
        return DropdownMenuItem(
          value: ratio,
          child: Text('${ratio}%'),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedPolishingRatio = value;
        });
      },
    );
  }

  bool _canSave() {
    final actualValue = _actualValueController.text.trim();
    final hasValidActualValue = actualValue.isNotEmpty && 
                               double.tryParse(actualValue) != null;
    
    print('保存可能チェック:');
    print('  結果: ${_currentResult != null}');
    print('  品種: ${_selectedVariety?.name}');
    print('  精米歩合: $_selectedPolishingRatio');
    print('  実測値: $actualValue');
    print('  有効な実測値: $hasValidActualValue');
    
    return _currentResult != null && hasValidActualValue;
    
    // 品種と精米歩合は必須ではなく、あとで設定可能にする
  }

  void _saveData() async {
    if (!_canSave()) return;
    
    final actualRate = double.tryParse(_actualValueController.text);
    if (actualRate == null || actualRate < 0 || actualRate > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('正しい吸水率を入力してください (0-100%)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // 精米歩合をユーザー履歴に追加
    await DatabaseService.instance.insertPolishingRatio(_selectedPolishingRatio!);
    
    // 解析結果を更新
    final updatedResult = _currentResult!.copyWith(
      actualRate: actualRate,
      riceVariety: _selectedVariety!.name,
      polishingRatio: _selectedPolishingRatio,
    );
    
    // 測定データとして保存
    final measurementData = MeasurementData(
      analysisResult: updatedResult,
      riceVariety: _selectedVariety,
      isLearningData: true,
    );
    
    await DatabaseService.instance.insertMeasurement(measurementData);
    
    context.read<AnalysisBloc>().add(SaveActualValueEvent(actualRate, updatedResult));
  }

  void _retakePhoto() {
    Navigator.pop(context);
  }

  Widget _buildDebugImageWidget() {
    return FutureBuilder<File?>(
      future: _findDebugImage(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: FileImage(snapshot.data!),
                fit: BoxFit.cover,
              ),
            ),
          );
        } else {
          return Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[300],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image, color: Colors.grey[600]),
                  SizedBox(height: 4),
                  Text('解析中...', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10)),
      ],
    );
  }

  Future<File?> _findDebugImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final debugDir = Directory('${directory.path}/debug_images');
      
      if (await debugDir.exists()) {
        final files = debugDir.listSync()
          .where((file) => file.path.endsWith('.png'))
          .cast<File>()
          .toList();
        
        if (files.isNotEmpty) {
          // 最新のデバッグ画像を取得
          files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
          return files.first;
        }
      }
    } catch (e) {
      print('デバッグ画像取得エラー: $e');
    }
    return null;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}