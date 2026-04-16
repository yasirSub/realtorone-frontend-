import 'dart:convert';

import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/api_endpoints.dart';

class AddClientPage extends StatefulWidget {
  final Map<String, dynamic>? client;
  const AddClientPage({super.key, this.client});

  @override
  State<AddClientPage> createState() => _AddClientPageState();
}

class _AddClientPageState extends State<AddClientPage> {
  final _clientNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  String? _leadSource;
  String? _leadStage = 'cold calling';
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      _clientNameController.text = widget.client!['client_name'] ?? '';
      _leadSource = widget.client!['source'];

      final notesStr = widget.client!['notes'];
      if (notesStr != null && notesStr is String) {
        try {
          final notes = jsonDecode(notesStr);
          _phoneController.text = notes['phone'] ?? '';
          _emailController.text = notes['email'] ?? '';
          _leadStage = notes['lead_stage'] ?? 'cold calling';
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  static const _leadSources = <({String label, String value})>[
    (label: 'Cold Call', value: 'cold_call'),
    (label: 'Referral', value: 'referral'),
    (label: 'Content', value: 'content'),
    (label: 'Portal', value: 'portal'),
    (label: 'Walk-in', value: 'walk_in'),
    (label: 'Other', value: 'other'),
  ];

  static const _leadStages = <String>[
    'cold calling',
    'follow up back',
    'client meeting',
    'deal negotiation',
    'deal close',
  ];

  Future<void> _saveClient() async {
    final name = _clientNameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final notes = jsonEncode({
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'lead_stage': _leadStage,
      });

      final status = _leadStage == 'deal close' ? 'lost' : 'active';

      final bool isEditing = widget.client != null;
      final String url = isEditing
          ? ApiEndpoints.client(widget.client!['id'])
          : ApiEndpoints.clients;

      final dynamic response;
      if (isEditing) {
        response = await ApiClient.patch(url, {
          'client_name': name,
          'source': _leadSource,
          'notes': notes,
          'status': status,
        }, requiresAuth: true);
      } else {
        response = await ApiClient.post(url, {
          'client_name': name,
          'source': _leadSource,
          'notes': notes,
          'status': status,
        }, requiresAuth: true);
      }

      if (!mounted) return;

      if (response['success'] == true) {
        Navigator.pop(context, true);
      } else {
        // Handle explicit 422 or validation messages from the server
        String errorMsg = response['message'] ?? 'Failed to save client';
        if (response['errors'] != null) {
          // If the backend returns Laravel-style validation errors
          final Map<String, dynamic> errors = response['errors'];
          errorMsg = errors.values.first.toString();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteClient() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Client'),
        content: const Text('Are you sure you want to delete this client?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final response = await ApiClient.delete(
        ApiEndpoints.client(widget.client!['id']),
        requiresAuth: true,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to delete client'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E21) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0A0E21) : Colors.white,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
        title: Text(widget.client != null ? 'Edit Client' : 'Add Client'),
        actions: widget.client != null
            ? [
                IconButton(
                  onPressed: _isDeleting ? null : _deleteClient,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white10
                      : const Color(0xFFEFF6FF), // light blue tint
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'THE DEAL ROOM CRM',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _fieldLabel('Client Name *', isDark),
            const SizedBox(height: 6),
            _textField(
              controller: _clientNameController,
              hintText: 'e.g. Johnathan Smith',
              isDark: isDark,
            ),
            const SizedBox(height: 14),
            _fieldLabel('Phone Number', isDark),
            const SizedBox(height: 6),
            _textField(
              controller: _phoneController,
              hintText: '+1 (555) 000-0000',
              isDark: isDark,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            _fieldLabel('Email ID', isDark),
            const SizedBox(height: 6),
            _textField(
              controller: _emailController,
              hintText: 'client@company.com',
              isDark: isDark,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 14),
            _fieldLabel('Lead Source', isDark),
            const SizedBox(height: 6),
            _dropdown(
              value: _leadSource,
              hintText: 'Select Source',
              isDark: isDark,
              items: _leadSources
                  .map(
                    (s) =>
                        DropdownMenuItem(value: s.value, child: Text(s.label)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _leadSource = v),
            ),
            const SizedBox(height: 14),
            _fieldLabel('Lead Stage', isDark),
            const SizedBox(height: 6),
            _dropdown(
              value: _leadStage,
              hintText: 'Select Stage',
              isDark: isDark,
              items: _leadStages
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _leadStage = v),
            ),
            const SizedBox(height: 26),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveClient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: const Text(
                  'Save Client',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        color: isDark ? Colors.white70 : const Color(0xFF111827),
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hintText,
    required bool isDark,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required String hintText,
    required bool isDark,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF111827) : Colors.white,
          hint: Text(
            hintText,
            style: TextStyle(
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
            ),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
