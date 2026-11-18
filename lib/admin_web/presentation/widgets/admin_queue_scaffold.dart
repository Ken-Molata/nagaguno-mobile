// lib/admin_web/presentation/widgets/admin_queue_scaffold.dart
//
// Shared chrome for every admin review queue screen (7 of them: KYC's
// own kyc_review_screen.dart predates this and keeps its mobile-
// styled layout; every queue built for the web admin app uses this
// instead) -- title/subtitle, loading/error/retry/empty states, and a
// simple column-flex table, so each queue screen only has to supply
// its own columns and row content, not reimplement all of that.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

class AdminQueueScaffold<T> extends StatelessWidget {
  const AdminQueueScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.asyncItems,
    required this.onRetry,
    required this.emptyLabel,
    required this.columns,
    required this.rowCells,
    required this.onOpen,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final AsyncValue<List<T>> asyncItems;
  final VoidCallback onRetry;
  final String emptyLabel;
  final List<String> columns;
  final List<Widget> Function(T item) rowCells;
  final void Function(T item) onOpen;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.h1),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppTypography.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: asyncItems.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Couldn\'t load this queue.'),
                  const SizedBox(height: AppSpacing.sm),
                  ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
                ]),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                      child: Text(emptyLabel, style: AppTypography.bodySmall));
                }
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: AppColors.border)),
                        ),
                        child: Row(
                          children: columns
                              .map((c) => Expanded(
                                    child: Text(c, style: AppTypography.label),
                                  ))
                              .toList(),
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (context, i) {
                            final item = items[i];
                            return InkWell(
                              onTap: () => onOpen(item),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.sm),
                                child: Row(
                                  children: rowCells(item)
                                      .map((w) => Expanded(child: w))
                                      .toList(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
