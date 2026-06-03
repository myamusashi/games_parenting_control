class GameModel {
  String id;
  String name;
  String packageId;

  GameModel({required this.id, required this.name, required this.packageId});

  factory GameModel.fromMap(String id, Map<dynamic, dynamic> map) => GameModel(
        id: id,
        name: map['name'] ?? '',
        packageId: map['packageId'] ?? '',
      );
}
