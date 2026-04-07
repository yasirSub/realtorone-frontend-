import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

/// Keep in sync with `App\Support\FollowUpFlow::MAX_CONTINUE_TOUCHES`
const int _kFollowUpMaxContinue = 5;

class _ClientRevenueActionsPageState extends State<ClientRevenueActionsPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _actions = [];
  List<dynamic> _clientActivities = [];
  final String _dateKey = DateTime.now().toIso8601String().split('T').first;
  String? _currentLeadStage;
  String? _clientCreatedAt;
  Map<String, dynamic>? _coldCalling;
  bool _ccSubmitting = false;
  String _ccMode = 'call'; // call | whatsapp
  Map<String, dynamic>? _followUp;
  bool _fuSubmitting = false;
  String _fuMode = 'call'; // call | whatsapp | email
  Map<String, dynamic>? _clientMeeting;
  bool _cmSubmitting = false;
  String _cmMode = 'in_person';
  Map<String, dynamic>? _dealNegotiation;
  bool _dnSubmitting = false;
  String _dnMode = 'call';
  Map<String, dynamic>? _dealClosure;
  bool _dcSubmitting = false;
  String _dcMode = 'call';

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

        final client = data['client'];
        if (client != null) {
          _clientCreatedAt = client['created_at']?.toString();
          if (client['notes'] != null) {
            try {
              final notes = jsonDecode(client['notes']);
              _currentLeadStage =
                  _normalizePipelineStage(notes['lead_stage']?.toString());
              final cc = notes['cold_calling'];
              if (cc is Map) {
                _coldCalling = Map<String, dynamic>.from(cc);
                final m = _coldCalling!['mode']?.toString();
                if (m == 'whatsapp' || m == 'call') {
                  _ccMode = m!;
                }
              } else {
                _coldCalling = null;
              }
              final fu = notes['follow_up'];
              if (fu is Map) {
                _followUp = Map<String, dynamic>.from(fu);
                final fm = _followUp!['mode']?.toString();
                if (fm == 'whatsapp' || fm == 'call' || fm == 'email') {
                  _fuMode = fm!;
                }
              } else {
                _followUp = null;
              }
              final cm = notes['client_meeting'];
              if (cm is Map) {
                _clientMeeting = Map<String, dynamic>.from(cm);
                final cmm = _clientMeeting!['mode']?.toString();
                if (['in_person', 'video', 'call', 'whatsapp'].contains(cmm)) {
                  _cmMode = cmm!;
                }
              } else {
                _clientMeeting = null;
              }
              final dn = notes['deal_negotiation'];
              if (dn is Map) {
                _dealNegotiation = Map<String, dynamic>.from(dn);
                final dnm = _dealNegotiation!['mode']?.toString();
                if (['in_person', 'video', 'call', 'whatsapp', 'email'].contains(dnm)) {
                  _dnMode = dnm!;
                }
              } else {
                _dealNegotiation = null;
              }
              final dcl = notes['deal_closure'];
              if (dcl is Map) {
                _dealClosure = Map<String, dynamic>.from(dcl);
                final dcm = _dealClosure!['mode']?.toString();
                if (['call', 'whatsapp', 'email'].contains(dcm)) {
                  _dcMode = dcm!;
                }
              } else {
                _dealClosure = null;
              }
            } catch (_) {}
          }
        }
      }
      await _loadClientActivities();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Aligns legacy PDF/backend spellings with the five canonical CRM stages.
  String? _normalizePipelineStage(String? raw) {
    if (raw == null || raw.isEmpty) return raw;
    final t = raw.toLowerCase().trim();
    if (t.contains('site') || t.contains('visite')) return 'deal negotiation';
    if (t.contains('clint')) return 'client meeting';
    return t;
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

    if (status == 'yes') {
      setState(() {
        _actions[index]['status'] = 'yes';
      });
    }

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
      if (res['success'] == true) {
        await _load();
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
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
      case 'cold_calling':
        await _setStatus(key, 'yes');
        break;
      case 'follow_up_back':
        await _setStatus(key, 'yes');
        break;
      case 'client_meeting':
        await _setStatus(key, 'yes');
        break;
      case 'deal_negotiation':
        await _setStatus(key, 'yes');
        break;
      case 'deal_close':
        await _setStatus(key, 'yes');
        break;
      default:
        await _setStatus(key, 'yes');
    }
  }

  String? _crmDaySubtitle() {
    if (_clientCreatedAt == null) return null;
    final dt = DateTime.tryParse(_clientCreatedAt!);
    if (dt == null) return null;
    final days = DateTime.now().difference(dt).inDays + 1;
    final ymd = dt.toIso8601String().split('T').first;
    return 'CRM Day $days · since $ymd';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final crmLine = _crmDaySubtitle();

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
        toolbarHeight: 68,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 22,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.rocket_launch_rounded,
                size: 22,
                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 4),
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
            if (crmLine != null) ...[
              const SizedBox(height: 2),
              Text(
                crmLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: isDark ? Colors.blue.shade200 : const Color(0xFF2563EB),
                ),
              ),
            ],
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStageStepper(isDark),
                  const SizedBox(height: 12),
                  _buildCurrentStageAction(isDark),
                  const SizedBox(height: 18),
                  Text(
                    'ACTIVITY HISTORY',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_clientActivities.isEmpty)
                    _emptyActivity(isDark)
                  else
                    ..._clientActivities.asMap().entries.map((entry) {
                      return _buildClientActivityItem(
                        entry.value,
                        entry.value['type'] ?? '',
                        entry.value['created_at'] ?? entry.value['date'],
                        isDark,
                        entry.key == _clientActivities.length - 1,
                      );
                    }),
                ],
              ),
            ).animate().fade(duration: 400.ms).slideY(
                  begin: 0.05,
                  end: 0,
                  duration: 400.ms,
                  curve: Curves.easeOutQuad,
                ),
    );
  }

  /// Readable goal title (avoids "FOLLOW-UP" all-caps vs stepper wording clash).
  String _prettyGoalTitle(String key, String apiLabel) {
    switch (key) {
      case 'cold_calling':
        return 'Cold calling';
      case 'follow_up_back':
        return 'Follow-up';
      case 'client_meeting':
        return 'Client meeting';
      case 'deal_negotiation':
        return 'Deal negotiation';
      case 'deal_close':
        return 'Deal closure';
      default:
        if (apiLabel.isEmpty) return 'Pipeline';
        return apiLabel[0].toUpperCase() + apiLabel.substring(1).toLowerCase();
    }
  }

  Widget _buildStageStepper(bool isDark) {
    const stages = [
      'cold calling',
      'follow up back',
      'client meeting',
      'deal negotiation',
      'deal close',
    ];
    const stageTitles = ['Cold', 'Follow', 'Meet', 'Nego', 'Close'];
    final normalized = _currentLeadStage?.toLowerCase();
    int currentIdx =
        normalized == null ? 0 : stages.indexOf(normalized);
    if (currentIdx == -1) currentIdx = 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          double dot = 24;
          var gap = (w - 5 * dot) / 4;
          if (gap < 2 && w > 0) {
            dot = ((w - 8) / 5).clamp(15.0, 24.0);
            gap = (w - 5 * dot) / 4;
          }
          final stackH = dot + 22.0;
          final lineY = dot / 2 - 1.5;
          final numSize = (dot * 0.48).clamp(11.0, 13.0);

          Color segColor(int segIndex) {
            if (segIndex < currentIdx) {
              return const Color(0xFF22C55E);
            }
            return isDark
                ? Colors.white.withValues(alpha: 0.11)
                : const Color(0xFFE2E8F0);
          }

          Widget dotFace(int index) {
            final isCompleted = index < currentIdx;
            final isCurrent = index == currentIdx;
            const done = Color(0xFF16A34A);
            const active = Color(0xFF3B82F6);
            final idleFill =
                isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
            final idleBorder = isDark
                ? Colors.white.withValues(alpha: 0.14)
                : const Color(0xFFCBD5E1);

            if (isCompleted) {
              return Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: done,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: done.withValues(alpha: 0.32),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: dot * 0.52,
                  color: Colors.white,
                ),
              );
            }

            if (isCurrent) {
              return Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: active,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: active.withValues(alpha: 0.42),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: numSize,
                      height: 1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              );
            }

            return Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: idleFill,
                shape: BoxShape.circle,
                border: Border.all(color: idleBorder, width: 1.2),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.44)
                        : const Color(0xFF64748B),
                    fontWeight: FontWeight.w800,
                    fontSize: numSize * 0.96,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            );
          }

          final labelW = ((w - 8) / 5).clamp(28.0, 56.0);

          return SizedBox(
            width: w,
            height: stackH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = 0; i < 4; i++)
                  Positioned(
                    left: dot + i * (dot + gap),
                    top: lineY,
                    width: gap.clamp(0.0, double.infinity),
                    height: 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: segColor(i),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                for (int i = 0; i < 5; i++)
                  Positioned(
                    left: i * (dot + gap),
                    top: 0,
                    child: dotFace(i),
                  ),
                for (int i = 0; i < 5; i++)
                  Positioned(
                    left: i * (dot + gap) + dot / 2 - labelW / 2,
                    top: dot + 4,
                    width: labelW,
                    child: Text(
                      stageTitles[i],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.08,
                        letterSpacing: -0.12,
                        fontWeight:
                            stages[i].toLowerCase() ==
                                    _currentLeadStage?.toLowerCase()
                                ? FontWeight.w900
                                : FontWeight.w600,
                        color: stages[i].toLowerCase() ==
                                _currentLeadStage?.toLowerCase()
                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
                            : (isDark
                                ? Colors.white38
                                : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentStageAction(bool isDark) {
    if (_currentLeadStage == null && _actions.isEmpty) return const SizedBox();

    // Match API keys (e.g. deal_negotiation) to current pipeline stage
    final currentStageNormalized =
        _currentLeadStage?.toLowerCase().replaceAll(' ', '_');
    final activeAction = _actions.firstWhere(
      (a) => a['key'] == currentStageNormalized,
      orElse: () => _actions.isNotEmpty ? _actions.first : {'key': 'none', 'label': 'N/A'},
    );

    final String key = activeAction['key']?.toString() ?? 'none';
    final String rawLabel = (activeAction['label'] ?? '').toString();
    final String label = _prettyGoalTitle(key, rawLabel);
    final bool isDoneToday = activeAction['status'] == 'yes';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _crmFlowSectionTitle(isDark, 'Today’s action'),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.35,
              height: 1.12,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _compactStageHint(key),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.3,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          _buildStageFooter(isDark, key, label, isDoneToday),
        ],
      ),
    );
  }

  String _compactStageHint(String key) {
    switch (key) {
      case 'cold_calling':
        return 'Pick how you contacted them, then tap the result.';
      case 'follow_up_back':
        return 'Log touch and schedule next step.';
      case 'client_meeting':
        return 'Track meeting touch and outcome.';
      case 'deal_negotiation':
        return 'Log negotiation touch and progress.';
      case 'deal_close':
        return 'Close deal or schedule paperwork follow-up.';
      default:
        return 'Log today\'s stage action.';
    }
  }

  Widget _buildStageFooter(bool isDark, String key, String label, bool isDoneToday) {
    if (key == 'cold_calling' && !isDoneToday) {
      final bucket = _coldCalling?['bucket']?.toString() ?? 'in_progress';
      if (bucket == 'nutshell') {
        return _coldCallTerminalBox(
          isDark,
          'Nutshell list',
          'No answer after 4 call attempts. No further call sequence — pick up from lists or archive.',
          Icons.voicemail_rounded,
        );
      }
      if (bucket == 'nurture_whatsapp') {
        return _coldCallTerminalBox(
          isDark,
          'Nurture (Retargeting)',
          'No reply after 3 WhatsApp attempts. Move to nurture / retargeting.',
          Icons.forum_outlined,
        );
      }
      if (bucket == 'retargeting') {
        return _coldCallTerminalBox(
          isDark,
          'Retargeting list',
          'Marked not interested. Use nurture campaigns or revisit later.',
          Icons.low_priority_rounded,
        );
      }
      return _buildColdCallingFlow(isDark, label);
    }

    if (key == 'follow_up_back' && !isDoneToday) {
      final bucket = _followUp?['bucket']?.toString() ?? 'in_progress';
      if (bucket == 'stalled') {
        return _coldCallTerminalBox(
          isDark,
          'Stalled (nurture)',
          'Max scheduled follow-up touches reached. Revisit later or move stage manually.',
          Icons.pause_circle_outline_rounded,
        );
      }
      if (bucket == 'retargeting') {
        return _coldCallTerminalBox(
          isDark,
          'Retargeting list',
          'Marked not interested at follow-up. Use nurture campaigns or revisit later.',
          Icons.low_priority_rounded,
        );
      }
      return _buildFollowUpFlow(isDark, label);
    }

    if (key == 'client_meeting' && !isDoneToday) {
      final bucket = _clientMeeting?['bucket']?.toString() ?? 'in_progress';
      if (bucket == 'stalled') {
        return _coldCallTerminalBox(
          isDark,
          'Stalled',
          'Max meeting follow-ups reached. Revisit or advance stage manually.',
          Icons.pause_circle_outline_rounded,
        );
      }
      if (bucket == 'retargeting') {
        return _coldCallTerminalBox(
          isDark,
          'Retargeting list',
          'Marked not interested at client meeting.',
          Icons.low_priority_rounded,
        );
      }
      return _buildClientMeetingFlow(isDark, label);
    }

    if (key == 'deal_negotiation' && !isDoneToday) {
      final bucket = _dealNegotiation?['bucket']?.toString() ?? 'in_progress';
      if (bucket == 'stalled') {
        return _coldCallTerminalBox(
          isDark,
          'Stalled',
          'Max negotiation follow-ups reached.',
          Icons.pause_circle_outline_rounded,
        );
      }
      if (bucket == 'retargeting') {
        return _coldCallTerminalBox(
          isDark,
          'Retargeting list',
          'Marked not interested during negotiation.',
          Icons.low_priority_rounded,
        );
      }
      return _buildDealNegotiationFlow(isDark, label);
    }

    if (key == 'deal_close' && !isDoneToday) {
      final bucket = _dealClosure?['bucket']?.toString() ?? 'in_progress';
      if (bucket == 'stalled') {
        return _coldCallTerminalBox(
          isDark,
          'Stalled',
          'Max closure follow-ups reached. Revisit paperwork or adjust manually.',
          Icons.pause_circle_outline_rounded,
        );
      }
      if (bucket == 'retargeting') {
        return _coldCallTerminalBox(
          isDark,
          'Deal lost',
          'Marked lost at closure stage.',
          Icons.sentiment_dissatisfied_outlined,
        );
      }
      return _buildDealClosureFlow(isDark, label);
    }

    if (isDoneToday) {
      return _completedTodayStrip(isDark);
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _handleYesTap(key),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
            label: Text(
              'Mark $label done for today',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: () => _setStatus(key, 'no'),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.white54 : const Color(0xFF64748B),
            side: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : const Color(0xFFE2E8F0),
            ),
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Stay in this stage',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _coldCallTerminalBox(
    bool isDark,
    String title,
    String body,
    IconData icon,
  ) {
    return _crmMutedPanel(
      isDark,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.orangeAccent, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: _crmCaptionStyle(isDark).copyWith(
                      color: isDark
                          ? Colors.orange.shade200
                          : Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.32,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Recognizable channel marks: phone call, WhatsApp asset, Gmail-style mail.
  Widget _crmChannelGlyph(
    String mode,
    bool selected,
    bool isDark, {
    double size = 26,
  }) {
    switch (mode) {
      case 'call':
        return Icon(
          Icons.call_rounded,
          size: size,
          color: selected
              ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534))
              : (isDark ? Colors.white54 : const Color(0xFF64748B)),
        );
      case 'whatsapp':
        return Opacity(
          opacity: selected ? 1 : 0.72,
          child: Image.asset(
            'assets/images/whatsapp.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => FaIcon(
              FontAwesomeIcons.whatsapp,
              size: size * 0.92,
              color: const Color(0xFF25D366),
            ),
          ),
        );
      case 'email':
        return Icon(
          Icons.mark_email_read_rounded,
          size: size,
          color: selected
              ? const Color(0xFFEA4335)
              : (isDark
                  ? const Color(0xFFF87171).withValues(alpha: 0.7)
                  : const Color(0xFFDC2626).withValues(alpha: 0.75)),
        );
      default:
        return SizedBox(width: size, height: size);
    }
  }

  // --- Shared layout: simple, consistent across Cold / Follow / Meet / Nego / Close ---

  TextStyle _crmCaptionStyle(bool isDark) => TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.65,
        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
      );

  Widget _crmFlowSectionTitle(bool isDark, String title) => Text(
        title.toUpperCase(),
        style: _crmCaptionStyle(isDark),
      );

  Widget _crmMutedPanel(bool isDark, {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  /// Thin rule between sections inside a single flow card (cold calling).
  Widget _crmSoftDivider(bool isDark, {double verticalPad = 8}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPad),
      child: Divider(
        height: 1,
        thickness: 1,
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFE2E8F0),
      ),
    );
  }

  /// Readable label for touch strips (avoids hard-to-scan ALL CAPS).
  String _crmProgressStripTitle(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return t;
    if (t == t.toUpperCase()) {
      return t.split(RegExp(r'\s+')).map((w) {
        if (w.isEmpty) return w;
        final lower = w.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      }).join(' ');
    }
    return '${t[0].toUpperCase()}${t.substring(1)}';
  }

  Widget _crmTouchProgressStrip(
    bool isDark,
    String label,
    int touch,
    int max, {
    String? footnote,
  }) {
    final pct = max > 0 ? (touch / max).clamp(0.0, 1.0) : 0.0;
    final title = _crmProgressStripTitle(label);
    final track = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : const Color(0xFFE2E8F0);
    final fill = const Color(0xFF2563EB);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.72)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.11)
              : const Color(0xFFCBD5E1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.insights_rounded,
                size: 20,
                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.15,
                    height: 1.25,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue.withValues(alpha: 0.22)
                      : const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isDark
                        ? Colors.blue.withValues(alpha: 0.35)
                        : const Color(0xFF93C5FD).withValues(alpha: 0.65),
                  ),
                ),
                child: Text(
                  '$touch / $max',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color:
                        isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1E40AF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: track,
              color: fill,
            ),
          ),
          if (footnote != null && footnote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              footnote,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.35,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _crmNextContactLine(bool isDark, String? next, {bool padTop = true}) {
    if (next == null || next.isEmpty) return const SizedBox.shrink();
    final d = next.split('T').first;
    return Padding(
      padding: EdgeInsets.only(top: padTop ? 6 : 0),
      child: Row(
        children: [
          Icon(
            Icons.event_note_rounded,
            size: 15,
            color: isDark ? Colors.blue.shade300 : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Next contact · $d',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.blue.shade200 : const Color(0xFF1D4ED8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _crmOutcomePair({
    required bool isDark,
    required bool submitting,
    required String positiveLabel,
    required VoidCallback? onPositive,
    required String negativeLabel,
    required VoidCallback? onNegative,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: submitting ? null : onPositive,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF166534),
              side: const BorderSide(color: Color(0xFF22C55E)),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              positiveLabel,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: submitting ? null : onNegative,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC2410C),
              side: const BorderSide(color: Color(0xFFFB923C)),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              negativeLabel,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _crmModeScrollRow(List<Widget> chips, {double chipMinWidth = 76}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: chipMinWidth),
              child: chips[i],
            ),
          ],
        ],
      ),
    );
  }

  Widget _crmSuccessCTA({
    required bool isDark,
    required VoidCallback? onPressed,
    required String label,
    IconData icon = Icons.check_circle_outline_rounded,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF16A34A),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade700,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _crmTertiaryButton({
    required bool isDark,
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    Color? foreground,
    Color? borderColor,
  }) {
    final fg = foreground ??
        (isDark ? Colors.white70 : const Color(0xFF334155));
    final br = borderColor ??
        (isDark ? Colors.white24 : const Color(0xFFCBD5E1));
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: br),
          padding: const EdgeInsets.symmetric(vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildModeChip({
    required String mode,
    required String currentMode,
    required dynamic icon,
    required bool isDark,
    required bool isSubmitting,
    required ValueChanged<String> onSelect,
    String? shortLabel,
  }) {
    final sel = currentMode == mode;
    final isFa = icon.runtimeType.toString().contains('FaIconData');
    final iconColor = sel
        ? (isDark ? Colors.blue.shade200 : const Color(0xFF1D4ED8))
        : (isDark ? Colors.white54 : const Color(0xFF64748B));
    final labelColor = sel
        ? (isDark ? Colors.white : const Color(0xFF1E3A8A))
        : (isDark ? Colors.white54 : const Color(0xFF64748B));

    Widget iconWidget() {
      if (mode == 'call' || mode == 'whatsapp' || mode == 'email') {
        return _crmChannelGlyph(mode, sel, isDark, size: 22);
      }
      return isFa
          ? FaIcon(icon, size: 19, color: iconColor)
          : Icon(icon, size: 19, color: iconColor);
    }

    return Material(
      color: sel
          ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF))
          : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: sel
              ? (isDark ? Colors.blue.shade400 : const Color(0xFF3B82F6))
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          width: sel ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isSubmitting ? null : () => onSelect(mode),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: shortLabel != null ? 8 : 8,
            horizontal: 7,
          ),
          child: shortLabel == null
              ? Center(child: iconWidget())
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    iconWidget(),
                    const SizedBox(height: 4),
                    Text(
                      shortLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: labelColor,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _scheduleTouchLeading(
    String channelMode,
    bool loading,
    bool isDark,
  ) {
    if (loading) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: isDark ? Colors.blue.shade300 : const Color(0xFF2563EB),
        ),
      );
    }
    switch (channelMode) {
      case 'whatsapp':
        return _crmChannelGlyph('whatsapp', true, isDark, size: 24);
      case 'email':
        return _crmChannelGlyph('email', true, isDark, size: 24);
      case 'call':
        return _crmChannelGlyph('call', true, isDark, size: 24);
      case 'in_person':
        return Icon(
          Icons.person_pin_circle_rounded,
          size: 24,
          color: isDark ? Colors.purple.shade200 : const Color(0xFF7C3AED),
        );
      case 'video':
        return Icon(
          Icons.videocam_rounded,
          size: 24,
          color: isDark ? Colors.blue.shade200 : const Color(0xFF2563EB),
        );
      default:
        return Icon(
          Icons.schedule_send_rounded,
          size: 24,
          color: isDark ? Colors.blue.shade200 : const Color(0xFF2563EB),
        );
    }
  }

  /// Calm card CTA for “log touch → pick next date” (less loud than full gradient).
  Widget _buildScheduleTouchButton({
    required bool isDark,
    required bool loading,
    required VoidCallback? onPressed,
    required String channelMode,
    required String title,
    required String subtitle,
  }) {
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFE2E8F0);
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final iconBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFEFF6FF);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 11, 10, 11),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _scheduleTouchLeading(channelMode, loading, isDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.05,
                          height: 1.22,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isDark
                      ? Colors.white.withValues(alpha: loading ? 0.3 : 0.45)
                      : const Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColdCallingFlow(bool isDark, String label) {
    final callA = int.tryParse(_coldCalling?['call_attempt']?.toString() ?? '0') ?? 0;
    final waA = int.tryParse(_coldCalling?['wa_attempt']?.toString() ?? '0') ?? 0;
    final next = _coldCalling?['next_contact_at']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _crmMutedPanel(
          isDark,
          children: [
            _ccAttemptLimitBlock(isDark, callA, waA),
            if (next != null && next.isNotEmpty) ...[
              const SizedBox(height: 4),
              _crmNextContactLine(isDark, next, padTop: false),
            ],
            _crmSoftDivider(isDark, verticalPad: 6),
            _crmFlowSectionTitle(isDark, 'How did you reach them?'),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: _buildModeChip(
                    mode: 'call',
                    currentMode: _ccMode,
                    icon: Icons.call_rounded,
                    isDark: isDark,
                    isSubmitting: _ccSubmitting,
                    shortLabel: 'Call',
                    onSelect: (v) => setState(() => _ccMode = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModeChip(
                    mode: 'whatsapp',
                    currentMode: _ccMode,
                    icon: FontAwesomeIcons.whatsapp,
                    isDark: isDark,
                    isSubmitting: _ccSubmitting,
                    shortLabel: 'WhatsApp',
                    onSelect: (v) => setState(() => _ccMode = v),
                  ),
                ),
              ],
            ),
            _crmSoftDivider(isDark, verticalPad: 6),
            _crmFlowSectionTitle(isDark, 'Outcome'),
            const SizedBox(height: 2),
            _ccOutcomeListRow(
              isDark: isDark,
              title: 'Interested',
              subtitle: 'They want to move forward',
              accent: const Color(0xFF16A34A),
              enabled: !_ccSubmitting,
              onTap: () => _submitColdCalling('interested'),
            ),
            _ccOutcomeListDivider(isDark),
            _ccOutcomeListRow(
              isDark: isDark,
              title: 'Exploring',
              subtitle: 'Thinking it over or needs more info',
              accent: const Color(0xFF0D9488),
              enabled: !_ccSubmitting,
              onTap: () => _submitColdCalling('exploring'),
            ),
            _ccOutcomeListDivider(isDark),
            _ccOutcomeListRow(
              isDark: isDark,
              title: 'Not interested',
              subtitle: 'Declined for now',
              accent: const Color(0xFFEA580C),
              enabled: !_ccSubmitting,
              onTap: () => _submitColdCalling('not_interested'),
            ),
            _crmSoftDivider(isDark, verticalPad: 6),
            Text('NO ANSWER?', style: _crmCaptionStyle(isDark)),
            const SizedBox(height: 2),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _ccSubmitting ? null : () => _onColdCallNoAnswerOrNoReply(isDark),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _ccMode == 'call'
                            ? Icons.phone_missed_rounded
                            : Icons.mark_chat_unread_rounded,
                        size: 20,
                        color: isDark ? Colors.white60 : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _ccMode == 'call'
                              ? 'No answer — schedule next try'
                              : 'No reply — schedule next try',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            height: 1.25,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _ccAttemptLimitBlock(bool isDark, int callA, int waA) {
    final muted = isDark ? Colors.white54 : const Color(0xFF64748B);
    Widget row(String channelLabel, int cur, int max, Color bar) {
      final v = max > 0 ? (cur / max).clamp(0.0, 1.0) : 0.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  channelLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ),
              Text(
                '$cur / $max',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 4,
              backgroundColor:
                  isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              color: bar,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ATTEMPT LIMITS', style: _crmCaptionStyle(isDark)),
        const SizedBox(height: 6),
        row('Phone', callA, 4, const Color(0xFF3B82F6)),
        const SizedBox(height: 6),
        row('WhatsApp', waA, 3, const Color(0xFF22C55E)),
      ],
    );
  }

  Widget _ccOutcomeListDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 20,
      endIndent: 0,
      color: isDark
          ? Colors.white.withValues(alpha: 0.07)
          : const Color(0xFFE2E8F0),
    );
  }

  Widget _ccOutcomeListRow({
    required bool isDark,
    required String title,
    required String subtitle,
    required Color accent,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration:
                    BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: -0.15,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                        color:
                            isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitColdCalling(String result) async {
    await _postColdCalling(result, schedule: 'tomorrow', nextDate: null);
  }

  Future<void> _onColdCallNoAnswerOrNoReply(bool isDark) async {
    final picked = await _pickNextSchedule(isDark);
    if (picked == null || !mounted) return;
    final r = _ccMode == 'call' ? 'no_answer' : 'no_reply';
    await _postColdCalling(
      r,
      schedule: picked['schedule'] ?? 'tomorrow',
      nextDate: picked['date'],
    );
  }

  Future<Map<String, String?>?> _pickNextSchedule(bool isDark) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Next reminder',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'When should we prompt you to reach out again?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isDark
                      ? Colors.blue.withValues(alpha: 0.2)
                      : const Color(0xFFEFF6FF),
                  child: Icon(Icons.wb_sunny_outlined,
                      color: isDark ? Colors.blue.shade200 : const Color(0xFF2563EB)),
                ),
                title: const Text('Tomorrow', style: TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => Navigator.pop(ctx, 'tomorrow'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFF1F5F9),
                  child: Icon(Icons.date_range_rounded,
                      color: isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                title: const Text('In 2 days', style: TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => Navigator.pop(ctx, 'plus_2_days'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFF1F5F9),
                  child: Icon(Icons.edit_calendar_rounded,
                      color: isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                title: const Text('Choose a date', style: TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => Navigator.pop(ctx, 'custom'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return null;
    if (choice == 'custom') {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: now.add(const Duration(days: 1)),
        firstDate: now,
        lastDate: now.add(const Duration(days: 365)),
      );
      if (picked == null) return null;
      final customDate =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      return {'schedule': 'custom', 'date': customDate};
    }
    return {'schedule': choice, 'date': null};
  }

  Future<void> _postColdCalling(
    String result, {
    required String schedule,
    String? nextDate,
  }) async {
    setState(() => _ccSubmitting = true);
    try {
      final body = <String, dynamic>{
        'mode': _ccMode,
        'result': result,
        if (result == 'no_answer' || result == 'no_reply') ...{
          'schedule': schedule,
          if (schedule == 'custom' && nextDate != null) 'next_contact_date': nextDate,
        },
      };
      final res = await ApiClient.post(
        ApiEndpoints.clientColdCallingTouch(widget.clientId),
        body,
        requiresAuth: true,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        final msg = res['message']?.toString() ?? 'Updated';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ccSubmitting = false);
    }
  }

  Widget _buildFollowUpFlow(bool isDark, String label) {
    final touch = int.tryParse(_followUp?['touch_count']?.toString() ?? '0') ?? 0;
    final next = _followUp?['next_contact_at']?.toString();
    final remaining = (_kFollowUpMaxContinue - touch).clamp(0, _kFollowUpMaxContinue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _crmTouchProgressStrip(
          isDark,
          'Follow-up streak',
          touch,
          _kFollowUpMaxContinue,
          footnote:
              '$remaining left before stalled · “schedule next” touches only',
        ),
        _crmNextContactLine(isDark, next),
        const SizedBox(height: 10),
        _crmFlowSectionTitle(isDark, 'Channel'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildModeChip(mode: 'call', currentMode: _fuMode, icon: Icons.call_rounded, isDark: isDark, isSubmitting: _fuSubmitting, onSelect: (v) => setState(() => _fuMode = v))),
            const SizedBox(width: 8),
            Expanded(child: _buildModeChip(mode: 'whatsapp', currentMode: _fuMode, icon: FontAwesomeIcons.whatsapp, isDark: isDark, isSubmitting: _fuSubmitting, onSelect: (v) => setState(() => _fuMode = v))),
            const SizedBox(width: 8),
            Expanded(child: _buildModeChip(mode: 'email', currentMode: _fuMode, icon: Icons.mark_email_read_rounded, isDark: isDark, isSubmitting: _fuSubmitting, onSelect: (v) => setState(() => _fuMode = v))),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: _buildScheduleTouchButton(
            isDark: isDark,
            loading: _fuSubmitting,
            onPressed: () => _onFollowUpContinue(isDark),
            channelMode: _fuMode,
            title: 'Save touch & set next reminder',
            subtitle: _fuMode == 'whatsapp'
                ? 'WhatsApp logged — choose the next date'
                : _fuMode == 'email'
                    ? 'Email logged — choose the next date'
                    : 'Call logged — choose the next date',
          ),
        ),
        const SizedBox(height: 6),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 2, bottom: 0),
            shape: const Border(),
            collapsedShape: const Border(),
            title: _crmFlowSectionTitle(isDark, 'Other outcomes'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Move stage or close the lead',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ),
            children: [
              _crmOutcomePair(
                isDark: isDark,
                submitting: _fuSubmitting,
                positiveLabel: 'Ready for meeting',
                onPositive: () => _postFollowUp('ready_for_meeting'),
                negativeLabel: 'Not interested',
                onNegative: () => _postFollowUp('not_interested'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onFollowUpContinue(bool isDark) async {
    final picked = await _pickNextSchedule(isDark);
    if (picked == null || !mounted) return;
    await _postFollowUp(
      'continue_touch',
      schedule: picked['schedule'] ?? 'tomorrow',
      nextDate: picked['date'],
    );
  }

  Future<void> _postFollowUp(
    String result, {
    String schedule = 'tomorrow',
    String? nextDate,
  }) async {
    setState(() => _fuSubmitting = true);
    try {
      final body = <String, dynamic>{
        'mode': _fuMode,
        'result': result,
        if (result == 'continue_touch') ...{
          'schedule': schedule,
          if (schedule == 'custom' && nextDate != null) 'next_contact_date': nextDate,
        },
      };
      final res = await ApiClient.post(
        ApiEndpoints.clientFollowUpTouch(widget.clientId),
        body,
        requiresAuth: true,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        final msg = res['message']?.toString() ?? 'Updated';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _fuSubmitting = false);
    }
  }

  Widget _buildClientMeetingFlow(bool isDark, String label) {
    final touch = int.tryParse(_clientMeeting?['touch_count']?.toString() ?? '0') ?? 0;
    final next = _clientMeeting?['next_contact_at']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _crmTouchProgressStrip(
          isDark,
          'Meeting touches',
          touch,
          5,
          footnote: 'Schedule-next touches toward staging — max 5 before stalled',
        ),
        _crmNextContactLine(isDark, next),
        const SizedBox(height: 10),
        _crmFlowSectionTitle(isDark, 'How did you meet?'),
        const SizedBox(height: 6),
        _crmModeScrollRow([
          _buildModeChip(mode: 'in_person', currentMode: _cmMode, icon: Icons.person_pin_circle_outlined, isDark: isDark, isSubmitting: _cmSubmitting, shortLabel: 'In person', onSelect: (v) => setState(() => _cmMode = v)),
          _buildModeChip(mode: 'video', currentMode: _cmMode, icon: Icons.videocam_outlined, isDark: isDark, isSubmitting: _cmSubmitting, shortLabel: 'Video', onSelect: (v) => setState(() => _cmMode = v)),
          _buildModeChip(mode: 'call', currentMode: _cmMode, icon: Icons.call_rounded, isDark: isDark, isSubmitting: _cmSubmitting, shortLabel: 'Call', onSelect: (v) => setState(() => _cmMode = v)),
          _buildModeChip(mode: 'whatsapp', currentMode: _cmMode, icon: FontAwesomeIcons.whatsapp, isDark: isDark, isSubmitting: _cmSubmitting, shortLabel: 'WhatsApp', onSelect: (v) => setState(() => _cmMode = v)),
        ]),
        const SizedBox(height: 10),
        _crmFlowSectionTitle(isDark, 'Outcomes'),
        const SizedBox(height: 6),
        _crmOutcomePair(
          isDark: isDark,
          submitting: _cmSubmitting,
          positiveLabel: 'Advance to negotiation',
          onPositive: () => _postClientMeeting('advance_to_negotiation'),
          negativeLabel: 'Not interested',
          onNegative: () => _postClientMeeting('not_interested'),
        ),
        const SizedBox(height: 8),
        _buildScheduleTouchButton(
          isDark: isDark,
          loading: _cmSubmitting,
          onPressed: () => _onClientMeetingContinue(isDark),
          channelMode: _cmMode,
          title: 'Save touch & set next reminder',
          subtitle: 'Log this meeting touch, then pick a date',
        ),
      ],
    );
  }

  Future<void> _onClientMeetingContinue(bool isDark) async {
    final picked = await _pickNextSchedule(isDark);
    if (picked == null || !mounted) return;
    await _postClientMeeting(
      'continue_touch',
      schedule: picked['schedule'] ?? 'tomorrow',
      nextDate: picked['date'],
    );
  }

  Future<void> _postClientMeeting(
    String result, {
    String schedule = 'tomorrow',
    String? nextDate,
  }) async {
    setState(() => _cmSubmitting = true);
    try {
      final body = <String, dynamic>{
        'mode': _cmMode,
        'result': result,
        if (result == 'continue_touch') ...{
          'schedule': schedule,
          if (schedule == 'custom' && nextDate != null) 'next_contact_date': nextDate,
        },
      };
      final res = await ApiClient.post(
        ApiEndpoints.clientClientMeetingTouch(widget.clientId),
        body,
        requiresAuth: true,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Updated')));
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Failed'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _cmSubmitting = false);
    }
  }

  Widget _buildDealNegotiationFlow(bool isDark, String label) {
    final touch = int.tryParse(_dealNegotiation?['touch_count']?.toString() ?? '0') ?? 0;
    final next = _dealNegotiation?['next_contact_at']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _crmTouchProgressStrip(
          isDark,
          'Negotiation touches',
          touch,
          5,
          footnote: 'Same 5-touch rhythm as meeting — stall if you only push dates',
        ),
        _crmNextContactLine(isDark, next),
        const SizedBox(height: 10),
        _crmFlowSectionTitle(isDark, 'Channel'),
        const SizedBox(height: 6),
        _crmModeScrollRow([
          _buildModeChip(mode: 'in_person', currentMode: _dnMode, icon: Icons.person_pin_circle_outlined, isDark: isDark, isSubmitting: _dnSubmitting, shortLabel: 'In person', onSelect: (v) => setState(() => _dnMode = v)),
          _buildModeChip(mode: 'video', currentMode: _dnMode, icon: Icons.videocam_outlined, isDark: isDark, isSubmitting: _dnSubmitting, shortLabel: 'Video', onSelect: (v) => setState(() => _dnMode = v)),
          _buildModeChip(mode: 'call', currentMode: _dnMode, icon: Icons.call_rounded, isDark: isDark, isSubmitting: _dnSubmitting, shortLabel: 'Call', onSelect: (v) => setState(() => _dnMode = v)),
          _buildModeChip(mode: 'whatsapp', currentMode: _dnMode, icon: FontAwesomeIcons.whatsapp, isDark: isDark, isSubmitting: _dnSubmitting, shortLabel: 'WhatsApp', onSelect: (v) => setState(() => _dnMode = v)),
          _buildModeChip(mode: 'email', currentMode: _dnMode, icon: Icons.mark_email_read_rounded, isDark: isDark, isSubmitting: _dnSubmitting, shortLabel: 'Email', onSelect: (v) => setState(() => _dnMode = v)),
        ]),
        const SizedBox(height: 10),
        _crmFlowSectionTitle(isDark, 'Outcomes'),
        const SizedBox(height: 6),
        _crmOutcomePair(
          isDark: isDark,
          submitting: _dnSubmitting,
          positiveLabel: 'Advance to closure',
          onPositive: () => _postDealNegotiation('advance_to_closure'),
          negativeLabel: 'Not interested',
          onNegative: () => _postDealNegotiation('not_interested'),
        ),
        const SizedBox(height: 8),
        _buildScheduleTouchButton(
          isDark: isDark,
          loading: _dnSubmitting,
          onPressed: () => _onDealNegotiationContinue(isDark),
          channelMode: _dnMode,
          title: 'Save touch & set next reminder',
          subtitle: 'Still negotiating — pick your next follow-up',
        ),
      ],
    );
  }

  Future<void> _onDealNegotiationContinue(bool isDark) async {
    final picked = await _pickNextSchedule(isDark);
    if (picked == null || !mounted) return;
    await _postDealNegotiation(
      'continue_touch',
      schedule: picked['schedule'] ?? 'tomorrow',
      nextDate: picked['date'],
    );
  }

  Future<void> _postDealNegotiation(
    String result, {
    String schedule = 'tomorrow',
    String? nextDate,
  }) async {
    setState(() => _dnSubmitting = true);
    try {
      final body = <String, dynamic>{
        'mode': _dnMode,
        'result': result,
        if (result == 'continue_touch') ...{
          'schedule': schedule,
          if (schedule == 'custom' && nextDate != null) 'next_contact_date': nextDate,
        },
      };
      final res = await ApiClient.post(
        ApiEndpoints.clientDealNegotiationTouch(widget.clientId),
        body,
        requiresAuth: true,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Updated')));
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Failed'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _dnSubmitting = false);
    }
  }

  Widget _buildDealClosureFlow(bool isDark, String label) {
    final touch = int.tryParse(_dealClosure?['touch_count']?.toString() ?? '0') ?? 0;
    final next = _dealClosure?['next_contact_at']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _crmTouchProgressStrip(
          isDark,
          'Closure touches',
          touch,
          5,
          footnote: 'Paperwork nudges count here until the deal is won or lost',
        ),
        _crmNextContactLine(isDark, next),
        const SizedBox(height: 10),
        _crmFlowSectionTitle(isDark, 'Channel'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: _buildModeChip(mode: 'call', currentMode: _dcMode, icon: Icons.call_rounded, isDark: isDark, isSubmitting: _dcSubmitting, shortLabel: 'Call', onSelect: (v) => setState(() => _dcMode = v))),
            const SizedBox(width: 8),
            Expanded(child: _buildModeChip(mode: 'whatsapp', currentMode: _dcMode, icon: FontAwesomeIcons.whatsapp, isDark: isDark, isSubmitting: _dcSubmitting, shortLabel: 'WhatsApp', onSelect: (v) => setState(() => _dcMode = v))),
            const SizedBox(width: 8),
            Expanded(child: _buildModeChip(mode: 'email', currentMode: _dcMode, icon: Icons.mark_email_read_rounded, isDark: isDark, isSubmitting: _dcSubmitting, shortLabel: 'Email', onSelect: (v) => setState(() => _dcMode = v))),
          ],
        ),
        const SizedBox(height: 10),
        _crmFlowSectionTitle(isDark, 'Won'),
        const SizedBox(height: 6),
        _crmSuccessCTA(
          isDark: isDark,
          onPressed: _dcSubmitting
              ? null
              : () async {
                  await _showDealClosedScreen();
                  if (!mounted) return;
                  await _setStatus('deal_close', 'yes');
                },
          label: 'Record closed deal',
          icon: Icons.celebration_rounded,
        ),
        const SizedBox(height: 10),
        _crmFlowSectionTitle(isDark, 'Still open'),
        const SizedBox(height: 6),
        _crmTertiaryButton(
          isDark: isDark,
          onPressed: _dcSubmitting ? null : () => _onDealClosureContinue(isDark),
          icon: Icons.description_outlined,
          label: 'Paperwork follow-up — schedule',
        ),
        const SizedBox(height: 6),
        _crmTertiaryButton(
          isDark: isDark,
          onPressed: _dcSubmitting ? null : () => _postDealClosure('lost'),
          icon: Icons.heart_broken_outlined,
          label: 'Mark deal lost',
          foreground: Colors.orange.shade700,
          borderColor: Colors.orange.shade400.withValues(alpha: 0.65),
        ),
      ],
    );
  }

  Future<void> _onDealClosureContinue(bool isDark) async {
    final picked = await _pickNextSchedule(isDark);
    if (picked == null || !mounted) return;
    await _postDealClosure(
      'continue_touch',
      schedule: picked['schedule'] ?? 'tomorrow',
      nextDate: picked['date'],
    );
  }

  Future<void> _postDealClosure(
    String result, {
    String schedule = 'tomorrow',
    String? nextDate,
  }) async {
    setState(() => _dcSubmitting = true);
    try {
      final body = <String, dynamic>{
        'mode': _dcMode,
        'result': result,
        if (result == 'continue_touch') ...{
          'schedule': schedule,
          if (schedule == 'custom' && nextDate != null) 'next_contact_date': nextDate,
        },
      };
      final res = await ApiClient.post(
        ApiEndpoints.clientDealClosureTouch(widget.clientId),
        body,
        requiresAuth: true,
      );
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Updated')));
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message']?.toString() ?? 'Failed'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _dcSubmitting = false);
    }
  }

  Widget _completedTodayStrip(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified, color: Colors.green, size: 21),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Action logged for today! Lead moved to next stage.',
              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyActivity(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.history, size: 48, color: isDark ? Colors.white10 : Colors.grey[200]),
            const SizedBox(height: 12),
            Text(
              'No logs for this client yet.',
              style: TextStyle(color: isDark ? Colors.white24 : Colors.grey),
            ),
          ],
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
    final statusLabel = _getStatusLabel(type);
    final statusColor = _getActivityIconColor(type);
    final description = _getActivityDescription(activity, type);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 2),
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

  Future<void> _showDealClosedScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String dealType = 'Sale';
    String dealAmount = '';
    String commission = '';
    final String quarter = 'Q${((DateTime.now().month - 1) ~/ 3) + 1}';

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
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
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF22C55E), Color(0xFF10B981)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                          ),
                        ),
                        child: const Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              top: -20,
                              right: -20,
                              child: Icon(Icons.celebration,
                                  size: 100, color: Colors.white12),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'MISSION ACCOMPLISHED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Deal Closed! 🎉',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('What kind of deal was this?', isDark),
                            const SizedBox(height: 10),
                            _chipRow(
                              options: ['Sale', 'Rent', 'Commercial', 'Land'],
                              selected: dealType,
                              onSelect: (v) =>
                                  setModalState(() => dealType = v),
                            ),
                            const SizedBox(height: 20),
                            _inputField(
                              hint: 'e.g. 5,000,000',
                              label: 'Deal Amount (Total Value)',
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                              onChanged: (v) => dealAmount = v,
                            ),
                            const SizedBox(height: 16),
                            _inputField(
                              hint: 'e.g. 100,000',
                              label: 'Your Commission',
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                              onChanged: (v) => commission = v,
                            ),

                            const SizedBox(height: 24),

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
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    const Text('🎉',
                                        style: TextStyle(fontSize: 18)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Confirm & Celebrate ($quarter)',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
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
}
