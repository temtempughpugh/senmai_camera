import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/analysis_result.dart';
import '../services/image_processor.dart';

// Events
abstract class AnalysisEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class AnalyzeImageEvent extends AnalysisEvent {
  final String imagePath;
  
  AnalyzeImageEvent(this.imagePath);
  
  @override
  List<Object?> get props => [imagePath];
}

class SaveActualValueEvent extends AnalysisEvent {
  final double actualValue;
  final AnalysisResult result;
  
  SaveActualValueEvent(this.actualValue, this.result);
  
  @override
  List<Object?> get props => [actualValue, result];
}

// States
abstract class AnalysisState extends Equatable {
  @override
  List<Object?> get props => [];
}

class AnalysisInitialState extends AnalysisState {}
class AnalysisLoadingState extends AnalysisState {}
class AnalysisCompleteState extends AnalysisState {
  final AnalysisResult result;
  
  AnalysisCompleteState(this.result);
  
  @override
  List<Object?> get props => [result];
}

class AnalysisErrorState extends AnalysisState {
  final String error;
  
  AnalysisErrorState(this.error);
  
  @override
  List<Object?> get props => [error];
}

class AnalysisSavedState extends AnalysisState {
  final String message;
  
  AnalysisSavedState(this.message);
  
  @override
  List<Object?> get props => [message];
}

// BLoC
class AnalysisBloc extends Bloc<AnalysisEvent, AnalysisState> {
  final ImageProcessorService _imageProcessor = ImageProcessorService.instance;
  
  AnalysisBloc() : super(AnalysisInitialState()) {
    on<AnalyzeImageEvent>(_onAnalyzeImage);
    on<SaveActualValueEvent>(_onSaveActualValue);
  }
  
  void _onAnalyzeImage(AnalyzeImageEvent event, Emitter<AnalysisState> emit) async {
    try {
      emit(AnalysisLoadingState());
      
      // 実際の画像処理を実行（軽量版）
      final result = await _imageProcessor.analyzeImage(event.imagePath);
      
      emit(AnalysisCompleteState(result));
    } catch (e) {
      emit(AnalysisErrorState('解析エラー: $e'));
    }
  }
  
  void _onSaveActualValue(SaveActualValueEvent event, Emitter<AnalysisState> emit) async {
    try {
      // TODO: データベースに保存する処理を実装
      await Future.delayed(Duration(milliseconds: 500)); // 保存処理のシミュレート
      
      emit(AnalysisSavedState('データを保存しました'));
    } catch (e) {
      emit(AnalysisErrorState('保存エラー: $e'));
    }
  }
}