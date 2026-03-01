// lib/services/onboarding_source_connection_service.dart
// Onboarding-only orchestration for local, OneDrive, and remote connectors.
import '../models/library_folder.dart';
import '../providers/library_provider.dart';
import '../services/graph_auth_service.dart';
import '../services/metadata_service.dart';
import '../services/remote_storage_service.dart';

enum OnboardingSourceType { local, oneDrive, sftp, ftp, webdav }

enum OnboardingSourceStatus { notStarted, inProgress, connected, incomplete, failed }

enum OnboardingOneDriveOutcome { connected, cancelled, timedOut, failed }

enum OnboardingRemoteOutcome { connected, cancelled, failed }

class OnboardingOneDriveAuthResult {
  final OnboardingOneDriveOutcome outcome;
  final GraphAccount? account;
  final String? message;

  const OnboardingOneDriveAuthResult({
    required this.outcome,
    this.account,
    this.message,
  });
}

class OnboardingRemoteConnectResult {
  final OnboardingRemoteOutcome outcome;
  final RemoteStorageAccount? account;
  final String? message;

  const OnboardingRemoteConnectResult({
    required this.outcome,
    this.account,
    this.message,
  });
}

class OnboardingSourceStatusEvent {
  final OnboardingSourceType source;
  final OnboardingSourceStatus status;
  final String message;
  final DateTime occurredAt;
  final int failures;
  final bool showEscalatedTroubleshooting;

  const OnboardingSourceStatusEvent({
    required this.source,
    required this.status,
    required this.message,
    required this.occurredAt,
    required this.failures,
    required this.showEscalatedTroubleshooting,
  });
}

class OnboardingSourceConnectionService {
  static const int troubleshootingEscalationThreshold = 3;

  final Map<OnboardingSourceType, int> _failureCounts =
      <OnboardingSourceType, int>{};

  int failureCountFor(OnboardingSourceType source) => _failureCounts[source] ?? 0;

  bool shouldEscalateTroubleshooting(OnboardingSourceType source) {
    return failureCountFor(source) >= troubleshootingEscalationThreshold;
  }

  void markFailure(OnboardingSourceType source) {
    _failureCounts[source] = failureCountFor(source) + 1;
  }

  void resetFailures(OnboardingSourceType source) {
    _failureCounts[source] = 0;
  }

  Future<OnboardingSourceStatusEvent> connectLocal({
    required LibraryProvider library,
    MetadataService? metadata,
    LibraryType? forcedType,
  }) async {
    final before = _folderFingerprints(library);

    try {
      await library.pickAndScan(metadata: metadata, forcedType: forcedType);
    } catch (error) {
      markFailure(OnboardingSourceType.local);
      return _event(
        source: OnboardingSourceType.local,
        status: OnboardingSourceStatus.failed,
        message: 'Local folder setup failed: $error',
      );
    }

    if (library.error != null && library.error!.isNotEmpty) {
      markFailure(OnboardingSourceType.local);
      return _event(
        source: OnboardingSourceType.local,
        status: OnboardingSourceStatus.failed,
        message: library.error!,
      );
    }

    final after = _folderFingerprints(library);
    final connected = after.length > before.length;

    if (connected) {
      resetFailures(OnboardingSourceType.local);
      return _event(
        source: OnboardingSourceType.local,
        status: OnboardingSourceStatus.connected,
        message: 'Local source connected.',
      );
    }

    return _event(
      source: OnboardingSourceType.local,
      status: OnboardingSourceStatus.incomplete,
      message: 'Local source setup was skipped or cancelled.',
    );
  }

  Future<OnboardingSourceStatusEvent> connectOneDrive({
    required Future<OnboardingOneDriveAuthResult> Function() startAuth,
  }) async {
    final result = await startAuth();

    switch (result.outcome) {
      case OnboardingOneDriveOutcome.connected:
        resetFailures(OnboardingSourceType.oneDrive);
        return _event(
          source: OnboardingSourceType.oneDrive,
          status: OnboardingSourceStatus.connected,
          message: result.message ?? 'OneDrive connected.',
        );
      case OnboardingOneDriveOutcome.cancelled:
      case OnboardingOneDriveOutcome.timedOut:
        return _event(
          source: OnboardingSourceType.oneDrive,
          status: OnboardingSourceStatus.incomplete,
          message: result.message ?? 'OneDrive setup was not completed.',
        );
      case OnboardingOneDriveOutcome.failed:
        markFailure(OnboardingSourceType.oneDrive);
        return _event(
          source: OnboardingSourceType.oneDrive,
          status: OnboardingSourceStatus.failed,
          message: result.message ?? 'OneDrive setup failed.',
        );
    }
  }

  Future<OnboardingSourceStatusEvent> connectRemote({
    required OnboardingSourceType source,
    required Future<OnboardingRemoteConnectResult?> Function(RemoteStorageType)
        showConnectionDialog,
  }) async {
    final remoteType = _remoteTypeFor(source);
    if (remoteType == null) {
      markFailure(source);
      return _event(
        source: source,
        status: OnboardingSourceStatus.failed,
        message: 'Unsupported remote source type: ${source.name}',
      );
    }

    final result = await showConnectionDialog(remoteType);
    if (result == null) {
      return _event(
        source: source,
        status: OnboardingSourceStatus.incomplete,
        message: '${source.name.toUpperCase()} setup was cancelled.',
      );
    }

    switch (result.outcome) {
      case OnboardingRemoteOutcome.connected:
        resetFailures(source);
        return _event(
          source: source,
          status: OnboardingSourceStatus.connected,
          message: result.message ?? '${source.name.toUpperCase()} connected.',
        );
      case OnboardingRemoteOutcome.cancelled:
        return _event(
          source: source,
          status: OnboardingSourceStatus.incomplete,
          message: result.message ?? '${source.name.toUpperCase()} setup cancelled.',
        );
      case OnboardingRemoteOutcome.failed:
        markFailure(source);
        return _event(
          source: source,
          status: OnboardingSourceStatus.failed,
          message: result.message ?? '${source.name.toUpperCase()} setup failed.',
        );
    }
  }

  Set<String> _folderFingerprints(LibraryProvider library) {
    return library.libraryFolders
        .map((folder) => '${folder.accountId}:${folder.path}')
        .toSet();
  }

  RemoteStorageType? _remoteTypeFor(OnboardingSourceType source) {
    switch (source) {
      case OnboardingSourceType.sftp:
        return RemoteStorageType.sftp;
      case OnboardingSourceType.ftp:
        return RemoteStorageType.ftp;
      case OnboardingSourceType.webdav:
        return RemoteStorageType.webdav;
      case OnboardingSourceType.local:
      case OnboardingSourceType.oneDrive:
        return null;
    }
  }

  OnboardingSourceStatusEvent _event({
    required OnboardingSourceType source,
    required OnboardingSourceStatus status,
    required String message,
  }) {
    return OnboardingSourceStatusEvent(
      source: source,
      status: status,
      message: message,
      occurredAt: DateTime.now(),
      failures: failureCountFor(source),
      showEscalatedTroubleshooting: shouldEscalateTroubleshooting(source),
    );
  }
}
