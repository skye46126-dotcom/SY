import 'package:flutter/foundation.dart';
import 'dart:async';

import '../models/user_models.dart';
import '../services/app_service.dart';
import '../services/startup_trace.dart';
import '../shared/view_state.dart';

class AppRuntimeController extends ChangeNotifier {
  AppRuntimeController(this.service);

  final AppService service;
  ViewState<UserProfileModel> state = ViewState.initial();
  bool _initialized = false;
  int _recordsVersion = 0;
  final Completer<UserProfileModel> _readyCompleter =
      Completer<UserProfileModel>();

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    StartupTrace.mark('runtime.initialize');
    await refreshProfile();
  }

  Future<void> refreshProfile() async {
    state = ViewState.loading();
    notifyListeners();
    try {
      StartupTrace.mark('runtime.init_database.start');
      final profile = await service.initDatabase();
      StartupTrace.mark('runtime.init_database.ready');
      state = ViewState.ready(profile);
      if (!_readyCompleter.isCompleted) {
        _readyCompleter.complete(profile);
      }
    } on UnimplementedError {
      state = ViewState.unavailable('Rust bridge 尚未接入 init_database。');
    } catch (error) {
      state = ViewState.error(error.toString());
    }
    notifyListeners();
  }

  UserProfileModel? get profile => state.data;

  String get userId => profile?.id ?? '';

  String get timezone => profile?.timezone ?? 'Asia/Shanghai';

  String get todayDate => DateTime.now().toIso8601String().split('T').first;

  bool get isReady => state.status == ViewStatus.data && profile != null;

  int get recordsVersion => _recordsVersion;

  void markRecordsChanged() {
    _recordsVersion += 1;
    notifyListeners();
  }

  Future<UserProfileModel> waitUntilReady() async {
    final current = profile;
    if (current != null && isReady) {
      return current;
    }
    return _readyCompleter.future;
  }
}
