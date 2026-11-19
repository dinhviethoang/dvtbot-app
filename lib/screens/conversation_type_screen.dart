import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_assistant/providers/config_provider.dart';
import 'package:ai_assistant/providers/conversation_provider.dart';
import 'package:ai_assistant/models/conversation.dart';
import 'package:ai_assistant/models/xiaozhi_config.dart';
import 'package:ai_assistant/screens/chat_screen.dart';
import 'package:ai_assistant/screens/settings_screen.dart';
import 'package:ai_assistant/utils/app_theme.dart';

class ConversationTypeScreen extends StatefulWidget {
  const ConversationTypeScreen({super.key});

  @override
  State<ConversationTypeScreen> createState() => _ConversationTypeScreenState();
}

class _ConversationTypeScreenState extends State<ConversationTypeScreen> {
  XiaozhiConfig? _selectedConfig;

  @override
  Widget build(BuildContext context) {
    final xiaozhiConfigs = Provider.of<ConfigProvider>(context).xiaozhiConfigs;

    if (_selectedConfig == null && xiaozhiConfigs.isNotEmpty) {
      _selectedConfig = xiaozhiConfigs.first;
    }

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
          'Tạo cuộc hội thoại mới',
          style: TextStyle(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body:
          xiaozhiConfigs.isEmpty
              ? _buildEmptyConfigView(context)
              : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        const Text(
                          'Chọn dịch vụ Xiaozhi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Cuộc trò chuyện sẽ kết nối qua giọng nói và văn bản với dịch vụ đã chọn.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ...xiaozhiConfigs.map(
                          (config) => _buildConfigOption(config),
                        ),
                      ],
                    ),
                  ),
                  _buildBottomButton(),
                ],
              ),
    );
  }

  Widget _buildEmptyConfigView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Icon(
                Icons.settings_voice_outlined,
                size: 64,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chưa có dịch vụ Xiaozhi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vui lòng thêm cấu hình kết nối Xiaozhi trong Cài đặt trước khi tạo cuộc hội thoại mới.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.secondaryTextColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => const SettingsScreen(
                          initialTab: 1,
                          autoShowAddDialog: true,
                        ),
                  ),
                );
              },
              icon: const Icon(Icons.add, color: Color(0xFF070B12)),
              label: const Text(
                'Thêm cấu hình Xiaozhi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: const Color(0xFF070B12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigOption(XiaozhiConfig config) {
    final bool isSelected = _selectedConfig?.id == config.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.surfaceColor : AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _selectedConfig = config;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.surfaceColor,
                  child: Icon(
                    Icons.mic,
                    color:
                        isSelected
                            ? const Color(0xFF070B12)
                            : AppTheme.secondaryTextColor,
                    size: 22,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        config.websocketUrl,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.secondaryTextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Radio<String>(
                  value: config.id,
                  groupValue: _selectedConfig?.id,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _selectedConfig = config;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: const Border(top: BorderSide(color: AppTheme.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _selectedConfig != null ? _createConversation : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: const Color(0xFF070B12),
            disabledBackgroundColor: AppTheme.borderColor,
            disabledForegroundColor: AppTheme.secondaryTextColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Bắt đầu cuộc trò chuyện',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  void _createConversation() async {
    if (_selectedConfig == null) return;

    final config = _selectedConfig!;
    final conversation = await Provider.of<ConversationProvider>(
      context,
      listen: false,
    ).createConversation(
      title: config.name.isNotEmpty ? config.name : 'botAi',
      type: ConversationType.xiaozhi,
      configId: config.id,
    );

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(conversation: conversation),
        ),
      );
    }
  }
}
