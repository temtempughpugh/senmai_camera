import 'dart:io';
import 'package:flutter/material.dart';
import '../models/measurement_data.dart';
import '../services/database_service.dart';
import '../widgets/result_display.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<MeasurementData> _measurements = [];
  bool _isLoading = true;
  bool _showLearningDataOnly = false;

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
  }

  Future<void> _loadMeasurements() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<MeasurementData> measurements;
      if (_showLearningDataOnly) {
        measurements = await DatabaseService.instance.getLearningData();
      } else {
        measurements = await DatabaseService.instance.getAllMeasurements();
      }

      setState(() {
        _measurements = measurements;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('データの読み込みに失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('測定履歴'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'filter',
                child: Row(
                  children: [
                    Icon(Icons.filter_list),
                    SizedBox(width: 8),
                    Text('フィルター'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('エクスポート'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete),
                    SizedBox(width: 8),
                    Text('全削除'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // フィルターオプション
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Text('表示設定: '),
                Switch(
                  value: _showLearningDataOnly,
                  onChanged: (value) {
                    setState(() {
                      _showLearningDataOnly = value;
                    });
                    _loadMeasurements();
                  },
                ),
                Text(_showLearningDataOnly ? '学習データのみ' : '全データ'),
                Spacer(),
                Text('${_measurements.length}件'),
              ],
            ),
          ),

          // データリスト
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _measurements.isEmpty
                    ? _buildEmptyView()
                    : RefreshIndicator(
                        onRefresh: _loadMeasurements,
                        child: ListView.builder(
                          itemCount: _measurements.length,
                          itemBuilder: (context, index) {
                            return _buildMeasurementCard(_measurements[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            _showLearningDataOnly ? '学習データがありません' : '測定履歴がありません',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            _showLearningDataOnly
                ? '実測値を入力したデータが表示されます'
                : '撮影・解析を行うとここに履歴が表示されます',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementCard(MeasurementData measurement) {
    final result = measurement.analysisResult;
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showDetailDialog(measurement),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // 画像サムネイル
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: File(result.imagePath).existsSync()
                      ? DecorationImage(
                          image: FileImage(File(result.imagePath)),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: Colors.grey[300],
                ),
                child: !File(result.imagePath).existsSync()
                    ? Icon(Icons.image_not_supported, color: Colors.grey)
                    : null,
              ),
              
              SizedBox(width: 16),
              
              // データ情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '予測: ${result.predictedRate.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        if (measurement.isLearningData)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '学習済',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green[800],
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    if (result.actualRate != null)
                      Text(
                        '実測: ${result.actualRate!.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[700],
                        ),
                      ),
                    
                    SizedBox(height: 4),
                    
                    Row(
                      children: [
                        if (measurement.riceVariety != null) ...[
                          Text(
                            measurement.riceVariety!.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          SizedBox(width: 8),
                        ],
                        if (result.polishingRatio != null)
                          Text(
                            '${result.polishingRatio}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                    
                    SizedBox(height: 4),
                    
                    Text(
                      _formatDateTime(result.timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailDialog(MeasurementData measurement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('測定詳細'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 画像
              if (File(measurement.analysisResult.imagePath).existsSync())
                Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(File(measurement.analysisResult.imagePath)),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              
              SizedBox(height: 16),
              
              // 詳細データ
              DataDisplayCard(
                title: '解析結果',
                items: [
                  DataItem(label: '予測吸水率', value: '${measurement.analysisResult.predictedRate.toStringAsFixed(1)}%'),
                  if (measurement.analysisResult.actualRate != null)
                    DataItem(label: '実測吸水率', value: '${measurement.analysisResult.actualRate!.toStringAsFixed(1)}%'),
                  DataItem(label: '米粒領域面積', value: '${measurement.analysisResult.areaPixels} px'),
                  DataItem(label: '平均明度', value: measurement.analysisResult.avgBrightness.toStringAsFixed(1)),
                  DataItem(label: '明度標準偏差', value: measurement.analysisResult.brightnessStd.toStringAsFixed(1)),
                  DataItem(label: '白濁面積率', value: '${measurement.analysisResult.whiteAreaRatio.toStringAsFixed(1)}%'),
                  if (measurement.riceVariety != null)
                    DataItem(label: '米品種', value: measurement.riceVariety!.name),
                  if (measurement.analysisResult.polishingRatio != null)
                    DataItem(label: '精米歩合', value: '${measurement.analysisResult.polishingRatio}%'),
                  DataItem(label: '測定日時', value: _formatDateTime(measurement.analysisResult.timestamp)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('閉じる'),
          ),
          if (measurement.id != null)
            TextButton(
              onPressed: () => _deleteConfirmation(measurement),
              child: Text('削除', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'filter':
        _showFilterDialog();
        break;
      case 'export':
        _exportData();
        break;
      case 'clear':
        _clearAllConfirmation();
        break;
    }
  }

  void _showFilterDialog() {
    // TODO: より詳細なフィルター機能を実装
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('フィルター'),
        content: Text('詳細なフィルター機能は今後実装予定です'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    // TODO: CSV出力機能を実装
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CSV出力機能は今後実装予定です'),
      ),
    );
  }

  void _deleteConfirmation(MeasurementData measurement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('削除確認'),
        content: Text('この測定データを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 詳細ダイアログを閉じる
              Navigator.pop(context); // 確認ダイアログを閉じる
              _deleteMeasurement(measurement);
            },
            child: Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _clearAllConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('全削除確認'),
        content: Text('すべての測定データを削除しますか？この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _clearAllData();
            },
            child: Text('全削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMeasurement(MeasurementData measurement) async {
    try {
      if (measurement.id != null) {
        await DatabaseService.instance.deleteMeasurement(measurement.id!);
        await _loadMeasurements();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('データを削除しました')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('削除に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearAllData() async {
    try {
      // TODO: 全削除機能を実装
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('全削除機能は今後実装予定です')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('削除に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}