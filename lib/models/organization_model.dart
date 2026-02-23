class OrganizationModel {
  final String id;
  final String name;
  final String logoPath;
  final String description;

  OrganizationModel({
    required this.id,
    required this.name,
    required this.logoPath,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'logoPath': logoPath,
      'description': description,
    };
  }

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationModel(
      id: json['id'],
      name: json['name'],
      logoPath: json['logoPath'],
      description: json['description'],
    );
  }
}
