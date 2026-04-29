enum ExportType {
  backup,
  dataPackage,
  report,
  snapshot,
  poster,
}

extension ExportTypeLabel on ExportType {
  String get key {
    switch (this) {
      case ExportType.backup:
        return 'backup';
      case ExportType.dataPackage:
        return 'data_package';
      case ExportType.report:
        return 'report';
      case ExportType.snapshot:
        return 'snapshot';
      case ExportType.poster:
        return 'poster';
    }
  }
}
