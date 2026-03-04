/// Content types in the learning hub
enum ContentType { video, audio, article, quiz }

enum ContentTier { free, premium }

/// Learning categories based on the blueprint
enum LearningCategory {
  // Free Content
  marketFundamentals,
  leadSystems,
  communication,
  negotiation,

  // Premium Content
  hniHandling,
  commissionScaling,
  dealArchitecture,
  brandAuthority,
}

extension LearningCategoryExtension on LearningCategory {
  String get title {
    switch (this) {
      case LearningCategory.marketFundamentals:
        return 'Market Fundamentals';
      case LearningCategory.leadSystems:
        return 'Lead Systems';
      case LearningCategory.communication:
        return 'Communication';
      case LearningCategory.negotiation:
        return 'Negotiation';
      case LearningCategory.hniHandling:
        return 'HNI Handling';
      case LearningCategory.commissionScaling:
        return 'Commission Scaling';
      case LearningCategory.dealArchitecture:
        return 'Deal Architecture';
      case LearningCategory.brandAuthority:
        return 'Brand Authority';
    }
  }

  String get description {
    switch (this) {
      case LearningCategory.marketFundamentals:
        return 'Understanding Dubai real estate market dynamics';
      case LearningCategory.leadSystems:
        return 'Building consistent lead generation systems';
      case LearningCategory.communication:
        return 'Master client communication and rapport';
      case LearningCategory.negotiation:
        return 'Advanced negotiation techniques';
      case LearningCategory.hniHandling:
        return 'Working with High Net Worth Individuals';
      case LearningCategory.commissionScaling:
        return 'Strategies to increase your commission';
      case LearningCategory.dealArchitecture:
        return 'Structuring complex real estate deals';
      case LearningCategory.brandAuthority:
        return 'Building your personal brand in real estate';
    }
  }

  String get icon {
    switch (this) {
      case LearningCategory.marketFundamentals:
        return '📊';
      case LearningCategory.leadSystems:
        return '🎯';
      case LearningCategory.communication:
        return '💬';
      case LearningCategory.negotiation:
        return '🤝';
      case LearningCategory.hniHandling:
        return '💎';
      case LearningCategory.commissionScaling:
        return '💰';
      case LearningCategory.dealArchitecture:
        return '🏗️';
      case LearningCategory.brandAuthority:
        return '⭐';
    }
  }

  ContentTier get tier {
    switch (this) {
      case LearningCategory.marketFundamentals:
      case LearningCategory.leadSystems:
      case LearningCategory.communication:
      case LearningCategory.negotiation:
        return ContentTier.free;
      case LearningCategory.hniHandling:
      case LearningCategory.commissionScaling:
      case LearningCategory.dealArchitecture:
      case LearningCategory.brandAuthority:
        return ContentTier.premium;
    }
  }
}

class LearningContent {
  final int id;
  final String title;
  final String? description;
  final LearningCategory category;
  final ContentType type;
  final ContentTier tier;
  final String? thumbnailUrl;
  final String? contentUrl;
  final int durationMinutes;
  final bool isCompleted;
  final int? progressPercent;
  final DateTime? lastAccessedAt;

  LearningContent({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.type,
    required this.tier,
    this.thumbnailUrl,
    this.contentUrl,
    required this.durationMinutes,
    this.isCompleted = false,
    this.progressPercent,
    this.lastAccessedAt,
  });

  factory LearningContent.fromJson(Map<String, dynamic> json) {
    return LearningContent(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      category: LearningCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => LearningCategory.marketFundamentals,
      ),
      type: ContentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ContentType.video,
      ),
      tier: json['tier'] == 'premium' ? ContentTier.premium : ContentTier.free,
      thumbnailUrl: json['thumbnail_url'],
      contentUrl: json['content_url'],
      durationMinutes: json['duration_minutes'] ?? 0,
      isCompleted: json['is_completed'] ?? false,
      progressPercent: json['progress_percent'],
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.parse(json['last_accessed_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category.name,
      'type': type.name,
      'tier': tier == ContentTier.premium ? 'premium' : 'free',
      'thumbnail_url': thumbnailUrl,
      'content_url': contentUrl,
      'duration_minutes': durationMinutes,
      'is_completed': isCompleted,
      'progress_percent': progressPercent,
    };
  }
}

class LearningProgress {
  final int totalContent;
  final int completedContent;
  final int freeCompleted;
  final int premiumCompleted;
  final Map<LearningCategory, int> categoryProgress;

  LearningProgress({
    required this.totalContent,
    required this.completedContent,
    required this.freeCompleted,
    required this.premiumCompleted,
    required this.categoryProgress,
  });

  double get completionRate {
    if (totalContent == 0) return 0;
    return completedContent / totalContent;
  }

  factory LearningProgress.fromJson(Map<String, dynamic> json) {
    final categoryProgress = <LearningCategory, int>{};
    if (json['category_progress'] != null) {
      (json['category_progress'] as Map<String, dynamic>).forEach((key, value) {
        final category = LearningCategory.values.firstWhere(
          (e) => e.name == key,
          orElse: () => LearningCategory.marketFundamentals,
        );
        categoryProgress[category] = value as int;
      });
    }

    return LearningProgress(
      totalContent: json['total_content'] ?? 0,
      completedContent: json['completed_content'] ?? 0,
      freeCompleted: json['free_completed'] ?? 0,
      premiumCompleted: json['premium_completed'] ?? 0,
      categoryProgress: categoryProgress,
    );
  }
}

class CourseModel {
  final int id;
  final String title;
  final String description;
  final String? url;
  final String? thumbnailUrl;
  final String minTier;
  final bool isLocked;
  final int moduleNumber;
  final int sequence;
  final int progressPercent;
  final bool isCompleted;
  final bool isPublished;
  final List<ModuleItem>? modules;

  CourseModel({
    required this.id,
    required this.title,
    required this.description,
    this.url,
    this.thumbnailUrl,
    required this.minTier,
    this.isLocked = false,
    this.moduleNumber = 1,
    this.sequence = 0,
    this.progressPercent = 0,
    this.isCompleted = false,
    this.isPublished = true,
    this.modules,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Untitled',
      description: json['description'] ?? '',
      url: json['url'],
      thumbnailUrl: json['thumbnail_url'],
      minTier: json['min_tier'] ?? 'Consultant',
      isLocked: json['is_locked'] ?? false,
      moduleNumber: json['module_number'] ?? 1,
      sequence: json['sequence'] ?? 0,
      progressPercent: json['progress_percent'] ?? 0,
      isCompleted: json['is_completed'] ?? false,
      isPublished: json['is_published'] ?? true,
      modules: (json['modules'] as List<dynamic>?)
          ?.map((m) => ModuleItem.fromJson(m))
          .toList(),
    );
  }
}

class ModuleItem {
  final int id;
  final String title;
  final String? description;
  final int sequence;
  final List<LessonItem> lessons;

  ModuleItem({
    required this.id,
    required this.title,
    this.description,
    required this.sequence,
    required this.lessons,
  });

  factory ModuleItem.fromJson(Map<String, dynamic> json) {
    return ModuleItem(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      sequence: json['sequence'] ?? 0,
      lessons: (json['lessons'] as List<dynamic>?)
              ?.map((l) => LessonItem.fromJson(l))
              .toList() ??
          [],
    );
  }
}

class LessonItem {
  final int id;
  final String title;
  final String? description;
  final int sequence;
  final bool isPublished;
  final bool isPreview;
  final List<MaterialItem> materials;
  final bool allowVideoDownload;
  final bool allowPdfDownload;
  final bool allowComments;

  LessonItem({
    required this.id,
    required this.title,
    this.description,
    required this.sequence,
    this.isPublished = true,
    this.isPreview = false,
    required this.materials,
    this.allowVideoDownload = false,
    this.allowPdfDownload = false,
    this.allowComments = false,
  });

  factory LessonItem.fromJson(Map<String, dynamic> json) {
    final allowVideo = json['allow_video_download'] ?? false;
    final allowPdf = json['allow_pdf_download'] ?? false;
    final allowComments = json['allow_comments'] ?? false;

    return LessonItem(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'],
      sequence: json['sequence'] ?? 0,
      isPublished: json['is_published'] ?? true,
      isPreview: json['is_preview'] ?? false,
      allowVideoDownload: allowVideo,
      allowPdfDownload: allowPdf,
      allowComments: allowComments,
      materials: (json['materials'] as List<dynamic>?)?.map((m) {
            final material = MaterialItem.fromJson(m);
            // Absolute Individual Control: 
            // Every training material follows its own specific setting from the backend.
            return material; 
          }).toList() ?? [],
    );
  }
}

class MaterialItem {
  final int id;
  final String? title;
  final String type;
  final String? url;
  final String? thumbnailUrl;
  final bool showDownloadLink;
  final bool isCompleted;
  final int progressSeconds;
  final String? completedAt;

  MaterialItem({
    required this.id,
    this.title,
    required this.type,
    this.url,
    this.thumbnailUrl,
    this.showDownloadLink = false,
    this.isCompleted = false,
    this.progressSeconds = 0,
    this.completedAt,
  });

  MaterialItem copyWith({
    bool? showDownloadLink,
  }) {
    return MaterialItem(
      id: id,
      title: title,
      type: type,
      url: url,
      thumbnailUrl: thumbnailUrl,
      showDownloadLink: showDownloadLink ?? this.showDownloadLink,
      isCompleted: isCompleted,
      progressSeconds: progressSeconds,
      completedAt: completedAt,
    );
  }

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      id: json['id'],
      title: json['title'],
      type: json['type'] ?? 'Video',
      url: json['url'],
      thumbnailUrl: json['thumbnail_url'],
      showDownloadLink: json['show_download_link'] ?? false,
      isCompleted: json['is_completed'] == true || json['is_completed'] == 1,
      progressSeconds: json['progress_seconds'] ?? 0,
      completedAt: json['completed_at'],
    );
  }
}

class ModuleModel {
  final int moduleNumber;
  final String moduleName;
  final bool isLocked;
  final String requiredTier;
  final List<CourseModel> courses;

  ModuleModel({
    required this.moduleNumber,
    required this.moduleName,
    required this.isLocked,
    required this.requiredTier,
    required this.courses,
  });

  factory ModuleModel.fromJson(Map<String, dynamic> json) {
    return ModuleModel(
      moduleNumber: json['module_number'] ?? 1,
      moduleName: json['module_name'] ?? 'Module ${json['module_number'] ?? 1}',
      isLocked: json['is_locked'] ?? false,
      requiredTier: json['required_tier'] ?? 'Consultant',
      courses: (json['courses'] as List<dynamic>?)
              ?.map((c) => CourseModel.fromJson(c))
              .toList() ??
          [],
    );
  }
}
