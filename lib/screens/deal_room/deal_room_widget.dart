import 'dart:convert';

import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';
import 'add_client_page.dart';
import 'client_revenue_actions_page.dart';

class DealRoomWidget extends StatefulWidget {
  final VoidCallback? onClientActionLogged;

  const DealRoomWidget({super.key, this.onClientActionLogged});

  @override
  State<DealRoomWidget> createState() => _DealRoomWidgetState();
}

class _DealRoomWidgetState extends State<DealRoomWidget> {
  bool _isLoading = true;
  bool _hasClients = true;
  List<dynamic> _clients = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final statusRes = await ApiClient.get(
        ApiEndpoints.clientsStatus,
        requiresAuth: true,
      );

      final hasClients = statusRes['success'] == true &&
          (statusRes['has_clients'] == true || (statusRes['clients_count'] ?? 0) > 0);

      setState(() => _hasClients = hasClients);

      if (hasClients) {
        final clientsRes = await ApiClient.get(
          '${ApiEndpoints.results}?type=hot_lead',
          requiresAuth: true,
        );
        if (clientsRes['success'] == true) {
          _clients = clientsRes['data'] ?? [];
        } else {
          _clients = [];
        }
      } else {
        _clients = [];
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startAddFirstClient() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _privacyDialog(ctx),
    );
    if (proceed != true || !mounted) return;

    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddClientPage()),
    );

    if (created == true && mounted) {
      await _load();
    }
  }

  Widget _privacyDialog(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0B1220) : const Color(0xFF0B1220),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: Color(0xFF22C55E),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your Privacy Matters',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Client details entered here are\nstrictly confidential and used only\nfor your personal tracking. This data\nis not accessed, analyzed, or shared\nby the company.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'I Understand & Continue',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'END-TO-END ENCRYPTED ENVIRONMENT',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return _hasClients ? _clientsList() : _intro();
  }

  Widget _intro() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'The Deal Room',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Compact hero tile
          Container(
            height: 190,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E3A8A),
                ],
              ),
            ),
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFACC15),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Text(
                'THE DEAL ROOM',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _startAddFirstClient,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFACC15),
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text(
                'Add First Client',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const _BottomMiniTab(
            icon: Icons.group_rounded,
            label: 'CLIENTS',
            active: true,
          ),
        ],
      ),
    );
  }

  Widget _clientsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          ..._clients.take(6).map((c) => _clientTile(c, isDark)),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _startAddFirstClient,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: BorderSide(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New Prospect',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _clientTile(dynamic client, bool isDark) {
    final name = (client['client_name'] ?? 'Unnamed').toString();
    final status = (client['status'] ?? 'active').toString();
    final notes = client['notes'];
    String? stage;
    if (notes is String && notes.isNotEmpty) {
      try {
        final parsed = jsonDecode(notes);
        if (parsed is Map && parsed['lead_stage'] is String) {
          stage = parsed['lead_stage'] as String;
        }
      } catch (_) {}
    }

    final label = (stage ?? status).toUpperCase();
    final color = label.contains('NEGOTIATION')
        ? const Color(0xFF2563EB)
        : label.contains('FOLLOW')
            ? const Color(0xFFF59E0B)
            : label.contains('CLOSED') || label.contains('LOST') || status == 'lost'
                ? const Color(0xFFEF4444)
                : const Color(0xFF10B981);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        final id = client['id'];
        if (id is int) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClientRevenueActionsPage(
                clientId: id,
                clientName: name,
              ),
            ),
          ).then((_) => widget.onClientActionLogged?.call());
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.04),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _BottomMiniTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _BottomMiniTab({
    required this.icon,
    required this.label,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF2563EB) : const Color(0xFF64748B);
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

