import 'package:flutter/material.dart';

import '../../api/chat_api.dart';
import '../../theme/realtorone_brand.dart';

class RevenFeedbackSheet extends StatefulWidget {
  const RevenFeedbackSheet({
    super.key,
    this.sessionId,
  });

  final int? sessionId;

  static Future<bool?> show(
    BuildContext context, {
    int? sessionId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: RevenFeedbackSheet(sessionId: sessionId),
      ),
    );
  }

  @override
  State<RevenFeedbackSheet> createState() => _RevenFeedbackSheetState();
}

class _RevenFeedbackSheetState extends State<RevenFeedbackSheet> {
  final _messageController = TextEditingController();
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategory;
  bool _loadingCategories = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await ChatApi.getFeedbackCategories();
      if (!mounted) return;
      if (res['success'] == true && res['data'] is List) {
        final list = (res['data'] as List).cast<Map<String, dynamic>>();
        setState(() {
          _categories = list;
          _selectedCategory = list.isNotEmpty
              ? list.first['id']?.toString()
              : 'general';
          _loadingCategories = false;
        });
      } else {
        setState(() {
          _categories = _fallbackCategories();
          _selectedCategory = 'general';
          _loadingCategories = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categories = _fallbackCategories();
        _selectedCategory = 'general';
        _loadingCategories = false;
      });
    }
  }

  List<Map<String, dynamic>> _fallbackCategories() {
    return const [
      {'id': 'general', 'label': 'General'},
      {'id': 'subscription', 'label': 'Subscription & Billing'},
      {'id': 'learning', 'label': 'Learning & Courses'},
      {'id': 'deal_room', 'label': 'Deal Room & CRM'},
      {'id': 'technical', 'label': 'Technical / Bug'},
      {'id': 'ai_assistant', 'label': 'AI Assistant (Reven)'},
      {'id': 'feature', 'label': 'Feature Request'},
      {'id': 'other', 'label': 'Other'},
    ];
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    final category = _selectedCategory;

    if (category == null || category.isEmpty) {
      setState(() => _error = 'Please choose a category');
      return;
    }
    if (message.length < 3) {
      setState(() => _error = 'Please enter at least 3 characters');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final res = await ChatApi.submitFeedback(
        category: category,
        message: message,
        sessionId: widget.sessionId,
      );
      if (!mounted) return;

      if (res['success'] == true) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message']?.toString() ??
                  'Thank you! Your feedback was sent to our team.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _error = res['message']?.toString() ?? 'Could not send feedback';
          _submitting = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Connection error. Please try again.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: RealtorOneBrand.seed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.feedback_outlined,
                  color: RealtorOneBrand.seed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send Feedback',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Help us improve RealtorOne',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'What is this about?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 10),
          if (_loadingCategories)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final id = cat['id']?.toString() ?? '';
                final label = cat['label']?.toString() ?? id;
                final selected = _selectedCategory == id;
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = id),
                  selectedColor: RealtorOneBrand.seed.withValues(alpha: 0.18),
                  checkmarkColor: RealtorOneBrand.seed,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? RealtorOneBrand.seed
                        : (isDark ? Colors.white70 : const Color(0xFF475569)),
                  ),
                  side: BorderSide(
                    color: selected
                        ? RealtorOneBrand.seed
                        : (isDark ? Colors.white24 : const Color(0xFFE2E8F0)),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            maxLines: 5,
            minLines: 3,
            maxLength: 4000,
            decoration: InputDecoration(
              hintText: 'Tell us what went well or what we can improve…',
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: RealtorOneBrand.seed, width: 1.5),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: RealtorOneBrand.seed,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Send Feedback',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
    );
  }
}
