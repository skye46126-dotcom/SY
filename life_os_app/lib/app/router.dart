import 'package:flutter/material.dart';

import '../features/capture/capture_launch.dart';
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
import '../models/review_models.dart';
import '../features/settings/backup_page.dart';
import '../features/settings/ai_service_configs_page.dart';
import '../features/settings/cloud_sync_configs_page.dart';
import '../features/settings/dimension_manage_page.dart';
import '../features/settings/export_center_page.dart';
import '../features/settings/operating_settings_page.dart';
import '../features/settings/poster_export_page.dart';
import '../features/settings/data_package_export_page.dart';
import '../features/settings/report_export_page.dart';
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

    if (uri.path == AppDestination.today.route) {
      return _page(
        settings,
        const ShellScaffold(
          destination: AppDestination.today,
          child: TodayPage(),
        ),
      );
    }

    if (uri.path == AppDestination.capture.route) {
      final launchConfig = CaptureLaunchConfig.fromRouteName(name) ??
          settings.arguments as CaptureLaunchConfig?;
      return _page(
        settings,
        ShellScaffold(
          destination: AppDestination.capture,
          child: CapturePage(launchConfig: launchConfig),
        ),
      );
    }

    if (uri.path == AppDestination.management.route) {
      return _page(
        settings,
        const ShellScaffold(
          destination: AppDestination.management,
          child: ManagementPage(),
        ),
      );
    }

    if (uri.path == AppDestination.review.route) {
      final initialKind =
          switch ((settings.arguments as ReviewPageRouteArgs?)?.windowKind) {
        'week' => ReviewWindowKind.week,
        'month' => ReviewWindowKind.month,
        'year' => ReviewWindowKind.year,
        _ => ReviewWindowKind.day,
      };
      return _page(
        settings,
        ShellScaffold(
          destination: AppDestination.review,
          child: ReviewPage(initialKind: initialKind),
        ),
      );
    }

    if (uri.path == '/projects') {
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

    if (uri.path == '/time-management') {
      return _standalonePage(settings, const TimeManagementPage());
    }

    if (uri.path == '/cost-management') {
      return _standalonePage(settings, const CostManagementPage());
    }

    if (uri.path == '/settings') {
      return _standalonePage(settings, const SettingsPage());
    }

    if (uri.path == '/settings/operating') {
      return _standalonePage(settings, const OperatingSettingsPage());
    }

    if (uri.path == '/settings/ai-services') {
      return _standalonePage(settings, const AiServiceConfigsPage());
    }

    if (uri.path == '/settings/cloud-sync') {
      return _standalonePage(settings, const CloudSyncConfigsPage());
    }

    if (uri.path == '/settings/tags') {
      return _standalonePage(settings, const TagManagePage());
    }

    if (uri.path == '/settings/dimensions') {
      return _standalonePage(settings, const DimensionManagePage());
    }

    if (uri.path == '/settings/backup') {
      return _standalonePage(settings, const BackupPage());
    }

    if (uri.path == '/settings/export-center') {
      return _standalonePage(settings, const ExportCenterPage());
    }

    if (uri.path == '/settings/poster-export') {
      return _standalonePage(settings, const PosterExportPage());
    }

    if (uri.path == '/settings/data-package-export') {
      return _standalonePage(settings, const DataPackageExportPage());
    }

    if (uri.path == '/settings/report-export') {
      return _standalonePage(settings, const ReportExportPage());
    }

    if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'day') {
      return _standalonePage(
        settings,
        DayDetailPage(anchorDate: uri.pathSegments[1]),
      );
    }

    if (uri.path == '/ai-chat') {
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
