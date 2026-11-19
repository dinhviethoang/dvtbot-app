import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ai_assistant/providers/config_provider.dart';
import 'package:ai_assistant/models/xiaozhi_config.dart';
import 'package:flutter/services.dart';
import 'package:ai_assistant/services/xiaozhi_ota_service.dart';
import 'package:ai_assistant/utils/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final int initialTab;
  final bool autoShowAddDialog;

  const SettingsScreen({
    super.key,
    this.initialTab = 0,
    this.autoShowAddDialog = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _voiceWakeEnabled = true;
  double _voiceWakeDbfs = -30.0;

  @override
  void initState() {
    super.initState();
    _loadVoiceWakeSettings();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );

    if (widget.autoShowAddDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddXiaozhiConfigDialog();
      });
    }
  }

  Future<void> _loadVoiceWakeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _voiceWakeEnabled = prefs.getBool('voice_wake_enabled') ?? true;
        _voiceWakeDbfs = prefs.getDouble('voice_wake_dbfs') ?? -30.0;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        toolbarHeight: 70,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppTheme.primaryColor,
            size: 26,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Cài đặt',
          style: TextStyle(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildGeneralTab(), _buildXiaozhiConfigTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.backgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              spreadRadius: 0,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          indicatorPadding: const EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 3,
          ),
          labelPadding: EdgeInsets.zero,
          padding: EdgeInsets.zero,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.secondaryTextColor,
          dividerColor: Colors.transparent,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          splashFactory: NoSplash.splashFactory,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
          tabs: const [Tab(text: 'Chung'), Tab(text: 'Xiaozhi AI')],
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCard(
              title: 'Giới thiệu',
              subtitle: 'Thông tin ứng dụng',
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/logo_king.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              child: const Icon(
                                Icons.smart_toy_outlined,
                                size: 32,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'botAi',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Phiên bản 2.0.0 (Bản cá nhân)',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Trợ lý robot giọng nói Xiaozhi AI',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildCard(
              title: 'Đánh thức bằng giọng nói',
              subtitle: 'Tự động đánh thức robot khi phát hiện tiếng nói',
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Bật đánh thức bằng giọng nói',
                        style: TextStyle(
                          color: AppTheme.textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: const Text(
                        'Robot mở micro cục bộ khi ngủ để tự thức dậy',
                        style: TextStyle(
                          color: AppTheme.secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                      activeColor: AppTheme.primaryColor,
                      value: _voiceWakeEnabled,
                      onChanged: (val) async {
                        setState(() => _voiceWakeEnabled = val);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('voice_wake_enabled', val);
                      },
                    ),
                    if (_voiceWakeEnabled) ...[
                      const Divider(color: AppTheme.borderColor),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Độ nhạy đánh thức bằng giọng nói',
                                  style: TextStyle(
                                    color: AppTheme.textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: AppTheme.primaryColor.withOpacity(
                                        0.4,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '${_voiceWakeDbfs.round()} dBFS',
                                    style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _voiceWakeDbfs,
                              min: -45.0,
                              max: -15.0,
                              divisions: 30,
                              activeColor: AppTheme.primaryColor,
                              inactiveColor: AppTheme.borderColor,
                              label: '${_voiceWakeDbfs.round()} dBFS',
                              onChanged: (val) async {
                                setState(() => _voiceWakeDbfs = val);
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setDouble('voice_wake_dbfs', val);
                                final threshold =
                                    math.pow(10, val / 20).toDouble();
                                await prefs.setDouble(
                                  'voice_wake_threshold',
                                  threshold,
                                );
                              },
                            ),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Nhạy hơn (-45 dBFS)',
                                  style: TextStyle(
                                    color: AppTheme.secondaryTextColor,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  'Nói to (-15 dBFS)',
                                  style: TextStyle(
                                    color: AppTheme.secondaryTextColor,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelectionCard() {
    return Consumer<ConfigProvider>(
      builder: (context, configProvider, child) {
        final currentMode = configProvider.appMode;
        final geminiKeyController = TextEditingController(
          text: configProvider.geminiApiKey,
        );

        return _buildCard(
          title: 'Chế độ hoạt động AI',
          subtitle: 'Chọn phương thức kết nối AI cho botAi',
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chế độ 1: Xiaozhi Server
                Container(
                  decoration: BoxDecoration(
                    color:
                        currentMode == 'xiaozhi'
                            ? AppTheme.primaryColor.withOpacity(0.12)
                            : AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          currentMode == 'xiaozhi'
                              ? AppTheme.primaryColor
                              : AppTheme.borderColor,
                    ),
                  ),
                  child: RadioListTile<String>(
                    title: const Text(
                      'Chế độ 1: Xiaozhi Server (Mặc định)',
                      style: TextStyle(
                        color: AppTheme.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: const Text(
                      'Kết nối hệ sinh thái Xiaozhi qua OTA và WebSocket thời gian thực.',
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 13,
                      ),
                    ),
                    value: 'xiaozhi',
                    groupValue: currentMode,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      if (val != null) configProvider.setAppMode(val);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Chế độ 2: Gemini Direct API (Fallback)
                Container(
                  decoration: BoxDecoration(
                    color:
                        currentMode == 'gemini'
                            ? AppTheme.primaryColor.withOpacity(0.12)
                            : AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          currentMode == 'gemini'
                              ? AppTheme.primaryColor
                              : AppTheme.borderColor,
                    ),
                  ),
                  child: RadioListTile<String>(
                    title: const Text(
                      'Chế độ 2: Gemini Direct API (Fallback)',
                      style: TextStyle(
                        color: AppTheme.textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: const Text(
                      'Giao tiếp trực tiếp với Google Gemini AI khi không dùng server Xiaozhi.',
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 13,
                      ),
                    ),
                    value: 'gemini',
                    groupValue: currentMode,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      if (val != null) configProvider.setAppMode(val);
                    },
                  ),
                ),
                if (currentMode == 'gemini') ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Gemini API Key:',
                    style: TextStyle(
                      color: AppTheme.textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: TextField(
                            controller: geminiKeyController,
                            style: const TextStyle(
                              color: AppTheme.textColor,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Nhập Google Gemini API Key...',
                              hintStyle: TextStyle(
                                color: AppTheme.secondaryTextColor,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          await configProvider.setGeminiApiKey(
                            geminiKeyController.text.trim(),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Đã lưu Gemini API Key thành công!',
                                ),
                                backgroundColor: AppTheme.primaryColor,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: const Color(0xFF070B12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Lưu'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _testOtaAndShowCode(XiaozhiConfig config) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const Center(
            child: Card(
              color: AppTheme.surfaceColor,
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primaryColor),
                    SizedBox(height: 16),
                    Text(
                      'Đang kết nối OTA lấy mã xác minh...',
                      style: TextStyle(color: AppTheme.textColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    try {
      final otaService = XiaozhiOtaService();
      final result = await otaService.checkVersion(
        otaUrl: config.otaUrl,
        mac: config.macAddress,
        clientId: config.macAddress,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.borderColor),
              ),
              title: const Text(
                'Thông tin OTA & Kích hoạt',
                style: TextStyle(
                  color: AppTheme.textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Địa chỉ MAC thiết bị:',
                                style: TextStyle(
                                  color: AppTheme.secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                config.macAddress,
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.copy,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: config.macAddress),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Đã sao chép MAC: ${config.macAddress}',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (result.hasActivationCode) ...[
                    const Text(
                      'MÃ XÁC MINH 6 SỐ:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.accentColor,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        result.activationCode!.split('').join(' '),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentColor,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: result.activationCode!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Đã sao chép mã: ${result.activationCode}',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.copy,
                        size: 16,
                        color: AppTheme.accentColor,
                      ),
                      label: const Text(
                        'Sao chép mã xác minh',
                        style: TextStyle(color: AppTheme.accentColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nhập mã này lên trang web xiaozhi.me để liên kết thiết bị!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textColor, fontSize: 13),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Thiết bị đã được kích hoạt thành công!',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (result.websocketUrl != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'WebSocket URL: ${result.websocketUrl}',
                        style: const TextStyle(
                          color: AppTheme.secondaryTextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: AppTheme.surfaceColor,
              title: const Text(
                'Lỗi kết nối OTA',
                style: TextStyle(color: AppTheme.errorColor),
              ),
              content: Text(
                e.toString().replaceFirst('Exception: ', ''),
                style: const TextStyle(color: AppTheme.textColor),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
      );
    }
  }

  Widget _buildXiaozhiConfigTab() {
    return Consumer<ConfigProvider>(
      builder: (context, configProvider, child) {
        final xiaozhiConfigs = configProvider.xiaozhiConfigs;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCard(
                title: 'Cấu hình dịch vụ Xiaozhi',
                subtitle: 'Quản lý cấu hình kết nối giọng nói Xiaozhi',
                actionButton: ElevatedButton.icon(
                  onPressed: _showAddXiaozhiConfigDialog,
                  icon: const Icon(
                    Icons.add,
                    color: Color(0xFF070B12),
                    size: 18,
                  ),
                  label: const Text(
                    'Thêm dịch vụ',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: const Color(0xFF070B12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                    minimumSize: const Size(100, 36),
                  ),
                ),
                child: Column(
                  children: [
                    if (xiaozhiConfigs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'Chưa có cấu hình Xiaozhi nào.\nNhấn nút "Thêm dịch vụ" ở trên để bắt đầu.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.secondaryTextColor,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    else
                      ...xiaozhiConfigs.map(
                        (config) => _buildXiaozhiConfigCard(config),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildXiaozhiConfigCard(XiaozhiConfig config) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.5),
                    ),
                  ),
                  child: const CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.surfaceColor,
                    child: Icon(
                      Icons.mic,
                      color: AppTheme.primaryColor,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        config.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.textColor,
                        ),
                      ),
                      Text(
                        config.websocketUrl.isNotEmpty
                            ? config.websocketUrl
                            : 'OTA: ${config.otaUrl}',
                        style: const TextStyle(
                          color: AppTheme.secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                    onPressed: () => _showEditXiaozhiConfigDialog(config),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppTheme.errorColor,
                      size: 22,
                    ),
                    onPressed: () => _showDeleteXiaozhiConfigDialog(config),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Địa chỉ MAC:',
                        style: TextStyle(
                          color: AppTheme.secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        config.macAddress.isEmpty
                            ? 'Tự động'
                            : config.macAddress,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Token:',
                        style: TextStyle(
                          color: AppTheme.secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        config.token.isEmpty ? 'Mặc định' : config.token,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final mac =
                          config.macAddress.isEmpty
                              ? 'Chưa có MAC'
                              : config.macAddress;
                      Clipboard.setData(ClipboardData(text: mac));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã sao chép MAC: ' + mac),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.copy,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    label: const Text(
                      'Sao chép MAC',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _testOtaAndShowCode(config),
                    icon: const Icon(
                      Icons.qr_code,
                      size: 16,
                      color: Color(0xFF070B12),
                    ),
                    label: const Text(
                      'Lấy mã 6 số OTA',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: const Color(0xFF070B12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? actionButton,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.secondaryTextColor,
                      ),
                    ),
                  ],
                ),
                if (actionButton != null) actionButton,
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderColor),
          child,
        ],
      ),
    );
  }

  void _showAddXiaozhiConfigDialog() {
    final nameController = TextEditingController(text: 'botAi');
    final otaUrlController = TextEditingController(
      text: XiaozhiConfig.defaultOtaUrl,
    );
    final websocketUrlController = TextEditingController();
    final tokenController = TextEditingController();
    final macAddressController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            elevation: 8,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Thêm dịch vụ Xiaozhi',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 20,
                              color: AppTheme.secondaryTextColor,
                            ),
                            onPressed: () => Navigator.pop(context),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cấu hình kết nối dịch vụ giọng nói Xiaozhi',
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Tên dịch vụ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: TextField(
                        controller: nameController,
                        style: const TextStyle(color: AppTheme.textColor),
                        decoration: const InputDecoration(
                          hintText: 'Ví dụ: botAi',
                          hintStyle: TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Địa chỉ OTA',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: TextField(
                        controller: otaUrlController,
                        style: const TextStyle(color: AppTheme.textColor),
                        decoration: const InputDecoration(
                          hintText: XiaozhiConfig.defaultOtaUrl,
                          hintStyle: TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Địa chỉ WebSocket (Tùy chọn)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: TextField(
                        controller: websocketUrlController,
                        style: const TextStyle(color: AppTheme.textColor),
                        decoration: const InputDecoration(
                          hintText: 'Tự điền sau khi kích hoạt',
                          hintStyle: TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tự điền sau khi kích hoạt OTA, không bắt buộc nhập',
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Địa chỉ MAC (Tùy chọn)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: TextField(
                        controller: macAddressController,
                        style: const TextStyle(color: AppTheme.textColor),
                        decoration: const InputDecoration(
                          hintText: 'Để trống sẽ tự động tạo từ thiết bị',
                          hintStyle: TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Để trống sẽ tự tạo địa chỉ MAC cố định theo máy',
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Token (Tùy chọn)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: TextField(
                        controller: tokenController,
                        style: const TextStyle(color: AppTheme.textColor),
                        decoration: const InputDecoration(
                          hintText: 'Mặc định: test-token',
                          hintStyle: TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        final name = nameController.text.trim();
                        final otaUrl = otaUrlController.text.trim();
                        final websocketUrl = websocketUrlController.text.trim();
                        final macAddress = macAddressController.text.trim();
                        final token = tokenController.text.trim();

                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Vui lòng nhập Tên dịch vụ',
                                style: TextStyle(color: Colors.white),
                              ),
                              backgroundColor: AppTheme.errorColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              margin: const EdgeInsets.all(10),
                            ),
                          );
                          return;
                        }

                        Provider.of<ConfigProvider>(
                          context,
                          listen: false,
                        ).addXiaozhiConfig(
                          name,
                          websocketUrl,
                          otaUrl:
                              otaUrl.isNotEmpty
                                  ? otaUrl
                                  : XiaozhiConfig.defaultOtaUrl,
                          customMacAddress:
                              macAddress.isNotEmpty ? macAddress : null,
                          token: token.isNotEmpty ? token : null,
                        );

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Đã thêm dịch vụ Xiaozhi thành công',
                              style: TextStyle(color: AppTheme.textColor),
                            ),
                            backgroundColor: AppTheme.surfaceColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            margin: const EdgeInsets.all(10),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: const Color(0xFF070B12),
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Lưu cấu hình',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textColor,
                        side: const BorderSide(color: AppTheme.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  void _showEditXiaozhiConfigDialog(XiaozhiConfig config) {
    final nameController = TextEditingController(text: config.name);
    final otaUrlController = TextEditingController(
      text:
          config.otaUrl.isNotEmpty
              ? config.otaUrl
              : XiaozhiConfig.defaultOtaUrl,
    );
    final websocketUrlController = TextEditingController(
      text: config.websocketUrl,
    );
    final macAddressController = TextEditingController(text: config.macAddress);
    final tokenController = TextEditingController(text: config.token);

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            elevation: 8,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sửa dịch vụ Xiaozhi',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppTheme.secondaryTextColor,
                          ),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Chỉnh sửa cấu hình kết nối Xiaozhi',
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Tên dịch vụ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: TextField(
                        controller: nameController,
                        style: const TextStyle(color: AppTheme.textColor),
                        decoration: const InputDecoration(
                          hintText: 'Ví dụ: botAi',
                          hintStyle: TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Địa chỉ OTA',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: TextField(
                        controller: otaUrlController,
                        style: const TextStyle(color: AppTheme.textColor),
                        decoration: const InputDecoration(
                          hintText: XiaozhiConfig.defaultOtaUrl,
                          hintStyle: TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Địa chỉ WebSocket (Tùy chọn)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: TextField(
                        controller: websocketUrlController,
                        style: const TextStyle(color: AppTheme.textColor),
                        decoration: const InputDecoration(
                          hintText: 'Tự điền sau khi kích hoạt',
                          hintStyle: TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tự điền sau khi kích hoạt OTA, không bắt buộc nhập',
                      style: TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Địa chỉ MAC',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: TextField(
                        controller: macAddressController,
                        enabled: true,
                        style: const TextStyle(color: AppTheme.textColor),
                        decoration: const InputDecoration(
                          hintText: 'Để trống sẽ tự tạo',
                          hintStyle: TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Token',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: TextField(
                        controller: tokenController,
                        style: const TextStyle(color: AppTheme.textColor),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        final name = nameController.text.trim();
                        final otaUrl = otaUrlController.text.trim();
                        final websocketUrl = websocketUrlController.text.trim();
                        final macAddress = macAddressController.text.trim();
                        final token = tokenController.text.trim();

                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Vui lòng nhập Tên dịch vụ',
                                style: TextStyle(color: Colors.white),
                              ),
                              backgroundColor: AppTheme.errorColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              margin: const EdgeInsets.all(10),
                            ),
                          );
                          return;
                        }

                        final updatedConfig = config.copyWith(
                          name: name,
                          otaUrl:
                              otaUrl.isNotEmpty
                                  ? otaUrl
                                  : XiaozhiConfig.defaultOtaUrl,
                          websocketUrl: websocketUrl,
                          macAddress:
                              macAddress.isNotEmpty
                                  ? macAddress
                                  : config.macAddress,
                          token: token.isNotEmpty ? token : config.token,
                        );

                        Provider.of<ConfigProvider>(
                          context,
                          listen: false,
                        ).updateXiaozhiConfig(updatedConfig);

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Đã cập nhật dịch vụ Xiaozhi',
                              style: TextStyle(color: AppTheme.textColor),
                            ),
                            backgroundColor: AppTheme.surfaceColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            margin: const EdgeInsets.all(10),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: const Color(0xFF070B12),
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Lưu thay đổi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textColor,
                        side: const BorderSide(color: AppTheme.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  void _showDeleteXiaozhiConfigDialog(XiaozhiConfig config) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: AppTheme.surfaceColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Xóa dịch vụ Xiaozhi',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: AppTheme.secondaryTextColor,
                          ),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Bạn có chắc chắn muốn xóa "${config.name}"?',
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Provider.of<ConfigProvider>(
                          context,
                          listen: false,
                        ).deleteXiaozhiConfig(config.id);

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Đã xóa dịch vụ thành công',
                              style: TextStyle(color: Colors.white),
                            ),
                            backgroundColor: AppTheme.errorColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            margin: const EdgeInsets.all(10),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Xóa',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textColor,
                        side: const BorderSide(color: AppTheme.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Hủy',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
