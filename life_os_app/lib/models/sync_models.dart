class BackupRecordModel {
  const BackupRecordModel({
    required this.id,
    required this.userId,
    required this.backupType,
    required this.filePath,
    required this.fileSizeBytes,
    required this.checksum,
    required this.status,
    required this.errorMessage,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String backupType;
  final String filePath;
  final int? fileSizeBytes;
  final String? checksum;
  final String status;
  final String? errorMessage;
  final String createdAt;

  bool get isSuccess => status == 'success';

  factory BackupRecordModel.fromJson(Map<String, dynamic> json) {
    return BackupRecordModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      backupType: json['backup_type'] as String? ?? '',
      filePath: json['file_path'] as String? ?? '',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt(),
      checksum: json['checksum'] as String?,
      status: json['status'] as String? ?? '',
      errorMessage: json['error_message'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class RestoreRecordModel {
  const RestoreRecordModel({
    required this.id,
    required this.userId,
    required this.backupRecordId,
    required this.status,
    required this.errorMessage,
    required this.restoredAt,
  });

  final String id;
  final String userId;
  final String? backupRecordId;
  final String status;
  final String? errorMessage;
  final String restoredAt;

  bool get isSuccess => status == 'success';

  factory RestoreRecordModel.fromJson(Map<String, dynamic> json) {
    return RestoreRecordModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      backupRecordId: json['backup_record_id'] as String?,
      status: json['status'] as String? ?? '',
      errorMessage: json['error_message'] as String?,
      restoredAt: json['restored_at'] as String? ?? '',
    );
  }
}

class BackupResultModel {
  const BackupResultModel({
    required this.id,
    required this.backupType,
    required this.filePath,
    required this.fileSizeBytes,
    required this.checksum,
    required this.success,
    required this.errorMessage,
    required this.createdAt,
  });

  final String id;
  final String backupType;
  final String filePath;
  final int fileSizeBytes;
  final String? checksum;
  final bool success;
  final String? errorMessage;
  final String createdAt;

  factory BackupResultModel.fromJson(Map<String, dynamic> json) {
    return BackupResultModel(
      id: json['id'] as String? ?? '',
      backupType: json['backup_type'] as String? ?? '',
      filePath: json['file_path'] as String? ?? '',
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      checksum: json['checksum'] as String?,
      success: json['success'] == true,
      errorMessage: json['error_message'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class RestoreResultModel {
  const RestoreResultModel({
    required this.id,
    required this.backupRecordId,
    required this.success,
    required this.errorMessage,
    required this.restoredAt,
  });

  final String id;
  final String backupRecordId;
  final bool success;
  final String? errorMessage;
  final String restoredAt;

  factory RestoreResultModel.fromJson(Map<String, dynamic> json) {
    return RestoreResultModel(
      id: json['id'] as String? ?? '',
      backupRecordId: json['backup_record_id'] as String? ?? '',
      success: json['success'] == true,
      errorMessage: json['error_message'] as String?,
      restoredAt: json['restored_at'] as String? ?? '',
    );
  }
}

class CloudSyncConfigModel {
  const CloudSyncConfigModel({
    required this.id,
    required this.userId,
    required this.provider,
    required this.endpointUrl,
    required this.bucketName,
    required this.region,
    required this.rootPath,
    required this.accessKeyId,
    required this.secretEncrypted,
    required this.isActive,
    required this.lastSyncAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String provider;
  final String? endpointUrl;
  final String? bucketName;
  final String? region;
  final String? rootPath;
  final String? accessKeyId;
  final String? secretEncrypted;
  final bool isActive;
  final String? lastSyncAt;
  final String createdAt;
  final String updatedAt;

  factory CloudSyncConfigModel.fromJson(Map<String, dynamic> json) {
    return CloudSyncConfigModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      endpointUrl: json['endpoint_url'] as String?,
      bucketName: json['bucket_name'] as String?,
      region: json['region'] as String?,
      rootPath: json['root_path'] as String?,
      accessKeyId: json['access_key_id'] as String?,
      secretEncrypted: json['secret_encrypted'] as String?,
      isActive: json['is_active'] == true,
      lastSyncAt: json['last_sync_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

class RemoteBackupFileModel {
  const RemoteBackupFileModel({
    required this.filename,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final String filename;
  final int sizeBytes;
  final String modifiedAt;

  factory RemoteBackupFileModel.fromJson(Map<String, dynamic> json) {
    return RemoteBackupFileModel(
      filename: json['filename'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      modifiedAt: json['modified_at'] as String? ?? '',
    );
  }
}

class RemoteUploadResultModel {
  const RemoteUploadResultModel({
    required this.filename,
    required this.sizeBytes,
    required this.checksum,
    required this.uploadedAt,
  });

  final String filename;
  final int sizeBytes;
  final String? checksum;
  final String? uploadedAt;

  factory RemoteUploadResultModel.fromJson(Map<String, dynamic> json) {
    return RemoteUploadResultModel(
      filename: json['filename'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      checksum: json['checksum'] as String?,
      uploadedAt: json['uploaded_at'] as String?,
    );
  }
}

class RemoteDownloadResultModel {
  const RemoteDownloadResultModel({
    required this.filePath,
    required this.sizeBytes,
  });

  final String filePath;
  final int sizeBytes;

  factory RemoteDownloadResultModel.fromJson(Map<String, dynamic> json) {
    return RemoteDownloadResultModel(
      filePath: json['file_path'] as String? ?? '',
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
    );
  }
}
