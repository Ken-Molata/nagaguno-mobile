// lib/shared/widgets/copyable_value.dart
//
// UW 1.2: "a copy icon on the account number, the same way a seller's
// receiving details are copyable at checkout" -- both sides of that
// comparison were actually missing before this (grepped the whole app:
// zero Clipboard usage anywhere). Shared here so the account-settings
// screen and the order-detail "send payment to" section use the exact
// same affordance rather than two copies of the same snackbar logic.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

/// A label/value row with a trailing copy-to-clipboard icon button.
class CopyableValue extends StatelessWidget {
  const CopyableValue({
    super.key,
    required this.value,
    this.label,
    this.style,
  });

  final String value;
  final String? label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label == null ? value : '$label: $value',
            style: style ?? AppTypography.body,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 16),
          tooltip: 'Copy',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Copied to clipboard.'),
                    duration: Duration(seconds: 1)),
              );
            }
          },
        ),
      ],
    );
  }
}
