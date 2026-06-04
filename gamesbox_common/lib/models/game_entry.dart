import 'dart:typed_data';

class GameEntry {
  final String name;
  final String packageName;
  final Uint8List? iconBytes;
  int totalPlayedSecondsToday;
  bool isLocked;

  GameEntry({
    required this.name,
    required this.packageName,
    this.iconBytes,
    this.totalPlayedSecondsToday = 0,
    this.isLocked = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'packageName': packageName,
      'isLocked': isLocked,
    };
  }

  factory GameEntry.fromJson(Map<String, dynamic> json) {
    return GameEntry(
      name: json['name'],
      packageName: json['packageName'],
      isLocked: json['isLocked'] ?? false,
    );
  }
}
