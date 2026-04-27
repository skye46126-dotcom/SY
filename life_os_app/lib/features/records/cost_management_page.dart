import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/config_models.dart';
import '../../models/cost_models.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';

class CostManagementPage extends StatefulWidget {
  const CostManagementPage({super.key});

  @override
  State<CostManagementPage> createState() => _CostManagementPageState();
}

class _CostManagementPageState extends State<CostManagementPage> {
  ViewState<MonthlyCostBaselineModel> _baselineState = ViewState.initial();
  ViewState<List<RecurringCostRuleModel>> _recurringState = ViewState.initial();
  ViewState<List<CapexCostModel>> _capexState = ViewState.initial();
  ViewState<RateComparisonSummaryModel> _rateState = ViewState.initial();
  List<DimensionOptionModel> _expenseCategoryOptions = const [];
  String? _selectedMonth;
  String _rateWindowType = 'month';
  bool _loaded = false;

  Future<void> _load() async {
    final runtime = LifeOsScope.runtimeOf(context);
    final month = _selectedMonth ?? runtime.todayDate.substring(0, 7);
    setState(() {
      _baselineState = ViewState.loading();
      _recurringState = ViewState.loading();
      _capexState = ViewState.loading();
      _rateState = ViewState.loading();
    });
    try {
      final service = LifeOsScope.of(context);
      final baseline = await service.getMonthlyBaseline(
        userId: runtime.userId,
        month: month,
      );
      final recurring = await service.listRecurringCostRules(userId: runtime.userId);
      final capex = await service.listCapexCosts(userId: runtime.userId);
      final expenseCategories = await service.invokeRaw(
        method: 'list_dimension_options',
        payload: {
          'user_id': runtime.userId,
          'kind': 'expense_category',
          'include_inactive': false,
        },
      );
      final rate = await service.getRateComparison(
        userId: runtime.userId,
        anchorDate: runtime.todayDate,
        windowType: _rateWindowType,
      );
      setState(() {
        _baselineState = ViewState.ready(baseline);
        _recurringState = ViewState.ready(recurring);
        _capexState = ViewState.ready(capex);
        _rateState = ViewState.ready(rate);
        _expenseCategoryOptions = ((expenseCategories as List?) ?? const [])
            .whereType<Map>()
            .map((item) => DimensionOptionModel.fromJson(item.cast<String, dynamic>()))
            .toList();
      });
    } catch (error) {
      setState(() {
        _baselineState = ViewState.error(error.toString());
        _recurringState = ViewState.error(error.toString());
        _capexState = ViewState.error(error.toString());
        _rateState = ViewState.error(error.toString());
      });
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
    final month = _selectedMonth ?? runtime.todayDate.substring(0, 7);
    final activeRecurring = (_recurringState.data ?? const [])
        .where((item) => item.isActive)
        .toList();
    final inactiveRecurring = (_recurringState.data ?? const [])
        .where((item) => !item.isActive)
        .toList();
    final activeCapex =
        (_capexState.data ?? const []).where((item) => item.isActive).toList();
    final inactiveCapex =
        (_capexState.data ?? const []).where((item) => !item.isActive).toList();
    return ModulePage(
      title: '成本管理',
      subtitle: 'Cost Management',
      actions: [
        OutlinedButton(
          onPressed: _previousMonth,
          child: const Text('上月'),
        ),
        OutlinedButton(
          onPressed: _nextMonth,
          child: const Text('下月'),
        ),
        ElevatedButton(
          onPressed: _editBaseline,
          child: const Text('编辑月基线'),
        ),
        OutlinedButton(
          onPressed: _createRecurringRule,
          child: const Text('新增周期规则'),
        ),
        OutlinedButton(
          onPressed: _createCapex,
          child: const Text('新增 CAPEX'),
        ),
      ],
      children: [
        SectionCard(
          eyebrow: 'Month',
          title: '成本分析窗口',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前月份: $month'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final value in const ['month', 'year'])
                    ChoiceChip(
                      label: Text(value == 'month' ? '月窗口' : '年窗口'),
                      selected: _rateWindowType == value,
                      onSelected: (_) {
                        setState(() => _rateWindowType = value);
                        _load();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          eyebrow: 'Cost',
          title: '月基线与时薪比较',
          child: switch (_baselineState.status) {
            ViewStatus.loading => const SectionLoadingView(label: '正在读取成本概览'),
            ViewStatus.data => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '基础生活: ¥${(_baselineState.data!.basicLivingCents / 100).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '固定订阅: ¥${(_baselineState.data!.fixedSubscriptionCents / 100).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '合计基线: ¥${((_baselineState.data!.basicLivingCents + _baselineState.data!.fixedSubscriptionCents) / 100).toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_rateState.hasData) ...[
                    const SizedBox(height: 12),
                    Text(
                      '理想时薪: ¥${(_rateState.data!.idealHourlyRateCents / 100).toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '本期实际时薪: ${_rateState.data!.actualHourlyRateCents == null ? '暂无数据' : '¥${(_rateState.data!.actualHourlyRateCents! / 100).toStringAsFixed(2)}'}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '上年平均时薪: ${_rateState.data!.previousYearAverageHourlyRateCents == null ? '暂无数据' : '¥${(_rateState.data!.previousYearAverageHourlyRateCents! / 100).toStringAsFixed(2)}'}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '本期工作时长: ${_rateState.data!.currentWorkMinutes} 分钟 · 本期收入: ¥${(_rateState.data!.currentIncomeCents / 100).toStringAsFixed(2)}',
                    ),
                  ],
                ],
              ),
            _ => SectionMessageView(
                icon: Icons.pie_chart_outline_rounded,
                title: '成本数据暂不可用',
                description: _baselineState.message ?? '请稍后重试。',
              ),
          },
        ),
        SectionCard(
          eyebrow: 'Recurring',
          title: '周期性成本规则 · 活跃',
          child: switch (_recurringState.status) {
            ViewStatus.data => Column(
                children: [
                  for (final item in activeRecurring)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.categoryCode} · ${item.startMonth}${item.endMonth == null ? '' : ' - ${item.endMonth}'} · ${item.isNecessary ? '必要' : '非必要'}',
                      ),
                      trailing: Text(
                        '¥${(item.monthlyAmountCents / 100).toStringAsFixed(2)}',
                      ),
                      onTap: () => _editRecurringRule(item),
                      onLongPress: () => _deleteRecurringRule(item.id),
                    ),
                ],
              ),
            ViewStatus.loading => const SectionLoadingView(label: '正在读取周期规则'),
            _ => SectionMessageView(
                icon: Icons.repeat_rounded,
                title: '周期规则暂不可用',
                description: _recurringState.message ?? '请稍后重试。',
              ),
          },
        ),
        if (_recurringState.hasData && inactiveRecurring.isNotEmpty)
          SectionCard(
            eyebrow: 'Recurring',
            title: '周期性成本规则 · 非活跃',
            child: Column(
              children: [
                for (final item in inactiveRecurring)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    subtitle: Text(item.categoryCode),
                    trailing: Text(
                      '¥${(item.monthlyAmountCents / 100).toStringAsFixed(2)}',
                    ),
                    onTap: () => _editRecurringRule(item),
                    onLongPress: () => _deleteRecurringRule(item.id),
                  ),
              ],
            ),
          ),
        SectionCard(
          eyebrow: 'CAPEX',
          title: '资本性支出 · 活跃',
          child: switch (_capexState.status) {
            ViewStatus.data => Column(
                children: [
                  for (final item in activeCapex)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.purchaseDate} · 摊销 ${item.monthlyAmortizedCents / 100} / 月 · ${item.amortizationStartMonth} - ${item.amortizationEndMonth}',
                      ),
                      trailing: Text(
                        '¥${(item.purchaseAmountCents / 100).toStringAsFixed(2)}',
                      ),
                      onTap: () => _editCapex(item),
                      onLongPress: () => _deleteCapex(item.id),
                    ),
                ],
              ),
            ViewStatus.loading => const SectionLoadingView(label: '正在读取 CAPEX'),
            _ => SectionMessageView(
                icon: Icons.memory_rounded,
                title: 'CAPEX 暂不可用',
                description: _capexState.message ?? '请稍后重试。',
              ),
          },
        ),
        if (_capexState.hasData && inactiveCapex.isNotEmpty)
          SectionCard(
            eyebrow: 'CAPEX',
            title: '资本性支出 · 非活跃',
            child: Column(
              children: [
                for (final item in inactiveCapex)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    subtitle: Text(item.purchaseDate),
                    trailing: Text(
                      '¥${(item.purchaseAmountCents / 100).toStringAsFixed(2)}',
                    ),
                    onTap: () => _editCapex(item),
                    onLongPress: () => _deleteCapex(item.id),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _previousMonth() {
    final base = DateTime.parse('${_selectedMonth ?? LifeOsScope.runtimeOf(context).todayDate.substring(0, 7)}-01');
    final previous = DateTime(base.year, base.month - 1, 1);
    setState(() => _selectedMonth = '${previous.year}-${previous.month.toString().padLeft(2, '0')}');
    _load();
  }

  void _nextMonth() {
    final base = DateTime.parse('${_selectedMonth ?? LifeOsScope.runtimeOf(context).todayDate.substring(0, 7)}-01');
    final next = DateTime(base.year, base.month + 1, 1);
    setState(() => _selectedMonth = '${next.year}-${next.month.toString().padLeft(2, '0')}');
    _load();
  }

  Future<void> _editBaseline() async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    final current = _baselineState.data;
    final basic = TextEditingController(
      text: current == null ? '' : (current.basicLivingCents / 100).toStringAsFixed(2),
    );
    final fixed = TextEditingController(
      text: current == null ? '' : (current.fixedSubscriptionCents / 100).toStringAsFixed(2),
    );
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('编辑月基线'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: basic, decoration: const InputDecoration(labelText: '基础生活(元)')),
                TextField(controller: fixed, decoration: const InputDecoration(labelText: '固定订阅(元)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
          ],
        ),
      );
      if (confirmed != true) return;
      await service.invokeRaw(
        method: 'upsert_monthly_baseline',
        payload: {
          'user_id': runtime.userId,
          'input': {
            'month': _selectedMonth ?? runtime.todayDate.substring(0, 7),
            'basic_living_cents': (double.parse(basic.text) * 100).round(),
            'fixed_subscription_cents': (double.parse(fixed.text) * 100).round(),
            'note': null,
          },
        },
      );
      if (!mounted) return;
      await _load();
    } finally {
      basic.dispose();
      fixed.dispose();
    }
  }

  Future<void> _createRecurringRule() => _openRecurringRuleDialog();

  Future<void> _editRecurringRule(RecurringCostRuleModel item) =>
      _openRecurringRuleDialog(existing: item);

  Future<void> _openRecurringRuleDialog({RecurringCostRuleModel? existing}) async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    final name = TextEditingController(text: existing?.name ?? '');
    String selectedCategory = existing?.categoryCode ?? 'necessary';
    final amount = TextEditingController(
      text: existing == null ? '' : (existing.monthlyAmountCents / 100).toStringAsFixed(2),
    );
    final startMonth = TextEditingController(
      text: existing?.startMonth ?? runtime.todayDate.substring(0, 7),
    );
    final endMonth = TextEditingController(text: existing?.endMonth ?? '');
    final necessary = ValueNotifier<bool>(existing?.isNecessary ?? true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(existing == null ? '新增周期规则' : '编辑周期规则'),
          content: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: '名称')),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('类别'),
                    subtitle: Text(
                      _expenseCategoryOptions
                              .where((item) => item.code == selectedCategory)
                              .map((item) => item.displayName)
                              .cast<String?>()
                              .firstWhere((item) => item != null, orElse: () => '请选择') ??
                          '请选择',
                    ),
                    trailing: const Icon(Icons.arrow_drop_down_rounded),
                    onTap: () async {
                      final selected = await showModalBottomSheet<String>(
                        context: context,
                        builder: (context) => SafeArea(
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (final item in _expenseCategoryOptions)
                                ListTile(
                                  title: Text(item.displayName),
                                  subtitle: Text(item.code),
                                  trailing: item.code == selectedCategory
                                      ? const Icon(Icons.check_rounded)
                                      : null,
                                  onTap: () => Navigator.of(context).pop(item.code),
                                ),
                            ],
                          ),
                        ),
                      );
                      if (selected != null) {
                        selectedCategory = selected;
                        setState(() {});
                      }
                    },
                  ),
                  TextField(controller: amount, decoration: const InputDecoration(labelText: '金额(元)')),
                  TextField(controller: startMonth, decoration: const InputDecoration(labelText: '开始月份 YYYY-MM')),
                  TextField(controller: endMonth, decoration: const InputDecoration(labelText: '结束月份 YYYY-MM')),
                  SwitchListTile(
                    value: necessary.value,
                    onChanged: (value) {
                      necessary.value = value;
                      setState(() {});
                    },
                    title: const Text('必要支出'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
          ],
        ),
      );
      if (confirmed != true) return;
      await service.invokeRaw(
        method: existing == null ? 'create_recurring_cost_rule' : 'update_recurring_cost_rule',
        payload: {
          'user_id': runtime.userId,
          if (existing != null) 'rule_id': existing.id,
          'input': {
            'name': name.text,
            'category_code': selectedCategory,
            'monthly_amount_cents': (double.parse(amount.text) * 100).round(),
            'is_necessary': necessary.value,
            'start_month': startMonth.text,
            'end_month': endMonth.text.isEmpty ? null : endMonth.text,
            'note': null,
          },
        },
      );
      if (!mounted) return;
      await _load();
    } finally {
      name.dispose();
      amount.dispose();
      startMonth.dispose();
      endMonth.dispose();
      necessary.dispose();
    }
  }

  Future<void> _deleteRecurringRule(String id) async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    await service.invokeRaw(
      method: 'delete_recurring_cost_rule',
      payload: {'user_id': runtime.userId, 'rule_id': id},
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _createCapex() => _openCapexDialog();

  Future<void> _editCapex(CapexCostModel item) => _openCapexDialog(existing: item);

  Future<void> _openCapexDialog({CapexCostModel? existing}) async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    final name = TextEditingController(text: existing?.name ?? '');
    final date = TextEditingController(text: existing?.purchaseDate ?? runtime.todayDate);
    final amount = TextEditingController(
      text: existing == null ? '' : (existing.purchaseAmountCents / 100).toStringAsFixed(2),
    );
    final usefulMonths = TextEditingController(text: '${existing?.usefulMonths ?? 12}');
    final residual = TextEditingController(
      text: ((existing?.residualRateBps ?? 0) / 100).toStringAsFixed(2),
    );
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(existing == null ? '新增 CAPEX' : '编辑 CAPEX'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: '名称')),
                TextField(controller: date, decoration: const InputDecoration(labelText: '购买日期 YYYY-MM-DD')),
                TextField(controller: amount, decoration: const InputDecoration(labelText: '金额(元)')),
                TextField(controller: usefulMonths, decoration: const InputDecoration(labelText: '使用月数')),
                TextField(
                  controller: residual,
                  decoration: const InputDecoration(
                    labelText: '残值率(%)',
                    helperText: '例如 20 表示残值率为 20%。',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
          ],
        ),
      );
      if (confirmed != true) return;
      await service.invokeRaw(
        method: existing == null ? 'create_capex_cost' : 'update_capex_cost',
        payload: {
          'user_id': runtime.userId,
          if (existing != null) 'capex_id': existing.id,
          'input': {
            'name': name.text,
            'purchase_date': date.text,
            'purchase_amount_cents': (double.parse(amount.text) * 100).round(),
            'useful_months': int.parse(usefulMonths.text),
            'residual_rate_bps': (double.parse(residual.text) * 100).round(),
            'note': null,
          },
        },
      );
      if (!mounted) return;
      await _load();
    } finally {
      name.dispose();
      date.dispose();
      amount.dispose();
      usefulMonths.dispose();
      residual.dispose();
    }
  }

  Future<void> _deleteCapex(String id) async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    await service.invokeRaw(
      method: 'delete_capex_cost',
      payload: {'user_id': runtime.userId, 'capex_id': id},
    );
    if (!mounted) return;
    await _load();
  }
}
