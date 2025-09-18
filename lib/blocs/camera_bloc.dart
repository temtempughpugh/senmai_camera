import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

// Events
abstract class CameraEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class CameraInitializeEvent extends CameraEvent {}
class CameraTakePhotoEvent extends CameraEvent {}
class CameraDisposeEvent extends CameraEvent {}

// States
abstract class CameraState extends Equatable {
  @override
  List<Object?> get props => [];
}

class CameraInitialState extends CameraState {}
class CameraLoadingState extends CameraState {}
class CameraReadyState extends CameraState {
  final CameraController controller;
  
  CameraReadyState(this.controller);
  
  @override
  List<Object?> get props => [controller];
}

class CameraErrorState extends CameraState {
  final String error;
  
  CameraErrorState(this.error);
  
  @override
  List<Object?> get props => [error];
}

class CameraPhotoTakenState extends CameraState {
  final String imagePath;
  
  CameraPhotoTakenState(this.imagePath);
  
  @override
  List<Object?> get props => [imagePath];
}

// BLoC
class CameraBloc extends Bloc<CameraEvent, CameraState> {
  CameraController? _controller;
  
  CameraBloc() : super(CameraInitialState()) {
    on<CameraInitializeEvent>(_onInitialize);
    on<CameraTakePhotoEvent>(_onTakePhoto);
    on<CameraDisposeEvent>(_onDispose);
  }
  
  void _onInitialize(CameraInitializeEvent event, Emitter<CameraState> emit) async {
    try {
      emit(CameraLoadingState());
      
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        emit(CameraErrorState('カメラが見つかりません'));
        return;
      }
      
      // iPhone 15のアスペクト比（19.5:9）に最も近い解像度を選択
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.max, // 最高解像度でiPhone 15のアスペクト比に近づける
        enableAudio: false,
      );
      
      await _controller!.initialize();
      
      print('カメラ解像度: ${_controller!.value.previewSize}');
      print('カメラアスペクト比: ${_controller!.value.aspectRatio}');
      
      emit(CameraReadyState(_controller!));
    } catch (e) {
      print('カメラ初期化エラー: $e');
      emit(CameraErrorState('カメラ初期化エラー: $e'));
    }
  }
  
  void _onTakePhoto(CameraTakePhotoEvent event, Emitter<CameraState> emit) async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) {
        emit(CameraErrorState('カメラが初期化されていません'));
        return;
      }
      
      final image = await _controller!.takePicture();
      emit(CameraPhotoTakenState(image.path));
      
    } catch (e) {
      print('撮影エラー: $e');
      emit(CameraErrorState('撮影エラー: $e'));
    }
  }
  
  void _onDispose(CameraDisposeEvent event, Emitter<CameraState> emit) async {
    await _controller?.dispose();
    _controller = null;
  }
  
  @override
  Future<void> close() {
    _controller?.dispose();
    return super.close();
  }
}