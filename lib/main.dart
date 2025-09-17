import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import 'screens/camera_screen.dart';
import 'blocs/camera_bloc.dart';
import 'blocs/analysis_bloc.dart';
import 'services/database_service.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // カメラの初期化
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('カメラエラー: $e');
  }
  
  // データベースの初期化
  await DatabaseService.instance.initialize();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => CameraBloc()),
        BlocProvider(create: (context) => AnalysisBloc()),
      ],
      child: MaterialApp(
        title: '米吸水率判定アプリ',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: CameraScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}