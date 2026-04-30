import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/record_models.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';

class TimeManagementPage extends StatefulWidget {
  const TimeManagementPage({super.key});

  @override
  State<TimeManagementPage> createState() => _TimeManagementPageState();
}

class _TimeManagementPageState extends State<TimeManagementPage> {
  ViewState<List<RecentRecordItem>> _state = ViewState.initial();
  bool _loaded = false;

  Future<void> _load() async {
    setState(() => _state = ViewState.loading());
    try {
      final runtime = LifeOsScope.runtimeOf(context);
      final records = await LifeOsScope.of(context).getRecordsForDate(
        userId: runtime.userId,
        date: runtime.todayDate,
        timezone: runtime.timezone,
      );
      final timeRecords =
          records.where((item) => item.kind == RecordKind.time).toList();
      if (!mounted) return;
      setState(() {
        _state = timeRecords.isEmpty
            ? ViewState.empty('今天还没有时间记录。')
            : ViewState.ready(timeRecords);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _state = ViewState.error(error.toString()));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final runtime = LifeOsScope.runtimeOf(context);
    return ModulePage(
      title: '时间记录管理',
      subtitle: 'Time Management',
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pushNamed('/review'),
          child: const Text('打开复盘'),
        ),
      ],
      children: [
        SectionCard(
          eyebrow: 'Calendar',
          title: '按日浏览时间记录',
          child: switch (_state.status) {
            ViewStatus.loading => const SectionLoadingView(label: '正在读取时间记录'),
            ViewStatus.data => Column(
                children: [
                  for (final record in _state.data!)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(record.title),
                      subtitle: Text(record.detail),
                      trailing: Text(record.occurredAt),
                      onTap: () => Navigator.of(context)
                          .pushNamed('/day/${runtime.todayDate}'),
                    ),
                ],
              ),
            _ => SectionMessageView(
                icon: Icons.schedule_rounded,
                title: '时间记录暂不可用',
                description: _state.message ?? '请稍后重试。',
              ),
          },
        ),
      ],
    );
  }
}
