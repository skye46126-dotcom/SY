class ExportMetadata {
  const ExportMetadata(this.value);

  final Map<String, dynamic> value;

  Map<String, dynamic> toJson() => value;
}
