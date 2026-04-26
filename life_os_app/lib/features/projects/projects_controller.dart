import 'package:flutter/foundation.dart';

import '../../models/project_models.dart';
import '../../services/app_service.dart';
import '../../shared/view_state.dart';

class ProjectsController extends ChangeNotifier {
  ProjectsController(this._service);

  final AppService _service;

  String? statusCode;
  ViewState<List<ProjectOverview>> state = ViewState.initial();

  Future<void> load({
    required String userId,
  }) async {
    state = ViewState.loading();
    notifyListeners();

    try {
      final projects = await _service.getProjects(
        userId: userId,
        statusCode: statusCode,
      );
      if (projects.isEmpty) {
        state = ViewState.empty('当前筛选下没有项目。');
      } else {
        state = ViewState.ready(projects);
      }
    } on UnimplementedError {
      state = ViewState.unavailable('项目查询接口尚未接入 Rust。');
    } catch (error) {
      state = ViewState.error(error.toString());
    }
    notifyListeners();
  }

  Future<void> changeStatus(String? nextStatus, String userId) async {
    statusCode = nextStatus;
    await load(userId: userId);
  }
}
