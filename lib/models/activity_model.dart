/// Types of activities in the habit engine
enum ActivityCategory {
  task, // Lead outreach, follow-ups, meetings
  subconscious, // Morning priming, focus drills, reflection
}

enum ActivityType {
  // Task activities
  leadOutreach,
  followUp,
  meeting,
  siteVisit,

  // Subconscious activities
  morningPriming,
  focusDrill,
  eveningReflection,
}

extension ActivityTypeExtension on ActivityType {
  String get title {
    switch (this) {
      case ActivityType.leadOutreach:
        return 'Lead Outreach';
      case ActivityType.followUp:
        return 'Follow Up';
      case ActivityType.meeting:
        return 'Meeting';
      case ActivityType.siteVisit:
        return 'Site Visit';
      case ActivityType.morningPriming:
        return 'Morning Priming';
      case ActivityType.focusDrill:
        return 'Focus Drill';
      case ActivityType.eveningReflection:
        return 'Evening Reflection';
    }
  }

  String get icon {
    switch (this) {
      case ActivityType.leadOutreach:
        return '📞';
      case ActivityType.followUp:
        return '💬';
      case ActivityType.meeting:
        return '🤝';
      case ActivityType.siteVisit:
        return '🏠';
      case ActivityType.morningPriming:
        return '🌅';
      case ActivityType.focusDrill:
        return '🎯';
      case ActivityType.eveningReflection:
        return '🌙';
    }
  }

  ActivityCategory get category {
    switch (this) {
      case ActivityType.leadOutreach:
      case ActivityType.followUp:
      case ActivityType.meeting:
      case ActivityType.siteVisit:
        return ActivityCategory.task;
      case ActivityType.morningPriming:
      case ActivityType.focusDrill:
      case ActivityType.eveningReflection:
        return ActivityCategory.subconscious;
    }
  }

  int get defaultDurationMinutes {
    switch (this) {
      case ActivityType.leadOutreach:
        return 30;
      case ActivityType.followUp:
        return 15;
      case ActivityType.meeting:
        return 60;
      case ActivityType.siteVisit:
        return 90;
      case ActivityType.morningPriming:
        return 10;
      case ActivityType.focusDrill:
        return 5;
      case ActivityType.eveningReflection:
        return 10;
    }
  }
}

/// Streak levels based on consecutive days
enum StreakLevel {
  none(0, 'No Streak', '🔥'),
  starter(3, 'Starter', '🔥'),
  builder(7, 'Builder', '🔥🔥'),
  performer(21, 'Performer', '🔥🔥🔥'),
  elite(90, 'Elite', '👑');

  final int daysRequired;
  final String title;
  final String badge;

  const StreakLevel(this.daysRequired, this.title, this.badge);

  static StreakLevel fromDays(int days) {
    if (days >= 90) return StreakLevel.elite;
    if (days >= 21) return StreakLevel.performer;
    if (days >= 7) return StreakLevel.builder;
    if (days >= 3) return StreakLevel.starter;
    return StreakLevel.none;
  }
}

class Activity {
  final int id;
  final String title;
  final String? description;
  final ActivityType type;
  final int durationMinutes;
  final DateTime? scheduledAt;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? notes;

  Activity({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.durationMinutes,
    this.scheduledAt,
    this.isCompleted = false,
    this.completedAt,
    this.notes,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: ActivityType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ActivityType.leadOutreach,
      ),
      durationMinutes: json['duration_minutes'] ?? 30,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'])
          : null,
      isCompleted: json['is_completed'] ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'duration_minutes': durationMinutes,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'notes': notes,
    };
  }
}

class DailyProgress {
  final DateTime date;
  final int tasksCompleted;
  final int tasksTotal;
  final int subconsciousCompleted;
  final int subconsciousTotal;
  final int currentStreak;
  final StreakLevel streakLevel;

  DailyProgress({
    required this.date,
    required this.tasksCompleted,
    required this.tasksTotal,
    required this.subconsciousCompleted,
    required this.subconsciousTotal,
    required this.currentStreak,
    required this.streakLevel,
  });

  double get completionRate {
    final total = tasksTotal + subconsciousTotal;
    if (total == 0) return 0;
    return (tasksCompleted + subconsciousCompleted) / total;
  }

  factory DailyProgress.fromJson(Map<String, dynamic> json) {
    final streak = json['current_streak'] ?? 0;
    return DailyProgress(
      date: DateTime.parse(json['date']),
      tasksCompleted: json['tasks_completed'] ?? 0,
      tasksTotal: json['tasks_total'] ?? 0,
      subconsciousCompleted: json['subconscious_completed'] ?? 0,
      subconsciousTotal: json['subconscious_total'] ?? 0,
      currentStreak: streak,
      streakLevel: StreakLevel.fromDays(streak),
    );
  }
}
