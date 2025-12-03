/// User model for InAppNinja
///
/// Represents a user with their identification and properties
class NinjaUser {
  /// External user ID
  final String? externalId;

  /// User's name
  final String? name;

  /// User's email
  final String? email;

  /// User's phone number
  final String? phoneNumber;

  /// Referral code
  final String? referralCode;

  /// Additional user properties
  final Map<String, dynamic>? properties;

  /// User ID (internal)
  final String? userId;

  /// Session ID
  final String? sessionId;

  /// Locale/language
  final String? locale;

  /// Creation timestamp
  final DateTime? createdAt;

  /// Last updated timestamp
  final DateTime? updatedAt;

  NinjaUser({
    this.externalId,
    this.name,
    this.email,
    this.phoneNumber,
    this.referralCode,
    this.properties,
    this.userId,
    this.sessionId,
    this.locale,
    this.createdAt,
    this.updatedAt,
  });

  /// Create from JSON
  factory NinjaUser.fromJson(Map<String, dynamic> json) {
    return NinjaUser(
      externalId: json['external_id'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
      referralCode: json['referral_code'] as String?,
      properties: json['properties'] as Map<String, dynamic>?,
      userId: json['user_id'] as String?,
      sessionId: json['session_id'] as String?,
      locale: json['locale'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      if (externalId != null) 'external_id': externalId,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (referralCode != null) 'referral_code': referralCode,
      if (properties != null) 'properties': properties,
      if (userId != null) 'user_id': userId,
      if (sessionId != null) 'session_id': sessionId,
      if (locale != null) 'locale': locale,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  NinjaUser copyWith({
    String? externalId,
    String? name,
    String? email,
    String? phoneNumber,
    String? referralCode,
    Map<String, dynamic>? properties,
    String? userId,
    String? sessionId,
    String? locale,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NinjaUser(
      externalId: externalId ?? this.externalId,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      referralCode: referralCode ?? this.referralCode,
      properties: properties ?? this.properties,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      locale: locale ?? this.locale,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'NinjaUser(externalId: $externalId, name: $name, email: $email, userId: $userId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NinjaUser &&
        other.externalId == externalId &&
        other.userId == userId;
  }

  @override
  int get hashCode => externalId.hashCode ^ userId.hashCode;
}
