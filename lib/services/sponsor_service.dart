import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sponsor_model.dart';
import 'supabase_service.dart';

class SponsorService {
  final SupabaseClient _client = SupabaseService().client;

  /// Get all sponsors
  Future<List<SponsorModel>> getAllSponsors() async {
    try {
      final response = await _client
          .from('sponsors')
          .select()
          .order('name');
      
      return (response as List)
          .map((json) => SponsorModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting all sponsors: $e');
      rethrow;
    }
  }

  /// Get sponsor by ID
  Future<SponsorModel?> getSponsorById(String id) async {
    try {
      final response = await _client
          .from('sponsors')
          .select()
          .eq('id', id)
          .maybeSingle();
      
      return response != null ? SponsorModel.fromJson(response) : null;
    } catch (e) {
      debugPrint('Error getting sponsor by ID: $e');
      return null;
    }
  }

  /// Create sponsor
  Future<SponsorModel> createSponsor(SponsorModel sponsor) async {
    try {
      final response = await _client
          .from('sponsors')
          .insert(sponsor.toJson())
          .select()
          .single();
      
      debugPrint('Sponsor created successfully: ${response['id']}');
      return SponsorModel.fromJson(response);
    } catch (e) {
      debugPrint('Error creating sponsor: $e');
      rethrow;
    }
  }

  /// Update sponsor
  Future<SponsorModel> updateSponsor(String id, SponsorModel sponsor) async {
    try {
      final response = await _client
          .from('sponsors')
          .update(sponsor.toJson())
          .eq('id', id)
          .select()
          .single();
      
      debugPrint('Sponsor updated successfully: $id');
      return SponsorModel.fromJson(response);
    } catch (e) {
      debugPrint('Error updating sponsor: $e');
      rethrow;
    }
  }

  /// Delete sponsor
  Future<void> deleteSponsor(String id) async {
    try {
      await _client
          .from('sponsors')
          .delete()
          .eq('id', id);
      
      debugPrint('Sponsor deleted successfully: $id');
    } catch (e) {
      debugPrint('Error deleting sponsor: $e');
      rethrow;
    }
  }
}
