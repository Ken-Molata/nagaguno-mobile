// lib/features/authentication/domain/nagaguno_user.dart
//
// Fields verified against the real login/register/adminLogin/
// googleAuth response bodies (controllers/authController.js) — note
// email and phone_number are both nullable since the backend allows
// registering with either one, not both.

class NagagunoUser {
  const NagagunoUser({
    required this.id,
    required this.fullName,
    required this.role,
    required this.accountStatus,
    this.email,
    this.phoneNumber,
    this.suspendedUntil,
    this.codRestrictedUntil,
    this.language = 'en',
    this.smsDeliveryUpdates = true,
    this.emailDeliveryUpdates = true,
    this.dateOfBirth,
    this.age,
    this.textSize = 'standard',
    this.textSizeSetByUser = false,
    this.highContrast = false,
    this.boldText = false,
    this.reduceMotion = false,
    this.readAloudEnabled = false,
    this.easyModeEnabled = false,
    this.hasSeenWalkthrough = false,
    this.twoFactorEnabled = false,
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.pendingEmail,
    this.pendingPhoneNumber,
  });

  final String id;
  final String fullName;
  final String role; // 'buyer' | 'farmer' | 'vendor' | 'admin'
  /// 'pending_verification' | 'active' | 'suspended' | 'blocked' —
  /// this, not the KYC submission's own status, is what the real
  /// backend's requireVerified middleware actually checks (verified
  /// directly against middleware/auth.js this session). A KYC
  /// submission being 'approved' is what CAUSES this to flip to
  /// 'active', but this field is the one every gated-action check in
  /// the app should read.
  final String accountStatus;
  final String? email;
  final String? phoneNumber;

  /// UW 1.3: present on login/register/verifyLogin2FA/googleAuth AND
  /// getMe (controllers/authController.js's completeLogin includes it
  /// directly, unlike language/twoFactorEnabled below) -- gates
  /// requireVerified-protected actions (listing, ordering, agreements)
  /// server-side regardless of role, and additionally gates a Buyer's
  /// own account_status transition to 'active' (see authController.js's
  /// verifyEmail -- REAL, SEVERE BUG FOUND AND FIXED this pass: nothing
  /// anywhere in this codebase previously activated a Buyer account at
  /// all, confirmed live against the real DB, where "active" buyers
  /// turned out to be directly-seeded rows with no real KYC/verification
  /// history).
  final bool isEmailVerified;

  /// Same gate as [isEmailVerified], for a phone-registered account
  /// (auth_provider = 'phone', no email on file) -- requireVerified
  /// checks whichever of the two matches how this account registered
  /// (see middleware/auth.js's own updated doc comment). Present on
  /// login/register/verifyLogin2FA/googleAuth AND getMe, same as
  /// isEmailVerified.
  final bool isPhoneVerified;

  /// UW 1.4/21.5: 'en' | 'tl'. Only ever present on /auth/me's response
  /// (controllers/authController.js's getMe -- REAL BUG FOUND AND FIXED
  /// this pass: this field and the two below were saved correctly by
  /// PATCH /profiles/account-settings, but getMe's own SELECT never
  /// listed them, so refreshUser() silently reverted the cached session
  /// user back to the defaults on every call) -- login/register don't
  /// return it, so this defaults to 'en' until the first getMe() call,
  /// matching UW 1.4's own "English is the default until changed."
  final String language;

  /// UW 21.7: both default true, matching "two separate switches,
  /// both on by default."
  final bool smsDeliveryUpdates;
  final bool emailDeliveryUpdates;

  /// UW 21.1's "Your verified details" card -- entered at registration
  /// (Section 1), matched against the user's ID (Section 10), and never
  /// directly editable afterward (see routes/profile.js's own header
  /// comment: the real fix for a genuine mistake is UW 21.1's "Request a
  /// correction" flow, not a free-text PATCH). [age] is the server's own
  /// computed value (controllers/authController.js's getMe), not
  /// recomputed client-side, so it always matches what the card showed
  /// at the moment of the last session refresh.
  final DateTime? dateOfBirth;
  final int? age;

  /// UW 17.5: login() now succeeds (issuing a real token) for a
  /// suspended/blocked account too, specifically so they can reach the
  /// appeal screen -- these two fields, only ever present right after
  /// login/verifyLogin2FA/googleAuth, are what tell the router which
  /// penalty (if any) to route them to appeal instead of /home.
  final DateTime? suspendedUntil;
  final DateTime? codRestrictedUntil;

  /// UW 21.6: "The settings belong to the account, so they follow the
  /// user to every device." REAL BUG FOUND AND FIXED this pass: these
  /// were previously stored ONLY in shared_preferences (device-local),
  /// directly contradicting that requirement -- same class of mistake
  /// as [language]/[smsDeliveryUpdates] before this session's earlier
  /// fix. [textSize] is one of UW 21.6's exact four named tiers:
  /// 'standard' | 'large' | 'extra_large' | 'maximum'.
  final String textSize;

  /// UW 21.6's "Aa" quick-access control reconciliation rule: "at
  /// login, the account's saved settings apply, and if the account has
  /// none saved, the device's choice is saved to the account." [textSize]
  /// always has a value (defaults to 'standard' server-side), so this
  /// separate flag is what actually distinguishes "never explicitly
  /// set" from "explicitly chose Standard" -- only ever present on
  /// /auth/me's response, same caveat as [language]/[twoFactorEnabled]
  /// above.
  final bool textSizeSetByUser;
  final bool highContrast;
  final bool boldText;
  final bool reduceMotion;

  /// UW 21.6 Read Aloud: "when on, a speaker button appears beside
  /// listings, notifications, and order status text." Only ever
  /// present on /auth/me's response, same caveat as [textSizeSetByUser]
  /// above.
  final bool readAloudEnabled;

  /// UW 21.6 Easy Mode: "larger tap targets with more space between
  /// them, an icon and a word on every navigation item, and a
  /// simplified home screen that shows the user's most-used actions as
  /// large buttons. It never removes a feature; everything else stays
  /// under 'More.'" Only ever present on /auth/me's response, same
  /// caveat as [readAloudEnabled] above.
  final bool easyModeEnabled;

  /// UW 2.3 First-Time Walkthrough: "shown automatically only once."
  /// Real present on every login/register/googleAuth response now
  /// (controllers/authController.js's completeLogin and googleAuth
  /// both fixed this pass to include it) -- a missing value here
  /// would otherwise make the walkthrough wrongly re-trigger on every
  /// login for an account that has already seen it, so this defaults
  /// to false only as a last-resort fallback, not the expected path.
  final bool hasSeenWalkthrough;

  /// UW 21.2: only ever present on /auth/me's response (same caveat
  /// as [language] above -- login/register don't return it), so this
  /// defaults to false until the first getMe() call.
  final bool twoFactorEnabled;

  /// UW 21.2: "Until the new address is verified ... Settings shows
  /// 'Waiting for verification of [new email]' with Resend link and
  /// Cancel change." Only ever present on /auth/me's response (same
  /// caveat as [twoFactorEnabled] above -- login/register don't return
  /// it), set by requestEmailChange/requestPhoneChange and cleared by
  /// confirm or cancel. REAL GAP FOUND AND FIXED this pass: these two
  /// fields didn't exist anywhere in the mobile client at all, so a
  /// user who started a change and left the screen before entering the
  /// OTP had no way to see the change was still pending, resend the
  /// code, or cancel it, other than re-running the whole request flow
  /// from scratch.
  final String? pendingEmail;
  final String? pendingPhoneNumber;

  factory NagagunoUser.fromJson(Map<String, dynamic> json) => NagagunoUser(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        role: json['role'] as String,
        accountStatus: json['account_status'] as String,
        email: json['email'] as String?,
        phoneNumber: json['phone_number'] as String?,
        suspendedUntil: json['suspended_until'] != null
            ? DateTime.tryParse(json['suspended_until'].toString())
            : null,
        codRestrictedUntil: json['cod_restricted_until'] != null
            ? DateTime.tryParse(json['cod_restricted_until'].toString())
            : null,
        language: json['language'] as String? ?? 'en',
        smsDeliveryUpdates: json['sms_delivery_updates'] as bool? ?? true,
        emailDeliveryUpdates: json['email_delivery_updates'] as bool? ?? true,
        dateOfBirth: json['date_of_birth'] != null
            ? DateTime.tryParse(json['date_of_birth'].toString())
            : null,
        age: json['age'] as int?,
        textSize: json['text_size'] as String? ?? 'standard',
        textSizeSetByUser: json['text_size_set_by_user'] as bool? ?? false,
        highContrast: json['high_contrast'] as bool? ?? false,
        boldText: json['bold_text'] as bool? ?? false,
        reduceMotion: json['reduce_motion'] as bool? ?? false,
        readAloudEnabled: json['read_aloud_enabled'] as bool? ?? false,
        easyModeEnabled: json['easy_mode_enabled'] as bool? ?? false,
        hasSeenWalkthrough: json['has_seen_walkthrough'] as bool? ?? false,
        twoFactorEnabled: json['two_factor_enabled'] as bool? ?? false,
        isEmailVerified: json['is_email_verified'] as bool? ?? false,
        isPhoneVerified: json['is_phone_verified'] as bool? ?? false,
        pendingEmail: json['pending_email'] as String?,
        pendingPhoneNumber: json['pending_phone_number'] as String?,
      );

  bool get isVerified => accountStatus == 'active';
  bool get isBuyer => role == 'buyer';
  bool get isFarmer => role == 'farmer';
  bool get isVendor => role == 'vendor';
  bool get isAdmin => role == 'admin';
  bool get isBanned => accountStatus == 'blocked';
  bool get isSuspended =>
      accountStatus == 'suspended' &&
      suspendedUntil != null &&
      suspendedUntil!.isAfter(DateTime.now());
  bool get hasCodRestriction =>
      codRestrictedUntil != null && codRestrictedUntil!.isAfter(DateTime.now());
  bool get isPenalized => isBanned || isSuspended;
}
