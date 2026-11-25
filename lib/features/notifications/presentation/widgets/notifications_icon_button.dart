// lib/features/notifications/presentation/widgets/notifications_icon_button.dart
//
// REAL GAP FOUND AND FIXED: GET /notifications has been reachable from
// the admin web app's own bell (admin_notification_bell.dart) since
// that was built, but the consumer app (Buyer/Farmer/Vendor) only ever
// reached /notifications from one Profile tile buried under Account &
// Security -- the exact "buried in Profile" gap messages_icon_button.dart's
// own header comment already describes and fixed for conversations,
// just never carried over to notifications. Mirrors that same
// icon+badge pattern exactly.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/notifications_unread_provider.dart';

class NotificationsIconButton extends ConsumerWidget {
  const NotificationsIconButton({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(notificationsUnreadCountProvider).valueOrNull ?? 0;
    return IconButton(
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        label: Text(count > 99 ? '99+' : '$count'),
        isLabelVisible: count > 0,
        backgroundColor: AppColors.error,
        textColor: Colors.white,
        child: Icon(Icons.notifications_outlined, color: color),
      ),
    );
  }
}
