// lib/services/onboarding_draft_service.dart
//
// SharedPreferences-backed onboarding draft persistence service.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/onboarding_draft.dart';
import '../utils/logger.dart';

class OnboardingDraftService {
  OnboardingDraftService({SharedPreferences? sharedPreferences})
      : _sharedPreferences = sharedPreferences;

  static const String _draftStorageKey = 'onboarding_draft_v1';

  final SharedPreferences? _sharedPreferences;

  Future<SharedPreferences> _resolvePreferences() async {
    return _sharedPreferences ?? SharedPreferences.getInstance();
  }

  Future<OnboardingDraft> loadDraft() async {
    try {
      final prefs = await _resolvePreferences();
      final encodedDraft = prefs.getString(_draftStorageKey);
      if (encodedDraft == null || encodedDraft.trim().isEmpty) {
        return const OnboardingDraft();
      }

      final decoded = jsonDecode(encodedDraft);
      if (decoded is! Map) {
        AppLogger.w(
          'Onboarding draft payload is not a JSON object. Resetting to default draft.',
          tag: 'OnboardingDraftService',
        );
        return const OnboardingDraft();
      }

      return OnboardingDraft.fromJson(decoded.cast<String, dynamic>());
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to load onboarding draft. Falling back to defaults.',
        tag: 'OnboardingDraftService',
        error: error,
        stackTrace: stackTrace,
      );
      return const OnboardingDraft();
    }
  }

  Future<void> saveDraft(OnboardingDraft draft) async {
    final prefs = await _resolvePreferences();
    final payload = jsonEncode(draft.toJson());
    await prefs.setString(_draftStorageKey, payload);
  }

  Future<void> clearDraft() async {
    final prefs = await _resolvePreferences();
    await prefs.remove(_draftStorageKey);
  }
}
