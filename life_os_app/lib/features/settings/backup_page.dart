import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/sync_models.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  ViewState<BackupResultModel?> _latestState = ViewState.initial();
  ViewState<List<BackupRecordModel>> _backupState = ViewState.initial();
  ViewState<List<RestoreRecordModel>> _restoreState = ViewState.initial();
  ViewState<List<RemoteBackupFileModel>> _remoteState = ViewState.initial();
  ViewState<BackupResultModel> _createState = ViewState.initial();
  ViewState<RemoteUploadResultModel> _uploadLatestState = ViewState.initial();
  bool _loaded = false;

  Future<void> _load() async {
    final service = LifeOsScope.of(context);
    final runtime = LifeOsScope.runtimeOf(context);
    setState(() {
      _latestState = ViewState.loading();
      _backupState = ViewState.loading();
      _restoreState = ViewState.loading();
      _remoteState = ViewState.loading();
    });
    try {
      final latest = await service.getLatestBackup(
        userId: runtime.userId,
        backupType: 'manual',
      );
      final backups = await service.listBackupRecords(userId: runtime.userId);
      final restores = await service.listRestoreRecords(userId: runtime.userId);
      List<RemoteBackupFileModel> remoteFiles = const [];
      try {
        remoteFiles = await service.listRemoteBackups(userId: runtime.userId);
      } catch (_) {
        remoteFiles = const [];
      }
      if (!mounted) return;
      setState(() {
        _latestState = ViewState.ready(latest);
        _backupState =
            backups.isEmpty ? ViewState.empty('暂无备份记录。') : ViewState.ready(backups);
        _restoreState = restores.isEmpty
            ? ViewState.empty('暂无恢复记录。')
            : ViewState.ready(restores);
        _remoteState = remoteFiles.isEmpty
            ? ViewState.empty('暂无远程备份或未配置云同步。')
            : ViewState.ready(remoteFiles);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _latestState = ViewState.error(error.toString());
        _backupState = ViewState.error(error.toString());
        _restoreState = ViewState.error(error.toString());
        _remoteState = ViewState.error(error.toString());
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return ModulePage(
      title: '备份与恢复',
      subtitle: 'Backup',
      actions: [
        ElevatedButton(
          onPressed: _createBackup,
          child: const Text('创建手动备份'),
        ),
        OutlinedButton(
          onPressed: _uploadLatestBackup,
          child: const Text('上传最新备份'),
        ),
        OutlinedButton(
          onPressed: _load,
          child: const Text('刷新'),
        ),
      ],
      children: [
        SectionCard(
          eyebrow: 'Latest',
          title: '最新备份状态',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              switch (_latestState.status) {
                ViewStatus.loading => const SectionLoadingView(label: '正在读取最新备份'),
                ViewStatus.data when _latestState.data != null => Text(
                    '最新备份: ${_latestState.data!.filePath}\n创建时间: ${_latestState.data!.createdAt}',
                  ),
                ViewStatus.empty => const Text('暂无最新备份'),
                _ => Text(_latestState.message ?? '暂无数据'),
              },
              if (_createState.status == ViewStatus.data) ...[
                const SizedBox(height: 12),
                Text('最近创建成功: ${_createState.data!.filePath}'),
              ],
              if (_uploadLatestState.status == ViewStatus.data) ...[
                const SizedBox(height: 12),
                Text('最近上传成功: ${_uploadLatestState.data!.filename}'),
              ],
            ],
          ),
        ),
        _SplitSection(
          left: SectionCard(
            eyebrow: 'Local',
            title: '本地备份记录',
            child: switch (_backupState.status) {
              ViewStatus.loading => const SectionLoadingView(label: '正在读取本地备份'),
              ViewStatus.data => Column(
                  children: [
                    for (final item in _backupState.data!)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(item.isSuccess ? Icons.check_circle : Icons.error_outline),
                        title: Text(item.backupType),
                        subtitle: Text(item.filePath),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'restore':
                                _restore(item.id);
                              case 'upload':
                                _upload(item.id);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'restore', child: Text('恢复')),
                            PopupMenuItem(value: 'upload', child: Text('上传云端')),
                          ],
                        ),
                      ),
                  ],
                ),
              _ => SectionMessageView(
                  icon: Icons.backup_outlined,
                  title: '本地备份暂不可用',
                  description: _backupState.message ?? '请稍后重试。',
                ),
            },
          ),
          right: SectionCard(
            eyebrow: 'Remote',
            title: '远程备份列表',
            child: switch (_remoteState.status) {
              ViewStatus.loading => const SectionLoadingView(label: '正在读取远程备份'),
              ViewStatus.data => Column(
                  children: [
                    for (final item in _remoteState.data!)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.filename),
                        subtitle: Text('${item.modifiedAt} · ${item.sizeBytes} bytes'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'download':
                                _download(item.filename);
                              case 'download_restore':
                                _downloadAndRestore(item.filename);
                              case 'delete':
                                _deleteRemote(item.filename);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'download', child: Text('只下载')),
                            PopupMenuItem(value: 'download_restore', child: Text('下载并恢复')),
                            PopupMenuItem(value: 'delete', child: Text('删除远程')),
                          ],
                        ),
                      ),
                  ],
                ),
              _ => SectionMessageView(
                  icon: Icons.cloud_outlined,
                  title: '远程备份暂不可用',
                  description: _remoteState.message ?? '请检查云同步配置。',
                ),
            },
          ),
        ),
        SectionCard(
          eyebrow: 'Restore',
          title: '恢复记录',
          child: switch (_restoreState.status) {
            ViewStatus.loading => const SectionLoadingView(label: '正在读取恢复记录'),
            ViewStatus.data => Column(
                children: [
                  for (final item in _restoreState.data!)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(item.isSuccess ? Icons.history_toggle_off : Icons.error_outline),
                      title: Text(item.status),
                      subtitle: Text(item.backupRecordId ?? '无备份记录 ID'),
                      trailing: Text(item.restoredAt),
                    ),
                ],
              ),
            _ => SectionMessageView(
                icon: Icons.history_rounded,
                title: '恢复记录暂不可用',
                description: _restoreState.message ?? '请稍后重试。',
              ),
          },
        ),
      ],
    );
  }

  Future<void> _createBackup() async {
    setState(() => _createState = ViewState.loading());
    try {
      final runtime = LifeOsScope.runtimeOf(context);
      final result = await LifeOsScope.of(context).createBackup(
        userId: runtime.userId,
        backupType: 'manual',
      );
      if (!mounted) return;
      setState(() => _createState = ViewState.ready(result));
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _createState = ViewState.error(error.toString()));
    }
  }

  Future<void> _uploadLatestBackup() async {
    setState(() => _uploadLatestState = ViewState.loading());
    try {
      final runtime = LifeOsScope.runtimeOf(context);
      final result = await LifeOsScope.of(context).uploadLatestBackupToCloud(
        userId: runtime.userId,
        backupType: 'manual',
      );
      if (!mounted) return;
      setState(() => _uploadLatestState = ViewState.ready(result));
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploadLatestState = ViewState.error(error.toString()));
    }
  }

  Future<void> _restore(String backupRecordId) async {
    final runtime = LifeOsScope.runtimeOf(context);
    await LifeOsScope.of(context).restoreFromBackupRecord(
      userId: runtime.userId,
      backupRecordId: backupRecordId,
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _upload(String backupRecordId) async {
    final runtime = LifeOsScope.runtimeOf(context);
    await LifeOsScope.of(context).uploadBackupToCloud(
      userId: runtime.userId,
      backupRecordId: backupRecordId,
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _download(String filename) async {
    final runtime = LifeOsScope.runtimeOf(context);
    await LifeOsScope.of(context).downloadBackupFromCloud(
      userId: runtime.userId,
      filename: filename,
      backupType: 'manual',
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _downloadAndRestore(String filename) async {
    final runtime = LifeOsScope.runtimeOf(context);
    await LifeOsScope.of(context).downloadAndRestoreFromCloud(
      userId: runtime.userId,
      filename: filename,
      backupType: 'manual',
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _deleteRemote(String filename) async {
    final runtime = LifeOsScope.runtimeOf(context);
    await LifeOsScope.of(context).deleteRemoteBackup(
      userId: runtime.userId,
      filename: filename,
    );
    if (!mounted) return;
    await _load();
  }
}

class _SplitSection extends StatelessWidget {
  const _SplitSection({
    required this.left,
    required this.right,
  });

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 960) {
          return Column(
            children: [
              left,
              const SizedBox(height: 20),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 20),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}
