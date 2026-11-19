import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ai_assistant/providers/conversation_provider.dart';
import 'package:ai_assistant/providers/config_provider.dart';
import 'package:ai_assistant/models/conversation.dart';
import 'package:ai_assistant/models/xiaozhi_config.dart';
import 'package:ai_assistant/screens/chat_screen.dart';
import 'package:ai_assistant/screens/settings_screen.dart';
import 'package:ai_assistant/screens/conversation_type_screen.dart';
import 'package:ai_assistant/screens/voice_call_screen.dart';
import 'package:ai_assistant/utils/app_theme.dart';
import 'package:ai_assistant/widgets/conversation_tile.dart';
import 'package:ai_assistant/widgets/slidable_delete_tile.dart';
import 'package:ai_assistant/widgets/discovery_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final FocusNode _searchFocusNode = FocusNode();
  bool _hasAutoLaunched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasAutoLaunched && mounted) {
        _hasAutoLaunched = true;
        _autoLaunch();
      }
    });
  }

  Future<void> _autoLaunch() async {
    final configProvider = Provider.of<ConfigProvider>(context, listen: false);
    final conversationProvider = Provider.of<ConversationProvider>(
      context,
      listen: false,
    );

    // Nếu chưa có cấu hình Xiaozhi nào thì tự tạo cấu hình mặc định (tên "botAi", otaUrl mặc định, websocketUrl rỗng)
    if (configProvider.xiaozhiConfigs.isEmpty) {
      await configProvider.addXiaozhiConfig(
        'botAi',
        '',
        otaUrl: XiaozhiConfig.defaultOtaUrl,
      );
    }

    if (configProvider.xiaozhiConfigs.isNotEmpty) {
      final xiaozhiConfig = configProvider.xiaozhiConfigs.first;
      Conversation? conversation;
      try {
        conversation = conversationProvider.conversations.firstWhere(
          (c) =>
              c.type == ConversationType.xiaozhi &&
              c.configId == xiaozhiConfig.id,
        );
      } catch (_) {
        conversation = null;
      }

      conversation ??= await conversationProvider.createConversation(
        title: xiaozhiConfig.name.isNotEmpty ? xiaozhiConfig.name : 'botAi',
        type: ConversationType.xiaozhi,
        configId: xiaozhiConfig.id,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => VoiceCallScreen(
                  conversation: conversation!,
                  xiaozhiConfig: xiaozhiConfig,
                ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _searchFocusNode.unfocus();
        SlidableController.instance.closeCurrentTile();
      },
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        backgroundColor: AppTheme.backgroundColor,
        appBar:
            _selectedIndex == 1
                ? null
                : AppBar(
                  title: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/logo_king.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'botAi',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ],
                  ),
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  backgroundColor: AppTheme.backgroundColor,
                  centerTitle: false,
                  titleSpacing: 20,
                  toolbarHeight: 65,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          splashColor: AppTheme.primaryColor.withOpacity(0.1),
                          highlightColor: AppTheme.primaryColor.withOpacity(
                            0.05,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(
                              Icons.settings,
                              size: 26,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        body:
            _selectedIndex == 1
                ? const SafeArea(bottom: false, child: DiscoveryScreen())
                : SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      _buildSearchBar(),
                      Expanded(child: _buildBody()),
                    ],
                  ),
                ),
        floatingActionButton:
            _selectedIndex == 0
                ? Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ConversationTypeScreen(),
                        ),
                      );
                    },
                    backgroundColor: AppTheme.primaryColor,
                    elevation: 0,
                    shape: const CircleBorder(),
                    child: const Icon(
                      Icons.add,
                      size: 30,
                      color: Color(0xFF070B12),
                    ),
                  ),
                )
                : null,
        bottomNavigationBar: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              border: const Border(
                top: BorderSide(color: AppTheme.borderColor),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 0,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom / 2,
              ),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                selectedItemColor: AppTheme.primaryColor,
                unselectedItemColor: AppTheme.secondaryTextColor,
                showSelectedLabels: true,
                showUnselectedLabels: true,
                backgroundColor: AppTheme.surfaceColor,
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                iconSize: 26,
                items: [
                  BottomNavigationBarItem(
                    icon: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              _selectedIndex == 0
                                  ? AppTheme.primaryColor.withOpacity(0.15)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              _selectedIndex == 0
                                  ? Border.all(
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.4,
                                    ),
                                  )
                                  : null,
                        ),
                        child: Icon(
                          _selectedIndex == 0
                              ? Icons.chat_bubble
                              : Icons.chat_bubble_outline,
                        ),
                      ),
                    ),
                    label: 'Tin nhắn',
                  ),
                  BottomNavigationBarItem(
                    icon: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              _selectedIndex == 1
                                  ? AppTheme.primaryColor.withOpacity(0.15)
                                  : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              _selectedIndex == 1
                                  ? Border.all(
                                    color: AppTheme.primaryColor.withOpacity(
                                      0.4,
                                    ),
                                  )
                                  : null,
                        ),
                        child: Icon(
                          _selectedIndex == 1
                              ? Icons.search
                              : Icons.search_outlined,
                        ),
                      ),
                    ),
                    label: 'Khám phá',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    if (_selectedIndex == 1) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: AppTheme.surfaceColor,
          child: TextField(
            focusNode: _searchFocusNode,
            style: const TextStyle(color: AppTheme.textColor, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Tìm kiếm cuộc hội thoại',
              hintStyle: const TextStyle(
                color: AppTheme.secondaryTextColor,
                fontSize: 16,
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.all(12),
                child: const Icon(
                  Icons.search,
                  color: AppTheme.primaryColor,
                  size: 22,
                ),
              ),
              suffixIcon: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(right: 4),
                child: const Icon(
                  Icons.mic_none_outlined,
                  color: AppTheme.secondaryTextColor,
                  size: 22,
                ),
              ),
              filled: true,
              fillColor: AppTheme.surfaceColor,
              focusColor: AppTheme.surfaceColor,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<ConversationProvider>(
      builder: (context, provider, child) {
        final pinnedConversations = provider.pinnedConversations;
        final unpinnedConversations = provider.unpinnedConversations;

        return ListView(
          padding: EdgeInsets.only(
            bottom: 16 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            if (pinnedConversations.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 8,
                  bottom: 8,
                ),
                child: Text(
                  'Cuộc trò chuyện đã ghim',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                    fontSize: 15,
                  ),
                ),
              ),
              ...pinnedConversations.map(
                (conversation) => _buildConversationTile(conversation),
              ),
            ],

            if (unpinnedConversations.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: pinnedConversations.isEmpty ? 8 : 16,
                  bottom: 8,
                ),
                child: const Text(
                  'Tất cả cuộc hội thoại',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondaryTextColor,
                    fontSize: 15,
                  ),
                ),
              ),
              ...unpinnedConversations.map(
                (conversation) => _buildConversationTile(conversation),
              ),
            ],

            if (pinnedConversations.isEmpty && unpinnedConversations.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(64.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 0,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/logo_king.png',
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 48,
                                  color: AppTheme.secondaryTextColor,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Chưa có cuộc trò chuyện nào',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 5,
                              spreadRadius: 0,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Nhấn + để tạo cuộc hội thoại mới',
                              style: TextStyle(
                                fontSize: 14,
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
          ],
        );
      },
    );
  }

  Widget _buildConversationTile(Conversation conversation) {
    return SlidableDeleteTile(
      key: Key(conversation.id),
      onDelete: () {
        Provider.of<ConversationProvider>(
          context,
          listen: false,
        ).deleteConversation(conversation.id);

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã xóa "${conversation.title}"',
              style: const TextStyle(color: AppTheme.textColor),
            ),
            backgroundColor: AppTheme.surfaceColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            margin: const EdgeInsets.only(bottom: 70, left: 20, right: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppTheme.borderColor),
            ),
            action: SnackBarAction(
              label: 'Hoàn tác',
              textColor: AppTheme.primaryColor,
              onPressed: () {
                Provider.of<ConversationProvider>(
                  context,
                  listen: false,
                ).restoreLastDeletedConversation();
              },
            ),
          ),
        );
      },
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(conversation: conversation),
          ),
        );
      },
      onLongPress: () {
        _showConversationOptions(conversation);
      },
      child: ConversationTile(
        conversation: conversation,
        onTap: null,
        onLongPress: null,
      ),
    );
  }

  void _showConversationOptions(Conversation conversation) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      elevation: 20,
      barrierColor: Colors.black.withOpacity(0.7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppTheme.borderColor),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          conversation.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        conversation.isPinned
                            ? 'Bỏ ghim'
                            : 'Ghim cuộc trò chuyện',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Provider.of<ConversationProvider>(
                          context,
                          listen: false,
                        ).togglePinConversation(conversation.id);
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.errorColor.withOpacity(0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.delete,
                          color: AppTheme.errorColor,
                          size: 24,
                        ),
                      ),
                      title: const Text(
                        'Xóa cuộc trò chuyện',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.errorColor,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Provider.of<ConversationProvider>(
                          context,
                          listen: false,
                        ).deleteConversation(conversation.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Đã xóa "${conversation.title}"',
                              style: const TextStyle(color: AppTheme.textColor),
                            ),
                            backgroundColor: AppTheme.surfaceColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: const BorderSide(
                                color: AppTheme.borderColor,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
