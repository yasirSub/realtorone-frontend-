import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api/chat_api.dart';
import 'data/reven_quick_prompts.dart';

// ignore_for_file: unused_element

class RevenChatPage extends StatefulWidget {
  const RevenChatPage({super.key});

  /// Opens Reven as a compact floating window.
  /// Animates from the chat icon as if the bot is speaking.
  static Future<void> show(BuildContext context) {
    return showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Reven chat',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.20),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (ctx, _, __) => const RevenChatPage(),
      transitionBuilder: (ctx, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOut),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.12, 0.15),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.45, end: 1).animate(curved),
              alignment: Alignment.bottomRight,
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  State<RevenChatPage> createState() => _RevenChatPageState();
}

class _RevenChatPageState extends State<RevenChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isExpanded = false;
  bool _isLoading = false;
  int? _sessionId;
  List<Map<String, dynamic>> _sessions = [];

  final List<_RevenMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<List<Map<String, dynamic>>> _fetchSessions() async {
    try {
      final res = await ChatApi.listSessions();
      if (res['success'] == true && res['sessions'] is List) {
        final list = (res['sessions'] as List)
            .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
            .toList();
        if (mounted) setState(() => _sessions = list);
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<void> _loadHistory() async {
    final sessions = await _fetchSessions();
    try {
      if (sessions.isNotEmpty) {
        final first = sessions.first;
        final rawId = first['id'];
        final sid = rawId is int ? rawId : int.tryParse(rawId.toString());
        if (sid != null) {
          final historyRes = await ChatApi.getHistory(sid);
          if (historyRes['success'] == true &&
              historyRes['messages'] is List) {
            final msgs = historyRes['messages'] as List;
            if (!mounted) return;
            setState(() {
              _sessionId = sid;
              _messages.clear();
              for (final m in msgs) {
                if (m is Map<String, dynamic>) {
                  final role = (m['role'] as String?) ?? 'assistant';
                  final content = (m['content'] as String?) ?? '';
                  final parsed = _parseMessageContent(content);
                  final createdAt = _parseDateTime(m['created_at']);
                  _messages.add(
                    _RevenMessage(
                      text: parsed.$1,
                      isUser: role == 'user',
                      courses: parsed.$2,
                      commands: parsed.$3,
                      createdAt: createdAt,
                    ),
                  );
                }
              }
            });
            _scrollToBottom();
            return;
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;
    if (_messages.isEmpty) {
      setState(() {
        _messages.add(const _RevenMessage(
          text:
              'Hi, I am Reven, your AI assistant. I am here to help you with what you need.',
          isUser: false,
        ));
      });
    }
  }

  void _startNewChat() {
    setState(() {
      _sessionId = null;
      _messages.clear();
      _messages.add(const _RevenMessage(
        text:
            'Hi, I am Reven, your AI assistant. I am here to help you with what you need.',
        isUser: false,
      ));
    });
    Navigator.of(context).pop();
    _scrollToBottom();
  }

  Future<void> _deleteSession(int sid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete chat?'),
        content: const Text(
          'This chat will be permanently deleted. You can\'t undo this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final res = await ChatApi.deleteSession(sid);
      if (res['success'] == true && mounted) {
        final wasCurrent = _sessionId == sid;
        if (wasCurrent) {
          Navigator.of(context).pop();
          setState(() {
            _sessionId = null;
            _messages.clear();
            _messages.add(const _RevenMessage(
              text:
                  'Hi, I am Reven, your AI assistant. I am here to help you with what you need.',
              isUser: false,
            ));
          });
        } else {
          await _fetchSessions();
        }
      }
    } catch (_) {}
  }

  Future<void> _switchToSession(int sid) async {
    Navigator.of(context).pop();
    try {
      final res = await ChatApi.getHistory(sid);
      if (res['success'] == true && res['messages'] is List && mounted) {
        final msgs = res['messages'] as List;
        setState(() {
          _sessionId = sid;
          _messages.clear();
          for (final m in msgs) {
            if (m is Map<String, dynamic>) {
              final role = (m['role'] as String?) ?? 'assistant';
              final content = (m['content'] as String?) ?? '';
              final parsed = _parseMessageContent(content);
              final createdAt = _parseDateTime(m['created_at']);
              _messages.add(
                _RevenMessage(
                  text: parsed.$1,
                  isUser: role == 'user',
                  courses: parsed.$2,
                  createdAt: createdAt,
                ),
              );
            }
          }
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  void _showChatList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF131E30) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF263148) : const Color(0xFFDDE5F0);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, scrollController) => Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: subtitleColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Chat history',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _startNewChat,
                      icon: Icon(Icons.add_rounded, size: 18, color: const Color(0xFF4F7CFF)),
                      label: Text(
                        'New chat',
                        style: TextStyle(
                          color: const Color(0xFF4F7CFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _sessions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 48, color: subtitleColor.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'No past chats yet',
                              style: TextStyle(color: subtitleColor, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _sessions.length,
                        itemBuilder: (_, i) {
                          final s = _sessions[i];
                          final rawId = s['id'];
                          final sid = rawId is int ? rawId : int.tryParse(rawId.toString());
                          final title = (s['title'] as String?)?.trim().isNotEmpty == true
                              ? (s['title'] as String)
                              : 'Chat ${i + 1}';
                          final updated = s['updated_at'] ?? s['created_at'];
                          final dateStr = updated != null
                              ? _formatDate(updated.toString())
                              : '';
                          final isActive = _sessionId == sid;

                          return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? const Color(0xFF4F7CFF).withValues(alpha: 0.15)
                                      : borderColor.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.chat_bubble_rounded,
                                  color: isActive ? const Color(0xFF4F7CFF) : subtitleColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                title,
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 15,
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                              subtitle: dateStr.isNotEmpty
                                  ? Text(
                                      dateStr,
                                      style: TextStyle(
                                        color: subtitleColor,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                              trailing: IconButton(
                                icon: Icon(Icons.delete_outline, color: subtitleColor, size: 20),
                                onPressed: sid != null
                                    ? () => _deleteSession(sid)
                                    : null,
                              ),
                              onTap: sid != null ? () => _switchToSession(sid) : null,
                            );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) async {
      await _fetchSessions();
    });
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  static (String, List<Map<String, dynamic>>?, List<Map<String, dynamic>>?)
      _parseMessageContent(String content) {
    if (content.isEmpty) return ('', null, null);
    if (content.startsWith('{')) {
      try {
        final decoded = jsonDecode(content) as Map<String, dynamic>?;
        if (decoded != null) {
          final text = decoded['text'] as String? ?? '';
          final courses = decoded['courses'];
          final commands = decoded['commands'];
          final coursesList = courses is List && courses.isNotEmpty
              ? courses
                  .map((e) =>
                      e is Map<String, dynamic> ? e : <String, dynamic>{})
                  .toList()
              : null;
          final commandsList = commands is List && commands.isNotEmpty
              ? commands
                  .map((e) =>
                      e is Map<String, dynamic> ? e : <String, dynamic>{})
                  .toList()
              : null;
          return (text, coursesList, commandsList);
        }
      } catch (_) {}
    }
    return (content, null, null);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _sendToApi(String text) async {
    if (_isLoading) return;
    final now = DateTime.now();
    setState(() {
      _messages.add(_RevenMessage(text: text, isUser: true, createdAt: now));
      _messages.add(const _RevenMessage(text: '…', isUser: false, isLoading: true));
      _isLoading = true;
    });
    _scrollToBottom();

    final res = await ChatApi.sendMessage(text, sessionId: _sessionId);

    if (!mounted) return;
    setState(() {
      _messages.removeLast();
      _isLoading = false;
        if (res['success'] == true) {
        final courses = res['courses'] as List?;
        final commands = res['commands'] as List?;
        _messages.add(_RevenMessage(
          text: res['reply'] as String? ?? 'No response.',
          isUser: false,
          courses: courses != null
              ? courses
                  .map((e) =>
                      e is Map<String, dynamic> ? e : <String, dynamic>{})
                  .toList()
              : null,
          commands: commands != null
              ? commands
                  .map((e) =>
                      e is Map<String, dynamic> ? e : <String, dynamic>{})
                  .toList()
              : null,
          createdAt: DateTime.now(),
        ));
        final sid = res['session_id'];
        if (sid != null) {
          _sessionId = sid is int ? sid : int.tryParse(sid.toString());
          _fetchSessions();
        }
      } else {
        _messages.add(_RevenMessage(
          text: res['message'] as String? ?? 'Something went wrong. Please try again.',
          isUser: false,
        ));
      }
    });
    _scrollToBottom();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    _sendToApi(text);
  }

  void _sendQuickPrompt(RevenQuickPrompt prompt) {
    _sendToApi(prompt.message);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0B1220)
        : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF131E30) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF263148)
        : const Color(0xFFDDE5F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactWidth = constraints.maxWidth > 460
                ? 420.0
                : constraints.maxWidth - 28;
            final compactHeight = constraints.maxHeight > 760
                ? 560.0
                : constraints.maxHeight * 0.55;
            final windowWidth = _isExpanded
                ? constraints.maxWidth
                : compactWidth.clamp(300.0, constraints.maxWidth);
            final windowHeight = _isExpanded
                ? constraints.maxHeight
                : compactHeight.clamp(420.0, constraints.maxHeight);
            final bubbleMaxWidth = _isExpanded
                ? 400.0
                : (windowWidth - 80).clamp(180.0, 310.0);

            return AnimatedPadding(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.fromLTRB(
                _isExpanded ? 0 : 20,
                _isExpanded ? 0 : 14,
                _isExpanded ? 0 : 24,
                MediaQuery.of(context).viewInsets.bottom +
                    (_isExpanded ? 0 : 185),
              ),
              child: Align(
                alignment: Alignment.bottomRight,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  width: windowWidth,
                  height: windowHeight,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(_isExpanded ? 0 : 24),
                    border: Border.all(color: borderColor, width: 1.4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                      BoxShadow(
                        color: const Color(
                          0xFF4F7CFF,
                        ).withValues(alpha: isDark ? 0.08 : 0.04),
                        blurRadius: 60,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // ── Header ────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          border: Border(
                            bottom: BorderSide(color: borderColor),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF4F7CFF,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(5),
                              child: Image.asset(
                                'assets/images/chat-bot.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reven',
                                    style: TextStyle(
                                      color: titleColor,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    _isExpanded ? 'Full view' : 'AI assistant',
                                    style: TextStyle(
                                      color: subtitleColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Online pulse dot
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4ADE80),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF4ADE80,
                                    ).withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Chat history',
                              onPressed: _showChatList,
                              icon: Icon(
                                Icons.history_rounded,
                                color: subtitleColor,
                                size: 20,
                              ),
                            ),
                            IconButton(
                              tooltip: _isExpanded
                                  ? 'Exit full screen'
                                  : 'Full screen',
                              onPressed: () =>
                                  setState(() => _isExpanded = !_isExpanded),
                              icon: Icon(
                                _isExpanded
                                    ? Icons.close_fullscreen_rounded
                                    : Icons.open_in_full_rounded,
                                color: subtitleColor,
                                size: 18,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(
                                Icons.close_rounded,
                                color: subtitleColor,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Messages ──────────────────────────────────────
                      Expanded(
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                          itemCount:
                              _messages.length +
                              (_messages.length == 1 ? 1 : 0),
                          separatorBuilder: (_, index) {
                            if (_messages.length == 1 && index == 0) {
                              return const SizedBox(height: 16);
                            }
                            return const SizedBox(height: 8);
                          },
                          itemBuilder: (context, index) {
                            if (_messages.length == 1 && index == 1) {
                              return _QuickPromptsPanel(
                                onPromptTapped: _sendQuickPrompt,
                              );
                            }
                            final msg = _messages[index];
                            return _ChatBubble(
                              message: msg,
                              bubbleMaxWidth: bubbleMaxWidth,
                              surfaceColor: surfaceColor,
                              borderColor: borderColor,
                              titleColor: titleColor,
                              subtitleColor: subtitleColor,
                              onCommandTapped: _sendToApi,
                            );
                          },
                        ),
                      ),

                      // ── Input ─────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          border: Border(top: BorderSide(color: borderColor)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: backgroundColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: borderColor),
                                ),
                                child: TextField(
                                  controller: _messageController,
                                  minLines: 1,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _sendMessage(),
                                  decoration: InputDecoration(
                                    hintText: 'Message Reven...',
                                    hintStyle: TextStyle(color: subtitleColor),
                                    border: InputBorder.none,
                                    isCollapsed: true,
                                  ),
                                  style: TextStyle(
                                    color: titleColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _sendMessage,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4F7CFF),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF4F7CFF,
                                      ).withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 19,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Typing indicator ─────────────────────────────────────────────────────

class _TypingDot extends StatefulWidget {
  const _TypingDot({required this.delay});

  final int delay;

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.3, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay * 200), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: color.withValues(alpha: _animation.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ── Bubble widget ────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.bubbleMaxWidth,
    required this.surfaceColor,
    required this.borderColor,
    required this.titleColor,
    required this.subtitleColor,
    this.onCommandTapped,
  });

  final _RevenMessage message;
  final double bubbleMaxWidth;
  final Color surfaceColor;
  final Color borderColor;
  final Color titleColor;
  final Color subtitleColor;
  final void Function(String)? onCommandTapped;

  static String _formatMessageTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF4F7CFF) : surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: borderColor),
          boxShadow: isUser
              ? [
                  BoxShadow(
                    color: const Color(0xFF4F7CFF).withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: message.isLoading
            ? SizedBox(
                width: 48,
                height: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _TypingDot(delay: 0),
                    _TypingDot(delay: 1),
                    _TypingDot(delay: 2),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: TextStyle(
                        color: isUser ? Colors.white : titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                      ),
                    ),
                  if (message.courses != null &&
                      message.courses!.isNotEmpty &&
                      !isUser) ...[
                    if (message.text.isNotEmpty) const SizedBox(height: 12),
                    _CourseList(
                      courses: message.courses!,
                      titleColor: titleColor,
                    ),
                  ],
                  if (message.commands != null &&
                      message.commands!.isNotEmpty &&
                      !isUser) ...[
                    if (message.text.isNotEmpty ||
                        (message.courses != null &&
                            message.courses!.isNotEmpty))
                      const SizedBox(height: 12),
                    _CommandChips(
                      commands: message.commands!,
                      titleColor: titleColor,
                      onCommandTapped: onCommandTapped,
                    ),
                  ],
                  if (message.createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _formatMessageTime(message.createdAt!),
                      style: TextStyle(
                        color: isUser
                            ? Colors.white.withValues(alpha: 0.8)
                            : subtitleColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

// ── Course list inside chat bubble ────────────────────────────────────────

class _CourseList extends StatelessWidget {
  const _CourseList({
    required this.courses,
    required this.titleColor,
  });

  final List<Map<String, dynamic>> courses;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: courses.map((c) {
        final title = (c['title'] as String?) ?? 'Course';
        final desc = (c['description'] as String?)?.toString();
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF4F7CFF).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF4F7CFF).withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.menu_book_rounded,
                      size: 16, color: const Color(0xFF4F7CFF)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (desc != null && desc.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor.withValues(alpha: 0.75),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Command chips inside chat bubble ────────────────────────────────────

class _CommandChips extends StatelessWidget {
  const _CommandChips({
    required this.commands,
    required this.titleColor,
    this.onCommandTapped,
  });

  final List<Map<String, dynamic>> commands;
  final Color titleColor;
  final void Function(String)? onCommandTapped;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: commands.map((c) {
        final keyword = (c['keyword'] as String?) ?? '';
        final label = (c['label'] as String?) ?? keyword;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final borderColor =
            isDark ? const Color(0xFF263148) : const Color(0xFFDDE5F0);
        final surfaceColor = isDark ? const Color(0xFF131E30) : Colors.white;

        return GestureDetector(
          onTap: onCommandTapped != null && keyword.isNotEmpty
              ? () => onCommandTapped!(keyword)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(color: titleColor, fontSize: 13)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Quick prompts panel ─────────────────────────────────────────────────

class _QuickPromptsPanel extends StatelessWidget {
  const _QuickPromptsPanel({required this.onPromptTapped});

  final void Function(RevenQuickPrompt) onPromptTapped;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          'QUICK TOPICS',
          style: TextStyle(
            color: subtitleColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        ...revenPromptCategories.map(
          (category) => _CategoryRow(
            category: category,
            onPromptTapped: onPromptTapped,
            subtitleColor: subtitleColor,
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.onPromptTapped,
    required this.subtitleColor,
  });

  final RevenPromptCategory category;
  final void Function(RevenQuickPrompt) onPromptTapped;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category.title,
          style: TextStyle(
            color: subtitleColor,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: category.prompts
                .map((p) => _PromptChip(prompt: p, onTapped: onPromptTapped))
                .toList(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.prompt, required this.onTapped});

  final RevenQuickPrompt prompt;
  final void Function(RevenQuickPrompt) onTapped;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? const Color(0xFF263148)
        : const Color(0xFFDDE5F0);
    final surfaceColor = isDark ? const Color(0xFF131E30) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return GestureDetector(
      onTap: () => onTapped(prompt),
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(prompt.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              prompt.label,
              style: TextStyle(
                color: titleColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data model ───────────────────────────────────────────────────────────

class _RevenMessage {
  final String text;
  final bool isUser;
  final bool isLoading;
  final List<Map<String, dynamic>>? courses;
  final List<Map<String, dynamic>>? commands;
  final DateTime? createdAt;

  const _RevenMessage({
    required this.text,
    required this.isUser,
    this.isLoading = false,
    this.courses,
    this.commands,
    this.createdAt,
  });
}
