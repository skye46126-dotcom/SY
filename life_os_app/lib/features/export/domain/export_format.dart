enum ExportFormat {
  sqlite,
  json,
  csv,
  zip,
  markdown,
  txt,
  pdf,
  png,
  svg,
}

extension ExportFormatLabel on ExportFormat {
  String get key {
    switch (this) {
      case ExportFormat.sqlite:
        return 'sqlite';
      case ExportFormat.json:
        return 'json';
      case ExportFormat.csv:
        return 'csv';
      case ExportFormat.zip:
        return 'zip';
      case ExportFormat.markdown:
        return 'markdown';
      case ExportFormat.txt:
        return 'txt';
      case ExportFormat.pdf:
        return 'pdf';
      case ExportFormat.png:
        return 'png';
      case ExportFormat.svg:
        return 'svg';
    }
  }
}
