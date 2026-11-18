// lib/core/validation/password_requirements_checklist.dart
//
// See password_requirements.dart's header for the exact UW 1 (and 2.1)
// text this renders. Driven by a TextEditingController via
// ValueListenableBuilder (TextEditingController is itself a
// ValueNotifier<TextEditingValue>) so it updates on every keystroke
// without the host screen needing its own setState wiring for this.

import 'package:flutter/material.dart';
import '../localization/app_strings.dart';
import '../theme/app_theme.dart';
import 'password_requirements.dart';

class PasswordRequirementsChecklist extends StatelessWidget {
  const PasswordRequirementsChecklist(
      {super.key, required this.controller, required this.strings});
  final TextEditingController controller;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final password = value.text;
        final requirements = passwordRequirements(strings);
        final allMet = requirements.every((r) => r.test(password));

        if (password.isEmpty) return const SizedBox.shrink();

        if (allMet) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(strings.passwordAccepted,
                style: AppTypography.label.copyWith(
                    color: AppColors.statusSuccessFg,
                    fontWeight: FontWeight.w600)),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: requirements.map((r) {
              final met = r.test(password);
              final color = met ? AppColors.statusSuccessFg : AppColors.error;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    Icon(met ? Icons.check_circle : Icons.cancel,
                        size: 13, color: color),
                    const SizedBox(width: 6),
                    Text(r.label,
                        style: AppTypography.label.copyWith(color: color)),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
