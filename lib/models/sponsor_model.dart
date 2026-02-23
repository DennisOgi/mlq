class SponsorModel {
  final String id;
  final String name;
  final String? logoUrl;
  final String? contactEmail;
  final String? contactPhone;
  final String? website;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  SponsorModel({
    required this.id,
    required this.name,
    this.logoUrl,
    this.contactEmail,
    this.contactPhone,
    this.website,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  SponsorModel copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? contactEmail,
    String? contactPhone,
    String? website,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SponsorModel(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      website: website ?? this.website,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory SponsorModel.fromJson(Map<String, dynamic> json) {
    return SponsorModel(
      id: json['id'],
      name: json['name'],
      logoUrl: json['logo_url'],
      contactEmail: json['contact_email'],
      contactPhone: json['contact_phone'],
      website: json['website'],
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'logo_url': logoUrl,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'website': website,
      'description': description,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
