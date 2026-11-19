import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ai_assistant/utils/app_log.dart';

/// Màn hình xem nhật ký hệ thống botAi
class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text(
          'Nhật ký hệ thống',
          style: TextStyle(
            color: Color(0xFF00F0FF),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF00F0FF)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(
              Icons.copy_rounded,
              color: Color(0xFF00F0FF),
              size: 16,
            ),
            label: const Text(
              'Sao chép',
              style: TextStyle(color: Color(0xFF00F0FF), fontSize: 13),
            ),
            onPressed: () {
              final text = AppLog.getAllText();
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã sao chép nhật ký vào bộ nhớ tạm'),
                  duration: Duration(seconds: 2),
                  backgroundColor: Color(0xFF1E293B),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
              size: 20,
            ),
            tooltip: 'Xóa',
            onPressed: () {
              AppLog.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: AppLog.logNotifier,
        builder: (context, _, __) {
          final logs = AppLog.logs;
          if (logs.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có dữ liệu nhật ký',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            );
          }

          return SelectionArea(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final line = logs[index];
                Color textColor = const Color(0xFFD1D5DB);
                if (line.contains('[Loi]') ||
                    line.contains('ERROR') ||
                    line.contains('fail')) {
                  textColor = const Color(0xFFFF6B6B);
                } else if (line.contains('[KetNoi]')) {
                  textColor = const Color(0xFF4ADE80);
                } else if (line.contains('[DanhThuc]')) {
                  textColor = const Color(0xFFFBBF24);
                } else if (line.contains('[Lenh]')) {
                  textColor = const Color(0xFF38BDF8);
                } else if (line.contains('[Phien]')) {
                  textColor = const Color(0xFFA78BFA);
                } else if (line.contains('[Chat]')) {
                  textColor = const Color(0xFF34D399);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      height: 1.35,
                      color: textColor,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
