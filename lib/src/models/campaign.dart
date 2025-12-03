/// Campaign model representing a nudge/campaign fetched from the server
class Campaign {
  final String id;
  final String title;
  final String? description;
  final String type; // 'bottom_sheet', 'modal', 'pip', 'scratch_card', 'banner', 'tooltip', 'story', 'inline'
  final Map<String, dynamic> config;
  final Map<String, dynamic>? targeting;
  final String? variant;
  final DateTime? createdAt;

  Campaign({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.config,
    this.targeting,
    this.variant,
    this.createdAt,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id']?.toString() ?? json['campaign_id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'Campaign',
      description: json['description']?.toString(),
      type: json['type']?.toString() ?? 'modal',
      config: Map<String, dynamic>.from(json['config'] ?? json['content'] ?? {}),
      targeting: json['targeting'] != null ? Map<String, dynamic>.from(json['targeting']) : null,
      variant: json['variant']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'config': config,
      'targeting': targeting,
      'variant': variant,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
