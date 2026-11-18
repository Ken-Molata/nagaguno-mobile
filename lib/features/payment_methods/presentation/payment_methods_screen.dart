// lib/features/payment_methods/presentation/payment_methods_screen.dart
//
// Closes a real gap: UW 1.2/21.3's Linked Payment Account had no
// mobile UI at all, which meant a seller could never actually make
// Manual Transfer (UW 6.1) available at checkout — the backend
// endpoints (routes/paymentMethods.js) worked the whole time, just
// unreachable from this app.
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/utils/image_picking.dart';
import '../../../core/utils/friendly_error_message.dart';
import '../../../core/localization/app_strings.dart';
import '../../../shared/widgets/copyable_value.dart';
import '../../authentication/application/auth_controller.dart';
import '../data/payment_methods_repository.dart';
import '../domain/payment_method.dart';

final paymentMethodsRepositoryProvider = Provider<PaymentMethodsRepository>(
    (ref) => PaymentMethodsRepository(ref.watch(apiClientProvider)));
final paymentMethodsListProvider =
    FutureProvider.autoDispose<List<PaymentMethod>>((ref) =>
        ref.watch(paymentMethodsRepositoryProvider).getMyPaymentMethods());
final _gatewayTestModeProvider = FutureProvider.autoDispose<bool>((ref) =>
    ref.watch(paymentMethodsRepositoryProvider).getGatewayTestMode());

/// UW 21.2 top: "Password confirmation is required for every add,
/// edit, or removal." One shared prompt so the three flows below
/// don't each re-implement it. Returns null if cancelled.
Future<String?> _askPassword(BuildContext context, WidgetRef ref,
    {required String action, required String actionTl}) {
  final controller = TextEditingController();
  final s = ref.read(appStringsProvider);
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(s.confirmYourPasswordTitle),
      content: TextField(
        controller: controller,
        obscureText: true,
        autofocus: true,
        decoration: InputDecoration(
            labelText: s.password,
            helperText: s.requiredForPaymentAction(action, actionTl)),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(s.cancel)),
        TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(s.continueLabel)),
      ],
    ),
  );
}

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  Future<void> _delete(
      BuildContext context, WidgetRef ref, String id, bool isLastMethod) async {
    final s = ref.read(appStringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.removePaymentMethodQuestion),
        // REAL GAP FOUND AND FIXED: UW 21.3's "last method" addendum,
        // see removeLastPaymentMethodWarning's own doc comment --
        // previously shown for every removal regardless of whether any
        // other method was left, or not shown at all.
        content:
            isLastMethod ? Text(s.removeLastPaymentMethodWarning) : null,
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(s.cancel)),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(s.removeLabel)),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final password =
        await _askPassword(context, ref, action: 'remove', actionTl: 'alisin');
    if (password == null || password.isEmpty) return;
    try {
      await ref
          .read(paymentMethodsRepositoryProvider)
          .deletePaymentMethod(id, password: password);
      ref.invalidate(paymentMethodsListProvider);
    } on PaymentDetailsLockedException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methodsAsync = ref.watch(paymentMethodsListProvider);
    final user = ref.watch(authControllerProvider).user;
    final isSeller = user?.isFarmer == true || user?.isVendor == true;
    final isTestMode =
        ref.watch(_gatewayTestModeProvider).valueOrNull ?? false;
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.paymentMethodsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _AddPaymentMethodSheet(),
        ),
        icon: const Icon(Icons.add),
        label: Text(s.addLabel),
      ),
      body: SafeArea(
        child: methodsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(s.couldntLoadPaymentMethods),
              const SizedBox(height: AppSpacing.sm),
              ElevatedButton(
                  onPressed: () => ref.invalidate(paymentMethodsListProvider),
                  child: Text(s.retry)),
            ]),
          ),
          data: (methods) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // UW 21.3's "What the screen explains" note: exact
                  // spec text, genuinely different per role (not a
                  // seller-only line shown to everyone, the previous,
                  // disclosed simplification here) -- a Farmer/Vendor's
                  // details receive both Manual Transfer payments and
                  // Gateway settlement payouts; a Buyer's receive
                  // refunds only.
                  Text(
                    isSeller
                        ? s.sellerPaymentExplanation
                        : s.buyerPaymentExplanation,
                    style: AppTypography.bodySmall,
                  ),
                  if (isSeller) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      s.gatewayNeedsNothingFromYou,
                      style: AppTypography.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  // UW 1.2: "Wherever this account is displayed, a
                  // reminder is shown alongside it" -- real backend
                  // copy, reused verbatim, not reworded.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.verificationPendingBg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: AppColors.accentDark),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            isTestMode
                                // UW 21.3: "While the gateway is in
                                // test mode (Section 6.4), the note
                                // adds: 'The gateway is in test mode.
                                // No real money is charged.'"
                                ? s.makeSureAccountDetailsCorrectTestMode
                                : s.makeSureAccountDetailsCorrect,
                            style: AppTypography.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (methods.isEmpty)
                    Expanded(
                        child: Center(
                            child: Text(s.noPaymentMethodsAddedYet,
                                style: AppTypography.bodySmall)))
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: methods.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) {
                          final m = methods[i];
                          return Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                                color: AppColors.surface,
                                border: Border.all(color: AppColors.border),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (m.hasGcash) ...[
                                        const Text('GCash',
                                            style: AppTypography.label),
                                        if (m.gcashNumber != null)
                                          CopyableValue(value: m.gcashNumber!),
                                        if (m.gcashQrUrl != null) ...[
                                          const SizedBox(height: AppSpacing.xs),
                                          ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadius.sm),
                                              child: Image.network(
                                                  m.gcashQrUrl!,
                                                  height: 100,
                                                  width: 100,
                                                  fit: BoxFit.cover)),
                                        ],
                                      ],
                                      if (m.hasBank) ...[
                                        if (m.hasGcash)
                                          const SizedBox(height: AppSpacing.sm),
                                        Text(s.bankTransferLabel,
                                            style: AppTypography.label),
                                        CopyableValue(
                                            label: m.bankName,
                                            value: m.bankAccountNumber ?? ''),
                                        if (m.bankAccountName != null)
                                          Text(m.bankAccountName!,
                                              style: AppTypography.bodySmall),
                                      ],
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: s.editTooltip,
                                  onPressed: () => showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (_) =>
                                        _EditPaymentMethodSheet(method: m),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: AppColors.error),
                                  onPressed: () => _delete(context, ref, m.id,
                                      isSeller && methods.length == 1),
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
          },
        ),
      ),
    );
  }
}

class _AddPaymentMethodSheet extends ConsumerStatefulWidget {
  const _AddPaymentMethodSheet();
  @override
  ConsumerState<_AddPaymentMethodSheet> createState() =>
      _AddPaymentMethodSheetState();
}

class _AddPaymentMethodSheetState
    extends ConsumerState<_AddPaymentMethodSheet> {
  final _gcashNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _bankAccountNameController = TextEditingController();
  String? _qrPath;
  bool _submitting = false;
  String? _errorMessage;

  bool get _hasAnyInput =>
      _gcashNumberController.text.trim().isNotEmpty ||
      _qrPath != null ||
      (_bankNameController.text.trim().isNotEmpty &&
          _bankAccountNumberController.text.trim().isNotEmpty);

  Future<void> _submit() async {
    if (!_hasAnyInput) {
      setState(() => _errorMessage =
          ref.read(appStringsProvider).provideAtLeastOnePaymentDetail);
      return;
    }
    final password =
        await _askPassword(context, ref, action: 'add', actionTl: 'idagdag');
    if (password == null || password.isEmpty) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(paymentMethodsRepositoryProvider).addPaymentMethod(
            password: password,
            gcashNumber: _gcashNumberController.text.trim().isEmpty
                ? null
                : _gcashNumberController.text.trim(),
            gcashQrPath: _qrPath,
            bankName: _bankNameController.text.trim().isEmpty
                ? null
                : _bankNameController.text.trim(),
            bankAccountNumber: _bankAccountNumberController.text.trim().isEmpty
                ? null
                : _bankAccountNumberController.text.trim(),
            bankAccountName: _bankAccountNameController.text.trim().isEmpty
                ? null
                : _bankAccountNameController.text.trim(),
          );
      ref.invalidate(paymentMethodsListProvider);
      if (mounted) Navigator.of(context).pop();
    } on PaymentDetailsLockedException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.addPaymentMethodTitle, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.md),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                    color: AppColors.statusCancelledBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Text(_errorMessage!,
                    style: const TextStyle(color: AppColors.statusCancelledFg)),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            const Text('GCash', style: AppTypography.label),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _gcashNumberController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: s.gcashNumberHint),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () async {
                final file = await pickAndCompressImage();
                if (file != null) setState(() => _qrPath = file.path);
              },
              icon: const Icon(Icons.qr_code),
              label: Text(_qrPath == null
                  ? s.addGcashQrOptional
                  : s.qrCodeSelected),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(s.bankAccountLabel, style: AppTypography.label),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
                controller: _bankNameController,
                decoration: InputDecoration(labelText: s.bankNameLabel)),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
                controller: _bankAccountNumberController,
                decoration: InputDecoration(labelText: s.accountNumberLabel)),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
                controller: _bankAccountNameController,
                decoration: InputDecoration(labelText: s.accountNameLabel)),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent))
                  : Text(s.saveLabel),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gcashNumberController.dispose();
    _bankNameController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountNameController.dispose();
    super.dispose();
  }
}

/// UW 21.3: "Add, edit, remove." Mirrors [_AddPaymentMethodSheet],
/// pre-filled with [method]'s current values and calling
/// editPaymentMethod (PATCH) instead of addPaymentMethod (POST).
class _EditPaymentMethodSheet extends ConsumerStatefulWidget {
  const _EditPaymentMethodSheet({required this.method});
  final PaymentMethod method;
  @override
  ConsumerState<_EditPaymentMethodSheet> createState() =>
      _EditPaymentMethodSheetState();
}

class _EditPaymentMethodSheetState
    extends ConsumerState<_EditPaymentMethodSheet> {
  late final _gcashNumberController =
      TextEditingController(text: widget.method.gcashNumber ?? '');
  late final _bankNameController =
      TextEditingController(text: widget.method.bankName ?? '');
  late final _bankAccountNumberController =
      TextEditingController(text: widget.method.bankAccountNumber ?? '');
  late final _bankAccountNameController =
      TextEditingController(text: widget.method.bankAccountName ?? '');
  String? _newQrPath;
  bool _removeExistingQr = false;
  bool _submitting = false;
  String? _errorMessage;

  bool get _hasExistingQr =>
      widget.method.gcashQrUrl != null && !_removeExistingQr;

  Future<void> _submit() async {
    final password = await _askPassword(context, ref,
        action: 'update', actionTl: 'i-update');
    if (password == null || password.isEmpty) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(paymentMethodsRepositoryProvider).editPaymentMethod(
            widget.method.id,
            password: password,
            gcashNumber: _gcashNumberController.text.trim().isEmpty
                ? null
                : _gcashNumberController.text.trim(),
            gcashQrPath: _newQrPath,
            removeQr: _removeExistingQr,
            bankName: _bankNameController.text.trim().isEmpty
                ? null
                : _bankNameController.text.trim(),
            bankAccountNumber: _bankAccountNumberController.text.trim().isEmpty
                ? null
                : _bankAccountNumberController.text.trim(),
            bankAccountName: _bankAccountNameController.text.trim().isEmpty
                ? null
                : _bankAccountNameController.text.trim(),
          );
      ref.invalidate(paymentMethodsListProvider);
      if (mounted) Navigator.of(context).pop();
    } on PaymentDetailsLockedException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.editPaymentMethodTitle, style: AppTypography.h3),
            const SizedBox(height: AppSpacing.md),
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                    color: AppColors.statusCancelledBg,
                    borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Text(_errorMessage!,
                    style: const TextStyle(color: AppColors.statusCancelledFg)),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            const Text('GCash', style: AppTypography.label),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
              controller: _gcashNumberController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: s.gcashNumberHint),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_hasExistingQr)
              Row(children: [
                Expanded(child: Text(s.qrCodeOnFile)),
                TextButton(
                  onPressed: () => setState(() => _removeExistingQr = true),
                  child: Text(s.removeLabel),
                ),
              ])
            else
              OutlinedButton.icon(
                onPressed: () async {
                  final file = await pickAndCompressImage();
                  if (file != null) {
                    setState(() {
                      _newQrPath = file.path;
                      _removeExistingQr = false;
                    });
                  }
                },
                icon: const Icon(Icons.qr_code),
                label: Text(_newQrPath == null
                    ? s.addGcashQrOptional
                    : s.qrCodeSelected),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(s.bankAccountLabel, style: AppTypography.label),
            const SizedBox(height: AppSpacing.xs),
            TextFormField(
                controller: _bankNameController,
                decoration: InputDecoration(labelText: s.bankNameLabel)),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
                controller: _bankAccountNumberController,
                decoration: InputDecoration(labelText: s.accountNumberLabel)),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
                controller: _bankAccountNameController,
                decoration: InputDecoration(labelText: s.accountNameLabel)),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent))
                  : Text(s.saveLabel),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _gcashNumberController.dispose();
    _bankNameController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountNameController.dispose();
    super.dispose();
  }
}
