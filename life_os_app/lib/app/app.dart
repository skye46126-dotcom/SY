import 'package:flutter/material.dart';

import '../features/today/today_page.dart';
import '../shared/view_state.dart';
import '../shared/widgets/module_page.dart';
import '../shared/widgets/state_views.dart';
import '../services/native_rust_api.dart';
import '../services/app_service.dart';
import '../services/rust_api.dart';
import 'router.dart';
import 'app_runtime.dart';
import 'shell_scaffold.dart';
import 'theme.dart';

class LifeOsScope extends InheritedWidget {
  const LifeOsScope({
    super.key,
    required this.service,
    required this.runtime,
    required super.child,
  });

  final AppService service;
  final AppRuntimeController runtime;

  static AppService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LifeOsScope>();
    assert(scope != null, 'LifeOsScope is missing above this context.');
    return scope!.service;
  }

  static AppRuntimeController runtimeOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LifeOsScope>();
    assert(scope != null, 'LifeOsScope is missing above this context.');
    return scope!.runtime;
  }

  @override
  bool updateShouldNotify(LifeOsScope oldWidget) {
    return service != oldWidget.service || runtime != oldWidget.runtime;
  }
}

class LifeOsApp extends StatefulWidget {
  const LifeOsApp({
    super.key,
    this.databasePath = 'life_os.db',
    this.api,
  });

  final String databasePath;
  final RustApi? api;

  @override
  State<LifeOsApp> createState() => _LifeOsAppState();
}

class _LifeOsAppState extends State<LifeOsApp> {
  late final AppService _service;
  late final AppRuntimeController _runtime;

  @override
  void initState() {
    super.initState();
    _service = AppService(
      api: widget.api ??
          NativeRustApi.createOrFallback(
            databasePath: widget.databasePath,
          ),
    );
    _runtime = AppRuntimeController(_service);
    _runtime.initialize();
  }

  @override
  void dispose() {
    _runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LifeOsScope(
      service: _service,
      runtime: _runtime,
      child: AnimatedBuilder(
        animation: _runtime,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'SkyeOS',
            theme: AppTheme.light(),
            home: _RootGate(runtime: _runtime),
            onGenerateRoute: AppRouter.onGenerateRoute,
          );
        },
      ),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate({
    required this.runtime,
  });

  final AppRuntimeController runtime;

  @override
  Widget build(BuildContext context) {
    switch (runtime.state.status) {
      case ViewStatus.loading:
      case ViewStatus.initial:
        return const Scaffold(
          body: Center(
            child: SectionLoadingView(label: '正在初始化数据库与用户会话'),
          ),
        );
      case ViewStatus.error:
      case ViewStatus.unavailable:
      case ViewStatus.empty:
        return Scaffold(
          body: ModulePage(
            title: '初始化失败',
            subtitle: 'Startup',
            children: [
              SectionMessageView(
                icon: Icons.error_outline_rounded,
                title: '应用启动未完成',
                description: runtime.state.message ?? '请检查数据库与原生桥接状态。',
              ),
            ],
          ),
        );
      case ViewStatus.data:
        return const ShellScaffold(
          destination: AppDestination.today,
          child: TodayPage(),
        );
    }
  }
}
