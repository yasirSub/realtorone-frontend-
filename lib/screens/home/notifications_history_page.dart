import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../services/push_notification_service.dart';

class NotificationsHistoryPage extends StatefulWidget {
  const NotificationsHistoryPage({super.key});

  @override
  State<NotificationsHistoryPage> createState() => _NotificationsHistoryPageState();
}

class _NotificationsHistoryPageState extends State<NotificationsHistoryPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await PushNotificationService.getStoredNotifications();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    await PushNotificationService.clearStoredNotifications();
    if (!mounted) return;
    setState(() => _items = []);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadItems = _items.where((e) => e['read'] != true).toList();
    final readItems = _items.where((e) => e['read'] == true).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadItems.isNotEmpty)
            TextButton(
              onPressed: () async {
                await PushNotificationService.markAllAsRead();
                if (!mounted) return;
                setState(() {});
              },
              child: const Text('Mark all read'),
            ),
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text('Clear all'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Text(
                    'No notifications yet.',
                    style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    if (unreadItems.isNotEmpty) ...[
                      Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...unreadItems.map((item) => _buildItemCard(context, item, isDark)).toList(),
                      const SizedBox(height: 18),
                    ],
                    if (readItems.isNotEmpty) ...[
                      Text(
                        'History',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...readItems.map((item) => _buildItemCard(context, item, isDark)).toList(),
                    ],
                  ],
                ),
    );
  }

  Widget _buildItemCard(BuildContext context, Map<String, dynamic> item, bool isDark) {
    final title = (item['title'] ?? '').toString();
    final body = (item['body'] ?? '').toString();
    final subtitle = (item['banner_subtitle'] ?? '').toString();
    final style = (item['style'] ?? 'standard').toString();
    final deepLink = (item['deep_link'] ?? '').toString().trim();

    final receivedAt = DateTime.tryParse((item['received_at'] ?? '').toString());
    final when = receivedAt == null
        ? ''
        : '${receivedAt.toLocal().year}-${receivedAt.toLocal().month.toString().padLeft(2, '0')}-${receivedAt.toLocal().day.toString().padLeft(2, '0')} ${receivedAt.toLocal().hour.toString().padLeft(2, '0')}:${receivedAt.toLocal().minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (deepLink.isEmpty) return;
          final uri = Uri.tryParse(deepLink);
          if (uri == null) return;
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: style == 'banner'
                          ? const Color(0xFF6366F1).withValues(alpha: 0.14)
                          : const Color(0xFF64748B).withValues(alpha: 0.12),
                    ),
                    child: Text(
                      style.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const Spacer(),
                  if (when.isNotEmpty)
                    Text(
                      when,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title.isEmpty ? 'RealtorOne' : title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ],
              if (body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(fontSize: 12.5, color: isDark ? Colors.white60 : Colors.black54),
                ),
              ],
              if (deepLink.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Tap to open',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF475569),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
