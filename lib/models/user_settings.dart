class UserProfileDraft {
  const UserProfileDraft({
    required this.displayName,
    required this.email,
    required this.phone,
    required this.bio,
  });

  final String displayName;
  final String email;
  final String phone;
  final String bio;

  factory UserProfileDraft.fromJson(Map<String, dynamic> json) {
    return UserProfileDraft(
      displayName: (json['displayName'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      bio: (json['bio'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'email': email,
        'phone': phone,
        'bio': bio,
      };

  UserProfileDraft copyWith({
    String? displayName,
    String? email,
    String? phone,
    String? bio,
  }) {
    return UserProfileDraft(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      bio: bio ?? this.bio,
    );
  }
}

class TrustedContact {
  const TrustedContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relationship,
    required this.notes,
  });

  final String id;
  final String name;
  final String phone;
  final String relationship;
  final String notes;

  factory TrustedContact.fromJson(Map<String, dynamic> json) {
    return TrustedContact(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      relationship: (json['relationship'] as String?) ?? '',
      notes: (json['notes'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'relationship': relationship,
        'notes': notes,
      };

  TrustedContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? relationship,
    String? notes,
  }) {
    return TrustedContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      notes: notes ?? this.notes,
    );
  }
}
