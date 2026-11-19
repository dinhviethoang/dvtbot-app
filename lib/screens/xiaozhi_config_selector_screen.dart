import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_assistant/providers/config_provider.dart';
import 'package:ai_assistant/providers/conversation_provider.dart';
import 'package:ai_assistant/models/conversation.dart';
import 'package:ai_assistant/models/xiaozhi_config.dart';
import 'package:ai_assistant/screens/chat_screen.dart';
import 'package:ai_assistant/utils/app_theme.dart';

class XiaozhiConfigSelectorScreen extends StatelessWidget {
  const XiaozhiConfigSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final xiaozhiConfigs = Provider.of<ConfigProvider>(context).xiaozhiConfigs;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Chọn dịch vụ Xiaozhi',
          style: TextStyle(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: xiaozhiConfigs.length,
        itemBuilder: (context, index) {
          final config = xiaozhiConfigs[index];
          return Card(
            color: AppTheme.surfaceColor,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              title: Text(
                config.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    'WebSocket: ${config.websocketUrl}',
                    style: const TextStyle(color: AppTheme.secondaryTextColor),
                  ),
                  Text(
                    'MAC: ${config.macAddress}',
                    style: const TextStyle(color: AppTheme.secondaryTextColor),
                  ),
                ],
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.primaryColor,
              ),
              onTap: () => _createXiaozhiConversation(context, config),
            ),
          );
        },
      ),
    );
  }

  void _createXiaozhiConversation(
    BuildContext context,
    XiaozhiConfig config,
  ) async {
    final conversation = await Provider.of<ConversationProvider>(
      context,
      listen: false,
    ).createConversation(
      title: 'Trò chuyện với ${config.name}',
      type: ConversationType.xiaozhi,
      configId: config.id,
    );

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(conversation: conversation),
        ),
      );
    }
  }
}
