import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rice_variety.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  RiceVariety? _defaultVariety;
  int? _defaultPolishingRatio;
  bool _autoSaveImages = true;
  bool _enableHapticFeedback = true;
  int _imageQuality = 80;
  
  final TextEditingController _customVarietyController = TextEditingController();
  final TextEditingController _customRatioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _customVarietyController.dispose();
    _customRatioController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      _autoSaveImages = prefs.getBool('autoSaveImages') ?? true;
      _enableHapticFeedback = prefs.getBool('enableHapticFeedback') ?? true;
      _imageQuality = prefs.getInt('imageQuality') ?? 80;
      
      final varietyName = prefs.getString('defaultVariety');
      if (varietyName != null) {
        _defaultVariety = PredefinedRiceVarieties.varieties
            .firstWhere((v) => v.name == varietyName, orElse: () => PredefinedRiceVarieties.varieties.first);
      }
      
      _defaultPolishingRatio = prefs.getInt('defaultPolishingRatio');
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setBool('autoSaveImages', _autoSaveImages);
    await prefs.setBool('enableHapticFeedback', _enableHapticFeedback);
    await prefs.setInt('imageQuality', _imageQuality);
    
    if (_defaultVariety != null) {
      await prefs.setString('defaultVariety', _defaultVariety!.name);
    }
    
    if (_defaultPolishingRatio != null) {
      await prefs.setInt('defaultPolishingRatio', _defaultPolishingRatio!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('設定'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: () async {
              await _saveSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('設定を保存しました')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // デフォルト設定セクション
          _buildSectionHeader('デフォルト設定'),
          _buildDefaultVarietyTile(),
          _buildDefaultPolishingRatioTile(),
          
          Divider(),
          
          // カスタム品種・精米歩合追加
          _buildSectionHeader('カスタム設定'),
          _buildAddCustomVarietyTile(),
          _buildAddCustomRatioTile(),
          
          Divider(),
          
          // アプリ設定セクション
          _buildSectionHeader('アプリ設定'),
          _buildAutoSaveImagesTile(),
          _buildHapticFeedbackTile(),
          _buildImageQualityTile(),
          
          Divider(),
          
          // データ管理セクション
          _buildSectionHeader('データ管理'),
          _buildExportDataTile(),
          _buildClearDataTile(),
          _buildResetSettingsTile(),
          
          Divider(),
          
          // アプリ情報セクション
          _buildSectionHeader('アプリ情報'),
          _buildAppVersionTile(),
          _buildAboutTile(),
          
          SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue[800],
        ),
      ),
    );
  }

  Widget _buildDefaultVarietyTile() {
    return FutureBuilder<List<RiceVariety>>(
      future: DatabaseService.instance.getAllRiceVarieties(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return ListTile(
            leading: Icon(Icons.rice_bowl),
            title: Text('デフォルト品種'),
            subtitle: Text('読み込み中...'),
          );
        }
        
        return ListTile(
          leading: Icon(Icons.rice_bowl),
          title: Text('デフォルト品種'),
          subtitle: Text(_defaultVariety?.name ?? '未設定'),
          trailing: Icon(Icons.chevron_right),
          onTap: () => _showVarietySelector(snapshot.data!),
        );
      },
    );
  }

  Widget _buildDefaultPolishingRatioTile() {
    return ListTile(
      leading: Icon(Icons.tune),
      title: Text('デフォルト精米歩合'),
      subtitle: Text(_defaultPolishingRatio != null ? '${_defaultPolishingRatio}%' : '未設定'),
      trailing: Icon(Icons.chevron_right),
      onTap: _showPolishingRatioSelector,
    );
  }

  Widget _buildAddCustomVarietyTile() {
    return ListTile(
      leading: Icon(Icons.add),
      title: Text('カスタム品種を追加'),
      subtitle: Text('独自の米品種を追加できます'),
      onTap: _showAddCustomVarietyDialog,
    );
  }

  Widget _buildAddCustomRatioTile() {
    return ListTile(
      leading: Icon(Icons.add),
      title: Text('カスタム精米歩合を追加'),
      subtitle: Text('よく使う精米歩合を追加できます'),
      onTap: _showAddCustomRatioDialog,
    );
  }

  Widget _buildAutoSaveImagesTile() {
    return SwitchListTile(
      secondary: Icon(Icons.save_alt),
      title: Text('画像の自動保存'),
      subtitle: Text('撮影した画像を自動的に端末に保存'),
      value: _autoSaveImages,
      onChanged: (value) {
        setState(() {
          _autoSaveImages = value;
        });
      },
    );
  }

  Widget _buildHapticFeedbackTile() {
    return SwitchListTile(
      secondary: Icon(Icons.vibration),
      title: Text('ハプティックフィードバック'),
      subtitle: Text('ボタンタップ時の振動'),
      value: _enableHapticFeedback,
      onChanged: (value) {
        setState(() {
          _enableHapticFeedback = value;
        });
      },
    );
  }

  Widget _buildImageQualityTile() {
    return ListTile(
      leading: Icon(Icons.high_quality),
      title: Text('画像品質'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_imageQuality}%'),
          Slider(
            value: _imageQuality.toDouble(),
            min: 50,
            max: 100,
            divisions: 10,
            onChanged: (value) {
              setState(() {
                _imageQuality = value.round();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExportDataTile() {
    return ListTile(
      leading: Icon(Icons.download),
      title: Text('データのエクスポート'),
      subtitle: Text('測定データをCSV形式で出力'),
      onTap: _exportData,
    );
  }

  Widget _buildClearDataTile() {
    return ListTile(
      leading: Icon(Icons.delete, color: Colors.red),
      title: Text('全データの削除', style: TextStyle(color: Colors.red)),
      subtitle: Text('すべての測定データを削除します'),
      onTap: _showClearDataConfirmation,
    );
  }

  Widget _buildResetSettingsTile() {
    return ListTile(
      leading: Icon(Icons.restore, color: Colors.orange),
      title: Text('設定のリセット', style: TextStyle(color: Colors.orange)),
      subtitle: Text('すべての設定を初期値に戻します'),
      onTap: _showResetSettingsConfirmation,
    );
  }

  Widget _buildAppVersionTile() {
    return ListTile(
      leading: Icon(Icons.info),
      title: Text('アプリバージョン'),
      subtitle: Text('1.0.0'),
    );
  }

  Widget _buildAboutTile() {
    return ListTile(
      leading: Icon(Icons.help),
      title: Text('アプリについて'),
      subtitle: Text('使い方とサポート情報'),
      onTap: _showAboutDialog,
    );
  }

  void _showVarietySelector(List<RiceVariety> varieties) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('デフォルト品種を選択'),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: varieties.length,
            itemBuilder: (context, index) {
              final variety = varieties[index];
              return RadioListTile<RiceVariety>(
                title: Text(variety.name),
                subtitle: Text(variety.absorptionCharacteristics),
                value: variety,
                groupValue: _defaultVariety,
                onChanged: (value) {
                  setState(() {
                    _defaultVariety = value;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  void _showPolishingRatioSelector() {
    final ratios = PolishingRatioManager.getAllRatios();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('デフォルト精米歩合を選択'),
        content: Container(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: ratios.length,
            itemBuilder: (context, index) {
              final ratio = ratios[index];
              return RadioListTile<int>(
                title: Text('${ratio}%'),
                value: ratio,
                groupValue: _defaultPolishingRatio,
                onChanged: (value) {
                  setState(() {
                    _defaultPolishingRatio = value;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
        ],
      ),
    );
  }

  void _showAddCustomVarietyDialog() {
    _customVarietyController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('カスタム品種を追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _customVarietyController,
              decoration: InputDecoration(
                labelText: '品種名',
                hintText: '例: 地元の酒米',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              final name = _customVarietyController.text.trim();
              if (name.isNotEmpty) {
                final variety = RiceVariety(
                  name: name,
                  absorptionCharacteristics: 'ユーザー追加品種',
                );
                await DatabaseService.instance.insertUserRiceVariety(variety);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('品種「$name」を追加しました')),
                );
              }
            },
            child: Text('追加'),
          ),
        ],
      ),
    );
  }

  void _showAddCustomRatioDialog() {
    _customRatioController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('カスタム精米歩合を追加'),
        content: TextField(
          controller: _customRatioController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '精米歩合 (%)',
            hintText: '例: 45',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              final ratioText = _customRatioController.text.trim();
              final ratio = int.tryParse(ratioText);
              if (ratio != null && PolishingRatioManager.isValidRatio(ratio)) {
                await DatabaseService.instance.insertPolishingRatio(ratio);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('精米歩合${ratio}%を追加しました')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('正しい精米歩合を入力してください (10-100%)'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('追加'),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    // TODO: CSV出力機能を実装
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('CSV出力機能は今後実装予定です')),
    );
  }

  void _showClearDataConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('全データ削除'),
        content: Text('すべての測定データを削除しますか？この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: 全データ削除機能を実装
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('全データ削除機能は今後実装予定です')),
              );
            },
            child: Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showResetSettingsConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('設定リセット'),
        content: Text('すべての設定を初期値に戻しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resetSettings();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('設定をリセットしました')),
              );
            },
            child: Text('リセット', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('米吸水率判定アプリについて'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('日本酒製造における米の吸水工程を支援するアプリです。'),
            SizedBox(height: 16),
            Text('使い方:'),
            Text('1. 米を撮影または画像を選択'),
            Text('2. 自動で吸水率を予測'),
            Text('3. 実測値を入力して学習データを蓄積'),
            SizedBox(height: 16),
            Text('バージョン: 1.0.0'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _loadSettings();
  }
}