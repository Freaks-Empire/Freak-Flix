/// test/onboarding/source_connection_recovery_test.dart
///
/// Tests onboarding source status mapping and recovery semantics.
import 'package:flutter_test/flutter_test.dart';
import 'package:freak_flix/services/onboarding_source_connection_service.dart';
import 'package:freak_flix/services/remote_storage_service.dart';

void main() {
  group('Onboarding source connection recovery', () {
    test('maps local source pick success to connected', () async {
      final service = OnboardingSourceConnectionService();
      final folderState = <String>{};
      String? localError;

      final event = await service.connectLocal(
        runPickAndScan: () async {
          folderState.add('/tmp/media');
        },
        readError: () => localError,
        folderSnapshot: () => Set<String>.from(folderState),
      );

      expect(event.source, OnboardingSourceType.local);
      expect(event.status, OnboardingSourceStatus.connected);
      expect(event.showEscalatedTroubleshooting, isFalse);
    });

    test('maps OneDrive timeout and cancel to incomplete', () async {
      final service = OnboardingSourceConnectionService();

      final timeoutEvent = await service.connectOneDrive(
        startAuth: () async => const OnboardingOneDriveAuthResult(
          outcome: OnboardingOneDriveOutcome.timedOut,
          message: 'Timed out',
        ),
      );
      final cancelEvent = await service.connectOneDrive(
        startAuth: () async => const OnboardingOneDriveAuthResult(
          outcome: OnboardingOneDriveOutcome.cancelled,
          message: 'Cancelled',
        ),
      );

      expect(timeoutEvent.status, OnboardingSourceStatus.incomplete);
      expect(cancelEvent.status, OnboardingSourceStatus.incomplete);
    });

    test('escalates remote troubleshooting after repeated failures', () async {
      final service = OnboardingSourceConnectionService();

      OnboardingSourceStatusEvent? lastEvent;
      for (var i = 0; i < 3; i++) {
        lastEvent = await service.connectRemote(
          source: OnboardingSourceType.sftp,
          showConnectionDialog: (_) async => const OnboardingRemoteConnectResult(
            outcome: OnboardingRemoteOutcome.failed,
            message: 'Authentication failed',
          ),
        );
      }

      expect(lastEvent, isNotNull);
      expect(lastEvent!.status, OnboardingSourceStatus.failed);
      expect(lastEvent.failures, 3);
      expect(lastEvent.showEscalatedTroubleshooting, isTrue);
    });

    test('keeps onboarding progress available despite incomplete sources', () async {
      final service = OnboardingSourceConnectionService();
      final folderState = <String>{};
      String? localError;

      final localIncomplete = await service.connectLocal(
        runPickAndScan: () async {},
        readError: () => localError,
        folderSnapshot: () => Set<String>.from(folderState),
      );
      final remoteConnected = await service.connectRemote(
        source: OnboardingSourceType.webdav,
        showConnectionDialog: (_) async => OnboardingRemoteConnectResult(
          outcome: OnboardingRemoteOutcome.connected,
          account: RemoteStorageAccount(
            id: 'remote-1',
            type: RemoteStorageType.webdav,
            host: 'cloud.example.com',
            port: 443,
            username: 'demo',
            displayName: 'Demo WebDAV',
          ),
        ),
      );

      expect(localIncomplete.status, OnboardingSourceStatus.incomplete);
      expect(remoteConnected.status, OnboardingSourceStatus.connected);
    });
  });
}
