import '../../../models/poster_models.dart';

class ExportPolicy {
  const ExportPolicy({
    required this.privacyMode,
    required this.moneyDisplayMode,
    required this.projectDisplayMode,
    required this.showStateScore,
    required this.showWorkMinutes,
    required this.showLearningMinutes,
    required this.showAiRatio,
    required this.showSummary,
    required this.showKeywords,
    required this.showProject,
    required this.showPassiveCover,
  });

  final PosterPrivacyMode privacyMode;
  final PosterMoneyDisplayMode moneyDisplayMode;
  final PosterProjectDisplayMode projectDisplayMode;
  final bool showStateScore;
  final bool showWorkMinutes;
  final bool showLearningMinutes;
  final bool showAiRatio;
  final bool showSummary;
  final bool showKeywords;
  final bool showProject;
  final bool showPassiveCover;

  factory ExportPolicy.fromPosterPolicy(PosterPrivacyPolicy policy) {
    return ExportPolicy(
      privacyMode: policy.mode,
      moneyDisplayMode: policy.moneyDisplayMode,
      projectDisplayMode: policy.projectDisplayMode,
      showStateScore: policy.showStateScore,
      showWorkMinutes: policy.showWorkMinutes,
      showLearningMinutes: policy.showLearningMinutes,
      showAiRatio: policy.showAiRatio,
      showSummary: policy.showSummary,
      showKeywords: policy.showKeywords,
      showProject: policy.showProject,
      showPassiveCover: policy.showPassiveCover,
    );
  }

  PosterPrivacyPolicy toPosterPolicy() {
    return PosterPrivacyPolicy(
      mode: privacyMode,
      moneyDisplayMode: moneyDisplayMode,
      projectDisplayMode: projectDisplayMode,
      showStateScore: showStateScore,
      showAiRatio: showAiRatio,
      showSummary: showSummary,
      showKeywords: showKeywords,
      showProject: showProject,
      showPassiveCover: showPassiveCover,
      showLearningMinutes: showLearningMinutes,
      showWorkMinutes: showWorkMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'privacy_mode': privacyMode.exportKey,
      'money_display_mode': moneyDisplayMode.name,
      'project_display_mode': projectDisplayMode.name,
      'show_state_score': showStateScore,
      'show_work_minutes': showWorkMinutes,
      'show_learning_minutes': showLearningMinutes,
      'show_ai_ratio': showAiRatio,
      'show_summary': showSummary,
      'show_keywords': showKeywords,
      'show_project': showProject,
      'show_passive_cover': showPassiveCover,
    };
  }
}
