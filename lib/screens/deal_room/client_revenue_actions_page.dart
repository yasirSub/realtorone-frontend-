import 'dart:convert';

import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';

class ClientRevenueActionsPage extends StatefulWidget {
  final int clientId;
  final String clientName;

  const ClientRevenueActionsPage({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<ClientRevenueActionsPage> createState() =>
      _ClientRevenueActionsPageState();
}

class _ClientRevenueActionsPageState extends State<ClientRevenueActionsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _actions = [];
  List<dynamic> _clientActivities = [];
  final String _dateKey = DateTime.now().toIso8601String().split('T').first;
  DateTime _scheduledAt =
      DateTime.now().add(const Duration(days: 1)); // default next day

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiClient.get(
        '${ApiEndpoints.clientActions(widget.clientId)}?date=$_dateKey',
        requiresAuth: true,
      );
      if (res['success'] == true) {
        final data = res['data'] ?? {};
        final List list = data['actions'] ?? [];
        _actions = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false);
      }
      await _loadClientActivities();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadClientActivities() async {
    try {
      final res = await ApiClient.get(
        ApiEndpoints.clientActivities(widget.clientId),
        requiresAuth: true,
      );
      if (mounted && res['success'] == true) {
        setState(() {
          _clientActivities = res['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error loading client activities: $e');
    }
  }

  Future<void> _setStatus(String key, String status) async {
    final index = _actions.indexWhere((a) => a['key'] == key);
    if (index == -1) return;

    setState(() {
      _actions[index]['status'] = status;
    });

    debugPrint('[DAILY_LOG_DEBUG] POST /clients/${widget.clientId}/actions');
    debugPrint('[DAILY_LOG_DEBUG]   action_key=$key, status=$status, date=$_dateKey');
    try {
      final res = await ApiClient.post(
        ApiEndpoints.clientActions(widget.clientId),
        {
          'action_key': key,
          'status': status,
          'date': _dateKey,
        },
        requiresAuth: true,
      );
      debugPrint('[DAILY_LOG_DEBUG]   Response: success=${res['success']}');
      if (res['success'] == true && status == 'yes') {
        await _loadClientActivities();
      }
      if (res['success'] != true) {
        debugPrint('[DAILY_LOG_DEBUG]   ERROR: ${res['message'] ?? res}');
      }
    } catch (e, st) {
      debugPrint('[DAILY_LOG_DEBUG]   EXCEPTION: $e');
      debugPrint('[DAILY_LOG_DEBUG]   Stack: $st');
    }
  }

  Future<void> _createFollowUp(DateTime when) async {
    await ApiClient.post(
      ApiEndpoints.followUps,
      {
        'result_id': widget.clientId,
        'client_name': widget.clientName,
        'due_at': when.toIso8601String(),
        'priority': 2,
      },
      requiresAuth: true,
    );
  }

  Future<void> _logAction(String actionType, Map<String, dynamic> payload) async {
    try {
      await ApiClient.post(
        ApiEndpoints.clientActionLog(widget.clientId),
        {
          'action_type': actionType,
          'date': _dateKey,
          'payload': payload,
        },
        requiresAuth: true,
      );
    } catch (e) {
      debugPrint('Failed to log action: $e');
    }
  }

  Future<void> _handleYesTap(String key) async {
    switch (key) {
      case 'follow_up_block':
        final confirmed = await _showFollowUpSheet();
        if (confirmed == true) {
          await _setStatus(key, 'yes');
          await _createFollowUp(_scheduledAt);
        }
        break;
      case 'cold_call_block':
        final saved = await _showColdCallSheet();
        if (saved == true) await _setStatus(key, 'yes');
        break;
      case 'site_visit':
        final saved = await _showSiteVisitSheet();
        if (saved == true) await _setStatus(key, 'yes');
        break;
      case 'deal_negotiation':
        final result = await _showDealNegotiationSheet();
        if (result != null) {
          await _setStatus(key, 'yes');
          if (result == 'Finalized' && mounted) {
            await _showDealClosedScreen();
          }
        }
        break;
      case 'referral_ask':
        final saved = await _showReferralAskSheet();
        if (saved == true) await _setStatus(key, 'yes');
        break;
      case 'deal_closed':
        await _showDealClosedScreen();
        await _setStatus(key, 'yes');
        break;
      default:
        await _setStatus(key, 'yes');
    }
  }

  // ─── Cold Call Sheet ───
  Future<bool?> _showColdCallSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool completed = true;
    String duration = '';
    String outcome = 'Interested';
    DateTime rescheduleDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay rescheduleTime = const TimeOfDay(hour: 14, minute: 0);

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheetWrapper(
        ctx,
        isDark,
        (ctx, setModalState) => [
          _sheetIcon(Icons.phone_rounded),
          const SizedBox(height: 12),
          _sheetTitle('Cold Call'),
          const SizedBox(height: 6),
          _sheetQuestion('Was the cold call completed?'),
          const SizedBox(height: 14),
          _yesNoRow(completed, (v) => setModalState(() => completed = v)),
          const SizedBox(height: 18),
          _sectionLabel('Call Details', isDark),
          const SizedBox(height: 8),
          _inputField(
            hint: 'e.g. 5:30',
            label: 'Call duration',
            isDark: isDark,
            onChanged: (v) => duration = v,
          ),
          const SizedBox(height: 10),
          _sectionLabel('Call outcome', isDark),
          const SizedBox(height: 8),
          _chipRow(
            options: ['Interested', 'Not Interested', 'Call Back'],
            selected: outcome,
            onSelect: (v) => setModalState(() => outcome = v),
          ),
          const SizedBox(height: 14),
          _sectionLabel('Reschedule Call', isDark),
          const SizedBox(height: 8),
          _dateTimeRow(
            ctx: ctx,
            isDark: isDark,
            date: rescheduleDate,
            time: rescheduleTime,
            onDatePicked: (d) => setModalState(() => rescheduleDate = d),
            onTimePicked: (t) => setModalState(() => rescheduleTime = t),
          ),
          const SizedBox(height: 18),
          _submitButton(
            label: 'Save Cold Call',
            enabled: completed,
            onTap: () {
              _logAction('cold_call', {
                'completed': completed,
                'duration': duration,
                'outcome': outcome,
                'reschedule_date': '${rescheduleDate.year}-${rescheduleDate.month.toString().padLeft(2, '0')}-${rescheduleDate.day.toString().padLeft(2, '0')}',
                'reschedule_time': '${rescheduleTime.hour.toString().padLeft(2, '0')}:${rescheduleTime.minute.toString().padLeft(2, '0')}',
              });
              Navigator.pop(ctx, true);
            },
          ),
        ],
      ),
    );
  }

  // ─── Site Visit Sheet ───
  Future<bool?> _showSiteVisitSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool completed = true;
    String propertyName = '';
    String interestLevel = 'Medium';
    DateTime visitDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay visitTime = const TimeOfDay(hour: 10, minute: 30);

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheetWrapper(
        ctx,
        isDark,
        (ctx, setModalState) => [
          _sheetIcon(Icons.location_on_rounded),
          const SizedBox(height: 12),
          _sheetTitle('Site Visit'),
          const SizedBox(height: 6),
          _sheetQuestion('Was site visit completed?'),
          const SizedBox(height: 14),
          _yesNoRow(completed, (v) => setModalState(() => completed = v)),
          const SizedBox(height: 18),
          _inputField(
            hint: 'e.g. Skyline Apartments',
            label: 'Property Name (optional)',
            isDark: isDark,
            onChanged: (v) => propertyName = v,
          ),
          const SizedBox(height: 10),
          _sectionLabel('Client Interest Level', isDark),
          const SizedBox(height: 8),
          _chipRow(
            options: ['Low', 'Medium', 'High'],
            selected: interestLevel,
            onSelect: (v) => setModalState(() => interestLevel = v),
          ),
          const SizedBox(height: 14),
          _sectionLabel('Schedule Site Visit', isDark),
          const SizedBox(height: 8),
          _dateTimeRow(
            ctx: ctx,
            isDark: isDark,
            date: visitDate,
            time: visitTime,
            onDatePicked: (d) => setModalState(() => visitDate = d),
            onTimePicked: (t) => setModalState(() => visitTime = t),
          ),
          const SizedBox(height: 18),
          _submitButton(
            label: 'Submit Visit Log',
            enabled: completed,
            onTap: () {
              _logAction('site_visit', {
                'completed': completed,
                'property_name': propertyName,
                'interest_level': interestLevel,
                'visit_date': '${visitDate.year}-${visitDate.month.toString().padLeft(2, '0')}-${visitDate.day.toString().padLeft(2, '0')}',
                'visit_time': '${visitTime.hour.toString().padLeft(2, '0')}:${visitTime.minute.toString().padLeft(2, '0')}',
              });
              Navigator.pop(ctx, true);
            },
          ),
        ],
      ),
    );
  }

  // ─── Deal Negotiation Sheet ───
  Future<String?> _showDealNegotiationSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String status = 'In Progress';
    String amount = '';
    DateTime? closingDate;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheetWrapper(
        ctx,
        isDark,
        (ctx, setModalState) => [
          _sheetIcon(Icons.handshake_rounded),
          const SizedBox(height: 12),
          _sheetTitle('Deal Negotiation'),
          const SizedBox(height: 14),
          _sectionLabel('Negotiation Status?', isDark),
          const SizedBox(height: 8),
          _chipRow(
            options: ['In Progress', 'Paused', 'Finalized'],
            selected: status,
            onSelect: (v) => setModalState(() => status = v),
          ),
          const SizedBox(height: 14),
          _inputField(
            hint: '0.00',
            label: 'Agreed Amount (AED)',
            isDark: isDark,
            keyboardType: TextInputType.number,
            onChanged: (v) => amount = v,
          ),
          const SizedBox(height: 14),
          _sectionLabel('Expected Closing Date', isDark),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 730)),
              );
              if (picked != null) setModalState(() => closingDate = picked);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                closingDate != null
                    ? '${closingDate!.year}-${closingDate!.month.toString().padLeft(2, '0')}-${closingDate!.day.toString().padLeft(2, '0')}'
                    : 'Select Date',
                style: TextStyle(
                  color: closingDate != null
                      ? (isDark ? Colors.white : const Color(0xFF111827))
                      : const Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (status == 'Finalized')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Changing status to Finalized will prepare the contract for digital signature.',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          _submitButton(
            label: 'Save Negotiation Details',
            enabled: true,
            onTap: () {
              _logAction('deal_negotiation', {
                'status': status,
                'agreed_amount': amount,
                'closing_date': closingDate != null
                    ? '${closingDate!.year}-${closingDate!.month.toString().padLeft(2, '0')}-${closingDate!.day.toString().padLeft(2, '0')}'
                    : null,
              });
              Navigator.pop(ctx, status);
            },
          ),
        ],
      ),
    );
  }

  // ─── Deal Closed Celebration Screen ───
  Future<void> _showDealClosedScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String dealType = 'Buy';
    String dealAmount = '';
    String commission = '';
    final quarter = 'Q${((DateTime.now().month - 1) ~/ 3) + 1}';

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.92,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF020617) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    children: [
                      // ── Top bar with X and label ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF374151),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                            const Spacer(),
                            Text(
                              'SUCCESS STATE',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 1.2,
                                color: isDark
                                    ? Colors.white38
                                    : const Color(0xFF9CA3AF),
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Celebration icon with sparkles ──
                      SizedBox(
                        height: 110,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              left: 60,
                              top: 0,
                              child: Icon(Icons.auto_awesome,
                                  size: 22,
                                  color: Colors.amber.shade400),
                            ),
                            Positioned(
                              right: 80,
                              top: 20,
                              child: Icon(Icons.auto_awesome,
                                  size: 14,
                                  color: Colors.amber.shade300),
                            ),
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF22C55E)
                                    .withValues(alpha: 0.1),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF22C55E),
                                  size: 40,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 100,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBBF24),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'WIN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Title & subtitle ──
                      Text(
                        'Deal Closed!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          "Great work! Let's log the final numbers for\n'The Deal Room' records.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Deal Type ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DEAL TYPE',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.5,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: ['Buy', 'Rent', 'Off-plan'].map((t) {
                                final active = dealType == t;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () => setModalState(
                                        () => dealType = t),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      margin: EdgeInsets.only(
                                          right: t != 'Off-plan' ? 8 : 0),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? (isDark
                                                ? Colors.white
                                                : const Color(0xFF111827))
                                            : (isDark
                                                ? const Color(0xFF0F172A)
                                                : const Color(0xFFF3F4F6)),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: active
                                              ? Colors.transparent
                                              : (isDark
                                                  ? Colors.white10
                                                  : const Color(0xFFE5E7EB)),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          t,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: active
                                                ? (isDark
                                                    ? const Color(0xFF111827)
                                                    : Colors.white)
                                                : (isDark
                                                    ? Colors.white70
                                                    : const Color(0xFF374151)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 22),

                            // ── Total Deal Amount ──
                            Text(
                              'TOTAL DEAL AMOUNT',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.5,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white10
                                      : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 14),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: isDark
                                              ? Colors.white10
                                              : const Color(0xFFE5E7EB),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          'AED',
                                          style: TextStyle(
                                            color: const Color(0xFF2563EB),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const Icon(
                                            Icons.expand_more_rounded,
                                            size: 16,
                                            color: Color(0xFF2563EB)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => dealAmount = v,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF111827),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: '0.00',
                                        hintStyle: TextStyle(
                                            color: Color(0xFF9CA3AF)),
                                        border: InputBorder.none,
                                        contentPadding:
                                            EdgeInsets.symmetric(
                                                horizontal: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 22),

                            // ── Net Commission Earned ──
                            Text(
                              'NET COMMISSION EARNED',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.5,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white10
                                      : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Padding(
                                    padding:
                                        EdgeInsets.only(left: 14),
                                    child: Text(
                                      '\$',
                                      style: TextStyle(
                                        color: Color(0xFF9CA3AF),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => commission = v,
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF111827),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Enter amount',
                                        hintStyle: TextStyle(
                                            color: Color(0xFF9CA3AF)),
                                        border: InputBorder.none,
                                        contentPadding:
                                            EdgeInsets.symmetric(
                                                horizontal: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 18),

                            // ── Info note ──
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline_rounded,
                                      size: 16, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xFF64748B),
                                        ),
                                        children: [
                                          const TextSpan(
                                              text:
                                                  'This deal will be added to your '),
                                          TextSpan(
                                            text:
                                                '$quarter Performance Report',
                                            style: const TextStyle(
                                              color: Color(0xFF2563EB),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const TextSpan(
                                              text:
                                                  ' automatically once confirmed.'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ── Confirm & Celebrate button ──
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: () {
                                  _logAction('deal_closed', {
                                    'deal_type': dealType,
                                    'deal_amount': dealAmount,
                                    'commission': commission,
                                    'client_name': widget.clientName,
                                  });
                                  Navigator.pop(ctx);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF22C55E),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text('🎉',
                                        style: TextStyle(fontSize: 18)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Confirm & Celebrate',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // ── Footer ──
                            Center(
                              child: Text(
                                'LOGGED FOR THE DEAL ROOM CRM',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: isDark
                                      ? Colors.white24
                                      : const Color(0xFFD1D5DB),
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
        );
      },
    );
  }

  // ─── Referral Ask Sheet ───
  Future<bool?> _showReferralAskSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String source = 'Client';
    String result = 'Given';
    String referralName = '';

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheetWrapper(
        ctx,
        isDark,
        (ctx, setModalState) => [
          _sheetIcon(Icons.person_add_alt_1_rounded),
          const SizedBox(height: 12),
          _sheetTitle('Referral Ask'),
          const SizedBox(height: 14),
          _sectionLabel('Referral requested from?', isDark),
          const SizedBox(height: 8),
          _chipRow(
            options: ['Client', 'Investor', 'Friend', 'Post Client'],
            selected: source,
            onSelect: (v) => setModalState(() => source = v),
          ),
          const SizedBox(height: 14),
          _sectionLabel('Result', isDark),
          const SizedBox(height: 8),
          _chipRow(
            options: ['Given', 'Will revert', 'Declined'],
            selected: result,
            onSelect: (v) => setModalState(() => result = v),
          ),
          const SizedBox(height: 14),
          _inputField(
            hint: 'Enter full name',
            label: 'Referral Name',
            isDark: isDark,
            onChanged: (v) => referralName = v,
          ),
          const SizedBox(height: 18),
          _submitButton(
            label: 'Save Referral Info',
            enabled: true,
            onTap: () {
              _logAction('referral_ask', {
                'source': source,
                'result': result,
                'referral_name': referralName,
              });
              Navigator.pop(ctx, true);
            },
          ),
        ],
      ),
    );
  }

  // ═══════ Shared sheet building blocks ═══════

  Widget _sheetWrapper(
    BuildContext ctx,
    bool isDark,
    List<Widget> Function(BuildContext, StateSetter) builder,
  ) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        top: 8,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF020617) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 26,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ...builder(ctx, setModalState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetIcon(IconData icon) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF2563EB), size: 22),
      ),
    );
  }

  Widget _sheetTitle(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _sheetQuestion(String text) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
      ),
    );
  }

  Widget _yesNoRow(bool selected, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: _pillButton(
            text: 'No',
            active: !selected,
            activeColor: const Color(0xFFE5E7EB),
            textColor: const Color(0xFF111827),
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _pillButton(
            text: 'Yes',
            active: selected,
            activeColor: const Color(0xFF2563EB),
            textColor: Colors.white,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.white : const Color(0xFF111827),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _inputField({
    required String hint,
    required String label,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF374151),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _chipRow({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isActive = opt == selected;
        return GestureDetector(
          onTap: () => onSelect(opt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF2563EB) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Text(
              opt,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF374151),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _dateTimeRow({
    required BuildContext ctx,
    required bool isDark,
    required DateTime date,
    required TimeOfDay time,
    required ValueChanged<DateTime> onDatePicked,
    required ValueChanged<TimeOfDay> onTimePicked,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.event_rounded),
            title: Text(
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            trailing: const Icon(Icons.expand_more_rounded),
            onTap: () async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: date,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) onDatePicked(picked);
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.access_time_rounded),
            title: Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            trailing: const Icon(Icons.expand_more_rounded),
            onTap: () async {
              final picked = await showTimePicker(context: ctx, initialTime: time);
              if (picked != null) onTimePicked(picked);
            },
          ),
        ],
      ),
    );
  }

  Widget _submitButton({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? const Color(0xFF2563EB) : Colors.grey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  Future<bool?> _showFollowUpSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool completed = true;

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _sheetWrapper(
        ctx,
        isDark,
        (ctx, setModalState) => [
          _sheetIcon(Icons.event_available_rounded),
          const SizedBox(height: 12),
          _sheetTitle('Follow-up'),
          const SizedBox(height: 6),
          _sheetQuestion('Was this follow-up completed?'),
          const SizedBox(height: 14),
          _yesNoRow(completed, (v) => setModalState(() => completed = v)),
          const SizedBox(height: 18),
          _sectionLabel('Pick New Schedule', isDark),
          const SizedBox(height: 8),
          _dateTimeRow(
            ctx: ctx,
            isDark: isDark,
            date: _scheduledAt,
            time: TimeOfDay.fromDateTime(_scheduledAt),
            onDatePicked: (d) => setModalState(() {
              _scheduledAt = DateTime(d.year, d.month, d.day,
                  _scheduledAt.hour, _scheduledAt.minute);
            }),
            onTimePicked: (t) => setModalState(() {
              _scheduledAt = DateTime(_scheduledAt.year, _scheduledAt.month,
                  _scheduledAt.day, t.hour, t.minute);
            }),
          ),
          const SizedBox(height: 18),
          _submitButton(
            label: completed ? 'Save Follow-up' : 'Skip for now',
            enabled: completed,
            onTap: () => Navigator.pop(ctx, completed),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF020617) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF020617) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: isDark ? const Color(0xFF020617) : Colors.white,
        foregroundColor: isDark ? Colors.white : const Color(0xFF111827),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.clientName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Revenue Actions',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.6,
                color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF020617) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.4 : 0.06,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text(
                        'REVENUE ACTIONS',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF9CA3AF),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Daily Log',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF111827),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'DAILY LOG',
                              style: TextStyle(
                                color: Color(0xFF4F46E5),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _dateKey,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._actions.map((action) => _actionRow(
                            keyValue: action['key'] ?? '',
                            label: action['label'] ?? '',
                            status: (action['status'] ?? '') as String,
                            onYes: () => _handleYesTap(action['key']),
                            onNo: () => _setStatus(action['key'], 'no'),
                            isDark: isDark,
                          )),
                      const SizedBox(height: 24),
                      Text(
                        'ACTIVITY FOR THIS CLIENT',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF9CA3AF),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_clientActivities.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No activities yet. Log actions above to see them here.',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white38
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        )
                      else
                        ..._clientActivities.asMap().entries.map((entry) {
                          final activity = entry.value;
                          final type = activity['type'] ?? '';
                          final timestamp = activity['created_at'] ??
                              activity['date']?.toString();
                          return _buildClientActivityItem(
                            activity,
                            type,
                            timestamp,
                            isDark,
                            entry.key == _clientActivities.length - 1,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  String _getActionLabelFromNotes(dynamic activity) {
    try {
      final notes = activity['notes'];
      if (notes is String && notes.isNotEmpty) {
        final map = jsonDecode(notes) as Map<String, dynamic>?;
        final label = map?['action_label']?.toString();
        if (label != null && label.isNotEmpty) return label;
      }
    } catch (_) {}
    return 'Activity';
  }

  String _getActivityDescription(dynamic activity, String type) {
    switch (type) {
      case 'hot_lead':
        return 'Initial outreach via phone';
      case 'deal_closed':
        return 'Deal successfully closed';
      case 'commission':
        return 'Commission received';
      case 'revenue_action':
        return _getActionLabelFromNotes(activity);
      default:
        return type.toString().replaceAll('_', ' ');
    }
  }

  String _getStatusLabel(String type) {
    switch (type) {
      case 'hot_lead':
        return 'Interested';
      case 'deal_closed':
        return 'Deal Closed';
      case 'commission':
        return 'Completed';
      case 'revenue_action':
        return 'Completed';
      default:
        return 'In Progress';
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'hot_lead':
        return Icons.local_fire_department_rounded;
      case 'deal_closed':
        return Icons.celebration_rounded;
      case 'commission':
        return Icons.monetization_on_rounded;
      case 'revenue_action':
        return Icons.task_alt_rounded;
      default:
        return Icons.circle;
    }
  }

  Color _getActivityIconColor(String type) {
    switch (type) {
      case 'hot_lead':
        return const Color(0xFF3B82F6);
      case 'deal_closed':
        return const Color(0xFF10B981);
      case 'commission':
        return const Color(0xFFF97316);
      case 'revenue_action':
        return const Color(0xFF6366F1);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Recently';
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${diff.inDays} days ago';
    } catch (_) {
      return 'Recently';
    }
  }

  Widget _buildClientActivityItem(
    dynamic activity,
    String type,
    dynamic timestamp,
    bool isDark,
    bool isLast,
  ) {
    final icon = _getActivityIcon(type);
    final iconColor = _getActivityIconColor(type);
    final statusLabel = _getStatusLabel(type);
    final statusColor = iconColor;
    final description = _getActivityDescription(activity, type);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 50,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey[200],
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Text(
          _formatTimestamp(timestamp?.toString()),
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _actionRow({
    required String keyValue,
    required String label,
    required String status,
    required VoidCallback onYes,
    required VoidCallback onNo,
    required bool isDark,
  }) {
    final hasYes = status == 'yes';
    final hasNo = status == 'no';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF020617) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF111827),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          _pillButton(
            text: 'No',
            active: hasNo,
            activeColor: const Color(0xFFE5E7EB),
            textColor: const Color(0xFF111827),
            onTap: onNo,
          ),
          const SizedBox(width: 6),
          _pillButton(
            text: 'Yes',
            active: hasYes,
            activeColor: const Color(0xFF2563EB),
            textColor: Colors.white,
            onTap: onYes,
          ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required String text,
    required bool active,
    required Color activeColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? textColor : const Color(0xFF6B7280),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

