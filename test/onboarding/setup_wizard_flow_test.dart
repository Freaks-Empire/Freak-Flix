/// test/onboarding/setup_wizard_flow_test.dart
///
/// Tests for onboarding wizard progression, resume/restart behavior, and review gate.

import 'package:flutter_test/flutter_test.dart';

import 'package:freak_flix/models/library_folder.dart';
import 'package:freak_flix/models/onboarding_draft.dart';
import 'package:freak_flix/providers/onboarding_provider.dart';
import 'package:freak_flix/services/onboarding_draft_service.dart';

class _FakeOnboardingDraftService extends OnboardingDraftService {
  _FakeOnboardingDraftService({OnboardingDraft? initialDraft})
      : _storedDraft = initialDraft;

  OnboardingDraft? _storedDraft;

  @override
  Future<OnboardingDraft> loadDraft() async {
    return _storedDraft ?? const OnboardingDraft();
  }

  @override
  Future<void> saveDraft(OnboardingDraft draft) async {
    _storedDraft = draft;
  }

  @override
  Future<void> clearDraft() async {
    _storedDraft = null;
  }
}

void main() {
  group('Setup wizard flow behavior via provider', () {
    test('starts at step 0', () {
      final provider = OnboardingProvider(
        onboardingDraftService: _FakeOnboardingDraftService(),
      );

      expect(provider.currentStep, 0);
    });

    test('can advance to next step', () async {
      final provider = OnboardingProvider(
        onboardingDraftService: _FakeOnboardingDraftService(),
      );

      await provider.goToNextStep();

      expect(provider.currentStep, 1);
    });

    test('can go back to previous step', () async {
      final provider = OnboardingProvider(
        onboardingDraftService: _FakeOnboardingDraftService(),
      );

      await provider.goToNextStep();
      await provider.goToPreviousStep();

      expect(provider.currentStep, 0);
    });

    test('cannot complete without selecting library types', () async {
      final provider = OnboardingProvider(
        onboardingDraftService: _FakeOnboardingDraftService(),
      );

      await provider.setAdultPrivacyAcknowledged(true);
      await provider.setFinalReviewAcknowledged(true);

      final canComplete = await provider.completeOnboarding();

      // Should fail - no library types selected
      expect(canComplete, isFalse);
    });

    test('can complete with library types and final review', () async {
      final provider = OnboardingProvider(
        onboardingDraftService: _FakeOnboardingDraftService(),
      );

      await provider.toggleLibraryTypeCard(LibraryType.movies);
      await provider.setFinalReviewAcknowledged(true);

      final canComplete = await provider.completeOnboarding();

      expect(canComplete, isTrue);
    });

    test('adult selection requires privacy acknowledgement', () async {
      final provider = OnboardingProvider(
        onboardingDraftService: _FakeOnboardingDraftService(),
      );

      await provider.toggleAdultLibrarySelection(true);
      await provider.setFinalReviewAcknowledged(true);

      // Cannot complete without privacy ack
      final canCompleteWithoutAck = await provider.completeOnboarding();
      expect(canCompleteWithoutAck, isFalse);

      // With privacy ack, can complete
      await provider.setAdultPrivacyAcknowledged(true);
      final canCompleteWithAck = await provider.completeOnboarding();
      expect(canCompleteWithAck, isTrue);
    });

    test('resume restores correct step', () async {
      final draft = OnboardingDraft(
        currentStep: 3,
        selectedLibraryTypes: {LibraryType.movies},
      );

      final provider = OnboardingProvider(
        onboardingDraftService: _FakeOnboardingDraftService(initialDraft: draft),
      );

      await provider.resumeDraft();

      expect(provider.currentStep, 3);
    });

    test('restart clears draft', () async {
      final draft = OnboardingDraft(
        currentStep: 5,
        selectedLibraryTypes: {LibraryType.movies, LibraryType.tv},
      );

      final provider = OnboardingProvider(
        onboardingDraftService: _FakeOnboardingDraftService(initialDraft: draft),
      );

      await provider.resumeDraft();
      expect(provider.selectedLibraryTypes, isNotEmpty);

      await provider.restartFromBeginning();

      expect(provider.currentStep, 0);
      expect(provider.selectedLibraryTypes, isEmpty);
    });

    test('draft persists across step navigation', () async {
      final provider = OnboardingProvider(
        onboardingDraftService: _FakeOnboardingDraftService(),
      );

      await provider.toggleLibraryTypeCard(LibraryType.anime);
      await provider.goToNextStep();
      await provider.goToNextStep();
      await provider.goToPreviousStep();

      // Library type selection should persist
      expect(provider.selectedLibraryTypes, contains(LibraryType.anime));
    });
  });
}
