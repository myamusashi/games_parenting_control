class ChildModel {
  String id;
  String name;

  ChildModel({required this.id, required this.name});

  factory ChildModel.fromMap(String id, Map<dynamic, dynamic> map) => ChildModel(
        id: id,
        name: map['name'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
      };
}
