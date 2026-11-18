// lib/app_router.dart
//
// Auth-guarded navigation, per the original spec's Section 7
// requirement: unauthenticated users cannot navigate into
// role-gated screens by deep link or back-navigation.
//
// Bottom-nav branches use StatefulShellRoute (see shared/widgets/
// app_shell.dart for the important note on why there's one FIXED
// 7-branch structure shared across all roles, rather than a
// per-role branch set). KYC, splash, login/register, and any
// full-screen push (e.g. verification) stay OUTSIDE the shell as
// top-level routes, since they're not tab destinations.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/navigation/root_navigator_key.dart';
import 'core/session/inactivity_listener.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/application/auth_controller.dart';
import 'features/authentication/presentation/login_screen.dart';
import 'features/authentication/presentation/register_screen.dart';
import 'features/marketplace/presentation/marketplace_screen.dart';
import 'features/marketplace/presentation/product_detail_screen.dart';
import 'features/kyc/presentation/kyc_screen.dart';
import 'features/notifications/presentation/notifications_screen.dart';
import 'features/farmers/presentation/farmers_screen.dart';
import 'features/farmers/presentation/farmer_detail_screen.dart';
import 'features/farmers/presentation/vendors_screen.dart';
import 'features/farmers/presentation/vendor_detail_screen.dart';
import 'features/buyers/presentation/buyer_profile_screen.dart';
import 'features/orders/presentation/orders_screen.dart';
import 'features/products/presentation/my_products_screen.dart';
import 'features/dashboard/presentation/home_screen.dart';
import 'features/dashboard/presentation/easy_mode_home_screen.dart';
import 'features/accessibility/application/accessibility_settings.dart';
import 'features/crop_plans/presentation/crop_plans_screen.dart';
import 'features/crop_plans/presentation/add_crop_plan_screen.dart';
import 'features/agreements/presentation/agreements_screen.dart';
import 'features/agreements/presentation/new_agreement_screen.dart';
import 'features/agreements/presentation/agreement_detail_screen.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/admin/presentation/admin_home_screen.dart';
import 'features/onboarding/presentation/onboarding_flow_screen.dart';
import 'features/walkthrough/presentation/walkthrough_screen.dart';
import 'features/profile/presentation/edit_profile_screen.dart';
import 'features/orders/presentation/order_detail_screen.dart';
import 'features/orders/presentation/checkout_screen.dart';
import 'features/payment_methods/presentation/payment_methods_screen.dart';
import 'features/authentication/presentation/contact_change_screen.dart';
import 'features/authentication/presentation/cancel_email_change_screen.dart';
import 'features/authentication/presentation/email_verification_screen.dart';
import 'features/authentication/presentation/phone_verification_screen.dart';
import 'features/profile/presentation/account_security_screen.dart';
import 'features/appeals/presentation/account_status_screen.dart';
import 'features/reviews/presentation/platform_feedback_screen.dart';
import 'features/conversations/presentation/conversations_list_screen.dart';
import 'features/conversations/presentation/chat_thread_screen.dart';
import 'features/spoilage/presentation/spoilage_monitoring_screen.dart';
import 'features/farmers/presentation/saved_farmers_screen.dart';
import 'shared/widgets/app_shell.dart';

/// Bridges Riverpod's AuthState stream to something GoRouter's
/// refreshListenable can use. This is the correct pattern — using
/// Provider + ref.watch(authControllerProvider) directly in a router
/// provider would recreate the entire GoRouter instance on every auth
/// change (a new object, not just a re-evaluated redirect), which is
/// heavier than necessary and risks losing navigation stack state.
/// refreshListenable re-runs the same router's redirect logic instead.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: _AuthChangeNotifier(ref),
    // UW 2.4: a route change counts as "navigation" activity even when
    // it wasn't itself a direct pointer event (a redirect, go_router's
    // own programmatic pushes).
    observers: [
      InactivityNavigatorObserver(
          () => ref.read(inactivityGuardProvider).recordActivity()),
    ],
    redirect: (context, state) {
      // Read (not watch) — this callback re-runs because
      // refreshListenable fired, not because of a widget rebuild, so
      // ref.read is correct here; ref.watch has no meaning outside a
      // build method / provider body.
      final authState = ref.read(authControllerProvider);
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      final onSplash = state.matchedLocation == '/splash';
      // UW 21.2's "This wasn't me" email-change-cancel link is
      // deliberately reachable with no session (see
      // CancelEmailChangeScreen's own comment) -- same auth-redirect
      // exemption as /login and /register, not gated behind one.
      final onCancelEmailChange =
          state.matchedLocation == '/settings/cancel-email-change';
      // Admin has no bottom-nav tab structure at all (see app_shell.dart —
      // tabsForRole falls back to buyer tabs for any unrecognized role,
      // which would be actively wrong for admin). Routed to its own
      // dedicated top-level screen instead of into the shell entirely.
      final isAdmin = authState.user?.role == 'admin';
      // UW 17.5: login() now succeeds for a suspended/banned account
      // (see authController.js's own comment on that fix) specifically
      // so they can reach this screen instead of being locked out with
      // no session at all -- forced here the same way Admin is forced
      // to /admin, since nothing else in the app is usable for them.
      final isPenalized = authState.user?.isPenalized ?? false;
      final onAccountStatus = state.matchedLocation == '/account-status';
      // UW 2.3: "shown automatically only once," before reaching the
      // dashboard, regardless of HOW the user authenticated (login,
      // register+onboarding, Google, 2FA) -- checked centrally here
      // rather than at each of those separate entry points, so it
      // can't be missed from one of them. /onboarding is exempted so
      // UW 1.1's existing registration flow (Buyer/Vendor only) isn't
      // interrupted mid-flow; the walkthrough still catches them right
      // after, the moment they'd otherwise land on /home.
      final onWalkthrough = state.matchedLocation == '/walkthrough';
      final onOnboarding = state.matchedLocation == '/onboarding';
      // REAL, SEVERE BUG FOUND AND FIXED: the /onboarding exemption
      // above only covered onboarding itself, not the screens that
      // lead up to it. register_screen.dart's register() call ends by
      // calling login() internally, which sets authState to
      // authenticated; email_verification_screen.dart/
      // phone_verification_screen.dart's own _verify() calls
      // refreshUser(). Both fire this redirect via refreshListenable
      // immediately, while the screen is STILL sitting on /register,
      // /verify-email, or /verify-phone -- with hasSeenWalkthrough
      // false for every brand-new account, needsWalkthrough was
      // already true and neither onWalkthrough nor onOnboarding
      // matched that location, so the redirect fired to /walkthrough
      // on its own, disposing the screen before its own next line
      // (the `context.go('/verify-email?next=/onboarding')` or
      // `context.go('/onboarding')` call) ever ran -- silently
      // swallowed by that screen's own `if (!mounted) return;` guard.
      // Confirmed live: a brand new account landed straight on the
      // walkthrough's text-size step, with no OTP verification screen
      // and no Preferences/Interests step shown at all. Exempting
      // these three the same way /onboarding and /walkthrough already
      // are lets the whole registration chain run uninterrupted; the
      // walkthrough still catches the user right after, the moment
      // they actually reach /home, exactly as already intended.
      final onPreOnboardingStep = state.matchedLocation == '/register' ||
          state.matchedLocation == '/verify-email' ||
          state.matchedLocation == '/verify-phone';
      final needsWalkthrough =
          authState.user != null && !authState.user!.hasSeenWalkthrough;

      switch (authState.status) {
        case AuthStatus.unknown:
          return onSplash ? null : '/splash';
        case AuthStatus.unauthenticated:
          return (loggingIn || onCancelEmailChange) ? null : '/login';
        case AuthStatus.authenticated:
          if (isPenalized) {
            return onAccountStatus ? null : '/account-status';
          }
          if (isAdmin) {
            return state.matchedLocation == '/admin' ? null : '/admin';
          }
          if (needsWalkthrough &&
              !onWalkthrough &&
              !onOnboarding &&
              !onPreOnboardingStep) {
            return '/walkthrough';
          }
          if (loggingIn || onSplash) return '/home';
          return null;
      }
    },
    routes: [
      // ── Outside the shell: full-screen flows, no bottom nav ──
      GoRoute(path: '/splash', builder: (_, __) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/onboarding',
          builder: (_, __) => const OnboardingFlowScreen()),
      // UW 2.3: auto-shown once via the redirect above; also reachable
      // manually to replay it (Profile's "App Walkthrough" tile).
      GoRoute(
          path: '/walkthrough',
          builder: (_, __) => const WalkthroughScreen()),
      GoRoute(
          path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
      // UW 1.2/21.3: a seller's own GCash/bank receiving details,
      // which had no mobile screen at all before this.
      GoRoute(
          path: '/payment-methods',
          builder: (_, __) => const PaymentMethodsScreen()),
      // UW 21.2: change email / change phone number -- same screen,
      // parametrized by channel (see ContactChangeScreen's own comment).
      GoRoute(
          path: '/profile/change-email',
          builder: (_, __) =>
              const ContactChangeScreen(channel: ContactChannel.email)),
      GoRoute(
          path: '/profile/change-phone',
          builder: (_, __) =>
              const ContactChangeScreen(channel: ContactChannel.phone)),
      // UW 21.2's "This wasn't me" link -- public, reachable with no
      // session (see CancelEmailChangeScreen's own comment and the
      // onCancelEmailChange redirect exemption above).
      GoRoute(
        path: '/settings/cancel-email-change',
        builder: (_, state) => CancelEmailChangeScreen(
            token: state.uri.queryParameters['token'] ?? ''),
      ),
      // UW 21.2: Password, Two-Factor Authentication, Logged-in
      // Devices -- the rest of Account & Security not covered above.
      GoRoute(
          path: '/profile/account-security',
          builder: (_, __) => const AccountSecurityScreen()),
      // UW 1.3: the OTP-code step registration's own success message
      // promises ("Log in, then enter the code we emailed you...").
      GoRoute(
        path: '/verify-email',
        builder: (_, state) => EmailVerificationScreen(
            nextRoute: state.uri.queryParameters['next'] ?? '/home'),
      ),
      // Phone-channel counterpart of /verify-email above -- see
      // PhoneVerificationScreen's own header comment.
      GoRoute(
        path: '/verify-phone',
        builder: (_, state) => PhoneVerificationScreen(
            nextRoute: state.uri.queryParameters['next'] ?? '/home'),
      ),
      // UW 17.5: forced destination for a banned/suspended account
      // (see the redirect above); also reachable normally from
      // Profile for a COD-restricted one.
      GoRoute(
          path: '/account-status',
          builder: (_, __) => const AccountStatusScreen()),
      // UW 14.4.
      GoRoute(
          path: '/feedback',
          builder: (_, __) => const PlatformFeedbackScreen()),
      // UW 13: a working chat backend with no mobile screen at all
      // before this (see routes/conversations.js's own header comment).
      GoRoute(
          path: '/conversations',
          builder: (_, __) => const ConversationsListScreen()),
      GoRoute(
        path: '/conversations/:id',
        builder: (_, state) => ChatThreadScreen(
          conversationId: state.pathParameters['id']!,
          otherUserName: state.uri.queryParameters['name'] ?? 'Conversation',
        ),
      ),
      GoRoute(path: '/kyc', builder: (_, __) => const KycScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminHomeScreen()),
      GoRoute(
          path: '/notifications',
          builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/farmers', builder: (_, __) => const FarmersScreen()),
      GoRoute(
          path: '/farmers/saved',
          builder: (_, __) => const SavedFarmersScreen()),
      GoRoute(
          path: '/farmers/:id',
          builder: (_, state) =>
              FarmerDetailScreen(farmerId: state.pathParameters['id']!)),
      // UW 5: a Vendor can own production plans exactly like a Farmer
      // can -- mirrors the Farmers routes above, which previously had
      // no vendor counterpart at all.
      GoRoute(path: '/vendors', builder: (_, __) => const VendorsScreen()),
      GoRoute(
          path: '/vendors/:id',
          builder: (_, state) =>
              VendorDetailScreen(vendorId: state.pathParameters['id']!)),
      // UW 12.4: reached by tapping the buyer's name/photo on a
      // seller's order detail view (UW 12.2).
      GoRoute(
          path: '/buyers/:id',
          builder: (_, state) =>
              BuyerProfileScreen(buyerId: state.pathParameters['id']!)),
      // NOTE: this must stay declared BEFORE the StatefulShellRoute below
      // — GoRouter matches in declaration order, and without this
      // ordering, "/agreements/new" could incorrectly match the nested
      // "/agreements/:id" pattern (treating "new" as an id) instead of
      // this route. Not verified against a running app (no Flutter SDK
      // in this environment) — flagging the dependency explicitly
      // rather than assuming it's safe to reorder later.
      // UW 4.1/5.1: a Smart Agreement is requested against a specific
      // production plan, not just "a seller" -- sellerId/sellerName
      // alone (the old params here) can no longer reach a working
      // create call, since POST /agreements now requires crop_plan_id.
      // Pushed from FarmerDetailScreen's per-plan "Request Agreement"
      // button with the plan's own fields already in hand, so no extra
      // fetch is needed here.
      // UW 6.1: checkout needs a payment method, a fulfillment method,
      // and the right delivery/pickup fields for it -- POST /orders
      // rejects a direct crop-listing order without all of that.
      // Pushed from ProductDetailScreen's "Place Order" button, which
      // used to call placeOrder() directly with none of this.
      GoRoute(
        path: '/checkout',
        builder: (_, state) {
          final qp = state.uri.queryParameters;
          return CheckoutScreen(
            productId: qp['productId'] ?? '',
            quantity: double.tryParse(qp['quantity'] ?? '') ?? 1,
          );
        },
      ),
      GoRoute(
        path: '/agreements/new',
        builder: (_, state) {
          final qp = state.uri.queryParameters;
          return NewAgreementScreen(
            cropPlanId: qp['cropPlanId'] ?? '',
            cropName: qp['cropName'] ?? 'Crop',
            sellerName: qp['sellerName'] ?? 'Seller',
            unit: qp['unit'] ?? 'kg',
            suggestedPrice: double.tryParse(qp['price'] ?? '') ?? 0,
            availableQuantity: double.tryParse(qp['available'] ?? '') ?? 0,
            harvestMonth:
                int.tryParse(qp['harvestMonth'] ?? '') ?? DateTime.now().month,
            harvestYear:
                int.tryParse(qp['harvestYear'] ?? '') ?? DateTime.now().year,
          );
        },
      ),

      // ── Inside the shell: the 7 fixed branches (see app_shell.dart's
      // branchHome..branchProfile constants — order here MUST match) ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // 0: Home
          StatefulShellBranch(routes: [
            // UW 21.6 Easy Mode: swaps in the simplified large-button
            // home screen when the account has it on -- see
            // EasyModeHomeScreen's own header comment. Every other
            // branch/tab below is untouched by this toggle.
            GoRoute(
              path: '/home',
              builder: (_, __) => Consumer(
                builder: (context, ref, _) =>
                    ref.watch(accessibilitySettingsProvider).easyModeEnabled
                        ? const EasyModeHomeScreen()
                        : const HomeScreen(),
              ),
            ),
          ]),
          // 1: Marketplace (+ nested product detail)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/marketplace',
              builder: (_, __) => const MarketplaceScreen(),
              routes: [
                GoRoute(
                  path:
                      'product/:id', // full path resolves to /marketplace/product/:id
                  builder: (_, state) => ProductDetailScreen(
                      productId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          // 2: Agreements (buyer/vendor-sourcing only)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/agreements',
              builder: (_, __) => const AgreementsScreen(),
              routes: [
                GoRoute(
                    path: ':id',
                    builder: (_, state) => AgreementDetailScreen(
                        agreementId: state.pathParameters['id']!)),
              ],
            ),
          ]),
          // 3: Orders
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/orders',
              builder: (_, __) => const OrdersScreen(),
              routes: [
                GoRoute(
                    path: ':id',
                    builder: (_, state) => OrderDetailScreen(
                        orderId: state.pathParameters['id']!)),
              ],
            ),
          ]),
          // 4: Production (farmer only)
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/crop-plans',
              builder: (_, __) => const CropPlansScreen(),
              routes: [
                GoRoute(
                    path: 'new', builder: (_, __) => const AddCropPlanScreen()),
              ],
            ),
          ]),
          // 5: My Products (farmer) / Listings (vendor) — same screen, two labels
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/my-products',
              builder: (_, __) => const MyProductsScreen(),
              routes: [
                GoRoute(
                    path: 'spoilage',
                    builder: (_, __) => const SpoilageMonitoringScreen()),
              ],
            ),
          ]),
          // 6: Profile / More
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  // Real branding for the FLUTTER-rendered splash (visible for the
  // duration of the auth-status check) -- previously a bare spinner
  // on a plain background, which looked unfinished for the very
  // first thing anyone sees on app launch. Doesn't address the
  // separate NATIVE pre-Flutter launch screen (shown briefly before
  // Flutter itself starts rendering at all), which still depends on
  // `flutter create` generating styles.xml -- same category of gap
  // as the launcher icon noted in PLATFORM_SETUP.md, not something
  // this Dart-level fix can reach.
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('NagaGuno',
                  style: AppTypography.display
                      .copyWith(color: AppColors.accent, fontSize: 40)),
              const SizedBox(height: AppSpacing.lg),
              const CircularProgressIndicator(color: AppColors.accent),
            ],
          ),
        ),
      );
}
