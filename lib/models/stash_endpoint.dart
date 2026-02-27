import 'package:uuid/uuid.dart';

class StashEndpoint {
  final String id;
  String name;
  String url;
  // Runtime-only secret. Persisted in secure storage via SecureKeyService.
  String apiKey;
  bool enabled;

  StashEndpoint({
    String? id,
    required this.name,
    required this.url,
    required this.apiKey,
    this.enabled = true,
  }) : id = id ?? const Uuid().v4();

  factory StashEndpoint.fromJson(Map<String, dynamic> json) {
    return StashEndpoint(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Stash',
      url: json['url'] as String? ?? '',
      apiKey: json['apiKey'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'enabled': enabled,
    };
  }
}
