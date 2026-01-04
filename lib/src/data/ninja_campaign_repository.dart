import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';
import 'package:sqflite/sqflite.dart';
import '../models/campaign.dart';
import 'ninja_database_helper.dart';

class NinjaCampaignRepository {
  static final NinjaCampaignRepository _instance = NinjaCampaignRepository._internal();
  factory NinjaCampaignRepository() => _instance;
  NinjaCampaignRepository._internal();

  final _dbHelper = NinjaDatabaseHelper();
  
  // Reactive Stream of campaigns
  final _campaignsSubject = BehaviorSubject<List<Campaign>>.seeded([]);
  Stream<List<Campaign>> get campaignsStream => _campaignsSubject.stream;
  List<Campaign> get currentCampaigns => _campaignsSubject.value;

  /// loads campaigns from local SQLite cache into memory/stream
  Future<void> loadFromCache() async {
    try {
      final db = await _dbHelper.database;
      final List<Map<String, dynamic>> maps = await db.query('campaigns');
      
      final campaigns = maps.map((map) {
        // Decode JSON fields back to objects
        final campaignMap = Map<String, dynamic>.from(map);
        if (campaignMap['config'] is String) {
          campaignMap['config'] = jsonDecode(campaignMap['config']);
        }
        if (campaignMap['triggers'] is String) {
          campaignMap['triggers'] = jsonDecode(campaignMap['triggers']);
        }
        if (campaignMap['layers'] is String && campaignMap['layers'] != null) {
          campaignMap['layers'] = jsonDecode(campaignMap['layers']);
        }
        if (campaignMap['interfaces'] is String && campaignMap['interfaces'] != null) {
          campaignMap['interfaces'] = jsonDecode(campaignMap['interfaces']);
        }
        return Campaign.fromJson(campaignMap);
      }).toList();

      _campaignsSubject.add(campaigns);
      debugPrint('📦 [NinjaRepo] Loaded ${campaigns.length} campaigns from offline cache');
    } catch (e) {
      debugPrint('❌ [NinjaRepo] Failed to load cache: $e');
    }
  }

  /// Fetches from API and updates local cache
  Future<List<Campaign>> fetchAndSync({
    required String baseUrl,
    required String userId,
    String? screenName,
    required Map<String, String> headers,
  }) async {
    final screen = screenName ?? 'all';
    final url = '$baseUrl/api/v1/nudge/fetch?userId=${Uri.encodeComponent(userId)}&screenName=${Uri.encodeComponent(screen)}&platform=flutter';

    try {
      debugPrint('🔄 [NinjaRepo] Fetching from $url');
      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        List<Campaign> campaigns = [];

        if (body is Map && body['campaigns'] is List) {
          campaigns = (body['campaigns'] as List).map((c) => Campaign.fromJson(c)).toList();
        } else if (body is List) {
          campaigns = body.map((c) => Campaign.fromJson(c)).toList();
        }

        // Save to DB (Transaction)
        await _saveToCache(campaigns);
        
        // Update Stream
        _campaignsSubject.add(campaigns);
        return campaigns;
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ [NinjaRepo] Fetch failed: $e. Using offline cache.');
      // Ensure specific error is rethrown if critical, otherwise return cached
      if (_campaignsSubject.value.isEmpty) {
         await loadFromCache();
      }
      return _campaignsSubject.value;
    }
  }

  Future<void> _saveToCache(List<Campaign> campaigns) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      // Strategy: Clear all and replace vs Upsert?
      // For "Fetch All" logic, usually Clear + Replace is safest to remove deleted campaigns.
      await txn.delete('campaigns');
      
      for (final c in campaigns) {
        await txn.insert('campaigns', {
          'id': c.id,
          'title': c.title,
          'config': jsonEncode(c.config),
          'triggers': jsonEncode(c.triggers),
          'layers': c.layers != null ? jsonEncode(c.layers) : null,
          'interfaces': c.interfaces != null ? jsonEncode(c.interfaces) : null,
          'start_date': c.startDate?.toIso8601String(),
          'end_date': c.endDate?.toIso8601String(),
          'created_at': c.createdAt?.toIso8601String(),
          'updated_at': c.updatedAt?.toIso8601String(),
          'status': c.status,
          'priority': c.priority,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    debugPrint('💾 [NinjaRepo] Cached ${campaigns.length} campaigns to SQLite');
  }
}
