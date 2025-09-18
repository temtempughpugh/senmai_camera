import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import '../blocs/camera_bloc.dart';
import '../blocs/analysis_bloc.dart';
import 'result_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'image_crop_screen.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // アプリがフォアグラウンドに戻ったときにカメラを再初期化
      final currentState = context.read<CameraBloc>().state;
      if (currentState is! CameraReadyState) {
        _initializeCamera();
      }
    }
  }

  void _initializeCamera() {
    context.read<CameraBloc>().add(CameraInitializeEvent());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 画面に戻ってきたときにカメラを再初期化
    final currentState = context.read<CameraBloc>().state;
    if (currentState is! CameraReadyState) {
      _initializeCamera();
    }
  }

@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  context.read<CameraBloc>().add(CameraDisposeEvent());
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('米吸水率判定'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.history),
            onPressed: () => _navigateToHistory(),
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => _navigateToSettings(),
          ),
        ],
      ),
      body: BlocListener<CameraBloc, CameraState>(
        listener: (context, state) {
          print('BlocListener: カメラ状態変更 - ${state.runtimeType}');
          if (state is CameraPhotoTakenState) {
            print('撮影完了 - 範囲調整画面に遷移: ${state.imagePath}');
            _navigateToCropScreen(state.imagePath);
            
            // 撮影完了後、すぐにカメラを再初期化
            Future.delayed(Duration(milliseconds: 500), () {
              if (mounted) {
                print('カメラを自動再初期化');
                context.read<CameraBloc>().add(CameraInitializeEvent());
              }
            });
          }
        },
        child: Column(
          children: [
            // カメラプレビュー部分
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: BlocBuilder<CameraBloc, CameraState>(
                  builder: (context, state) {
                    if (state is CameraLoadingState) {
                      return Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    } else if (state is CameraReadyState) {
                      return Stack(
                        children: [
                          // カメラプレビュー（タップフォーカス対応）
                          Positioned.fill(
                            child: GestureDetector(
                              onTapUp: (details) {
                                _onCameraViewTap(details, state.controller);
                              },
                              child: AspectRatio(
                                aspectRatio: state.controller.value.aspectRatio,
                                child: state.controller.buildPreview(),
                              ),
                            ),
                          ),
                          // 大きな撮影ガイド（強制的に画面からはみ出す正円）
                          Positioned.fill(
                            child: OverflowBox(
                              maxWidth: double.infinity,
                              maxHeight: double.infinity,
                              child: Center(
                                child: Container(
                                  width: 500, // 500x500に設定
                                  height: 500, // 同じ値で正円
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.red,
                                      width: 5,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '米粒をこの円内に\n収めてください',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 15.0,
                                            color: Colors.black,
                                            offset: Offset(2.0, 2.0),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    } else if (state is CameraErrorState) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.white,
                              size: 64,
                            ),
                            SizedBox(height: 16),
                            Text(
                              state.error,
                              style: TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                context.read<CameraBloc>().add(CameraInitializeEvent());
                              },
                              child: Text('再試行'),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }
                  },
                ),
              ),
            ),
            
            // 操作ボタン部分
            Expanded(
              flex: 1,
              child: Container(
                padding: EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // ギャラリー選択ボタン
                    _buildActionButton(
                      icon: Icons.photo_library,
                      label: 'ギャラリー',
                      onPressed: _selectFromGallery,
                    ),
                    
                    // 撮影ボタン
                    BlocBuilder<CameraBloc, CameraState>(
                      builder: (context, state) {
                        return Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                print('撮影ボタンタップ - 現在の状態: ${state.runtimeType}');
                                if (state is CameraReadyState) {
                                  _takePhoto();
                                } else {
                                  print('カメラが準備できていません');
                                }
                              },
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: state is CameraReadyState 
                                      ? Colors.white 
                                      : Colors.grey,
                                  border: Border.all(
                                    color: Colors.blue[800]!,
                                    width: 4,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 40,
                                  color: state is CameraReadyState 
                                      ? Colors.blue[800] 
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                            // デバッグ用：強制再初期化ボタン
                            SizedBox(height: 8),
                            if (state is! CameraReadyState)
                              ElevatedButton(
                                onPressed: () {
                                  print('強制カメラ再初期化');
                                  _initializeCamera();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                ),
                                child: Text('カメラ再起動', 
                                  style: TextStyle(fontSize: 10)),
                              ),
                          ],
                        );
                      },
                    ),
                    
                    // 設定ボタン
                    _buildActionButton(
                      icon: Icons.tune,
                      label: '設定',
                      onPressed: _navigateToSettings,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 32),
          style: IconButton.styleFrom(
            backgroundColor: Colors.blue[100],
            foregroundColor: Colors.blue[800],
            padding: EdgeInsets.all(12),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue[800],
          ),
        ),
      ],
    );
  }

  void _takePhoto() {
    print('_takePhoto メソッド呼び出し');
    context.read<CameraBloc>().add(CameraTakePhotoEvent());
  }

  // タップフォーカス機能
  void _onCameraViewTap(TapUpDetails details, CameraController controller) async {
    if (!controller.value.isInitialized) return;
    
    try {
      final offset = Offset(
        details.localPosition.dx / controller.value.previewSize!.width,
        details.localPosition.dy / controller.value.previewSize!.height,
      );
      await controller.setFocusPoint(offset);
      await controller.setExposurePoint(offset);
      print('フォーカス設定: ${offset.dx}, ${offset.dy}');
    } catch (e) {
      print('フォーカス設定エラー: $e');
    }
  }

  // 撮影後の範囲調整画面への遷移
  void _navigateToCropScreen(String imagePath) async {
    final adjustedImagePath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => ImageCropScreen(imagePath: imagePath),
      ),
    );
    
    // 範囲調整完了後、結果画面に遷移
    if (adjustedImagePath != null) {
      _navigateToResult(adjustedImagePath);
    }
  }

  void _selectFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      // 範囲調整画面に遷移
      final adjustedImagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageCropScreen(imagePath: image.path),
        ),
      );
      
      // 範囲調整完了後、結果画面に遷移
      if (adjustedImagePath != null) {
        _navigateToResult(adjustedImagePath);
      }
    }
  }

  void _navigateToResult(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<AnalysisBloc>()),
            BlocProvider.value(value: context.read<CameraBloc>()),
          ],
          child: ResultScreen(imagePath: imagePath),
        ),
      ),
    );
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryScreen(),
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(),
      ),
    );
  }
}