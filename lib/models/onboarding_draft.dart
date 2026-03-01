// lib/models/onboarding_draft.dart
//
// Persisted onboarding draft state for resumable setup flow.

import 'package:flutter/foundation.dart';

import 'library_folder.dart';

enum OnboardingSourceStatus {
  notStarted,
  inProgress,
  incomplete,
  connected,
  failed,
}

String onboardingSourceStatusToString(OnboardingSourceStatus status) {
  switch (status) {
    case OnboardingSourceStatus.notStarted:
      return 'not_started';
    case OnboardingSourceStatus.inProgress:
      return 'in_progress';
    case OnboardingSourceStatus.incomplete:
      return 'incomplete';
    case OnboardingSourceStatus.connected:
      return 'connected';
    case OnboardingSourceStatus.failed:
      return 'failed';
  }
}

OnboardingSourceStatus onboardingSourceStatusFromString(String? value) {
  switch (value) {
    case 'in_progress':
      return OnboardingSourceStatus.inProgress;
    case 'incomplete':
      return OnboardingSourceStatus.incomplete;
    case 'connected':
      return OnboardingSourceStatus.connected;
    case 'failed':
      return OnboardingSourceStatus.failed;
    case 'not_started':
    default:
      return OnboardingSourceStatus.notStarted;
  }
}

class OnboardingChecklistState {
  const OnboardingChecklistState({
    this.libraryTypesCompleted = false,
    this.sourcesReviewed = false,
    this.adultPrivacyReviewed = false,
    this.finalReviewCompleted = false,
  });

  final bool libraryTypesCompleted;
  final bool sourcesReviewed;
  final bool adultPrivacyReviewed;
  final bool finalReviewCompleted;

  OnboardingChecklistState copyWith({
    bool? libraryTypesCompleted,
    bool? sourcesReviewed,
    bool? adultPrivacyReviewed,
    bool? finalReviewCompleted,
  }) {
    return OnboardingChecklistState(
      libraryTypesCompleted:
          libraryTypesCompleted ?? this.libraryTypesCompleted,
      sourcesReviewed: sourcesReviewed ?? this.sourcesReviewed,
      adultPrivacyReviewed: adultPrivacyReviewed ?? this.adultPrivacyReviewed,
      finalReviewCompleted: finalReviewCompleted ?? this.finalReviewCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'libraryTypesCompleted': libraryTypesCompleted,
      'sourcesReviewed': sourcesReviewed,
      'adultPrivacyReviewed': adultPrivacyReviewed,
      'finalReviewCompleted': finalReviewCompleted,
    };
  }

  factory OnboardingChecklistState.fromJson(Map<String, dynamic> json) {
    return OnboardingChecklistState(
      libraryTypesCompleted: json['libraryTypesCompleted'] == true,
      sourcesReviewed: json['sourcesReviewed'] == true,
      adultPrivacyReviewed: json['adultPrivacyReviewed'] == true,
      finalReviewCompleted: json['finalReviewCompleted'] == true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OnboardingChecklistState &&
        other.libraryTypesCompleted == libraryTypesCompleted &&
        other.sourcesReviewed == sourcesReviewed &&
        other.adultPrivacyReviewed == adultPrivacyReviewed &&
        other.finalReviewCompleted == finalReviewCompleted;
  }

  @override
  int get hashCode {
    return Object.hash(
      libraryTypesCompleted,
      sourcesReviewed,
      adultPrivacyReviewed,
      finalReviewCompleted,
    );
  }
}

class OnboardingDraft {
  const OnboardingDraft({
    this.currentStep = 0,
    this.checklistState = const OnboardingChecklistState(),
    this.selectedLibraryTypes = const <LibraryType>{},
    this.sourceStatuses = const <LibraryType, OnboardingSourceStatus>{},
    this.hasAcknowledgedAdultPrivacy = false,
    this.hasAcknowledgedFinalReview = false,
  });

  final int currentStep;
  final OnboardingChecklistState checklistState;
  final Set<LibraryType> selectedLibraryTypes;
  final Map<LibraryType, OnboardingSourceStatus> sourceStatuses;
  final bool hasAcknowledgedAdultPrivacy;
  final bool hasAcknowledgedFinalReview;

  OnboardingDraft copyWith({
    int? currentStep,
    OnboardingChecklistState? checklistState,
    Set<LibraryType>? selectedLibraryTypes,
    Map<LibraryType, OnboardingSourceStatus>? sourceStatuses,
    bool? hasAcknowledgedAdultPrivacy,
    bool? hasAcknowledgedFinalReview,
  }) {
    return OnboardingDraft(
      currentStep: currentStep ?? this.currentStep,
      checklistState: checklistState ?? this.checklistState,
      selectedLibraryTypes: selectedLibraryTypes ?? this.selectedLibraryTypes,
      sourceStatuses: sourceStatuses ?? this.sourceStatuses,
      hasAcknowledgedAdultPrivacy:
          hasAcknowledgedAdultPrivacy ?? this.hasAcknowledgedAdultPrivacy,
      hasAcknowledgedFinalReview:
          hasAcknowledgedFinalReview ?? this.hasAcknowledgedFinalReview,
    );
  }

  Map<String, dynamic> toJson() {
    final selectedTypes = selectedLibraryTypes
        .map(libraryTypeToString)
        .toList(growable: false);
    final serializedStatuses = <String, String>{};
    sourceStatuses.forEach((type, status) {
      serializedStatuses[libraryTypeToString(type)] =
          onboardingSourceStatusToString(status);
    });

    return {
      'currentStep': currentStep,
      'checklistState': checklistState.toJson(),
      'selectedLibraryTypes': selectedTypes,
      'sourceStatuses': serializedStatuses,
      'hasAcknowledgedAdultPrivacy': hasAcknowledgedAdultPrivacy,
      'hasAcknowledgedFinalReview': hasAcknowledgedFinalReview,
    };
  }

  factory OnboardingDraft.fromJson(Map<String, dynamic> json) {
    final currentStepValue = json['currentStep'];
    final rawSelectedTypes = json['selectedLibraryTypes'];
    final rawChecklistState = json['checklistState'];
    final rawSourceStatuses = json['sourceStatuses'];

    final parsedSelectedTypes = <LibraryType>{};
    if (rawSelectedTypes is List) {
      for (final value in rawSelectedTypes) {
        if (value is! String) {
          continue;
        }
        parsedSelectedTypes.add(libraryTypeFromString(value));
      }
    }

    final parsedSourceStatuses = <LibraryType, OnboardingSourceStatus>{};
    if (rawSourceStatuses is Map) {
      for (final entry in rawSourceStatuses.entries) {
        final key = entry.key;
        if (key is! String) {
          continue;
        }

        final statusValue = entry.value;
        if (statusValue is! String) {
          continue;
        }

        parsedSourceStatuses[libraryTypeFromString(key)] =
            onboardingSourceStatusFromString(statusValue);
      }
    }

    OnboardingChecklistState checklistState = const OnboardingChecklistState();
    if (rawChecklistState is Map<String, dynamic>) {
      checklistState = OnboardingChecklistState.fromJson(rawChecklistState);
    } else if (rawChecklistState is Map) {
      checklistState = OnboardingChecklistState.fromJson(
        rawChecklistState.cast<String, dynamic>(),
      );
    }

    final clampedStep =
        currentStepValue is int ? (currentStepValue < 0 ? 0 : currentStepValue) : 0;

    return OnboardingDraft(
      currentStep: clampedStep,
      checklistState: checklistState,
      selectedLibraryTypes: parsedSelectedTypes,
      sourceStatuses: parsedSourceStatuses,
      hasAcknowledgedAdultPrivacy: json['hasAcknowledgedAdultPrivacy'] == true,
      hasAcknowledgedFinalReview: json['hasAcknowledgedFinalReview'] == true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OnboardingDraft &&
        other.currentStep == currentStep &&
        other.checklistState == checklistState &&
        setEquals(other.selectedLibraryTypes, selectedLibraryTypes) &&
        mapEquals(other.sourceStatuses, sourceStatuses) &&
        other.hasAcknowledgedAdultPrivacy == hasAcknowledgedAdultPrivacy &&
        other.hasAcknowledgedFinalReview == hasAcknowledgedFinalReview;
  }

  @override
  int get hashCode {
    return Object.hash(
      currentStep,
      checklistState,
      Object.hashAll(selectedLibraryTypes),
      Object.hashAll(
        sourceStatuses.entries
            .map((entry) => Object.hash(entry.key, entry.value)),
      ),
      hasAcknowledgedAdultPrivacy,
      hasAcknowledgedFinalReview,
    );
  }
}
