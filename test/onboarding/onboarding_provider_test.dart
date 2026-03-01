/// test/onboarding/onboarding_provider_test.dart
///
/// Provider tests for resumable onboarding state transitions.

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
  group('OnboardingProvider', () {
    test('starts with no default selected library types', () {
      final provider = OnboardingProvider(
        onboardingDraftService: _FakeOnboardingDraftService(),
      );

      expect(provider.selectedLibraryTypes, isEmpty);
      expect(provider.isAdultLibrarySelected, isFalse);
    });

    test('restart clears selected types and source statuses', () async {
      final provider = OnboardingProvider(
        onboardingDraftService: _FakeOnboardingDraftService(),
      );

      await provider.toggleLibraryTypeCard(LibraryType.movies);
      await provider.toggleAdultLibrarySelection(true);
      await provider.updateSourceConnectionStatus(
        LibraryType.movies,
        OnboardingSourceStatus.connected,
      );

      expect(provider.selectedLibraryTypes, isNotEmpty);
      expect(provider.sourceStatuses, isNotEmpty);

      await provider.restartFromBeginning();

      expect(provider.currentStep, 0);
      expect(provider.selectedLibraryTypes, isEmpty);
      expect(provider.sourceStatuses, isEmpty);
    });

    test('resume restores draft step and checklist flags', () async {
      final draft = OnboardingDraft(
        currentStep: 2,
        checklistState: const OnboardingChecklistState(
          libraryTypesCompleted: true,
          sourcesReviewed: true,
          adultPrivacyReviewed: true,
          finalReviewCompleted: false,
        ),
        selectedLibraryTypes: const <LibraryType>{
          LibraryType.tv,
          LibraryType.adult,
        },
        sourceStatuses: const <LibraryType, OnboardingSourceStatus>{
          LibraryType.tv: OnboardingSourceStatus.inProgress,
        },
        hasAcknowledgedAdultPrivacy: true,
        hasAcknowledgedFinalReview: false,
      );
      final provider = OnboardingProvider(
        onboardingDraftService: _FakeOnboardingDraftService(
          initialDraft: draft,
        ),
      );

      await provider.resumeDraft();

      expect(provider.currentStep, 2);
      expect(provider.checklistState.libraryTypesCompleted, isTrue);
      expect(provider.checklistState.sourcesReviewed, isTrue);
      expect(provider.checklistState.adultPrivacyReviewed, isTrue);
      expect(provider.checklistState.finalReviewCompleted, isFalse);
      expect(provider.selectedLibraryTypes, contains(LibraryType.tv));
      expect(provider.selectedLibraryTypes, contains(LibraryType.adult));
      expect(
        provider.sourceStatuses[LibraryType.tv],
        OnboardingSourceStatus.inProgress,
      );
    });

    test('adult library is managed through explicit privacy section state',
        () async {
      final provider = OnboardingProvider(
        onboardingDraftService: _FakeOnboardingDraftService(),
      );

      await provider.toggleAdultLibrarySelection(true);
      expect(provider.isAdultLibrarySelected, isTrue);
      expect(provider.hasAcknowledgedAdultPrivacy, isFalse);
      expect(provider.checklistState.adultPrivacyReviewed, isFalse);

      await provider.setAdultPrivacyAcknowledged(true);
      expect(provider.hasAcknowledgedAdultPrivacy, isTrue);
      expect(provider.checklistState.adultPrivacyReviewed, isTrue);
    });

    test('completion requires final review acknowledgement', () async {
      final provider = OnboardingProvider(
        onboardingDraftService: _FakeOnboardingDraftService(),
      );

      await provider.toggleLibraryTypeCard(LibraryType.movies);
      await provider.setAdultPrivacyAcknowledged(true);

      final canCompleteBeforeReview = await provider.completeOnboarding();
      expect(canCompleteBeforeReview, isFalse);

      await provider.setFinalReviewAcknowledged(true);
      final canCompleteAfterReview = await provider.completeOnboarding();
      expect(canCompleteAfterReview, isTrue);
    });
  });
}
