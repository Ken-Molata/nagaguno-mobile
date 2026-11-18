// lib/admin_web/presentation/widgets/admin_decision_dialogs.dart
//
// Two small reusable dialogs shared by every admin decision screen --
// "pick a predefined reason, 'Other' needs free text" and "write a
// free-text note" -- same pattern the mobile app's order_detail_screen.dart
// already uses locally; extracted here since the web admin app needs
// it in 5+ places (reports, refunds, appeals, corrections, recovery).

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

/// Real backend validation messages here are specific and actionable
/// (e.g. UW 2.5's "You cannot review your own account recovery
/// request" self-review block) -- worth surfacing as-is rather than a
/// generic "something went wrong" that would hide exactly why an
/// action was rejected.
String adminErrorMessage(Object error, {String fallback = 'Something went wrong. Please try again.'}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
  }
  return fallback;
}

/// Returns (reasonCode, note) or null if cancelled. [note] is only
/// non-null when the selected reason is 'other'.
Future<(String, String?)?> showReasonDialog({
  required BuildContext context,
  required String title,
  required Map<String, String> reasons,
}) {
  String? selected;
  final noteController = TextEditingController();
  return showDialog<(String, String?)>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RadioGroup<String>(
                groupValue: selected,
                onChanged: (v) => setDialogState(() => selected = v),
                child: Column(
                  children: reasons.entries
                      .map((e) => RadioListTile<String>(
                          title: Text(e.value), value: e.key, dense: true))
                      .toList(),
                ),
              ),
              if (selected == 'other')
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: 'Please specify'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: selected == null ||
                    (selected == 'other' && noteController.text.trim().isEmpty)
                ? null
                : () => Navigator.of(dialogContext)
                    .pop((selected!, noteController.text.trim())),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ),
  );
}

/// UW 19: "Submitting shows 'Submitting decision...' (Loading state)...
/// 'Decision recorded.' is Success." Every admin decision screen
/// (reports, refunds, appeals, corrections, recovery, shelf-life
/// feedback) called its decide action directly with no loading
/// indicator at all -- the screen just sat unresponsive for the
/// duration of the request. Wrap the actual submit call in this so
/// every one of them gets the same real in-progress indicator instead
/// of each re-inventing it (or not).
Future<void> runAdminDecision(
    BuildContext context, Future<void> Function() action) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
              height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 16),
          Text('Submitting decision...'),
        ],
      ),
    ),
  );
  try {
    await action();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

Future<String?> showNoteDialog({
  required BuildContext context,
  required String title,
  required String label,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          maxLines: 3,
          autofocus: true,
          onChanged: (_) => setDialogState(() {}),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: controller.text.trim().isEmpty
                ? null
                : () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ),
  );
}
