class GameModel {
  String id;
  String name;
  String packageId;
  bool enabled;

  GameModel({
    required this.id,
    required this.name,
    required this.packageId,
    this.enabled = true,
  });

  factory GameModel.fromMap(String id, Map<dynamic, dynamic> map) => GameModel(
        id: id,
        name: map['name'] ?? '',
        packageId: map['packageId'] ?? '',
        enabled: map['enabled'] ?? true,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'packageId': packageId,
        'enabled': enabled,
      };
}
