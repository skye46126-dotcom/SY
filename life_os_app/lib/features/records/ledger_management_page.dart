import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/record_models.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';

class LedgerManagementPage extends StatefulWidget {
  const LedgerManagementPage({
    super.key,
    required this.recordType,
  });

  final String recordType;

  @override
  State<LedgerManagementPage> createState() => _LedgerManagementPageState();
}

class _LedgerManagementPageState extends State<LedgerManagementPage> {
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
      final kind = widget.recordType == 'income' ? RecordKind.income : RecordKind.expense;
      final filtered = records.where((item) => item.kind == kind).toList();
      if (!mounted) return;
      setState(() {
        _state = filtered.isEmpty
            ? ViewState.empty('今天还没有${widget.recordType == 'income' ? '收入' : '支出'}记录。')
            : ViewState.ready(filtered);
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
    return ModulePage(
      title: '${widget.recordType == 'income' ? '收入' : '支出'}流水管理',
      subtitle: 'Ledger',
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pushNamed('/capture'),
          child: const Text('新增记录'),
        ),
      ],
      children: [
        SectionCard(
          eyebrow: 'Ledger',
          title: '流水列表与筛选',
          child: switch (_state.status) {
            ViewStatus.loading => const SectionLoadingView(label: '正在读取流水'),
            ViewStatus.data => Column(
                children: [
                  for (final record in _state.data!)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(record.title),
                      subtitle: Text(record.detail),
                      trailing: Text(record.occurredAt),
                    ),
                ],
              ),
            _ => SectionMessageView(
                icon: Icons.account_balance_wallet_outlined,
                title: '流水数据暂不可用',
                description: _state.message ?? '请稍后重试。',
              ),
          },
        ),
      ],
    );
  }
}
