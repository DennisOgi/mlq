/// Represents a user community (organization, health, study group, etc.).
///
/// This model is intentionally client-focused: it combines community
/// metadata with the current user's membership role for that community.
class CommunityModel {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final String createdBy;
  final String status; // 'pending', 'active', 'rejected', 'suspended' (community approval status)
  final String? imageUrl; // Community branding image uploaded by owner

  /// The current user's role in this community: 'owner', 'moderator', 'member'.
  final String role;
  
  /// The current user's membership status: 'pending', 'active', 'removed'.
  /// 'pending' means the user has been invited but hasn't accepted yet.
  final String membershipStatus;

  /// Whether this community is currently active (approved and not suspended).
  bool get isActive => status == 'active';

  /// Whether the current user is the owner of this community.
  bool get isOwner => role == 'owner';

  /// Whether the current user is a moderator of this community.
  bool get isModerator => role == 'moderator';
  
  /// Whether the current user has a pending invite to this community.
  bool get hasPendingInvite => membershipStatus == 'pending';
  
  /// Whether the current user is an active member of this community.
  bool get isActiveMember => membershipStatus == 'active';

  const CommunityModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.createdBy,
    required this.status,
    required this.role,
    this.membershipStatus = 'active',
    this.imageUrl,
  });

  CommunityModel copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? createdBy,
    String? status,
    String? role,
    String? membershipStatus,
    String? imageUrl,
  }) {
    return CommunityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      role: role ?? this.role,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  factory CommunityModel.fromJoinedRow(Map<String, dynamic> row) {
    // Row shape expected from a community_members <-> communities join:
    // {
    //   'community_id': ...,
    //   'role': ...,
    //   'status': ... (membership status: pending, active, removed),
    //   'communities': { id, name, description, category, created_by, status, image_url, ... }
    // }
    final community = row['communities'] as Map<String, dynamic>? ?? {};

    return CommunityModel(
      id: (community['id'] ?? row['community_id']).toString(),
      name: (community['name'] as String?) ?? 'Community',
      description: community['description'] as String?,
      category: community['category'] as String?,
      createdBy: (community['created_by'] ?? '').toString(),
      status: (community['status'] as String?) ?? 'pending', // Community approval status
      role: (row['role'] as String?) ?? 'member',
      membershipStatus: (row['status'] as String?) ?? 'active', // User's membership status
      imageUrl: community['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'created_by': createdBy,
      'status': status,
      'role': role,
      'membership_status': membershipStatus,
      'image_url': imageUrl,
    };
  }
}
