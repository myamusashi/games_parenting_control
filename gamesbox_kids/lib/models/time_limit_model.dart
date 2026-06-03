class TimeLimitModel {
  String childId;
  int dailySeconds;

  TimeLimitModel({required this.childId, required this.dailySeconds});

  factory TimeLimitModel.fromMap(Map<dynamic, dynamic> map) => TimeLimitModel(
        childId: map['childId'] ?? '',
        dailySeconds: map['dailySeconds'] ?? 0,
      );
}
