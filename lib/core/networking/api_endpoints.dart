// lib/core/networking/api_endpoints.dart
//
// Every path below verified directly against the real, live backend
// route files this session (routes/auth.js, routes/kyc.js,
// routes/orders.js, etc.) — not assumed from a naming convention.

import '../configuration/env_config.dart';

class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = EnvConfig.apiBaseUrl;

  // Auth
  static const register = '/auth/register';
  static const login = '/auth/login';
  // UW 2.2: when the account has 2FA on, POST /auth/login returns
  // {requires2FA: true, userId} instead of tokens -- these two finish
  // that second step. Had no mobile caller at all before this, which
  // meant a 2FA-enabled account couldn't actually complete login
  // (login() would throw trying to read a non-existent access_token).
  static const loginVerify2FA = '/auth/login/verify-2fa';
  static const loginResend2FA = '/auth/login/resend-2fa';
  static const adminLogin = '/auth/admin/login';

  // UW 1.3: the OTP-code verification step registration's own message
  // ("Log in, then enter the code we emailed you...") promises, which
  // had no mobile screen or repository call at all before this --
  // also the one real activation step a Buyer account has (see
  // NagagunoUser.isEmailVerified's own doc comment).
  static const verifyEmail = '/auth/verify-email';
  static const verifyEmailResend = '/auth/verify-email/resend';

  // Same activation step as verifyEmail/verifyEmailResend above, for a
  // phone-registered account (auth_provider = 'phone', no email on
  // file) -- registration now lets the user pick either channel.
  static const verifyPhoneRequest = '/auth/verify-phone/request';
  static const verifyPhoneConfirm = '/auth/verify-phone/confirm';

  // UW 21.2: change email / change phone number, both require-then-
  // confirm-with-OTP, neither of which had any mobile screen at all
  // before this despite the backend fully supporting them.
  static const changeEmailRequest = '/auth/change-email/request';
  static const changeEmailConfirm = '/auth/change-email/confirm';
  static const changeEmailCancel = '/auth/change-email/cancel';
  // UW 21.2's "This wasn't me" link, sent to the OLD address -- real,
  // concrete gap found and fixed this pass: the backend has always
  // generated and emailed this link (controllers/authController.js's
  // cancelEmailChangeByLink, unauthenticated by design so it works even
  // from a device with no session), but nothing in the app ever had a
  // screen or route to land on when it's actually clicked.
  static const changeEmailCancelByLink = '/auth/change-email/cancel-by-link';
  // UW 21.2's "Resend link" on the pending-change state -- real gap
  // found and fixed this pass, see NagagunoUser.pendingEmail's own
  // doc comment.
  static const changeEmailResend = '/auth/change-email/resend';
  static const changePhoneRequest = '/auth/change-phone/request';
  static const changePhoneConfirm = '/auth/change-phone/confirm';
  static const changePhoneCancel = '/auth/change-phone/cancel';
  static const changePhoneResend = '/auth/change-phone/resend';

  // UW 21.2: Password (while logged in, distinct from forgot-password)
  // and Logged-in devices -- neither had any mobile screen, or even a
  // backend endpoint for the password case, before this.
  static const changePassword = '/auth/change-password';
  static const authDevices = '/auth/devices';
  static String authDeviceLogout(String id) => '/auth/devices/$id/logout';
  static const authDevicesLogoutAllOthers = '/auth/devices/logout-all-others';

  // UW 21.2: Two-factor authentication toggle -- backend existed, no
  // mobile screen called any of these three before this.
  static const twoFactorToggle = '/auth/2fa/toggle';
  static const twoFactorEnableRequest = '/auth/2fa/enable/request';
  static const twoFactorEnableConfirm = '/auth/2fa/enable/confirm';

  // UW 2.5: Locked-Out Account Recovery -- a fully working, fairly
  // involved backend (routes/accountRecovery.js: enumeration-safe
  // identity check, Didit Route A/B id-check, then reason+submit) with
  // no mobile screen at all before this.
  static const recoveryVerifyIdentity = '/account-recovery/verify-identity';
  // REAL BUG FOUND AND FIXED: AccountRecoveryScreen's Step 2 used to
  // call kycIdTypes below (GET /kyc/id-types) for the Admin-editable
  // Route table -- always a 401 here, since that endpoint sits behind
  // routes/kyc.js's own router.use(authenticate) and this entire
  // screen is, by definition, for someone who can't log in. This is
  // the same data, same snake_case shape, from a route this router
  // never puts behind authenticate (see accountRecovery.js's own
  // comment on it).
  static const recoveryIdTypes = '/account-recovery/id-types';
  // UW 2.5 Step 2 / UW 10.2: same Screen Flash Challenge as KYC.
  static const recoveryLivenessChallenge = '/account-recovery/liveness-challenge';
  static const recoveryIdCheck = '/account-recovery/id-check';
  static const recoverySubmit = '/account-recovery/submit';
  static const recoveryCheck = '/account-recovery/check';
  // Answers an Admin's "Request More Information" decision -- no
  // login, same request_number + date_of_birth identity check as
  // recoveryCheck above.
  static const recoveryRespond = '/account-recovery/respond';
  static const recoveryDispute = '/account-recovery/dispute';
  // UW 2.5 Step 4, web admin app only.
  static const recoveryAdminQueue = '/account-recovery/admin/queue';
  static String recoveryAdminDetail(String id) =>
      '/account-recovery/admin/$id';
  static String recoveryAdminLinkAccount(String id) =>
      '/account-recovery/admin/$id/link-account';
  static String recoveryAdminDecision(String id) =>
      '/account-recovery/admin/$id/decision';

  // UW 17.5: a single appeal against a ban, suspension, or COD
  // restriction. Only reachable for ban/suspension at all after this
  // session's login()/authenticateAllowPenalized fix -- see
  // routes/appeals.js's and middleware/auth.js's own comments.
  static const appeals = '/appeals';
  static const appealsMine = '/appeals/mine';
  // UW 17.5: "the Appeal entry point for that specific penalty is
  // disabled or removed from view at the source" -- lets the UI know
  // before showing the button, rather than relying on POST /'s own
  // 404/409 to silently block a retry.
  static const appealsEligibility = '/appeals/eligibility';
  static const appealsAdminQueue = '/appeals/admin/queue';
  static String appealsAdminDetail(String id) => '/appeals/admin/$id';
  static String appealsAdminDecision(String id) =>
      '/appeals/admin/$id/decision';

  // UW 9/7.6/17.6/17.7: filing a report/dispute against another user --
  // a general transaction issue, a non-arrival claim, or a conduct
  // complaint.
  static const reports = '/reports';
  static const reportsMine = '/reports/mine';
  static const reportsAdminQueue = '/reports/admin/queue';
  static String reportsAdminDetail(String id) => '/reports/admin/$id';
  static String reportsAdminDecision(String id) =>
      '/reports/admin/$id/decision';

  // UW 9.3: "Users may block another specific user independently of
  // filing a report" -- a real, working backend (routes/blocks.js,
  // wired into marketplace/recommendation/conversations browsing and
  // messaging exclusion) with no mobile screen or call anywhere before
  // this.
  static const blocks = '/blocks';
  static String blockDetail(String userId) => '/blocks/$userId';

  // UW 9.4 escalated refund requests, web admin app only.
  static const refundsAdminQueue = '/refunds/admin/queue';
  static String refundsAdminDecision(String id) =>
      '/refunds/admin/$id/decision';

  // UW 9.4 refund requests -- buyer files, seller responds. REAL GAP
  // FOUND AND FIXED: the real backend (routes/refunds.js) had every
  // one of these endpoints working with zero mobile caller for any of
  // them -- only the admin web escalation queue above ever reached
  // this router. A buyer blocked from cancelling an already-paid
  // order (see order_detail_screen.dart's ALREADY_PAID handling) had
  // nowhere to actually go.
  static const refunds = '/refunds';
  static const refundsMine = '/refunds/mine';
  static String refundDetail(String id) => '/refunds/$id';
  static String refundRespond(String id) => '/refunds/$id/respond';
  static String refundEscalate(String id) => '/refunds/$id/escalate';
  static String refundProcessLater(String id) => '/refunds/$id/process-later';
  static String refundComplete(String id) => '/refunds/$id/complete';

  // UW 21.1 "Request a correction," web admin app only.
  static const correctionsAdminQueue = '/profile-corrections/admin/queue';
  static String correctionsAdminDetail(String id) =>
      '/profile-corrections/admin/$id';
  static String correctionsAdminDecision(String id) =>
      '/profile-corrections/admin/$id/decision';


  // UW 14 (Reviews & Ratings) — a real, working feature
  // (routes/reviews.js) with no mobile screen at all before this.
  static const reviews = '/reviews';
  static String reviewsForUser(String userId) => '/reviews/user/$userId';
  static const reviewsFeedback = '/reviews/feedback';
  // UW 14.1: a separate product review, distinct from the seller
  // review above -- added via the product_reviews table/migration.
  static const reviewsProduct = '/reviews/product';
  static String reviewsForProduct(String productId) =>
      '/reviews/product/$productId';

  // UW 13 (In-App Communication) -- a real, working backend
  // (routes/conversations.js) with no mobile screen at all before
  // this, and silently broken the whole time regardless until this
  // session's conversations_messages_rls migration.
  static const conversations = '/conversations';
  static String conversationMessages(String conversationId) =>
      '/conversations/$conversationId/messages';
  static const conversationsUnreadCount = '/conversations/unread-count';

  // UW 15's proposed push channel (FCM) -- where a device registers
  // the token the backend pushes to.
  static const devices = '/devices';
  static String deviceToken(String token) =>
      '/devices/${Uri.encodeComponent(token)}';

  static const googleAuth = '/auth/google';
  static const forgotPassword = '/auth/forgot-password';
  static const resetPassword = '/auth/reset-password';
  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';
  static const me = '/auth/me';

  // KYC
  static const kycSubmit = '/kyc/submit';
  // UW 10.2: issues a fresh Screen Flash Challenge for one capture attempt.
  static const kycLivenessChallenge = '/kyc/liveness-challenge';
  // UW 10.1's Route table -- now Admin-editable (migration 027).
  static const kycIdTypes = '/kyc/id-types';
  static String kycIdTypeDetail(String idType) => '/kyc/id-types/$idType'; // admin
  static const kycMe = '/kyc/me';
  static const kycQueue = '/kyc/queue'; // admin
  static String kycDetail(String id) => '/kyc/$id'; // admin
  static String kycDecision(String id) => '/kyc/$id/decision'; // admin

  // Profile
  static const profileMe = '/profiles/me';
  static const profilePhoto = '/profiles/me/photo';
  static const preferences = '/profiles/preferences';
  // UW 21.5/21.7 -- deliberately separate from `preferences` above,
  // which is the UW 1.1 onboarding-category preferences, a different
  // feature despite the similar name.
  static const accountSettings = '/profiles/account-settings';
  // UW 2.3: marks the First-Time Walkthrough as seen.
  static const walkthroughSeen = '/profiles/walkthrough-seen';
  // UW 17.3's "red indicator" (Near Suspension / Suspended) -- backend
  // (utils/violations.js's getViolationIndicator) already existed and
  // was already used by the Admin users screen, but nothing fetched it
  // for the account holder's OWN profile, despite 17.3 explicitly
  // naming them as one of only two audiences who should ever see it.
  static const violationStatus = '/profiles/violation-status';
  // UW 21.1: "Request a correction" for a verified account's name/DOB.
  static const profileCorrections = '/profile-corrections';
  static const profileCorrectionsMine = '/profile-corrections/mine';
  static const profileFarmers = '/profiles/farmers';
  static const savedFarmers = '/profiles/farmers/saved';
  static String profileFarmerDetail(String id) => '/profiles/farmers/$id';
  static String saveFarmer(String id) => '/profiles/farmers/$id/save';

  // Products (own-listing management — farmer/vendor)
  static const products = '/products';
  static String productDetail(String id) => '/products/$id';
  static String productToggle(String id) => '/products/$id/toggle';
  // The real path from a production plan (UW 5) to a crop listing
  // (UW 3) once the crop is actually harvested.
  static String productFromPlan(String planId) => '/products/from-plan/$planId';

  // Marketplace — verified exact paths against the real route file
  static const marketplaceProducts = '/marketplace/products';
  static const marketplaceFlashSale = '/marketplace/flash-sale';
  static String marketplaceProductDetail(String id) =>
      '/marketplace/products/$id';
  // UW 5.1/20.1: the marketplace's "Production Plans" view -- market-
  // wide, distinct from GET /production (self-scoped to the caller's
  // own plans) and GET /profiles/farmers/:id's crop_plans (scoped to
  // one seller).
  static const marketplaceProductionPlans = '/marketplace/production-plans';

  // Crop plans — real mount point is /api/production, NOT /crop-plans
  // (verified directly against server.js this session, despite the
  // route file being named cropPlans.js).
  static const cropPlans = '/production';
  static String cropPlanDetail(String id) => '/production/$id';
  // UW 4.3: raising a plan's own quantity post-agreement -- see
  // crop_plans_repository.dart's own comment for why PATCH /:id can't
  // do this once any agreement exists against the plan.
  static String cropPlanAddQuantity(String id) => '/production/$id/add-quantity';

  // Orders — re-verified against the real routes/orders.js this
  // session. POST / requires a full fulfillment/payment contract
  // (fulfillment_method, payment_channel, delivery/pickup fields) that
  // nothing here was sending at all -- every placeOrder call would
  // have 400'd against validateFulfillment(). The rest of these
  // (proof, retry-payment, ready-for-pickup, reschedule, cancel-at-
  // fulfillment, decline-paid) existed on the backend with no mobile
  // caller at all.
  static const orders = '/orders';
  static String orderDetail(String id) => '/orders/$id';
  static String orderStatus(String id) => '/orders/$id/status';
  static String orderProof(String id) => '/orders/$id/proof';
  static String orderRetryPayment(String id) => '/orders/$id/retry-payment';
  static String orderReadyForPickup(String id) =>
      '/orders/$id/ready-for-pickup';
  static String orderReschedule(String id) => '/orders/$id/reschedule';
  static String orderDeliveryLocation(String id) =>
      '/orders/$id/delivery-location';
  static String orderCancelAtFulfillment(String id) =>
      '/orders/$id/cancel-at-fulfillment';
  static String orderDeclinePaid(String id) => '/orders/$id/decline-paid';
  static String orderNote(String id) => '/orders/$id/note';

  // Agreements — re-verified against the real routes/agreement.js after
  // this session's UW 4.1 negotiation-loop / UW 4.3 expiry / UW 5.2
  // rewrite. There is no generic PATCH /:id and no /:id/proof route any
  // more (proof moved to orders.js, reused via the agreement's linked
  // order_id once Active) — both removed. Accept/Reject/Propose/
  // farmer-adjustment/rounds added; cancel is DELETE /:id with a
  // required reason body, not a PATCH.
  static const agreements = '/agreements';
  static String agreementDetail(String id) => '/agreements/$id';
  static String agreementAccept(String id) => '/agreements/$id/accept';
  static String agreementReject(String id) => '/agreements/$id/reject';
  static String agreementPropose(String id) => '/agreements/$id/propose';
  static String agreementFarmerAdjustment(String id) =>
      '/agreements/$id/farmer-adjustment';
  static String agreementRounds(String id) => '/agreements/$id/rounds';

  // Spoilage
  static const spoilageMyListings = '/spoilage/my-listings';
  static String spoilageReport(String productId) =>
      '/spoilage/report/$productId';
  static String spoilageSale(String productId) => '/spoilage/sale/$productId';
  static String spoilageRecommendationRespond(String id) =>
      '/spoilage/recommendations/$id/respond';
  static String spoilageUnhide(String productId) =>
      '/spoilage/unhide/$productId';
  static String spoilageCvOverride(String productId) =>
      '/spoilage/cv-override/$productId';
  static const spoilageFreshnessModelInfo = '/spoilage/freshness-model-info';
  static const spoilageDashboard = '/spoilage/dashboard'; // admin

  // Notifications
  static const notifications = '/notifications';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const notificationsReadAll = '/notifications/read-all';

  // Dashboard — three separate, role-gated endpoints (verified this
  // session), not one generic endpoint.
  static const dashboardBuyer = '/dashboard/buyer';
  static const dashboardFarmer = '/dashboard/farmer';
  static const dashboardVendor = '/dashboard/vendor';

  // UW 16: Sales/Inventory Analytics + Transaction History.
  static const analyticsSales = '/analytics/sales';
  static const analyticsTransactions = '/analytics/transactions';

  // Admin
  static const adminAnalytics = '/admin/analytics';
  static const adminUsers = '/admin/users';
  static String adminUserDetail(String id) => '/admin/users/$id';
  static const adminOrders = '/admin/orders';
  static const adminAgreements = '/admin/agreements';
  static const adminListings = '/admin/listings';
  static String adminListingDetail(String id) => '/admin/listings/$id';
  static const adminFeedback = '/admin/feedback';
  // UW 6.1 Gateway settlement, web admin app only.
  static const adminSettlements = '/admin/settlements';
  static String adminSettlementDetail(String sellerId) =>
      '/admin/settlements/$sellerId';
  // UW 8 Generate Reports -- four platform-wide report types, each
  // optionally downloadable via ?format=csv on the same URL.
  static const adminReportsAgreements = '/admin/reports/agreements';
  static const adminReportsOrders = '/admin/reports/orders';
  static const adminReportsVendorPerformance =
      '/admin/reports/vendor-performance';
  static const adminReportsMarketDemand = '/admin/reports/market-demand';
  // UW 3.3 "Farmer feedback" on shelf life, web admin app only.
  static const adminShelfLifeFeedbackQueue = '/admin/shelf-life-feedback/queue';
  static String adminShelfLifeFeedbackDecision(String id) =>
      '/admin/shelf-life-feedback/$id/decision';
  // UW 3.3: the farmer/vendor's own submission, from their listing.
  static String productShelfLifeFeedback(String productId) =>
      '/products/$productId/shelf-life-feedback';

  // Demand forecast — re-verified against the real routes/demand.js
  // this session: /predict and /predict/batch don't exist on the
  // backend at all any more (replaced earlier this session with a
  // per-category model computed from the seller's own order history,
  // deliberately dropping the old synthetic-dataset Flask model). The
  // real, current route is GET /demand/forecast?category=.
  static const demandForecast = '/demand/forecast';

  // Payment methods (UW 1.2/21.3's "Linked Payment Account") — a
  // seller's own GCash/bank receiving details, managed by the seller
  // themselves (paymentMethodsMe/create/delete), plus the buyer-side
  // availability check (UW 6.1: Manual Transfer is shown disabled up
  // front when the seller has none on file, not discovered via a
  // rejected order). The actual receiving details, once Active/an
  // order exists, stay behind the order/agreement detail endpoints,
  // never a standalone cross-user lookup.
  static const paymentMethodsMe = '/payment-methods/me';
  static const paymentMethods = '/payment-methods';
  static String paymentMethodDetail(String id) => '/payment-methods/$id';
  static String paymentMethodAvailability(String sellerId) =>
      '/payment-methods/availability/$sellerId';

  // Vendors — mirrors the Farmers endpoints above (UW 5: a Vendor can
  // own production plans exactly like a Farmer can, but had no public
  // browse path at all before this).
  static const vendors = '/profiles/vendors';
  static String vendorDetail(String id) => '/profiles/vendors/$id';

  // UW 12.4: Buyer Profile (Full View), reached from an order or
  // agreement (UW 12.2).
  static String buyerDetail(String id) => '/profiles/buyers/$id';

  // Recommendations (UW 20.1) — re-verified against the real
  // routes/recommendation.js this session: the old POST /recommendations/
  // all with buyer_id in the body doesn't exist at all any more (removed
  // as a real security fix -- buyer identity now comes only from the
  // authenticated session). Replaced with two separate GET endpoints;
  // there is no single combined products+farmers response.
  static const recommendations = '/recommendations';
  static const recommendationsFarmers = '/recommendations/farmers';
  // Product-detail "You may also like" -- real item-item CF
  // (strategy: 'item_cf'), falling back server-side to same-category
  // popularity ('category_popularity_fallback') when a product has no
  // CF data yet. See routes/recommendation.js's GET /similar/:product_id.
  static String recommendationsSimilar(String productId) =>
      '/recommendations/similar/$productId';

  // Vendor business permits — separate from KYC (personal identity);
  // verifies business legitimacy for the Vendor role specifically. See
  // routes/vendorPermits.js's own header for the full reasoning.
  static const vendorPermitsReference = '/vendor-permits/reference';
  static const vendorPermitsMine = '/vendor-permits/my';
  static const vendorPermitsSubmit = '/vendor-permits';
  static const vendorPermitsAdminQueue = '/vendor-permits/admin';
  static String vendorPermitsAdminDocument(String id) =>
      '/vendor-permits/admin/$id/document';
  static const vendorPermitsAdminDemoRegistry =
      '/vendor-permits/admin/demo-registry';
  static String vendorPermitsAdminDecide(String id) =>
      '/vendor-permits/admin/$id/decide';
}
