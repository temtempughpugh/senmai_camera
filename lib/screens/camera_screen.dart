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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<CameraBloc>().add(CameraDisposeEvent());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<CameraBloc, CameraState>(
        listener: (context, state) {
          print('BlocListener: カメラ状態変更 - ${state.runtimeType}');
          if (state is CameraPhotoTakenState) {
            print('撮影完了 - 範囲調整画面に遷移: ${state.imagePath}');
            _navigateToCropScreen(state.imagePath);
            
            // 撮影完了後、カメラを再初期化
            Future.delayed(Duration(milliseconds: 500), () {
              if (mounted) {
                print('カメラを自動再初期化');
                context.read<CameraBloc>().add(CameraInitializeEvent());
              }
            });
          }
        },
        child: Stack(
          children: [
            // カメラプレビュー（適切なアスペクト比で表示）
            Positioned.fill(
              child: Container(
                color: Colors.black,
                child: BlocBuilder<CameraBloc, CameraState>(
                  builder: (context, state) {
                    if (state is CameraLoadingState) {
                      return Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    } else if (state is CameraReadyState) {
                      return Center(
                        child: GestureDetector(
                          onTapUp: (details) => _onCameraViewTap(details, state.controller),
                          child: CameraPreview(state.controller),
                        ),
                      );
                    } else if (state is CameraErrorState) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, color: Colors.white, size: 64),
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
            
            // 上部のAppBar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  height: 56,
                  padding: EdgeInsets.symmetric(horizontal: 16),
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
                  child: Row(
                    children: [
                      Text(
                        '米吸水率判定',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.history, color: Colors.white),
                        onPressed: () => _navigateToHistory(),
                      ),
                      IconButton(
                        icon: Icon(Icons.settings, color: Colors.white),
                        onPressed: () => _navigateToSettings(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // 下部のボタン
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
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
                          return GestureDetector(
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
            backgroundColor: Colors.white.withOpacity(0.2),
            foregroundColor: Colors.white,
            padding: EdgeInsets.all(12),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  void _takePhoto() {
    print('_takePhoto メソッド呼び出し');
    context.read<CameraBloc>().add(CameraTakePhotoEvent());
  }

  void _onCameraViewTap(TapUpDetails details, CameraController controller) async {
    if (!controller.value.isInitialized) return;
    
    try {
      // タップ位置を正規化（0.0-1.0の範囲）
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final offset = Offset(
        details.localPosition.dx / renderBox.size.width,
        details.localPosition.dy / renderBox.size.height,
      );
      
      print('フォーカス設定: ${offset.dx.toStringAsFixed(3)}, ${offset.dy.toStringAsFixed(3)}');
      
      // フォーカスと露出を設定
      await controller.setFocusPoint(offset);
      await controller.setExposurePoint(offset);
      
    } catch (e) {
      print('フォーカス設定エラー: $e');
    }
  }

  void _navigateToCropScreen(String imagePath) async {
    final adjustedImagePath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => ImageCropScreen(imagePath: imagePath),
      ),
    );
    
    if (adjustedImagePath != null) {
      _navigateToResult(adjustedImagePath);
    }
  }

  void _selectFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final adjustedImagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageCropScreen(imagePath: image.path),
        ),
      );
      
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