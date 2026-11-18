// lib/admin_web/presentation/platform_reports/admin_platform_reports_screen.dart
//
// UW 8 "Generate Reports" -- the one section this whole app build was
// originally blocked on for lack of anywhere to show it. The four
// report endpoints (routes/admin.js) already existed; this is the
// screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/admin/data/admin_repository.dart';
import '../../utils/web_download.dart';

const _reportTabs = [
  (AdminReportType.agreements, 'Agreements'),
  (AdminReportType.orders, 'Orders'),
  (AdminReportType.vendorPerformance, 'Vendor Performance'),
  (AdminReportType.marketDemand, 'Market Demand'),
];

class AdminPlatformReportsScreen extends ConsumerStatefulWidget {
  const AdminPlatformReportsScreen({super.key});
  @override
  ConsumerState<AdminPlatformReportsScreen> createState() =>
      _AdminPlatformReportsScreenState();
}

class _AdminPlatformReportsScreenState
    extends ConsumerState<AdminPlatformReportsScreen> {
  AdminReportType _reportType = AdminReportType.agreements;
  DateTime? _start;
  DateTime? _end;
  List<Map<String, dynamic>>? _rows;
  bool _loading = false;
  String? _error;
  bool _downloading = false;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
      _rows = null;
    });
    try {
      final rows = await ref.read(adminRepositoryProvider).getPlatformReport(
          _reportType,
          start: _start, end: _end);
      if (mounted) setState(() => _rows = rows);
    } on NoReportDataException {
      if (mounted) setState(() => _error = 'No data available for the selected period.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn\'t generate this report.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadCsv() async {
    setState(() => _downloading = true);
    try {
      final bytes = await ref
          .read(adminRepositoryProvider)
          .fetchPlatformReportCsv(_reportType, start: _start, end: _end);
      final name = _reportTabs.firstWhere((t) => t.$1 == _reportType).$2;
      triggerBrowserDownload(bytes, '${name.toLowerCase().replaceAll(' ', '-')}-report.csv');
    } on NoReportDataException {
      if (mounted) setState(() => _error = 'No data available for the selected period.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn\'t prepare the download.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Platform Reports', style: AppTypography.h1),
          const SizedBox(height: 2),
          const Text('Platform-wide reports, each covering the whole marketplace rather than one account.',
              style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            children: _reportTabs
                .map((t) => ChoiceChip(
                      label: Text(t.$2),
                      selected: _reportType == t.$1,
                      onSelected: (_) => setState(() {
                        _reportType = t.$1;
                        _rows = null;
                      }),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          // REAL GAP FOUND AND FIXED: a fixed-width Row of six controls
          // (Start date/End date/Clear/Generate, then Download CSV once
          // a report exists) -- the Download CSV button pushed the row
          // past the available width and overflowed horizontally rather
          // than wrapping, same bug class as the stats-grid overflows
          // fixed elsewhere this session. Wrap is a drop-in replacement
          // here since every child already has its own intrinsic width
          // (nothing relies on Row's unbounded-width-per-child behavior
          // the comment below still correctly explains).
          Wrap(runSpacing: AppSpacing.sm, children: [
            // The theme's OutlinedButton/ElevatedButton minimumSize is
            // Size.fromHeight(48), i.e. infinite width -- fine inside a
            // Column, but a Row gives each non-flex child unbounded
            // width too, so without a bounded minimumSize override here
            // this throws "BoxConstraints forces an infinite width"
            // (same root cause as the WalkthroughScreen bug).
            OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => _pickDate(isStart: true),
                child: Text(_start == null ? 'Start date' : _fmt(_start!))),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => _pickDate(isStart: false),
                child: Text(_end == null ? 'End date' : _fmt(_end!))),
            const SizedBox(width: AppSpacing.sm),
            if (_start != null || _end != null)
              TextButton(
                  onPressed: () => setState(() {
                        _start = null;
                        _end = null;
                      }),
                  child: const Text('Clear')),
            const SizedBox(width: AppSpacing.md),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: _loading ? null : _generate,
              child: _loading
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Generate'),
            ),
            if (_rows != null && _rows!.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: _downloading ? null : _downloadCsv,
                icon: const Icon(Icons.download, size: 16),
                label: Text(_downloading ? 'Preparing…' : 'Download CSV'),
              ),
            ],
          ]),
          const SizedBox(height: AppSpacing.lg),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          if (_rows != null)
            Expanded(child: _ReportTable(rows: _rows!)),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final keys = rows.first.keys.toList();
    return SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: DataTable(
          columns: keys
              .map((k) => DataColumn(
                  label: Text(k.replaceAll('_', ' '), style: AppTypography.label)))
              .toList(),
          rows: rows
              .map((row) => DataRow(
                    cells: keys
                        .map((k) => DataCell(Text(row[k]?.toString() ?? '—')))
                        .toList(),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
