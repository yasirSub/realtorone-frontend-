class Webinar {
  final int id;
  final String title;
  final String? description;
  final String? zoomLink;
  final String? imageUrl;
  final DateTime? scheduledAt;
  final String? timezone;
  final bool reminderPushEnabled;
  final bool isActive;
  final bool isPromotional;
  final String? targetTier;

  Webinar({
    required this.id,
    required this.title,
    this.description,
    this.zoomLink,
    this.imageUrl,
    this.scheduledAt,
    this.timezone,
    this.reminderPushEnabled = false,
    this.isActive = true,
    this.isPromotional = false,
    this.targetTier,
  });

  factory Webinar.fromJson(Map<String, dynamic> json) {
    DateTime? parseUtc(String? raw) {
      if (raw == null || raw.isEmpty) return null;
      final s = raw.trim();
      final parsed = DateTime.tryParse(s);
      if (parsed == null) return null;
      return parsed.isUtc ? parsed : parsed.toUtc();
    }

    return Webinar(
      id: json['id'] as int,
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      zoomLink: json['zoom_link']?.toString(),
      imageUrl: json['image_url']?.toString(),
      scheduledAt: parseUtc(json['scheduled_at']?.toString()),
      timezone: json['timezone']?.toString(),
      reminderPushEnabled:
          json['reminder_push_enabled'] == true || json['reminder_push_enabled'] == 1,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      isPromotional: json['is_promotional'] == true || json['is_promotional'] == 1,
      targetTier: json['target_tier']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'zoom_link': zoomLink,
      'image_url': imageUrl,
      'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
      'timezone': timezone,
      'reminder_push_enabled': reminderPushEnabled,
      'is_active': isActive,
      'is_promotional': isPromotional,
      'target_tier': targetTier,
    };
  }

  /// User-facing local time label (device timezone).
  String? localScheduleLabel() {
    if (scheduledAt == null) return null;
    final local = scheduledAt!.toLocal();
    final y = local.year;
    final mo = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final min = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$y-$mo-$d · $h:$min $ampm (your time)';
  }
}
