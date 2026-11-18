// lib/features/admin/presentation/admin_users_screen.dart
//
// admin_home_screen.dart's own note says "User management... [is]
// available on the NagaGuno web admin panel" -- full platform
// oversight is still deliberately not duplicated here. This is a
// narrower, additive piece: search/filter/view, using the real GET
// /admin/users (which already supports role/status/search server-side,
// verified against routes/admin.js) that had nothing in the mobile app
// calling it yet, plus the same restrict/restore action the KYC queue
// pattern already establishes for admin decisions on mobile.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../data/admin_repository.dart' show adminRepositoryProvider;
import '../domain/admin_models.dart';

final _roleFilterProvider = StateProvider.autoDispose<String?>((ref) => null);
final _statusFilterProvider = StateProvider.autoDispose<String?>((ref) => null);
final _searchProvider = StateProvider.autoDispose<String>((ref) => '');

// account_status 'blocked' is the permanent-exclusion state (admin.js's
// recordAdminDirectAction records it under consequence 'banned', and its
// own notification type is 'account_blocked' / "Account Banned") -- the
// raw enum value stays 'blocked' in the database and API, but every
// admin-facing label calls it what it actually is: a ban.
String _statusLabel(String status) =>
    status == 'blocked' ? 'Banned' : status[0].toUpperCase() + status.substring(1);

final _adminUsersProvider =
    FutureProvider.autoDispose<List<AdminUserListItem>>((ref) {
  final role = ref.watch(_roleFilterProvider);
  final status = ref.watch(_statusFilterProvider);
  final search = ref.watch(_searchProvider);
  return ref.watch(adminRepositoryProvider).getUsers(
      role: role,
      status: status,
      search: search.trim().isEmpty ? null : search.trim());
});

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  // Debounced the same 300ms the real web admin's own AdminUsers page
  // uses for this exact field, so a keystroke doesn't fire a request
  // per character.
  DateTime _lastEdit = DateTime.now();

  void _onSearchChanged(String value) {
    final editedAt = DateTime.now();
    _lastEdit = editedAt;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_lastEdit == editedAt) {
        ref.read(_searchProvider.notifier).state = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_adminUsersProvider);
    final role = ref.watch(_roleFilterProvider);
    final status = ref.watch(_statusFilterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                  hintText: 'Search name or email',
                  prefixIcon: Icon(Icons.search)),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              children: [
                ChoiceChip(
                    label: const Text('All roles'),
                    selected: role == null,
                    onSelected: (_) =>
                        ref.read(_roleFilterProvider.notifier).state = null),
                const SizedBox(width: AppSpacing.xs),
                for (final r in const ['buyer', 'farmer', 'vendor']) ...[
                  ChoiceChip(
                      label: Text(r[0].toUpperCase() + r.substring(1)),
                      selected: role == r,
                      onSelected: (_) =>
                          ref.read(_roleFilterProvider.notifier).state = r),
                  const SizedBox(width: AppSpacing.xs),
                ],
                const SizedBox(width: AppSpacing.sm),
                ChoiceChip(
                    label: const Text('All statuses'),
                    selected: status == null,
                    onSelected: (_) =>
                        ref.read(_statusFilterProvider.notifier).state = null),
                const SizedBox(width: AppSpacing.xs),
                for (final s in const ['active', 'blocked', 'suspended']) ...[
                  ChoiceChip(
                      label: Text(_statusLabel(s)),
                      selected: status == s,
                      onSelected: (_) =>
                          ref.read(_statusFilterProvider.notifier).state = s),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
          ),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Couldn\'t load users.'),
                  const SizedBox(height: AppSpacing.sm),
                  ElevatedButton(
                      onPressed: () => ref.invalidate(_adminUsersProvider),
                      child: const Text('Retry')),
                ]),
              ),
              data: (users) {
                if (users.isEmpty) {
                  return const Center(
                      child: Text('No users match this search.'));
                }
                return RefreshIndicator(
                  onRefresh: () => ref.refresh(_adminUsersProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: users.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final user = users[i];
                      return ListTile(
                        tileColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            side: const BorderSide(color: AppColors.border)),
                        title: Text(user.fullName,
                            style: AppTypography.body
                                .copyWith(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${user.email ?? user.phoneNumber ?? '—'}\n${user.role[0].toUpperCase()}${user.role.substring(1)} · ${_statusLabel(user.accountStatus)}'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  AdminUserDetailScreen(userId: user.id)));
                          ref.invalidate(_adminUsersProvider);
                        },
                      );
                    },
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

final _userDetailProvider = FutureProvider.autoDispose.family(
  (ref, String id) => ref.watch(adminRepositoryProvider).getUserDetail(id),
);

class AdminUserDetailScreen extends ConsumerStatefulWidget {
  const AdminUserDetailScreen({super.key, required this.userId});
  final String userId;
  @override
  ConsumerState<AdminUserDetailScreen> createState() =>
      _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  bool _busy = false;

  Future<void> _setStatus(String accountStatus) async {
    String? reason;
    if (accountStatus != 'active') {
      reason = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          final controller = TextEditingController();
          return AlertDialog(
            title: Text(accountStatus == 'blocked'
                ? 'Ban this account'
                : 'Suspend this account'),
            content: TextField(
                controller: controller,
                decoration:
                    const InputDecoration(labelText: 'Reason (required)')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(controller.text.trim()),
                  child: const Text('Confirm')),
            ],
          );
        },
      );
      if (reason == null || reason.isEmpty) return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).updateUserStatus(widget.userId,
          accountStatus: accountStatus, reason: reason);
      ref.invalidate(_userDetailProvider(widget.userId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Something went wrong.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(_userDetailProvider(widget.userId));

    return Scaffold(
      appBar: AppBar(title: const Text('User Detail')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            const Center(child: Text('Couldn\'t load this user.')),
        data: (user) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(user.fullName, style: AppTypography.h2),
              const SizedBox(height: AppSpacing.xs),
              if (user.email != null)
                Text(user.email!, style: AppTypography.body),
              if (user.phoneNumber != null)
                Text(user.phoneNumber!, style: AppTypography.body),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                    color: AppColors.backgroundStart,
                    borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Role: ${user.role}'),
                      Text('Status: ${_statusLabel(user.accountStatus)}'),
                      if (user.suspendedUntil != null)
                        Text('Suspended until: ${user.suspendedUntil}'),
                      if (user.violationStatus != null)
                        Text('Violation status: ${user.violationStatus}'),
                      Text(
                          'Orders: ${user.orderCount} · Agreements: ${user.agreementCount}'),
                    ]),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text('Account Action', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.sm),
              Wrap(spacing: AppSpacing.sm, children: [
                // REAL GAP FOUND AND FIXED: enabled for ANY non-active
                // status, including 'pending_verification' -- letting
                // an Admin force a user who has never passed KYC
                // straight to 'active', bypassing verification
                // entirely (the backend now rejects this too; see
                // routes/admin.js's PATCH /users/:id). A restore only
                // makes sense reversing an actual suspension/ban.
                OutlinedButton(
                    onPressed: _busy ||
                            !['suspended', 'blocked']
                                .contains(user.accountStatus)
                        ? null
                        : () => _setStatus('active'),
                    child: const Text('Restore to Active')),
                OutlinedButton(
                    onPressed: _busy || user.accountStatus == 'suspended'
                        ? null
                        : () => _setStatus('suspended'),
                    child: const Text('Suspend')),
                OutlinedButton(
                    onPressed: _busy || user.accountStatus == 'blocked'
                        ? null
                        : () => _setStatus('blocked'),
                    child: const Text('Ban')),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
