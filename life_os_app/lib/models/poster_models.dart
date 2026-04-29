enum PosterTimeRange {
  today,
  week,
  month,
}

extension PosterTimeRangeLabel on PosterTimeRange {
  String get label {
    switch (this) {
      case PosterTimeRange.today:
        return '今日';
      case PosterTimeRange.week:
        return '本周';
      case PosterTimeRange.month:
        return '本月';
    }
  }

  String get exportKey {
    switch (this) {
      case PosterTimeRange.today:
        return 'daily';
      case PosterTimeRange.week:
        return 'weekly';
      case PosterTimeRange.month:
        return 'monthly';
    }
  }
}

enum PosterTemplateKind {
  poster,
  minimal,
  magazine,
}

extension PosterTemplateKindLabel on PosterTemplateKind {
  String get label {
    switch (this) {
      case PosterTemplateKind.poster:
        return '海报型';
      case PosterTemplateKind.minimal:
        return '极简卡片';
      case PosterTemplateKind.magazine:
        return '周报型';
    }
  }

  String get exportKey {
    switch (this) {
      case PosterTemplateKind.poster:
        return 'poster';
      case PosterTemplateKind.minimal:
        return 'minimal';
      case PosterTemplateKind.magazine:
        return 'magazine';
    }
  }
}

enum PosterArtKind {
  focusBeam,
  growthWave,
  amberSun,
  glassRibbon,
  projectCard,
  galleryFrame,
  uploadedImage,
}

class PosterCoverAsset {
  const PosterCoverAsset({
    required this.id,
    required this.label,
    required this.helperText,
    required this.themeKey,
    required this.artKind,
    this.imagePath,
    this.imageLabel,
  });

  final String id;
  final String label;
  final String helperText;
  final String themeKey;
  final PosterArtKind artKind;
  final String? imagePath;
  final String? imageLabel;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'label': label,
      'helper_text': helperText,
      'theme_key': themeKey,
      'art_kind': artKind.name,
      'image_path': imagePath,
      'image_label': imageLabel,
    };
  }
}

enum PosterCoverSource {
  auto,
  focusBlue,
  growthMint,
  amberReset,
  calmSilver,
  projectCover,
  galleryImage,
  localUpload,
}

extension PosterCoverSourceLabel on PosterCoverSource {
  String get label {
    switch (this) {
      case PosterCoverSource.auto:
        return '自动选择';
      case PosterCoverSource.focusBlue:
        return 'Focus Blue';
      case PosterCoverSource.growthMint:
        return 'Growth Mint';
      case PosterCoverSource.amberReset:
        return 'Amber Reset';
      case PosterCoverSource.calmSilver:
        return 'Calm Silver';
      case PosterCoverSource.projectCover:
        return '项目封面';
      case PosterCoverSource.galleryImage:
        return '画廊图片';
      case PosterCoverSource.localUpload:
        return '本地上传';
    }
  }

  String get exportKey {
    switch (this) {
      case PosterCoverSource.auto:
        return 'auto';
      case PosterCoverSource.focusBlue:
        return 'focus_blue';
      case PosterCoverSource.growthMint:
        return 'growth_mint';
      case PosterCoverSource.amberReset:
        return 'amber_reset';
      case PosterCoverSource.calmSilver:
        return 'calm_silver';
      case PosterCoverSource.projectCover:
        return 'project_cover';
      case PosterCoverSource.galleryImage:
        return 'gallery_image';
      case PosterCoverSource.localUpload:
        return 'local_upload';
    }
  }

  String get helperText {
    switch (this) {
      case PosterCoverSource.auto:
        return '按经营状态自动匹配主题';
      case PosterCoverSource.focusBlue:
        return '专注、理性、正向推进';
      case PosterCoverSource.growthMint:
        return '学习、成长、轻盈节奏';
      case PosterCoverSource.amberReset:
        return '恢复、复位、重新起步';
      case PosterCoverSource.calmSilver:
        return '克制、留白、公开分享';
      case PosterCoverSource.projectCover:
        return '使用主项目相关封面';
      case PosterCoverSource.galleryImage:
        return '使用画廊中的图片路径';
      case PosterCoverSource.localUpload:
        return '使用本地图片文件';
    }
  }

  bool get acceptsImagePath {
    switch (this) {
      case PosterCoverSource.projectCover:
      case PosterCoverSource.galleryImage:
      case PosterCoverSource.localUpload:
        return true;
      case PosterCoverSource.auto:
      case PosterCoverSource.focusBlue:
      case PosterCoverSource.growthMint:
      case PosterCoverSource.amberReset:
      case PosterCoverSource.calmSilver:
        return false;
    }
  }
}

enum PosterPrivacyMode {
  publicShare,
  limitedShare,
  privateReview,
}

extension PosterPrivacyModeLabel on PosterPrivacyMode {
  String get label {
    switch (this) {
      case PosterPrivacyMode.publicShare:
        return '公开分享';
      case PosterPrivacyMode.limitedShare:
        return '半公开';
      case PosterPrivacyMode.privateReview:
        return '私人复盘';
    }
  }

  String get exportKey {
    switch (this) {
      case PosterPrivacyMode.publicShare:
        return 'public';
      case PosterPrivacyMode.limitedShare:
        return 'limited';
      case PosterPrivacyMode.privateReview:
        return 'private';
    }
  }
}

enum PosterMoneyDisplayMode {
  hidden,
  trend,
  exact,
}

extension PosterMoneyDisplayModeLabel on PosterMoneyDisplayMode {
  String get label {
    switch (this) {
      case PosterMoneyDisplayMode.hidden:
        return '隐藏金额';
      case PosterMoneyDisplayMode.trend:
        return '显示趋势';
      case PosterMoneyDisplayMode.exact:
        return '显示金额';
    }
  }
}

enum PosterProjectDisplayMode {
  category,
  anonymous,
  exact,
}

extension PosterProjectDisplayModeLabel on PosterProjectDisplayMode {
  String get label {
    switch (this) {
      case PosterProjectDisplayMode.category:
        return '项目分类';
      case PosterProjectDisplayMode.anonymous:
        return '匿名显示';
      case PosterProjectDisplayMode.exact:
        return '真实项目名';
    }
  }
}

class PosterPrivacyPolicy {
  const PosterPrivacyPolicy({
    required this.mode,
    required this.moneyDisplayMode,
    required this.projectDisplayMode,
    required this.showStateScore,
    required this.showAiRatio,
    required this.showSummary,
    required this.showKeywords,
    required this.showProject,
    required this.showPassiveCover,
    required this.showLearningMinutes,
    required this.showWorkMinutes,
  });

  final PosterPrivacyMode mode;
  final PosterMoneyDisplayMode moneyDisplayMode;
  final PosterProjectDisplayMode projectDisplayMode;
  final bool showStateScore;
  final bool showAiRatio;
  final bool showSummary;
  final bool showKeywords;
  final bool showProject;
  final bool showPassiveCover;
  final bool showLearningMinutes;
  final bool showWorkMinutes;

  factory PosterPrivacyPolicy.preset(PosterPrivacyMode mode) {
    switch (mode) {
      case PosterPrivacyMode.publicShare:
        return const PosterPrivacyPolicy(
          mode: PosterPrivacyMode.publicShare,
          moneyDisplayMode: PosterMoneyDisplayMode.hidden,
          projectDisplayMode: PosterProjectDisplayMode.category,
          showStateScore: true,
          showAiRatio: true,
          showSummary: true,
          showKeywords: true,
          showProject: true,
          showPassiveCover: true,
          showLearningMinutes: true,
          showWorkMinutes: true,
        );
      case PosterPrivacyMode.limitedShare:
        return const PosterPrivacyPolicy(
          mode: PosterPrivacyMode.limitedShare,
          moneyDisplayMode: PosterMoneyDisplayMode.trend,
          projectDisplayMode: PosterProjectDisplayMode.category,
          showStateScore: true,
          showAiRatio: true,
          showSummary: true,
          showKeywords: true,
          showProject: true,
          showPassiveCover: true,
          showLearningMinutes: true,
          showWorkMinutes: true,
        );
      case PosterPrivacyMode.privateReview:
        return const PosterPrivacyPolicy(
          mode: PosterPrivacyMode.privateReview,
          moneyDisplayMode: PosterMoneyDisplayMode.exact,
          projectDisplayMode: PosterProjectDisplayMode.exact,
          showStateScore: true,
          showAiRatio: true,
          showSummary: true,
          showKeywords: true,
          showProject: true,
          showPassiveCover: true,
          showLearningMinutes: true,
          showWorkMinutes: true,
        );
    }
  }

  PosterPrivacyPolicy copyWith({
    PosterPrivacyMode? mode,
    PosterMoneyDisplayMode? moneyDisplayMode,
    PosterProjectDisplayMode? projectDisplayMode,
    bool? showStateScore,
    bool? showAiRatio,
    bool? showSummary,
    bool? showKeywords,
    bool? showProject,
    bool? showPassiveCover,
    bool? showLearningMinutes,
    bool? showWorkMinutes,
  }) {
    return PosterPrivacyPolicy(
      mode: mode ?? this.mode,
      moneyDisplayMode: moneyDisplayMode ?? this.moneyDisplayMode,
      projectDisplayMode: projectDisplayMode ?? this.projectDisplayMode,
      showStateScore: showStateScore ?? this.showStateScore,
      showAiRatio: showAiRatio ?? this.showAiRatio,
      showSummary: showSummary ?? this.showSummary,
      showKeywords: showKeywords ?? this.showKeywords,
      showProject: showProject ?? this.showProject,
      showPassiveCover: showPassiveCover ?? this.showPassiveCover,
      showLearningMinutes: showLearningMinutes ?? this.showLearningMinutes,
      showWorkMinutes: showWorkMinutes ?? this.showWorkMinutes,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'privacy_mode': mode.exportKey,
      'money_display_mode': moneyDisplayMode.name,
      'project_display_mode': projectDisplayMode.name,
      'show_state_score': showStateScore,
      'show_ai_ratio': showAiRatio,
      'show_summary': showSummary,
      'show_keywords': showKeywords,
      'show_project': showProject,
      'show_passive_cover': showPassiveCover,
      'show_learning_minutes': showLearningMinutes,
      'show_work_minutes': showWorkMinutes,
    };
  }
}

class PosterMetricData {
  const PosterMetricData({
    required this.key,
    required this.label,
    required this.value,
    required this.note,
    required this.tone,
  });

  final String key;
  final String label;
  final String value;
  final String note;
  final String tone;

  Map<String, Object?> toJson() {
    return {
      'key': key,
      'label': label,
      'value': value,
      'note': note,
      'tone': tone,
    };
  }
}

class PosterSourceData {
  const PosterSourceData({
    required this.range,
    required this.anchorDate,
    required this.dateLabel,
    required this.periodLabel,
    required this.summaryText,
    required this.financeStateLabel,
    required this.netIncomeCents,
    required this.incomeCents,
    required this.expenseCents,
    required this.workMinutes,
    required this.learningMinutes,
    required this.aiRatio,
    required this.passiveCoverRatio,
    required this.actualHourlyRateCents,
    required this.idealHourlyRateCents,
    required this.primaryProjectName,
    required this.keywordPool,
    required this.incomeChangeRatio,
    required this.expenseChangeRatio,
    required this.workChangeRatio,
  });

  final PosterTimeRange range;
  final DateTime anchorDate;
  final String dateLabel;
  final String periodLabel;
  final String summaryText;
  final String financeStateLabel;
  final int netIncomeCents;
  final int incomeCents;
  final int expenseCents;
  final int workMinutes;
  final int learningMinutes;
  final double? aiRatio;
  final double? passiveCoverRatio;
  final int? actualHourlyRateCents;
  final int? idealHourlyRateCents;
  final String? primaryProjectName;
  final List<String> keywordPool;
  final double? incomeChangeRatio;
  final double? expenseChangeRatio;
  final double? workChangeRatio;
}

class PosterExportData {
  const PosterExportData({
    required this.range,
    required this.template,
    required this.coverSource,
    required this.coverAsset,
    required this.policy,
    required this.brandLabel,
    required this.title,
    required this.periodLabel,
    required this.dateLabel,
    required this.stateScore,
    required this.stateLabel,
    required this.summary,
    required this.projectLabel,
    required this.keywords,
    required this.themeKey,
    required this.metrics,
    required this.generatedAt,
  });

  final PosterTimeRange range;
  final PosterTemplateKind template;
  final PosterCoverSource coverSource;
  final PosterCoverAsset coverAsset;
  final PosterPrivacyPolicy policy;
  final String brandLabel;
  final String title;
  final String periodLabel;
  final String dateLabel;
  final int stateScore;
  final String stateLabel;
  final String summary;
  final String? projectLabel;
  final List<String> keywords;
  final String themeKey;
  final List<PosterMetricData> metrics;
  final DateTime generatedAt;

  Map<String, Object?> toJson() {
    return {
      'range': range.exportKey,
      'template': template.exportKey,
      'cover_source': coverSource.exportKey,
      'cover_asset': coverAsset.toJson(),
      'policy': policy.toJson(),
      'brand_label': brandLabel,
      'title': title,
      'period_label': periodLabel,
      'date_label': dateLabel,
      'state_score': stateScore,
      'state_label': stateLabel,
      'summary': summary,
      'project_label': projectLabel,
      'keywords': keywords,
      'theme_key': themeKey,
      'metrics': metrics.map((item) => item.toJson()).toList(),
      'generated_at': generatedAt.toIso8601String(),
    };
  }
}
