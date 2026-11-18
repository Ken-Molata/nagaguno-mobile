// lib/features/reports/presentation/report_user_screen.dart
//
// UW 9.1/7.6/17.6/17.7: the general "Report" flow. [fixedGroup] locks
// the violation group (and hides the group picker) for an entry point
// that already knows exactly what it's reporting -- UW 7.6's "Report:
// Order Not Arrived" button always passes ViolationGroup.nonArrival
// plus the orderId, for instance. A generic entry point (reporting a
// user's conduct from their profile) leaves [fixedGroup] null and
// lets the picker show.
//
// Translated (UW 21.5) as part of the same screen-by-screen rollout as
// profile/presentation/account_settings_screen.dart -- see
// core/localization/app_strings.dart's header comment for scope. The
// violation TYPE labels themselves (types.entries' e.value, from
// violationTypes below) are left in English for now -- same
// "representative, not exhaustive" scope as other large domain content
// catalogs this pass.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/networking/api_client.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/utils/image_picking.dart';
import '../data/reports_repository.dart';
import '../domain/report_models.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>(
    (ref) => ReportsRepository(ref.watch(apiClientProvider)));

class ReportUserScreen extends ConsumerStatefulWidget {
  const ReportUserScreen({
    super.key,
    required this.reportedUserId,
    required this.reportedUserName,
    this.fixedGroup,
    this.availableGroups,
    this.initialType,
    this.orderId,
    this.agreementId,
    this.productId,
    this.messageId,
    this.reviewId,
    this.productReviewId,
    this.reportProfilePicture = false,
  });

  final String reportedUserId;
  final String reportedUserName;

  /// When set, the group picker is hidden and this is the only group
  /// submitted. When null, [availableGroups] (or every group, if that
  /// is also null) is offered as a picker.
  final String? fixedGroup;
  final List<String>? availableGroups;

  /// UW 12.1's overflow-menu Report entry: "the violation type pre-set
  /// to 'Crop state misrepresented at listing'" -- a starting value,
  /// not a lock the way [fixedGroup] is; the user can still change it
  /// to a different type within the same (fixed) group.
  final String? initialType;
  final String? orderId;
  final String? agreementId;
  final String? productId;
  final String? messageId;
  final String? reviewId;

  /// UW 9.1/14.1: the product review (distinct from [reviewId], the
  /// seller review -- these are two different backend tables).
  final String? productReviewId;

  /// UW 9.1/12.3/12.4: "A profile picture specifically, from the
  /// three-dot menu" -- still reports [reportedUserId] (there's no
  /// separate id for an avatar), just flags original-content capture
  /// to target their avatar instead of nothing.
  final bool reportProfilePicture;

  @override
  ConsumerState<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends ConsumerState<ReportUserScreen> {
  late String _group = widget.fixedGroup ??
      (widget.availableGroups ?? violationTypes.keys.toList()).first;
  late String? _type = widget.initialType;
  final _essayController = TextEditingController();
  final List<String> _photoPaths = [];
  bool _submitting = false;
  String? _errorMessage;

  List<String> get _groupChoices => widget.fixedGroup != null
      ? [widget.fixedGroup!]
      : (widget.availableGroups ?? violationTypes.keys.toList());

  Future<void> _addPhoto() async {
    if (_photoPaths.length >= 5) return;
    final file = await pickAndCompressImage();
    if (file != null) setState(() => _photoPaths.add(file.path));
  }

  Future<void> _submit() async {
    final s = ref.read(appStringsProvider);
    if (_type == null) {
      setState(() => _errorMessage = s.selectWhatHappenedError);
      return;
    }
    if (_type == 'other' && _essayController.text.trim().isEmpty) {
      setState(() => _errorMessage = s.pleaseDescribeWhatHappenedError);
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(reportsRepositoryProvider).submitReport(
            reportedUserId: widget.reportedUserId,
            violationGroup: _group,
            violationType: _type!,
            essay: _essayController.text,
            photoPaths: _photoPaths,
            orderId: widget.orderId,
            agreementId: widget.agreementId,
            productId: widget.productId,
            messageId: widget.messageId,
            reviewId: widget.reviewId,
            productReviewId: widget.productReviewId,
            reportProfilePicture: widget.reportProfilePicture,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.reportSubmittedAdminWillReview)));
    } on ReportException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = violationTypes[_group] ?? const {};
    final s = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.reportUserLabel(widget.reportedUserName))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                      color: AppColors.statusCancelledBg,
                      borderRadius: BorderRadius.circular(AppRadius.sm)),
                  child: Text(_errorMessage!,
                      style:
                          const TextStyle(color: AppColors.statusCancelledFg)),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (widget.fixedGroup == null && _groupChoices.length > 1) ...[
                Text(s.whatKindOfIssueIsThisLabel, style: AppTypography.h3),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _group,
                  items: _groupChoices
                      .map((g) => DropdownMenuItem(
                          value: g, child: Text(s.violationGroupLabel(g))))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _group = v!;
                    _type = null;
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              Text(s.whatHappenedLabel, style: AppTypography.h3),
              const SizedBox(height: AppSpacing.xs),
              RadioGroup<String>(
                groupValue: _type,
                onChanged: (v) => setState(() => _type = v),
                child: Column(
                  children: types.entries
                      .map((e) => RadioListTile<String>(
                          title: Text(e.value),
                          value: e.key,
                          contentPadding: EdgeInsets.zero))
                      .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _essayController,
                maxLines: 4,
                decoration: InputDecoration(
                    labelText: _type == 'other'
                        ? s.pleaseDescribeWhatHappenedLabel
                        : s.additionalDetailsOptionalLabel),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final path in _photoPaths)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(AppRadius.sm)),
                        child: Image.file(File(path), fit: BoxFit.cover),
                      ),
                    ),
                  if (_photoPaths.length < 5)
                    InkWell(
                      onTap: _addPhoto,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(AppRadius.sm)),
                        child: const Icon(Icons.add_a_photo_outlined),
                      ),
                    ),
                ],
              ),
              Text(s.photosEvidenceCount(_photoPaths.length),
                  style: AppTypography.label),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(s.submitReportLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _essayController.dispose();
    super.dispose();
  }
}
