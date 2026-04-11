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
      backgroundColor: isDark ? const Color(0xFF020617) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              onPressed: _clearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildToggleHeader(context, isDark),
                ),
                if (_items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off_outlined,
                            size: 64,
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications yet.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  if (unreadItems.isNotEmpty) ...[
                    _buildSectionHeader('ACTIVE', isDark),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildItemCard(context, unreadItems[index], isDark),
                          childCount: unreadItems.length,
                        ),
                      ),
                    ),
                  ],
                  if (readItems.isNotEmpty) ...[
                    _buildSectionHeader('HISTORY', isDark),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildItemCard(context, readItems[index], isDark),
                          childCount: readItems.length,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
    );
  }

  Widget _buildToggleHeader(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: PushNotificationService.notificationsEnabled,
        builder: (context, enabled, _) {
          return SwitchListTile.adaptive(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            value: enabled,
            activeColor: const Color(0xFF6366F1),
            onChanged: (v) => PushNotificationService.toggleNotifications(v),
            title: Text(
              'Daily Alerts',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            subtitle: Text(
              enabled ? 'Notifications are enabled for today' : 'Notifications are muted for today',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (enabled ? const Color(0xFF6366F1) : Colors.grey).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                enabled ? Icons.notifications_active_rounded : Icons.notifications_paused_rounded,
                color: enabled ? const Color(0xFF6366F1) : Colors.grey,
                size: 24,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: isDark ? Colors.white30 : const Color(0xFF64748B),
          ),
        ),
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
    final timeStr = receivedAt == null
        ? '--:--'
        : '${receivedAt.toLocal().hour.toString().padLeft(2, '0')}:${receivedAt.toLocal().minute.toString().padLeft(2, '0')}';
    final dateStr = receivedAt == null
        ? ''
        : '${receivedAt.toLocal().year}-${receivedAt.toLocal().month.toString().padLeft(2, '0')}-${receivedAt.toLocal().day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
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
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: style == 'banner'
                          ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                          : const Color(0xFF64748B).withValues(alpha: 0.08),
                    ),
                    child: Text(
                      style.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                        color: style == 'banner' ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title.isEmpty ? 'RealtorOne' : title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
              ],
              if (body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  if (dateStr.isNotEmpty)
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                    ),
                  const Spacer(),
                  if (deepLink.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'OPEN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
