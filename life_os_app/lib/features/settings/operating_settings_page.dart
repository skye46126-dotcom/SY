import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/config_models.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';

class OperatingSettingsPage extends StatefulWidget {
  const OperatingSettingsPage({super.key});

  @override
  State<OperatingSettingsPage> createState() => _OperatingSettingsPageState();
}

class _OperatingSettingsPageState extends State<OperatingSettingsPage> {
  ViewState<OperatingSettingsModel> _state = ViewState.initial();
  ViewState<String> _saveState = ViewState.initial();
  final _timezone = TextEditingController();
  final _currency = TextEditingController();
  final _idealHourlyRate = TextEditingController();
  final _workTarget = TextEditingController();
  final _learningTarget = TextEditingController();
  final _basicLiving = TextEditingController();
  final _fixedSubscription = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _timezone.dispose();
    _currency.dispose();
    _idealHourlyRate.dispose();
    _workTarget.dispose();
    _learningTarget.dispose();
    _basicLiving.dispose();
    _fixedSubscription.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _state = ViewState.loading();
    });
    try {
      final runtime = LifeOsScope.runtimeOf(context);
      final data = await LifeOsScope.of(context).invokeRaw(
        method: 'get_operating_settings',
        payload: {'user_id': runtime.userId},
      );
      final settings =
          OperatingSettingsModel.fromJson((data as Map).cast<String, dynamic>());
      _timezone.text = settings.timezone;
      _currency.text = settings.currencyCode;
      _idealHourlyRate.text =
          (settings.idealHourlyRateCents / 100).toStringAsFixed(2);
      _workTarget.text = settings.todayWorkTargetMinutes.toString();
      _learningTarget.text = settings.todayLearningTargetMinutes.toString();
      _basicLiving.text =
          (settings.currentMonthBasicLivingCents / 100).toStringAsFixed(2);
      _fixedSubscription.text =
          (settings.currentMonthFixedSubscriptionCents / 100).toStringAsFixed(2);
      if (!mounted) {
        return;
      }
      setState(() => _state = ViewState.ready(settings));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _state = ViewState.error(error.toString()));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final settings = _state.data;
    return ModulePage(
      title: '经营参数',
      subtitle: 'Operating Settings',
      actions: [
        OutlinedButton(
          onPressed: _load,
          child: const Text('刷新'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('保存参数'),
        ),
      ],
      children: [
        SectionCard(
          eyebrow: 'Operating',
          title: '长期经营参数',
          child: switch (_state.status) {
            ViewStatus.loading => const SectionLoadingView(label: '正在读取经营参数'),
            ViewStatus.data => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _idealHourlyRate,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: '理想时薪',
                      suffixText: '元/小时',
                      helperText: '长期参考标准，用于时间债、项目时间成本等计算。',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _workTarget,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '每日工作目标',
                      suffixText: '分钟',
                      helperText: 'Today 页面会用它判断工作目标是否达标。',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _learningTarget,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '每日学习目标',
                      suffixText: '分钟',
                      helperText: 'Today 页面会用它判断学习目标是否达标。',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AutocompleteTextField(
                    controller: _timezone,
                    suggestions: _commonTimezones,
                    labelText: '时区',
                    helperText: '例如 Asia/Shanghai。影响时间换算和日界线。',
                  ),
                  const SizedBox(height: 12),
                  _AutocompleteTextField(
                    controller: _currency,
                    suggestions: _commonCurrencies,
                    labelText: '币种',
                    helperText: '使用 3 位 ISO 货币代码，例如 CNY、USD。',
                    uppercase: true,
                  ),
                ],
              ),
            _ => SectionMessageView(
                icon: Icons.tune_rounded,
                title: '经营参数暂不可用',
                description: _state.message ?? '请稍后重试。',
              ),
          },
        ),
        SectionCard(
          eyebrow: 'Cost',
          title: '本月固定成本摘要',
          child: switch (_state.status) {
            ViewStatus.data => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('月份: ${settings!.currentMonth}'),
                  const SizedBox(height: 8),
                  Text(
                    '基础生活: ¥${(settings.currentMonthBasicLivingCents / 100).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _basicLiving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '${settings.currentMonth} 基础生活',
                      suffixText: '元',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '固定订阅: ¥${(settings.currentMonthFixedSubscriptionCents / 100).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _fixedSubscription,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: '${settings.currentMonth} 固定订阅',
                      suffixText: '元',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '合计基线: ¥${((settings.currentMonthBasicLivingCents + settings.currentMonthFixedSubscriptionCents) / 100).toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/cost-management'),
                    child: const Text('前往成本管理'),
                  ),
                ],
              ),
            ViewStatus.loading => const SectionLoadingView(label: '正在读取成本摘要'),
            _ => SectionMessageView(
                icon: Icons.pie_chart_outline_rounded,
                title: '成本摘要暂不可用',
                description: _state.message ?? '请稍后重试。',
              ),
          },
        ),
        if (_saveState.status == ViewStatus.loading)
          const SectionCard(
            eyebrow: 'Save',
            title: '正在保存',
            child: SectionLoadingView(label: '正在更新经营参数'),
          ),
        if (_saveState.status == ViewStatus.error)
          SectionCard(
            eyebrow: 'Save',
            title: '保存失败',
            child: SectionMessageView(
              icon: Icons.error_outline_rounded,
              title: '经营参数未保存',
              description: _saveState.message ?? '请检查输入后重试。',
            ),
          ),
        if (_saveState.status == ViewStatus.data)
          SectionCard(
            eyebrow: 'Save',
            title: '保存成功',
            child: SectionMessageView(
              icon: Icons.check_circle_outline_rounded,
              title: '经营参数已更新',
              description: _saveState.data ?? '新的参数已经生效。',
            ),
          ),
      ],
    );
  }

  Future<void> _save() async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    setState(() => _saveState = ViewState.loading());
    try {
      await service.invokeRaw(
        method: 'update_operating_settings',
        payload: {
          'user_id': runtime.userId,
          'input': {
            'timezone': _timezone.text,
            'currency_code': _currency.text,
            'ideal_hourly_rate_cents':
                (double.parse(_idealHourlyRate.text) * 100).round(),
            'today_work_target_minutes': int.parse(_workTarget.text),
            'today_learning_target_minutes': int.parse(_learningTarget.text),
          },
        },
      );
      await service.invokeRaw(
        method: 'upsert_monthly_baseline',
        payload: {
          'user_id': runtime.userId,
          'input': {
            'month': _state.data?.currentMonth ?? runtime.todayDate.substring(0, 7),
            'basic_living_cents': (double.parse(_basicLiving.text) * 100).round(),
            'fixed_subscription_cents':
                (double.parse(_fixedSubscription.text) * 100).round(),
            'note': null,
          },
        },
      );
      await runtime.refreshProfile();
      if (!mounted) {
        return;
      }
      setState(() => _saveState = ViewState.ready('新的经营参数已经保存。'));
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saveState = ViewState.error(error.toString()));
    }
  }
}

class _AutocompleteTextField extends StatelessWidget {
  const _AutocompleteTextField({
    required this.controller,
    required this.suggestions,
    required this.labelText,
    required this.helperText,
    this.uppercase = false,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final String labelText;
  final String helperText;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) {
          return suggestions;
        }
        return suggestions.where((item) => item.toLowerCase().contains(query));
      },
      onSelected: (selection) {
        controller.text = uppercase ? selection.toUpperCase() : selection;
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        textController.value = controller.value;
        textController.addListener(() {
          controller.value = uppercase
              ? textController.value.copyWith(
                  text: textController.text.toUpperCase(),
                  selection: textController.selection,
                )
              : textController.value;
        });
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          textCapitalization:
              uppercase ? TextCapitalization.characters : TextCapitalization.none,
          decoration: InputDecoration(
            labelText: labelText,
            helperText: helperText,
          ),
        );
      },
    );
  }
}

const List<String> _commonTimezones = [
  'Asia/Shanghai',
  'Asia/Tokyo',
  'Asia/Singapore',
  'Europe/London',
  'Europe/Berlin',
  'America/Los_Angeles',
  'America/New_York',
];

const List<String> _commonCurrencies = [
  'CNY',
  'USD',
  'EUR',
  'JPY',
  'SGD',
  'GBP',
];
