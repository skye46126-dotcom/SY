enum ExportRange {
  all,
  today,
  week,
  month,
  year,
  custom,
}

extension ExportRangeLabel on ExportRange {
  String get key {
    switch (this) {
      case ExportRange.all:
        return 'all';
      case ExportRange.today:
        return 'today';
      case ExportRange.week:
        return 'week';
      case ExportRange.month:
        return 'month';
      case ExportRange.year:
        return 'year';
      case ExportRange.custom:
        return 'custom';
    }
  }
}
