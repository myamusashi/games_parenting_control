class TimeLimitModel {
  String childId;
  int dailySeconds;
  String? updatedAt;

  TimeLimitModel({
    required this.childId,
    required this.dailySeconds,
    this.updatedAt,
  });

  factory TimeLimitModel.fromMap(Map<dynamic, dynamic> map) => TimeLimitModel(
        childId: map['childId'] as String? ?? '',
        dailySeconds: map['dailySeconds'] as int? ?? 0,
        updatedAt: map['updatedAt'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'childId': childId,
        'dailySeconds': dailySeconds,
        'updatedAt': updatedAt ?? DateTime.now().toIso8601String(),
      };

  /// Convenience: daily limit in minutes
  int get dailyMinutes => dailySeconds ~/ 60;

  /// Unlimited when dailySeconds is 0
  bool get isUnlimited => dailySeconds == 0;
}
