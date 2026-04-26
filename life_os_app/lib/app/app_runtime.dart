import 'package:flutter/foundation.dart';

import '../models/user_models.dart';
import '../services/app_service.dart';
import '../shared/view_state.dart';

class AppRuntimeController extends ChangeNotifier {
  AppRuntimeController(this.service);

  final AppService service;
  ViewState<UserProfileModel> state = ViewState.initial();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await refreshProfile();
  }

  Future<void> refreshProfile() async {
    state = ViewState.loading();
    notifyListeners();
    try {
      final profile = await service.initDatabase();
      state = ViewState.ready(profile);
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
}
