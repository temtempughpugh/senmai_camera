import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:camera/camera.dart';

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
      
      // カメラを取得（背面カメラを優先）
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        emit(CameraErrorState('カメラが見つかりません'));
        return;
      }
      
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
      );
      
      await _controller!.initialize();
      emit(CameraReadyState(_controller!));
    } catch (e) {
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
      
      // Future.delayedを使わずに直接Ready状態に戻す
      // ただし、画面遷移処理中は状態を変更しない
    } catch (e) {
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