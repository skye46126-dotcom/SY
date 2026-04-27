import '../models/poster_models.dart';

class PosterCoverSelector {
  const PosterCoverSelector();

  static const available = <PosterCoverAsset>[
    PosterCoverAsset(
      id: 'focus_blue',
      label: 'Focus Blue',
      helperText: '专注、推进、经营状态正向',
      themeKey: 'focus_blue',
      artKind: PosterArtKind.focusBeam,
    ),
    PosterCoverAsset(
      id: 'growth_mint',
      label: 'Growth Mint',
      helperText: '学习、成长、节奏轻盈',
      themeKey: 'growth_mint',
      artKind: PosterArtKind.growthWave,
    ),
    PosterCoverAsset(
      id: 'amber_reset',
      label: 'Amber Reset',
      helperText: '恢复、缓冲、重新蓄力',
      themeKey: 'amber_reset',
      artKind: PosterArtKind.amberSun,
    ),
    PosterCoverAsset(
      id: 'calm_silver',
      label: 'Calm Silver',
      helperText: '克制、留白、适合公开分享',
      themeKey: 'calm_silver',
      artKind: PosterArtKind.glassRibbon,
    ),
  ];

  PosterCoverAsset resolve({
    required PosterSourceData source,
    required PosterCoverSource coverSource,
  }) {
    switch (coverSource) {
      case PosterCoverSource.auto:
        return _autoSelect(source);
      case PosterCoverSource.focusBlue:
        return available.firstWhere((item) => item.id == 'focus_blue');
      case PosterCoverSource.growthMint:
        return available.firstWhere((item) => item.id == 'growth_mint');
      case PosterCoverSource.amberReset:
        return available.firstWhere((item) => item.id == 'amber_reset');
      case PosterCoverSource.calmSilver:
        return available.firstWhere((item) => item.id == 'calm_silver');
    }
  }

  PosterCoverAsset _autoSelect(PosterSourceData source) {
    final efficiencyRatio = source.actualHourlyRateCents != null &&
            (source.idealHourlyRateCents ?? 0) > 0
        ? source.actualHourlyRateCents! / source.idealHourlyRateCents!
        : 0.6;
    if (source.netIncomeCents >= 0 &&
        source.workMinutes >= source.learningMinutes &&
        efficiencyRatio >= 0.95) {
      return available.firstWhere((item) => item.id == 'focus_blue');
    }
    if (source.learningMinutes >= 60 ||
        (source.keywordPool.join(' ').contains('learn'))) {
      return available.firstWhere((item) => item.id == 'growth_mint');
    }
    if (source.netIncomeCents < 0 || (source.passiveCoverRatio ?? 0) < 0.8) {
      return available.firstWhere((item) => item.id == 'amber_reset');
    }
    return available.firstWhere((item) => item.id == 'calm_silver');
  }
}
