/// NinjaReferralLead - Model for referral lead data
///
/// Similar to NudgeReferralLead from nudgecore_v2
///
/// Represents a user that was referred by the current user
class NinjaReferralLead {
  /// External ID of the referred user
  final String externalId;

  /// Name of the referred user
  final String? name;

  /// Email of the referred user
  final String? email;

  /// Phone number of the referred user
  final String? phoneNumber;

  /// Additional properties for the lead
  final Map<String, dynamic>? properties;

  const NinjaReferralLead({
    required this.externalId,
    this.name,
    this.email,
    this.phoneNumber,
    this.properties,
  });

  /// Convert to JSON for API calls
  Map<String, dynamic> toJson() {
    return {
      'external_id': externalId,
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
      'properties': properties,
    };
  }

  /// Create from JSON response
  factory NinjaReferralLead.fromJson(Map<String, dynamic> json) {
    return NinjaReferralLead(
      externalId: json['external_id']?.toString() ??
          json['externalId']?.toString() ??
          '',
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      phoneNumber:
          json['phone_number']?.toString() ?? json['phoneNumber']?.toString(),
      properties: json['properties'] != null
          ? Map<String, dynamic>.from(json['properties'])
          : null,
    );
  }

  /// Create a copy with updated fields
  NinjaReferralLead copyWith({
    String? externalId,
    String? name,
    String? email,
    String? phoneNumber,
    Map<String, dynamic>? properties,
  }) {
    return NinjaReferralLead(
      externalId: externalId ?? this.externalId,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      properties: properties ?? this.properties,
    );
  }

  @override
  String toString() {
    return 'NinjaReferralLead{'
        'externalId: $externalId, '
        'name: $name, '
        'email: $email, '
        'phoneNumber: $phoneNumber, '
        'properties: $properties}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NinjaReferralLead && other.externalId == externalId;
  }

  @override
  int get hashCode => externalId.hashCode;
}
