class ChildModel {
  String id;
  String name;
  String? pairedAt;
  String? lastSeen;

  ChildModel({
    required this.id,
    required this.name,
    this.pairedAt,
    this.lastSeen,
  });

  factory ChildModel.fromMap(String id, Map<dynamic, dynamic> map) => ChildModel(
        id: id,
        name: map['name'] as String? ?? 'Anak',
        pairedAt: map['pairedAt'] as String?,
        lastSeen: map['lastSeen'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        if (pairedAt != null) 'pairedAt': pairedAt,
        if (lastSeen != null) 'lastSeen': lastSeen,
      };

  /// Returns true if lastSeen is within 5 minutes
  bool get isOnline {
    if (lastSeen == null) return false;
    final last = DateTime.tryParse(lastSeen!);
    if (last == null) return false;
    return DateTime.now().difference(last).inMinutes < 5;
  }

  /// Display initial for avatar
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}
