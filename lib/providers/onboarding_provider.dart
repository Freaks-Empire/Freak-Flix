// lib/providers/onboarding_provider.dart
//
// Onboarding state machine with resumable draft persistence.

import 'package:flutter/material.dart';

import '../models/library_folder.dart';
import '../models/onboarding_draft.dart';
import '../services/onboarding_draft_service.dart';

enum OnboardingStep {
  libraryTypes,
  sourceConnections,
  adultPrivacy,
  review,
}

class OnboardingProvider extends ChangeNotifier {
  OnboardingProvider({OnboardingDraftService? onboardingDraftService})
      : _onboardingDraftService =
            onboardingDraftService ?? OnboardingDraftService();

  final OnboardingDraftService _onboardingDraftService;

  int _currentStep = 0;
  OnboardingChecklistState _checklistState = const OnboardingChecklistState();
  final Set<LibraryType> _selectedLibraryTypes = <LibraryType>{};
  final Map<LibraryType, OnboardingSourceStatus> _sourceStatuses =
      <LibraryType, OnboardingSourceStatus>{};
  bool _hasAcknowledgedAdultPrivacy = false;
  bool _hasAcknowledgedFinalReview = false;

  static int get maxStepIndex => OnboardingStep.values.length - 1;

  int get currentStep => _currentStep;

  OnboardingStep get activeStep => OnboardingStep.values[_currentStep];

  OnboardingChecklistState get checklistState => _checklistState;

  Set<LibraryType> get selectedLibraryTypes =>
      Set<LibraryType>.unmodifiable(_selectedLibraryTypes);

  Map<LibraryType, OnboardingSourceStatus> get sourceStatuses =>
      Map<LibraryType, OnboardingSourceStatus>.unmodifiable(_sourceStatuses);

  bool get hasAcknowledgedAdultPrivacy => _hasAcknowledgedAdultPrivacy;

  bool get hasAcknowledgedFinalReview => _hasAcknowledgedFinalReview;

  bool get isAdultLibrarySelected =>
      _selectedLibraryTypes.contains(LibraryType.adult);

  bool get canCompleteOnboarding {
    return _checklistState.libraryTypesCompleted &&
        _checklistState.adultPrivacyReviewed &&
        _hasAcknowledgedFinalReview;
  }

  Future<void> resumeDraft() async {
    final draft = await _onboardingDraftService.loadDraft();
    _applyDraft(_sanitizeDraft(draft));
    notifyListeners();
  }

  Future<void> restartFromBeginning() async {
    _applyDraft(const OnboardingDraft());
    await _onboardingDraftService.clearDraft();
    notifyListeners();
  }

  Future<void> goToNextStep() async {
    if (_currentStep >= maxStepIndex) {
      return;
    }

    _currentStep += 1;
    _recalculateChecklistState();
    await _persistDraft();
    notifyListeners();
  }

  Future<void> goToPreviousStep() async {
    if (_currentStep <= 0) {
      return;
    }

    _currentStep -= 1;
    _recalculateChecklistState();
    await _persistDraft();
    notifyListeners();
  }

  Future<void> toggleLibraryTypeCard(LibraryType type) async {
    if (type == LibraryType.adult) {
      await toggleAdultLibrarySelection(!isAdultLibrarySelected);
      return;
    }

    if (_selectedLibraryTypes.contains(type)) {
      _selectedLibraryTypes.remove(type);
    } else {
      _selectedLibraryTypes.add(type);
    }

    _recalculateChecklistState();
    await _persistDraft();
    notifyListeners();
  }

  Future<void> toggleAdultLibrarySelection(bool value) async {
    if (value) {
      _selectedLibraryTypes.add(LibraryType.adult);
    } else {
      _selectedLibraryTypes.remove(LibraryType.adult);
      _hasAcknowledgedAdultPrivacy = false;
    }

    _recalculateChecklistState();
    await _persistDraft();
    notifyListeners();
  }

  Future<void> updateSourceConnectionStatus(
    LibraryType libraryType,
    OnboardingSourceStatus status,
  ) async {
    _sourceStatuses[libraryType] = status;
    _recalculateChecklistState();
    await _persistDraft();
    notifyListeners();
  }

  Future<void> setAdultPrivacyAcknowledged(bool value) async {
    _hasAcknowledgedAdultPrivacy = value;
    _recalculateChecklistState();
    await _persistDraft();
    notifyListeners();
  }

  Future<void> setFinalReviewAcknowledged(bool value) async {
    _hasAcknowledgedFinalReview = value;
    _recalculateChecklistState();
    await _persistDraft();
    notifyListeners();
  }

  Future<bool> completeOnboarding() async {
    if (!canCompleteOnboarding) {
      return false;
    }

    _hasAcknowledgedFinalReview = true;
    _recalculateChecklistState();
    await _persistDraft();
    notifyListeners();
    return true;
  }

  Map<String, dynamic> buildReviewSummary() {
    final selectedTypeNames = _selectedLibraryTypes
        .map(libraryTypeDisplayName)
        .toList(growable: false)
      ..sort();

    final sourceStatusByType = <String, String>{};
    _sourceStatuses.forEach((libraryType, status) {
      sourceStatusByType[libraryTypeToString(libraryType)] =
          onboardingSourceStatusToString(status);
    });

    return {
      'step': activeStep.name,
      'selectedLibraryTypes': selectedTypeNames,
      'sourceStatuses': sourceStatusByType,
      'adultPrivacy': {
        'adultSelected': isAdultLibrarySelected,
        'acknowledged': _hasAcknowledgedAdultPrivacy,
      },
      'finalReviewAcknowledged': _hasAcknowledgedFinalReview,
      'checklist': _checklistState.toJson(),
      'canCompleteOnboarding': canCompleteOnboarding,
    };
  }

  void _applyDraft(OnboardingDraft draft) {
    _currentStep = draft.currentStep;
    _checklistState = draft.checklistState;
    _selectedLibraryTypes
      ..clear()
      ..addAll(draft.selectedLibraryTypes);
    _sourceStatuses
      ..clear()
      ..addAll(draft.sourceStatuses);
    _hasAcknowledgedAdultPrivacy = draft.hasAcknowledgedAdultPrivacy;
    _hasAcknowledgedFinalReview = draft.hasAcknowledgedFinalReview;
    _recalculateChecklistState();
  }

  void _recalculateChecklistState() {
    _checklistState = _checklistState.copyWith(
      libraryTypesCompleted: _selectedLibraryTypes.isNotEmpty,
      sourcesReviewed: _sourceStatuses.isNotEmpty,
      adultPrivacyReviewed: !isAdultLibrarySelected || _hasAcknowledgedAdultPrivacy,
      finalReviewCompleted: _hasAcknowledgedFinalReview,
    );
  }

  Future<void> _persistDraft() async {
    final draft = OnboardingDraft(
      currentStep: _currentStep,
      checklistState: _checklistState,
      selectedLibraryTypes: Set<LibraryType>.from(_selectedLibraryTypes),
      sourceStatuses:
          Map<LibraryType, OnboardingSourceStatus>.from(_sourceStatuses),
      hasAcknowledgedAdultPrivacy: _hasAcknowledgedAdultPrivacy,
      hasAcknowledgedFinalReview: _hasAcknowledgedFinalReview,
    );
    await _onboardingDraftService.saveDraft(draft);
  }

  OnboardingDraft _sanitizeDraft(OnboardingDraft draft) {
    final clampedStep = draft.currentStep.clamp(0, maxStepIndex);
    return draft.copyWith(currentStep: clampedStep);
  }
}
