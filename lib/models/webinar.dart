class Webinar {
  final int id;
  final String title;
  final String? description;
  final String? zoomLink;
  final String? imageUrl;
  final DateTime? scheduledAt;
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
    this.isActive = true,
    this.isPromotional = false,
    this.targetTier,
  });

  factory Webinar.fromJson(Map<String, dynamic> json) {
    return Webinar(
      id: json['id'] as int,
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      zoomLink: json['zoom_link']?.toString(),
      imageUrl: json['image_url']?.toString(),
      scheduledAt: json['scheduled_at'] != null 
          ? DateTime.tryParse(json['scheduled_at'].toString()) 
          : null,
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
      'scheduled_at': scheduledAt?.toIso8601String(),
      'is_active': isActive,
      'is_promotional': isPromotional,
      'target_tier': targetTier,
    };
  }
}
