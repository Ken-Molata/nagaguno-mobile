// lib/features/cart/presentation/widgets/cart_icon_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/cart_controller.dart';
import '../cart_screen.dart';

class CartIconButton extends ConsumerWidget {
  const CartIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartItemCountProvider);
    return IconButton(
      onPressed: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const CartScreen())),
      icon: Badge(
        label: Text('$count'),
        isLabelVisible: count > 0,
        backgroundColor: AppColors.error,
        textColor: Colors.white,
        child: const Icon(Icons.shopping_cart_outlined),
      ),
    );
  }
}
