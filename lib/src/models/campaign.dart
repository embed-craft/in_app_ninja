/// Campaign model representing a nudge/campaign fetched from the server
class Campaign {
  final String id;
  final String title;
  final String? description;
  final String type; // 'bottom_sheet', 'modal', 'pip', 'scratch_card', 'banner', 'tooltip', 'story', 'inline'
  final Map<String, dynamic> config;
  final List<dynamic>? targeting; // Changed from Map to List
  final List<dynamic>? triggers; // Added
  final List<dynamic>? layers;
  final List<Map<String, dynamic>>? interfaces; // NEW: Sub-interfaces for linked UI flows
  final String? variant;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? status;
  final int? priority;

  Campaign({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    required this.config,
    this.targeting,
    this.triggers,
    this.layers,
    this.interfaces,
    this.variant,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.updatedAt,
    this.status,
    this.priority,
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['campaign_name']?.toString() ?? json['title']?.toString() ?? json['name']?.toString() ?? 'Campaign',
      description: json['description']?.toString(),
      type: json['config']?['type']?.toString() ?? json['type']?.toString() ?? 'modal',
      config: Map<String, dynamic>.from(json['config'] ?? json['content'] ?? {}),
      targeting: json['targeting'] != null && json['targeting'] is List
          ? List<dynamic>.from(json['targeting'])
          : null,
      triggers: json['triggers'] != null && json['triggers'] is List
          ? List<dynamic>.from(json['triggers'])
          : null,
      layers: json['layers'] != null && json['layers'] is List
          ? List<dynamic>.from(json['layers'])
          : null,
      interfaces: json['interfaces'] != null && json['interfaces'] is List
          ? List<Map<String, dynamic>>.from(
              (json['interfaces'] as List).map((e) => Map<String, dynamic>.from(e))
            )
          : null,
      variant: json['variant']?.toString(),
      startDate: json['start_date'] != null ? DateTime.tryParse(json['start_date'].toString()) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date'].toString()) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
      status: json['status']?.toString(),
      priority: int.tryParse(json['priority']?.toString() ?? '0'),
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
      'triggers': triggers,
      'layers': layers,
      'interfaces': interfaces,
      'variant': variant,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'status': status,
      'priority': priority,
    };
  }
}
