// test/security/secret_storage_test.dart
// Regression tests for secret redaction in settings serialization

import 'package:flutter_test/flutter_test.dart';

import 'package:freak_flix/models/stash_endpoint.dart';
import 'package:freak_flix/providers/settings_provider.dart';

void main() {
  group('Secret storage redaction', () {
    test('stash endpoint legacy apiKey is not serialized', () {
      final endpoint = StashEndpoint.fromJson({
        'id': 'legacy-endpoint',
        'name': 'Legacy Stash',
        'url': 'https://stashdb.org/graphql',
        'apiKey': 'legacy-secret',
        'enabled': true,
      });

      expect(endpoint.apiKey, 'legacy-secret');
      expect(endpoint.toJson().containsKey('apiKey'), isFalse);
    });

    test('exportState omits TMDB and Stash secrets', () {
      final provider = SettingsProvider();
      provider.tmdbApiKey = 'tmdb-secret';
      provider.stashEndpoints = [
        StashEndpoint(
          id: 'ep-1',
          name: 'Primary',
          url: 'https://stashdb.org/graphql',
          apiKey: 'stash-secret',
        ),
      ];

      final state = provider.exportState();
      final serializedEndpoints = state['stashEndpoints'] as List<dynamic>;

      expect(state.containsKey('tmdbApiKey'), isFalse);
      expect(serializedEndpoints, hasLength(1));
      expect((serializedEndpoints.first as Map<String, dynamic>).containsKey('apiKey'), isFalse);
    });

    test('exportSettings omits TMDB and Stash secrets', () {
      final provider = SettingsProvider();
      provider.tmdbApiKey = 'tmdb-secret';
      provider.stashEndpoints = [
        StashEndpoint(
          id: 'ep-1',
          name: 'Primary',
          url: 'https://stashdb.org/graphql',
          apiKey: 'stash-secret',
        ),
      ];

      final settings = provider.exportSettings();
      final serializedEndpoints = settings['stashEndpoints'] as List<dynamic>;

      expect(settings.containsKey('tmdbApiKey'), isFalse);
      expect(serializedEndpoints, hasLength(1));
      expect((serializedEndpoints.first as Map<String, dynamic>).containsKey('apiKey'), isFalse);
    });
  });
}
