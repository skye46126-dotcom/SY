import 'package:flutter/material.dart';

import '../features/capture/capture_page.dart';
import '../features/management/management_page.dart';
import '../features/projects/project_detail_page.dart';
import '../features/projects/projects_page.dart';
import '../features/records/cost_management_page.dart';
import '../features/records/ledger_management_page.dart';
import '../features/records/time_management_page.dart';
import '../features/review/ai_chat_page.dart';
import '../features/review/day_detail_page.dart';
import '../features/review/review_page.dart';
import '../features/settings/backup_page.dart';
import '../features/settings/ai_service_configs_page.dart';
import '../features/settings/cloud_sync_configs_page.dart';
import '../features/settings/dimension_manage_page.dart';
import '../features/settings/operating_settings_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/tag_manage_page.dart';
import '../features/today/today_page.dart';
import 'shell_scaffold.dart';

enum AppDestination {
  today('/today', '今日', Icons.stacked_line_chart_rounded),
  capture('/capture', '记录', Icons.edit_note_rounded),
  management('/management', '管理', Icons.grid_view_rounded),
  review('/review', '复盘', Icons.auto_graph_rounded);

  const AppDestination(this.route, this.label, this.icon);

  final String route;
  final String label;
  final IconData icon;
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final name = settings.name ?? AppDestination.today.route;
    final uri = Uri.parse(name);

    if (name == AppDestination.today.route) {
      return _page(
        settings,
        const ShellScaffold(
          destination: AppDestination.today,
          child: TodayPage(),
        ),
      );
    }

    if (name == AppDestination.capture.route) {
      return _page(
        settings,
        const ShellScaffold(
          destination: AppDestination.capture,
          child: CapturePage(),
        ),
      );
    }

    if (name == AppDestination.management.route) {
      return _page(
        settings,
        const ShellScaffold(
          destination: AppDestination.management,
          child: ManagementPage(),
        ),
      );
    }

    if (name == AppDestination.review.route) {
      return _page(
        settings,
        const ShellScaffold(
          destination: AppDestination.review,
          child: ReviewPage(),
        ),
      );
    }

    if (name == '/projects') {
      return _standalonePage(settings, const ProjectsPage());
    }

    if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'projects') {
      return _standalonePage(
        settings,
        ProjectDetailPage(projectId: uri.pathSegments[1]),
      );
    }

    if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'ledger') {
      return _standalonePage(
        settings,
        LedgerManagementPage(recordType: uri.pathSegments[1]),
      );
    }

    if (name == '/time-management') {
      return _standalonePage(settings, const TimeManagementPage());
    }

    if (name == '/cost-management') {
      return _standalonePage(settings, const CostManagementPage());
    }

    if (name == '/settings') {
      return _standalonePage(settings, const SettingsPage());
    }

    if (name == '/settings/operating') {
      return _standalonePage(settings, const OperatingSettingsPage());
    }

    if (name == '/settings/ai-services') {
      return _standalonePage(settings, const AiServiceConfigsPage());
    }

    if (name == '/settings/cloud-sync') {
      return _standalonePage(settings, const CloudSyncConfigsPage());
    }

    if (name == '/settings/tags') {
      return _standalonePage(settings, const TagManagePage());
    }

    if (name == '/settings/dimensions') {
      return _standalonePage(settings, const DimensionManagePage());
    }

    if (name == '/settings/backup') {
      return _standalonePage(settings, const BackupPage());
    }

    if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'day') {
      return _standalonePage(
        settings,
        DayDetailPage(anchorDate: uri.pathSegments[1]),
      );
    }

    if (name == '/ai-chat') {
      return _standalonePage(settings, const AiChatPage());
    }

    return _page(
      settings,
      const ShellScaffold(
        destination: AppDestination.today,
        child: TodayPage(),
      ),
    );
  }

  static MaterialPageRoute<void> _page(RouteSettings settings, Widget child) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => child,
    );
  }

  static MaterialPageRoute<void> _standalonePage(
    RouteSettings settings,
    Widget child,
  ) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => Scaffold(
        body: child,
      ),
    );
  }
}
