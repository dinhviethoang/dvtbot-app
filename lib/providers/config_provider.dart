import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_assistant/models/xiaozhi_config.dart';
import 'package:ai_assistant/utils/device_util.dart';

class ConfigProvider extends ChangeNotifier {
  List<XiaozhiConfig> _xiaozhiConfigs = [];
  bool _isLoaded = false;
  String _appMode = 'xiaozhi'; // 'xiaozhi' hoặc 'gemini'
  String _geminiApiKey = '';

  List<XiaozhiConfig> get xiaozhiConfigs => _xiaozhiConfigs;
  bool get isLoaded => _isLoaded;
  String get appMode => _appMode;
  bool get isGeminiMode => _appMode == 'gemini';
  String get geminiApiKey => _geminiApiKey;

  ConfigProvider() {
    loadConfigs();
  }

  Future<void> loadConfigs() async {
    final prefs = await SharedPreferences.getInstance();

    _appMode = prefs.getString('app_mode') ?? 'xiaozhi';
    _geminiApiKey = prefs.getString('gemini_api_key') ?? '';

    // Load Xiaozhi configs
    final xiaozhiConfigsJson = prefs.getStringList('xiaozhiConfigs') ?? [];
    _xiaozhiConfigs =
        xiaozhiConfigsJson
            .map((json) => XiaozhiConfig.fromJson(jsonDecode(json)))
            .toList();

    final defaultMac = await DeviceUtil.getDeviceMac();
    bool needSave = false;

    // Tự tạo cấu hình mặc định nếu danh sách trống (lần đầu mở app)
    if (_xiaozhiConfigs.isEmpty) {
      _xiaozhiConfigs.add(
        XiaozhiConfig(
          id: 'default_botai',
          name: 'botAi',
          otaUrl: XiaozhiConfig.defaultOtaUrl,
          websocketUrl: '',
          macAddress: defaultMac,
          token: 'test-token',
        ),
      );
      needSave = true;
    } else {
      // Nâng cấp tên mặc định cũ nếu có mà không ghi đè cấu hình cá nhân
      for (int i = 0; i < _xiaozhiConfigs.length; i++) {
        final config = _xiaozhiConfigs[i];
        if (config.id == 'default_hdvbot' ||
            (config.id == 'default_botai' &&
                (config.name == 'HDVbot' || config.name == 'DVTbot'))) {
          _xiaozhiConfigs[i] = config.copyWith(
            id: 'default_botai',
            name: 'botAi',
          );
          needSave = true;
        }
      }
      // Mọi cấu hình có macAddress không đúng định dạng MAC thì tự thay bằng MAC chuẩn
      for (int i = 0; i < _xiaozhiConfigs.length; i++) {
        final config = _xiaozhiConfigs[i];
        if (!DeviceUtil.isValidMac(config.macAddress)) {
          _xiaozhiConfigs[i] = config.copyWith(macAddress: defaultMac);
          needSave = true;
        }
      }
    }

    if (needSave) {
      await _saveConfigs();
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveConfigs() async {
    final prefs = await SharedPreferences.getInstance();

    // Save Xiaozhi configs
    final xiaozhiConfigsJson =
        _xiaozhiConfigs.map((config) => jsonEncode(config.toJson())).toList();
    await prefs.setStringList('xiaozhiConfigs', xiaozhiConfigsJson);
  }

  Future<void> setAppMode(String mode) async {
    _appMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_mode', mode);
    notifyListeners();
  }

  Future<void> setGeminiApiKey(String key) async {
    _geminiApiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', key);
    notifyListeners();
  }

  Future<void> addXiaozhiConfig(
    String name,
    String websocketUrl, {
    String? customMacAddress,
    String? otaUrl,
    String? token,
  }) async {
    final defaultMac = await DeviceUtil.getDeviceMac();
    final macAddress =
        (customMacAddress != null && DeviceUtil.isValidMac(customMacAddress))
            ? customMacAddress.toLowerCase()
            : defaultMac;

    final newConfig = XiaozhiConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      otaUrl:
          (otaUrl != null && otaUrl.isNotEmpty)
              ? otaUrl
              : XiaozhiConfig.defaultOtaUrl,
      websocketUrl: websocketUrl,
      macAddress: macAddress,
      token: (token != null && token.isNotEmpty) ? token : 'test-token',
    );

    _xiaozhiConfigs.add(newConfig);
    await _saveConfigs();
    notifyListeners();
  }

  Future<void> updateXiaozhiConfig(XiaozhiConfig updatedConfig) async {
    final index = _xiaozhiConfigs.indexWhere(
      (config) => config.id == updatedConfig.id,
    );
    if (index != -1) {
      _xiaozhiConfigs[index] = updatedConfig;
      await _saveConfigs();
      notifyListeners();
    }
  }

  Future<void> deleteXiaozhiConfig(String id) async {
    _xiaozhiConfigs.removeWhere((config) => config.id == id);
    await _saveConfigs();
    notifyListeners();
  }

  Future<String> _getDeviceMacAddress() async {
    return await DeviceUtil.getDeviceMac();
  }
}
