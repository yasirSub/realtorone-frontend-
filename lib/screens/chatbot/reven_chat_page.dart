import 'dart:convert';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';
import '../../api/chat_api.dart';
import '../../routes/app_routes.dart';
import '../../widgets/realtor_one_dialog_scaffold.dart';
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
      pageBuilder: (ctx, _, _) => const RevenChatPage(),
      transitionBuilder: (ctx, animation, _, child) {
        final openCurve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        final t = openCurve.value.clamp(0.0, 1.0);
        final slideX = lerpDouble(0.22, 0.0, t) ?? 0.0;
        final slideY = lerpDouble(0.30, 0.0, t) ?? 0.0;
        final squashX = lerpDouble(0.24, 1.0, t) ?? 1.0;
        final squashY = lerpDouble(0.08, 1.0, t) ?? 1.0;
        final widthFactor = lerpDouble(0.28, 1.0, t) ?? 1.0;
        final heightFactor = lerpDouble(0.12, 1.0, t) ?? 1.0;

        return Opacity(
          opacity: lerpDouble(0.0, 1.0, t) ?? 1.0,
          child: Transform.translate(
            offset: Offset(slideX * 100, slideY * 100),
            child: Align(
              alignment: Alignment.bottomRight,
              widthFactor: widthFactor,
              heightFactor: heightFactor,
              child: Transform(
                alignment: Alignment.bottomRight,
                transform: Matrix4.diagonal3Values(squashX, squashY, 1.0),
                child: child,
              ),
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
  bool _humanHandoffActive = false;
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
          if (historyRes['success'] == true && historyRes['messages'] is List) {
            final msgs = historyRes['messages'] as List;
            if (!mounted) return;
            setState(() {
              _sessionId = sid;
              _humanHandoffActive = historyRes['human_handoff_active'] == true;
              _messages.clear();
              for (final m in msgs) {
                if (m is Map<String, dynamic>) {
                  _messages.add(_messageFromApiRow(m));
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
        _messages.add(
          const _RevenMessage(
            text:
                'Hi, I am Reven, your AI assistant. I am here to help you with what you need.',
            isUser: false,
          ),
        );
      });
    }
  }

  void _startNewChat() {
    setState(() {
      _sessionId = null;
      _messages.clear();
      _messages.add(
        const _RevenMessage(
          text:
              'Hi, I am Reven, your AI assistant. I am here to help you with what you need.',
          isUser: false,
        ),
      );
    });
    Navigator.of(context).pop();
    _scrollToBottom();
  }

  Future<void> _deleteSession(int sid) async {
    final confirm = await RealtorOneDialogScaffold.show<bool>(
      context: context,
      semanticsLabel: 'Confirm delete chat',
      builder: (d) {
        final isDark = Theme.of(d).brightness == Brightness.dark;
        return RealtorOneDialogScaffold(
          title: 'Delete chat?',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
          child: Text(
            'This chat will be permanently deleted. You can\'t undo this.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        );
      },
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
            _messages.add(
              const _RevenMessage(
                text:
                    'Hi, I am Reven, your AI assistant. I am here to help you with what you need.',
                isUser: false,
              ),
            );
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
          _humanHandoffActive = res['human_handoff_active'] == true;
          _messages.clear();
          for (final m in msgs) {
            if (m is Map<String, dynamic>) {
              _messages.add(_messageFromApiRow(m));
            }
          }
        });
        _scrollToBottom();
      }
    } catch (_) {}
  }

  _RevenMessage _messageFromApiRow(Map<String, dynamic> m) {
    final role = (m['role'] as String?) ?? 'assistant';
    final content = (m['content'] as String?) ?? '';
    final parsed = _parseMessageContent(content);
    final createdAt = _parseDateTime(m['created_at']);
    return _RevenMessage(
      text: parsed.$1,
      isUser: role == 'user',
      isHuman: role == 'human',
      courses: parsed.$2,
      commands: parsed.$3,
      clients: parsed.$4,
      createdAt: createdAt,
    );
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
    final borderColor = isDark
        ? const Color(0xFF263148)
        : const Color(0xFFDDE5F0);

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
                      icon: Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: const Color(0xFF4F7CFF),
                      ),
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
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: subtitleColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No past chats yet',
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 15,
                              ),
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
                          final sid = rawId is int
                              ? rawId
                              : int.tryParse(rawId.toString());
                          final title =
                              (s['title'] as String?)?.trim().isNotEmpty == true
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
                                    ? const Color(
                                        0xFF4F7CFF,
                                      ).withValues(alpha: 0.15)
                                    : borderColor.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.chat_bubble_rounded,
                                color: isActive
                                    ? const Color(0xFF4F7CFF)
                                    : subtitleColor,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              title,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 15,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
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
                              icon: Icon(
                                Icons.delete_outline,
                                color: subtitleColor,
                                size: 20,
                              ),
                              onPressed: sid != null
                                  ? () => _deleteSession(sid)
                                  : null,
                            ),
                            onTap: sid != null
                                ? () => _switchToSession(sid)
                                : null,
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

  static (
    String,
    List<Map<String, dynamic>>?,
    List<Map<String, dynamic>>?,
    List<Map<String, dynamic>>?,
  )
  _parseMessageContent(String content) {
    if (content.isEmpty) return ('', null, null, null);

    String text = content;
    List<Map<String, dynamic>>? courses;
    List<Map<String, dynamic>>? commands;
    List<Map<String, dynamic>>? clients;

    if (content.startsWith('{')) {
      try {
        final decoded = jsonDecode(content) as Map<String, dynamic>?;
        if (decoded != null) {
          text = decoded['text'] as String? ?? '';
          final c = decoded['courses'];
          if (c is List && c.isNotEmpty) {
            courses = c
                .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
                .toList();
          }
          final cmd = decoded['commands'];
          if (cmd is List && cmd.isNotEmpty) {
            commands = cmd
                .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
                .toList();
          }
          final cl = decoded['clients'];
          if (cl is List && cl.isNotEmpty) {
            clients = cl
                .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
                .toList();
          }
        }
      } catch (_) {}
    }

    // --- NEW: Parse bracketed commands from text [View X] ---
    final List<Map<String, dynamic>> extracted = commands ?? [];
    // More inclusive regex to capture common navigation requests
    final reg = RegExp(
      r'\[View\s+(Dashboard|Profile|Tasks|Learning|Courses|Deal Room|Active Clients|Clients|Home|Settings)\]',
      caseSensitive: false,
    );
    final matches = reg.allMatches(text).toList();

    if (matches.isNotEmpty) {
      for (final m in matches) {
        final fullMatch = m.group(0)!;
        final target = m.group(1)!.toLowerCase();

        // Prevent duplicates
        if (!extracted.any((e) => e['label'] == fullMatch)) {
          extracted.add({
            'label': fullMatch,
            'keyword': fullMatch,
            'target': target.replaceAll(' ', '-'),
          });
        }
      }
      commands = extracted;
    }

    return (text, courses, commands, clients);
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
      _messages.add(
        const _RevenMessage(text: '…', isUser: false, isLoading: true),
      );
      _isLoading = true;
    });
    _scrollToBottom();

    final res = await ChatApi.sendMessage(text, sessionId: _sessionId);

    if (!mounted) return;
    setState(() {
      _messages.removeLast();
      _isLoading = false;
      if (res['success'] == true && res['awaiting_human'] == true) {
        _humanHandoffActive = res['human_handoff_active'] == true;
        final sid = res['session_id'];
        if (sid is int) _sessionId = sid;
        else if (sid != null) _sessionId = int.tryParse(sid.toString());
        return;
      }
      if (res['success'] == true) {
        _humanHandoffActive = res['human_handoff_active'] == true;
        List<Map<String, dynamic>>? courses = res['courses'] is List
            ? (res['courses'] as List)
                  .map(
                    (e) => e is Map<String, dynamic> ? e : <String, dynamic>{},
                  )
                  .toList()
            : null;
        List<Map<String, dynamic>>? commands = res['commands'] is List
            ? (res['commands'] as List)
                  .map(
                    (e) => e is Map<String, dynamic> ? e : <String, dynamic>{},
                  )
                  .toList()
            : null;
        List<Map<String, dynamic>>? clients = res['clients'] is List
            ? (res['clients'] as List)
                  .map(
                    (e) => e is Map<String, dynamic> ? e : <String, dynamic>{},
                  )
                  .toList()
            : null;

        // --- Parse bracketed commands from text if commands is empty ---
        String replyText = res['reply'] as String? ?? '';
        if (commands == null || commands.isEmpty) {
          final regex = RegExp(r'\[(.*?)\]');
          final matches = regex.allMatches(replyText);
          if (matches.isNotEmpty) {
            commands = matches.map((m) {
              final label = m.group(1)!;
              return {
                'label': label,
                'target': label.toLowerCase().replaceAll(' ', '-'),
              };
            }).toList();
            // Optional: Remove the bracketed parts from the text to avoid duplication
            replyText = replyText
                .replaceAll(RegExp(r'\s*\[.*?\]\s*'), '')
                .trim();
          }
        }

        _messages.add(
          _RevenMessage(
            text: replyText,
            isUser: false,
            courses: courses,
            commands: commands,
            clients: clients,
            createdAt: DateTime.now(),
          ),
        );

        // --- Auto-fetch clients/courses if promised but not sent ---
        final lastMsg = _messages.last;
        final replyLower = lastMsg.text.toLowerCase();

        final needsClients =
            (lastMsg.clients == null || lastMsg.clients!.isEmpty) &&
            (replyLower.contains('client') ||
                replyLower.contains('lead') ||
                replyLower.contains('deal room') ||
                replyLower.contains('active clients') ||
                replyLower.contains('your clients'));

        final needsCourses =
            (lastMsg.courses == null || lastMsg.courses!.isEmpty) &&
            (replyLower.contains('course') ||
                replyLower.contains('learn') ||
                replyLower.contains('curriculum') ||
                replyLower.contains('available courses') ||
                replyLower.contains('your courses'));

        final needsRevenue =
            lastMsg.revenueSummary == null &&
            (replyLower.contains('revenue') ||
                replyLower.contains('commission') ||
                replyLower.contains('performance') ||
                replyLower.contains('earned') ||
                replyLower.contains('income'));

        if (needsClients) {
          _autoFetchClientsForLastMessage();
        }
        if (needsCourses) {
          _autoFetchCoursesForLastMessage();
        }
        if (needsRevenue) {
          _autoFetchRevenueForLastMessage();
        }

        final sid = res['session_id'];
        if (sid != null) {
          _sessionId = sid is int ? sid : int.tryParse(sid.toString());
          _fetchSessions();
        }
      } else {
        _messages.add(
          _RevenMessage(
            text:
                res['message'] as String? ??
                'Something went wrong. Please try again.',
            isUser: false,
          ),
        );
      }
    });
    _scrollToBottom();
  }

  Future<void> _autoFetchClientsForLastMessage() async {
    try {
      final res = await ApiClient.get(
        '${ApiEndpoints.results}?type=hot_lead',
        requiresAuth: true,
      );
      if (res['success'] == true && res['data'] is List && mounted) {
        final list = (res['data'] as List)
            .take(5)
            .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
            .toList();
        if (list.isNotEmpty) {
          setState(() {
            final idx = _messages.lastIndexWhere(
              (m) => !m.isUser && m.clients == null,
            );
            if (idx != -1) {
              final old = _messages[idx];
              _messages[idx] = _RevenMessage(
                text: old.text,
                isUser: old.isUser,
                courses: old.courses,
                commands: old.commands,
                clients: list,
                createdAt: old.createdAt,
              );
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _autoFetchCoursesForLastMessage() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.courses, requiresAuth: true);
      if (res['success'] == true && res['data'] is List && mounted) {
        final list = (res['data'] as List)
            .take(3)
            .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
            .toList();
        if (list.isNotEmpty) {
          setState(() {
            final idx = _messages.lastIndexWhere(
              (m) => !m.isUser && m.courses == null,
            );
            if (idx != -1) {
              final old = _messages[idx];
              _messages[idx] = _RevenMessage(
                text: old.text,
                isUser: old.isUser,
                courses: list,
                commands: old.commands,
                clients: old.clients,
                createdAt: old.createdAt,
              );
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _autoFetchRevenueForLastMessage() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.results, requiresAuth: true);
      if (res['success'] == true && res['summary'] != null && mounted) {
        setState(() {
          final idx = _messages.lastIndexWhere(
            (m) => !m.isUser && m.revenueSummary == null,
          );
          if (idx != -1) {
            final old = _messages[idx];
            _messages[idx] = _RevenMessage(
              text: old.text,
              isUser: old.isUser,
              courses: old.courses,
              commands: old.commands,
              clients: old.clients,
              revenueSummary: res['summary'],
              createdAt: old.createdAt,
            );
          }
        });
      }
    } catch (_) {}
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
                                    _humanHandoffActive
                                        ? 'Human support is chatting'
                                        : (_isExpanded ? 'Full view' : 'AI assistant'),
                                    style: TextStyle(
                                      color: _humanHandoffActive
                                          ? const Color(0xFFF59E0B)
                                          : subtitleColor,
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

                      if (_humanHandoffActive)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          child: Text(
                            'A team member is helping you. AI replies are paused for now.',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFFB45309),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                      if (_humanHandoffActive)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          child: Text(
                            'A team member is helping you. AI replies are paused for now.',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFFDE68A)
                                  : const Color(0xFFB45309),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
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
    _animation = Tween<double>(
      begin: 0.3,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
      builder: (_, _) => Container(
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
    final isHuman = message.isHuman;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF4F7CFF)
              : isHuman
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.14)
                  : surfaceColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser
              ? null
              : Border.all(
                  color: isHuman ? const Color(0xFFF59E0B).withValues(alpha: 0.45) : borderColor,
                ),
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
                  if (message.clients != null &&
                      message.clients!.isNotEmpty &&
                      !isUser) ...[
                    if (message.text.isNotEmpty ||
                        (message.courses != null &&
                            message.courses!.isNotEmpty))
                      const SizedBox(height: 12),
                    _ClientList(
                      clients: message.clients!,
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                    ),
                  ],
                  if (message.revenueSummary != null && !isUser) ...[
                    if (message.text.isNotEmpty ||
                        (message.courses != null &&
                            message.courses!.isNotEmpty) ||
                        (message.clients != null &&
                            message.clients!.isNotEmpty))
                      const SizedBox(height: 12),
                    _RevenueSummary(
                      summary: message.revenueSummary!,
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
  const _CourseList({required this.courses, required this.titleColor});

  final List<Map<String, dynamic>> courses;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available Courses',
              style: TextStyle(
                color: titleColor.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            _ListNavigateButton(
              context: context,
              label: 'Open Hub',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.main,
                  (route) => false,
                  arguments: const {'initialIndex': 2},
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...courses.map((c) {
          final title = (c['title'] as String?) ?? 'Course';
          final desc = (c['description'] as String?)?.toString();
          final isPublished =
              (c['is_published'] == true ||
              c['is_published'] == 1 ||
              c['is_published'] == "1");
          final isOffline = !isPublished;

          return Opacity(
            opacity: isOffline ? 0.5 : 1.0,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4F7CFF).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF4F7CFF).withValues(alpha: 0.2),
                ),
              ),
              child: InkWell(
                onTap: isOffline
                    ? null
                    : () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.courseCurriculum,
                          arguments: {
                            'courseId': c['id'],
                            'courseTitle': title,
                          },
                        );
                      },
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    color: titleColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isOffline)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'OFFLINE',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 7,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (desc != null && desc.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              desc,
                              style: TextStyle(
                                color: titleColor.withOpacity(0.5),
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      Icons.play_circle_outline_rounded,
                      size: 20,
                      color: const Color(0xFF667EEA).withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
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
        final target = (c['target'] as String?) ?? '';
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final borderColor = isDark
            ? const Color(0xFF263148)
            : const Color(0xFFDDE5F0);
        final surfaceColor = isDark ? const Color(0xFF131E30) : Colors.white;

        void openTarget() {
          // IMPORTANT: Close the chat dialog before navigating
          Navigator.of(context).pop();

          switch (target) {
            case 'dashboard':
            case 'home':
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.main,
                (route) => false,
                arguments: const {'initialIndex': 0},
              );
              return;
            case 'tasks':
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.main,
                (route) => false,
                arguments: const {'initialIndex': 1},
              );
              return;
            case 'courses':
            case 'learning':
            case 'learn':
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.main,
                (route) => false,
                arguments: const {'initialIndex': 2},
              );
              return;
            case 'badges':
              Navigator.of(context).pushNamed(AppRoutes.badges);
              return;
            case 'profile':
            case 'settings':
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.main,
                (route) => false,
                arguments: const {'initialIndex': 3},
              );
              return;
            case 'deal-room':
            case 'client-list':
            case 'clients':
            case 'active-clients':
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.main,
                (route) => false,
                arguments: const {
                  'initialIndex': 1,
                  'activitiesTabIndex': 1,
                  'revenueSubTab': 0,
                },
              );
              return;
          }
        }

        return GestureDetector(
          onTap: () {
            if (target.isNotEmpty) {
              openTarget();
              return;
            }
            if (onCommandTapped != null && keyword.isNotEmpty) {
              onCommandTapped!(keyword);
            }
          },
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
  final bool isHuman;
  final bool isLoading;
  final List<Map<String, dynamic>>? courses;
  final List<Map<String, dynamic>>? commands;
  final List<Map<String, dynamic>>? clients;
  final Map<String, dynamic>? revenueSummary;
  final DateTime? createdAt;

  const _RevenMessage({
    required this.text,
    required this.isUser,
    this.isHuman = false,
    this.isLoading = false,
    this.courses,
    this.commands,
    this.clients,
    this.revenueSummary,
    this.createdAt,
  });
}

class _ClientList extends StatelessWidget {
  const _ClientList({
    required this.clients,
    required this.titleColor,
    required this.subtitleColor,
  });

  final List<Map<String, dynamic>> clients;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Active Clients',
              style: TextStyle(
                color: titleColor.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            _ListNavigateButton(
              context: context,
              label: 'View All',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.main,
                  (route) => false,
                  arguments: const {
                    'initialIndex': 1,
                    'activitiesTabIndex': 1,
                    'revenueSubTab': 0,
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...clients.map((c) {
          final name = (c['client_name'] as String?) ?? 'Client';
          final status = (c['status'] as String?) ?? '-';
          final source = (c['source'] as String?) ?? '-';
          final value = c['value']?.toString() ?? '-';
          final date = (c['date'] as String?) ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.badge_rounded,
                            size: 16,
                            color: const Color(0xFF0EA5E9),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: $status · Source: $source · Value: $value${date.isNotEmpty ? ' · Date: $date' : ''}',
                        style: TextStyle(
                          color: subtitleColor,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: subtitleColor.withOpacity(0.3),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Shared navigation button for lists ────────────────────────────────────

class _ListNavigateButton extends StatelessWidget {
  const _ListNavigateButton({
    required this.context,
    required this.label,
    required this.onTap,
  });

  final BuildContext context;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF667EEA).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF667EEA),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.open_in_new_rounded,
              size: 10,
              color: Color(0xFF667EEA),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueSummary extends StatelessWidget {
  const _RevenueSummary({required this.summary, required this.titleColor});

  final Map<String, dynamic> summary;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    final commission = (summary['total_commission'] ?? 0).toStringAsFixed(0);
    final deals = summary['deals_closed'] ?? 0;
    final conversion = summary['conversion_rate'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'REVENUE PERFORMANCE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              _ListNavigateButton(
                context: context,
                label: 'Tracker',
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.main,
                    (route) => false,
                    arguments: const {
                      'initialIndex': 1,
                      'activitiesTabIndex': 1,
                      'revenueSubTab': 1, // REVENUE tab
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'COMMISSION',
                  value: '$commission AED',
                  icon: Icons.payments_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryStat(
                  label: 'DEALS',
                  value: '$deals',
                  icon: Icons.handshake_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SummaryStat(
            label: 'CONVERSION RATE',
            value: '$conversion%',
            icon: Icons.trending_up_rounded,
            horizontal: true,
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.icon,
    this.horizontal = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    if (horizontal) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
