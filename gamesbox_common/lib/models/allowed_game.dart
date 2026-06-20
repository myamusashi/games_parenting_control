class AllowedGame {
  final String packageName;
  final String name;
  final String addedBy;
  final String addedAt;

  const AllowedGame({
    required this.packageName,
    required this.name,
    required this.addedBy,
    required this.addedAt,
  });

  factory AllowedGame.fromMap(Map<dynamic, dynamic> map) {
    return AllowedGame(
      packageName: map['packageName'] as String? ?? '',
      name: map['name'] as String? ?? '',
      addedBy: map['addedBy'] as String? ?? 'parent',
      addedAt: map['addedAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'name': name,
      'addedBy': addedBy,
      'addedAt': addedAt,
    };
  }
}
