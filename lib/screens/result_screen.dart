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
                  // 予測吸水率（メイン表示）
                  ResultDisplay(
                    title: '予測吸水率',
                    value: '${result.predictedRate.toStringAsFixed(1)}%',
                    isMainResult: true,
                  ),
                  
                  SizedBox(height: 16),
                  
                  // 3つの画像を同じサイズで表示
                  _buildImageGallery(),
                  
                  SizedBox(height: 16),
                  
                  // 凡例
                  Column(
                    children: [
                      Text('凡例', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildLegendItem('背景', Colors.green),
                          _buildLegendItem('透明米', Colors.blue),
                          _buildLegendItem('白濁米', Colors.red),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('分類グループ', style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildLegendItem('最明', Colors.white),
                          _buildLegendItem('明', Colors.yellow),
                          _buildLegendItem('中', Colors.green),
                          _buildLegendItem('暗', Colors.purple),
                          _buildLegendItem('最暗', Colors.black),
                        ],
                      ),
                    ],
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
                  _buildDataRow('平均明度', result.avgBrightness.toStringAsFixed(1)),
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

  Widget _buildImageGallery() {
    return FutureBuilder<List<ImageData>>(
      future: _getImageData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final images = snapshot.data!;
        
        return Column(
          children: [
            // 3つの画像を同じサイズで表示
            Row(
              children: images.map((imageData) => Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      Text(
                        imageData.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12
                        ),
                      ),
                      SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _showImageGalleryDialog(images, images.indexOf(imageData)),
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[300],
                          ),
                          child: imageData.file != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    imageData.file!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    '解析中...',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ],
        );
      },
    );
  }

  Future<List<ImageData>> _getImageData() async {
    // 元画像は元のサイズのまま
    final originalImage = File(widget.imagePath).existsSync() 
        ? File(widget.imagePath) 
        : null;
    
    // 解析画像は元画像サイズに引き延ばし
    final debugImage = await _findDebugImage();
    final classificationImage = await _findClassificationImage();
    
    return [
      ImageData(title: '元画像', file: originalImage),
      ImageData(title: '白濁判定', file: debugImage),
      ImageData(title: '分類表示', file: classificationImage),
    ];
  }

  void _showImageGalleryDialog(List<ImageData> images, int initialIndex) {
    showDialog(
      context: context,
      builder: (context) => ImageGalleryDialog(
        images: images,
        initialIndex: initialIndex,
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
    if (_selectedPolishingRatio != null) {
      await DatabaseService.instance.insertPolishingRatio(_selectedPolishingRatio!);
    }
    
    // 解析結果を更新
    final updatedResult = _currentResult!.copyWith(
      actualRate: actualRate,
      riceVariety: _selectedVariety?.name,
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
            border: color == Colors.white ? Border.all(color: Colors.grey) : null,
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
          .where((file) => file.path.contains('debug_') && 
                          !file.path.contains('classification_') && 
                          file.path.endsWith('.png'))
          .cast<File>()
          .toList();
        
        if (files.isNotEmpty) {
          files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
          print('デバッグ画像を取得: ${files.first.path}');
          return files.first;
        }
      }
    } catch (e) {
      print('デバッグ画像取得エラー: $e');
    }
    return null;
  }

  Future<File?> _findClassificationImage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final debugDir = Directory('${directory.path}/debug_images');
      
      if (await debugDir.exists()) {
        final files = debugDir.listSync()
          .where((file) => file.path.contains('classification_') && 
                          file.path.endsWith('.png'))
          .cast<File>()
          .toList();
        
        if (files.isNotEmpty) {
          files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
          print('分類画像を取得: ${files.first.path}');
          return files.first;
        }
      }
    } catch (e) {
      print('分類画像取得エラー: $e');
    }
    return null;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class ImageData {
  final String title;
  final File? file;
  
  ImageData({required this.title, this.file});
}

class ImageGalleryDialog extends StatefulWidget {
  final List<ImageData> images;
  final int initialIndex;
  
  const ImageGalleryDialog({
    Key? key,
    required this.images,
    required this.initialIndex,
  }) : super(key: key);
  
  @override
  _ImageGalleryDialogState createState() => _ImageGalleryDialogState();
}

class _ImageGalleryDialogState extends State<ImageGalleryDialog> {
  late PageController _pageController;
  late int _currentIndex;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // 画像表示エリア
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              final imageData = widget.images[index];
              return Container(
                width: double.infinity,
                height: double.infinity,
                child: imageData.file != null
                    ? InteractiveViewer(
                        panEnabled: true,
                        boundaryMargin: EdgeInsets.all(20),
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.file(
                          imageData.file!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Center(
                        child: Text(
                          '画像を読み込めません',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
              );
            },
          ),
          
          // 上部のタイトルバー
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        widget.images[_currentIndex].title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: 48), // アイコンボタンのサイズ分のスペース
                  ],
                ),
              ),
            ),
          ),
          
          // 下部のページインジケーター
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: widget.images.asMap().entries.map((entry) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == entry.key
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}