// lib/core/localization/app_strings.dart
//
// UW 21.5: "The change applies immediately, with no reload or new
// login: every label, button, validation message, and notification
// created after the change uses the new language." REAL, LARGE GAP
// FOUND AND PARTIALLY ADDRESSED this pass: the account's `language`
// field has always been saved and synced correctly end to end (see
// NagagunoUser's own doc comment on an earlier fix this session), but
// nothing anywhere in this app actually switched any UI text based on
// it -- every screen was hardcoded English regardless of the setting.
//
// Building full coverage ("every label, button, validation message,
// and notification" across this entire app) is a genuinely separate,
// much larger content-authoring undertaking than one pass can
// respectably finish -- dozens of screens, hundreds of strings, each
// needing a correctly-considered Tagalog translation, not a
// find-and-replace. What IS real and working here: the mechanism
// itself ([appLanguageProvider], reactive to both the account's saved
// language and -- pre-login -- the device-local choice, so switching
// takes effect "immediately, with no reload" exactly as the spec
// requires), and a first, COMPLETE vertical slice: the login screen,
// translated in full, not partially. Extending coverage to the rest of
// the app from here is the same mechanism applied screen by screen,
// adding more getters below (or splitting this class by screen, once
// it's large enough that one shared class stops being the right
// shape), not a different piece left to design.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/authentication/application/auth_controller.dart';
import 'pre_login_language.dart';

/// 'en' | 'tl'. Reads the authenticated account's own saved language
/// when there is one; falls back to the device-local pre-login choice
/// otherwise -- same authenticated-vs-pre-login split as
/// core/accessibility/quick_text_size_control.dart's text-size
/// equivalent.
final appLanguageProvider = Provider<String>((ref) {
  final authState = ref.watch(authControllerProvider);
  if (authState.status == AuthStatus.authenticated && authState.user != null) {
    return authState.user!.language;
  }
  return ref.watch(preLoginLanguageProvider);
});

final appStringsProvider =
    Provider<AppStrings>((ref) => AppStrings(ref.watch(appLanguageProvider)));

class AppStrings {
  const AppStrings(this.language);
  final String language;
  bool get _tl => language == 'tl';

  // ── Login screen (lib/features/authentication/presentation/login_screen.dart) ──
  String get welcomeBack => _tl ? 'Maligayang pagbabalik' : 'Welcome back';
  String get logInToYourAccount =>
      _tl ? 'Mag-log in sa iyong NagaGuno account' : 'Log in to your NagaGuno account';
  String get emailOrMobileNumber =>
      _tl ? 'Email o Numero ng Mobile' : 'Email or Mobile Number';
  String get password => 'Password';
  String get thisFieldIsRequired =>
      _tl ? 'Kailangan ang field na ito' : 'This field is required';
  String get passwordIsRequired =>
      _tl ? 'Kailangan ang password' : 'Password is required';
  String get forgotPassword =>
      _tl ? 'Nakalimutan ang password?' : 'Forgot password?';
  String get cantAccessEmailOrPhone => _tl
      ? 'Hindi ma-access ang iyong email o telepono?'
      : 'Can\'t access your email or phone?';
  String get checkARecoveryRequest =>
      _tl ? 'Tingnan ang recovery request' : 'Check a recovery request';
  String get logIn => _tl ? 'Mag-log In' : 'Log In';
  String get orDivider => _tl ? 'o' : 'or';
  String get signInWithGoogle =>
      _tl ? 'Mag-sign In gamit ang Google' : 'Sign in with Google';
  String get dontHaveAnAccount =>
      _tl ? 'Wala ka pang account? ' : 'Don\'t have an account? ';
  String get register => _tl ? 'Mag-rehistro' : 'Register';
  String get googleSignInNoToken => _tl
      ? 'Hindi nagbalik ang Google sign-in ng wastong token. Subukan muli.'
      : 'Google sign-in did not return a valid token. Please try again.';
  String get googleSignInFailed => _tl
      ? 'Nabigo ang Google sign-in. Subukan muli.'
      : 'Google sign-in failed. Please try again.';
  String get somethingWentWrongTryAgain => _tl
      ? 'May nangyaring mali. Pakisubukan muli.'
      : 'Something went wrong. Please try again.';
  String get tapSignInWithGoogleAgain => _tl
      ? 'May nangyaring mali. I-tap muli ang "Mag-sign In gamit ang Google."'
      : 'Something went wrong. Please tap "Sign in with Google" again.';
  String get almostDoneWhatDescribesYou => _tl
      ? 'Halos tapos na — alin ang pinakaangkop sa iyo?'
      : 'Almost done — what best describes you?';
  String get buyer => _tl ? 'Mamimili' : 'Buyer';
  String get farmer => _tl ? 'Magsasaka' : 'Farmer';
  String get vendor => _tl ? 'Nagtitinda' : 'Vendor';

  // ── Register screen (lib/features/authentication/presentation/register_screen.dart) ──
  String get createAccount => _tl ? 'Gumawa ng Account' : 'Create Account';
  String get iAmA => _tl ? 'Ako ay...' : 'I am a...';
  String get fullName => _tl ? 'Buong Pangalan' : 'Full Name';
  String get enterNameAsOnGovernmentId => _tl
      ? 'Ilagay ang iyong pangalan nang eksakto gaya ng nasa iyong government ID.'
      : 'Enter your name exactly as it appears on your government ID.';
  String get fullNameRequired =>
      _tl ? 'Kailangan ang buong pangalan.' : 'Full name is required.';
  String get fullNameTooShort => _tl
      ? 'Ang buong pangalan ay dapat hindi bababa sa 2 characters.'
      : 'Full name must be at least 2 characters.';
  String get fullNameTooLong => _tl
      ? 'Ang buong pangalan ay hindi dapat lumampas sa 50 characters.'
      : 'Full name must not exceed 50 characters.';
  String get dateOfBirth => _tl ? 'Petsa ng Kapanganakan' : 'Date of Birth';
  String get month => _tl ? 'Buwan' : 'Month';
  String get day => _tl ? 'Araw' : 'Day';
  String get year => _tl ? 'Taon' : 'Year';
  String get required_ => _tl ? 'Kailangan' : 'Required';
  String get pleaseEnterValidDateOfBirth => _tl
      ? 'Mangyaring maglagay ng wastong petsa ng kapanganakan.'
      : 'Please enter a valid date of birth.';
  String get mustBeAtLeast18 => _tl
      ? 'Dapat ay hindi bababa sa 18 taong gulang para makagawa ng NagaGuno account.'
      : 'You must be at least 18 years old to create a NagaGuno account.';
  String get nameAndDobVerifyIdentityNotice => _tl
      ? 'Ginagamit ang iyong pangalan at petsa ng kapanganakan para patunayan ang iyong pagkakakilanlan. Hindi mo na ito maeedit pagkatapos mag-rehistro, kaya siguraduhing tama ang mga ito.'
      : 'Your name and date of birth are used to verify your identity. You will not be able to edit them after you register, so please check that they are correct.';
  // Registration channel toggle: the user picks ONE of Email/Phone to
  // register with (middleware/auth.js's validateRegistration requires
  // at least one, not email specifically); whichever is picked is also
  // how the post-registration verification OTP is delivered.
  String get registerWithEmail => _tl ? 'Email' : 'Email';
  String get registerWithPhone => _tl ? 'Numero ng Mobile' : 'Phone Number';
  String get registerVia =>
      _tl ? 'Magrehistro gamit ang...' : 'Register using...';
  String get emailAddress => _tl ? 'Email Address' : 'Email Address';
  String get emailAddressOptional =>
      _tl ? 'Email Address (opsyonal)' : 'Email Address (optional)';
  String get emailAddressRequired =>
      _tl ? 'Kailangan ang email address.' : 'Email address is required.';
  String get enterValidEmailAddress => _tl
      ? 'Maglagay ng wastong email address.'
      : 'Please enter a valid email address.';
  String get mobileNumber => _tl ? 'Numero ng Mobile' : 'Mobile Number';
  String get mobileNumberOptional =>
      _tl ? 'Numero ng Mobile (opsyonal)' : 'Mobile Number (optional)';
  String get mobileNumberRequired => _tl
      ? 'Kailangan ang numero ng mobile.'
      : 'Mobile number is required.';
  String get phoneNumberMustBe11Digits => _tl
      ? 'Ang numero ng telepono ay dapat eksaktong 11 digits (hal. 09123456789).'
      : 'Phone number must be exactly 11 digits (e.g. 09123456789).';
  String get passwordHelper => _tl
      ? '8+ characters na may malaking titik, maliit na titik, numero, at special character'
      : '8+ characters with uppercase, lowercase, a number, and a special character';
  String get passwordRequiredDot =>
      _tl ? 'Kailangan ang password.' : 'Password is required.';
  String get passwordRequirementsNotMet => _tl
      ? 'Ang password ay dapat 8+ characters na may malaking titik, maliit na titik, numero, at special character.'
      : 'Password must be 8+ chars with uppercase, lowercase, number, and special character.';
  // UW 1's live password checklist, shown beneath the password field as
  // the user types (registration) and reused for Forgot Password's new-
  // password step (UW 2.1), which the spec says follows "the same
  // requirements as registration, with the same live red/green checklist
  // and 'Password accepted' confirmation."
  String get passwordReqLength =>
      _tl ? 'Hindi bababa sa 8 characters' : 'At least 8 characters';
  String get passwordReqUppercase => _tl
      ? 'Hindi bababa sa isang malaking titik'
      : 'At least one uppercase letter';
  String get passwordReqLowercase => _tl
      ? 'Hindi bababa sa isang maliit na titik'
      : 'At least one lowercase letter';
  String get passwordReqNumber =>
      _tl ? 'Hindi bababa sa isang numero' : 'At least one number';
  String get passwordReqSpecial => _tl
      ? 'Hindi bababa sa isang special character (@\$!%*?&.)'
      : 'At least one special character (@\$!%*?&.)';
  String get passwordAccepted =>
      _tl ? 'Tinanggap ang password.' : 'Password accepted.';
  String get alreadyHaveAnAccount =>
      _tl ? 'May account ka na? ' : 'Already have an account? ';

  /// UW 1's Month dropdown, January through December.
  static const _monthNamesEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  static const _monthNamesTl = [
    'Enero', 'Pebrero', 'Marso', 'Abril', 'Mayo', 'Hunyo',
    'Hulyo', 'Agosto', 'Setyembre', 'Oktubre', 'Nobyembre', 'Disyembre',
  ];
  List<String> get monthNames => _tl ? _monthNamesTl : _monthNamesEn;

  // ── Onboarding (lib/features/onboarding/presentation/onboarding_flow_screen.dart) ──
  // Category/preference VALUE labels (Vegetables, Proximity, etc.) are
  // deliberately left untranslated here: those same English values are
  // displayed on marketplace filters, product cards, and elsewhere
  // across the app that isn't translated yet, so translating them only
  // on this one screen would show a buyer "Gulay" during onboarding and
  // "Vegetables" everywhere else immediately after -- worse than
  // leaving them consistently in English until the rest of the app's
  // category displays are covered too.
  String welcomeToNagaGuno(String name) =>
      _tl ? 'Maligayang pagdating sa NagaGuno, $name!' : 'Welcome to NagaGuno, $name!';
  String get chooseInterestsIntro => _tl
      ? 'Piliin ang mga interesado ka para maipakita namin ang mga produktong maaaring gamitin mo.'
      : 'Choose what you\'re interested in so we can show products that may be useful to you.';
  String get getStarted => _tl ? 'Magsimula' : 'Get Started';
  String get setUpLater => _tl ? 'I-set Up Mamaya' : 'Set Up Later';
  String get whatAreYouInterestedIn =>
      _tl ? 'Ano ang mga interesado ka?' : 'What are you interested in?';
  String get chooseOneOrMore =>
      _tl ? 'Pumili ng isa o higit pa.' : 'Choose one or more.';
  String get continueLabel => _tl ? 'Magpatuloy' : 'Continue';
  String get aCoupleMoreThings =>
      _tl ? 'Kaunting bagay na lang' : 'A couple more things';
  String get thisStepIsOptional => _tl
      ? 'Opsyonal ang hakbang na ito — maaari mo itong laktawan.'
      : 'This step is optional — you can skip it.';
  String get pricePreference =>
      _tl ? 'Kagustuhan sa Presyo' : 'Price preference';
  String get whatMattersMostToYou =>
      _tl ? 'Ano ang pinakamahalaga sa iyo?' : 'What matters most to you?';
  String get yourNagaGunoIsReady =>
      _tl ? 'Handa na ang iyong NagaGuno.' : 'Your NagaGuno is ready.';
  String get onboardingCompletionBody => _tl
      ? 'Gagamitin namin ang iyong mga interes para i-personalize ang mga produkto, pananim, magsasaka, at mungkahi sa marketplace.'
      : 'We\'ll use your interests to personalize products, crops, farmers, and marketplace recommendations.';
  String get exploreNagaGuno => _tl ? 'Tuklasin ang NagaGuno' : 'Explore NagaGuno';
  String get couldntSavePreferences => _tl
      ? 'Hindi ma-save ang iyong mga kagustuhan. Pakisubukan muli.'
      : 'Couldn\'t save your preferences. Please try again.';

  // ── Home dashboard (lib/features/dashboard/presentation/home_screen.dart) ──
  String get inventoryAndSales =>
      _tl ? 'Imbentaryo at Benta' : 'Inventory & Sales';
  // REAL GAP FOUND AND FIXED: this quick link showed "Inventory &
  // Sales" to every role unconditionally, including Buyers -- a Buyer
  // has no inventory and makes no sales, only purchases. The real
  // backend endpoint behind it (routes/analytics.js's GET /sales) was
  // already buyer-aware (resolveViewAsBuyer) and genuinely returns a
  // Buyer's own purchase analytics correctly -- only the label was
  // wrong, not the data.
  String get orderAnalytics =>
      _tl ? 'Analytics ng Order' : 'Order Analytics';
  String get history => _tl ? 'Kasaysayan' : 'History';
  String get couldntLoadDashboard =>
      _tl ? 'Hindi ma-load ang iyong dashboard.' : 'Couldn\'t load your dashboard.';
  String get nextHarvest => _tl ? 'SUSUNOD NA ANI' : 'NEXT HARVEST';
  String get addCrop => _tl ? 'Magdagdag ng Pananim' : 'Add Crop';
  String get addProduct => _tl ? 'Magdagdag ng Produkto' : 'Add Product';
  String get ordersNeedingAttention =>
      _tl ? 'Mga Order na Kailangan ng Aksyon' : 'Orders Needing Attention';
  String get activeAgreements =>
      _tl ? 'Aktibong Kasunduan' : 'Active Agreements';
  String get orders => _tl ? 'Mga Order' : 'Orders';
  String get thisMonth => _tl ? 'Ngayong Buwan' : 'This Month';
  String get demandForecast =>
      _tl ? 'Tinatayang Demand' : 'Demand Forecast';
  String get activeListings => _tl ? 'Aktibong Listahan' : 'Active Listings';
  String get totalRevenue => _tl ? 'Kabuuang Kita' : 'Total Revenue';
  String get recentOrders => _tl ? 'Mga Kamakailang Order' : 'Recent Orders';
  String get totalOrders => _tl ? 'Kabuuang Order' : 'Total Orders';
  String get savedFarmers =>
      _tl ? 'Na-save na mga Magsasaka' : 'Saved Farmers';
  String get viewSavedFarmers =>
      _tl ? 'Tingnan ang Na-save na mga Magsasaka' : 'View Saved Farmers';

  // ── Bottom nav labels (lib/shared/widgets/app_shell.dart) --
  // always-visible, cross-role, so translated together with the rest
  // of the completed first-run journey.
  String get navHome => _tl ? 'Home' : 'Home';
  String get navMarketplace => _tl ? 'Marketplace' : 'Marketplace';
  String get navAgreements => _tl ? 'Kasunduan' : 'Agreements';
  String get navOrders => _tl ? 'Mga Order' : 'Orders';
  String get navProfile => _tl ? 'Profile' : 'Profile';
  String get navProduction => _tl ? 'Produksyon' : 'Production';
  String get navMyProducts => _tl ? 'Mga Produkto Ko' : 'My Products';
  String get navListings => _tl ? 'Mga Listahan' : 'Listings';
  String get navMore => _tl ? 'Higit Pa' : 'More';

  // ── Easy Mode home (lib/features/dashboard/presentation/easy_mode_home_screen.dart) ──
  String get everythingElseUnderMore => _tl
      ? 'Ang lahat ng iba pa ay nasa ilalim ng Higit Pa, sa ibaba ng screen.'
      : 'Everything else is still under More, in the bottom bar.';
  String get browseMarketplace =>
      _tl ? 'Tingnan ang Marketplace' : 'Browse Marketplace';
  String get myOrders => _tl ? 'Mga Order Ko' : 'My Orders';
  String get myAgreements => _tl ? 'Mga Kasunduan Ko' : 'My Agreements';
  String get messages => _tl ? 'Mga Mensahe' : 'Messages';
  String get myProducts => _tl ? 'Mga Produkto Ko' : 'My Products';
  String get productionPlans =>
      _tl ? 'Mga Plano sa Produksyon' : 'Production Plans';
  String get myListings => _tl ? 'Mga Listahan Ko' : 'My Listings';

  // ── Profile screen (lib/features/profile/presentation/profile_screen.dart) ──
  String get profile => _tl ? 'Profile' : 'Profile';
  String get editProfile => _tl ? 'I-edit ang Profile' : 'Edit Profile';
  String get verifiedAccount => _tl ? 'Na-verify na Account' : 'Verified Account';
  String get verificationRequired =>
      _tl ? 'Kailangan ng Verification' : 'Verification Required';
  // Folded onto the email/phone row's own subtitle (see
  // profile_screen.dart's own note) instead of a separate "Verify Now"
  // tile -- tapping the row itself is still what reaches the verify
  // screen, this just labels why.
  String get notVerifiedTapToVerify => _tl
      ? 'Hindi pa verified — i-tap para i-verify'
      : 'Not verified — tap to verify';
  // REAL GAP FOUND AND FIXED: UW 21.2's Account & Security top rule and
  // requestEnableTwoFactor's own error message ("Add a phone number
  // before turning on two-factor authentication") both assume there's
  // a way to add one from Settings -- but the phone row on this screen
  // only ever rendered when a phone number already existed, so an
  // email-only-registered account (a real, spec-allowed registration
  // path, Section 1) had no way to add one at all, including no way
  // to follow that exact instruction.
  String get addPhoneNumber => _tl ? 'Magdagdag ng Numero ng Telepono' : 'Add Phone Number';
  String get accountAndSecurity =>
      _tl ? 'Account at Seguridad' : 'Account & Security';
  String get notifications => _tl ? 'Mga Notification' : 'Notifications';
  String get paymentMethods => _tl ? 'Paraan ng Pagbabayad' : 'Payment Methods';
  String get accountStatusAndAppeals =>
      _tl ? 'Status ng Account at Apela' : 'Account Status & Appeals';
  String get myReports => _tl ? 'Mga Ulat Ko' : 'My Reports';
  String get blockedUsers => _tl ? 'Mga Naka-block na User' : 'Blocked Users';
  String get sendFeedback => _tl ? 'Magpadala ng Feedback' : 'Send Feedback';
  String get preferencesAndInterests =>
      _tl ? 'Mga Kagustuhan at Interes' : 'Preferences & Interests';
  String get appWalkthrough => _tl ? 'Gabay sa App' : 'App Walkthrough';
  String get languageAndNotifications =>
      _tl ? 'Wika at Mga Notification' : 'Language & Notifications';
  String get accessibility => _tl ? 'Accessibility' : 'Accessibility';
  String get privacyPolicy => _tl ? 'Patakaran sa Privacy' : 'Privacy Policy';
  String get termsOfService =>
      _tl ? 'Mga Tuntunin ng Serbisyo' : 'Terms of Service';
  String get logOutQuestion => _tl ? 'Mag-log out?' : 'Log out?';
  String get cancel => _tl ? 'Kanselahin' : 'Cancel';
  String get logOut => _tl ? 'Mag-log Out' : 'Log Out';
  String get yourVerifiedDetails =>
      _tl ? 'Ang iyong verified na detalye' : 'Your verified details';
  String get verifiedDetailsCannotBeEdited => _tl
      ? 'Ginagamit ang mga detalyeng ito para patunayan ang iyong pagkakakilanlan, kaya hindi ito maaaring i-edit.'
      : 'These details are used to verify your identity, so they can\'t be edited.';
  String get requestACorrection =>
      _tl ? 'Humiling ng Pagwawasto' : 'Request a correction';
  String get detailWrongWillBeAskedAtReview => _tl
      ? 'Kung may maling detalye, hihingan ka ng pagwawasto kapag na-review na ang iyong ID.'
      : 'If a detail is wrong, you will be asked to correct it when your ID is reviewed.';
  String get detailFullName => _tl ? 'Buong pangalan' : 'Full name';
  String get detailDateOfBirth =>
      _tl ? 'Petsa ng kapanganakan' : 'Date of birth';
  String get detailAge => _tl ? 'Edad' : 'Age';

  // ── Account settings: Language & Notifications (lib/features/profile/presentation/account_settings_screen.dart) ──
  String get languageAndNotificationsTitle =>
      _tl ? 'Wika at Mga Notification' : 'Language & Notifications';
  String get languageLabel => _tl ? 'Wika' : 'Language';
  String get english => 'English';
  String get tagalog => 'Tagalog';
  String get notificationPreferences =>
      _tl ? 'Mga Kagustuhan sa Notification' : 'Notification Preferences';
  String get inAppNotificationsAlwaysOn => _tl
      ? 'Laging naka-on ang mga in-app na notification para sa order, bayad, at mga paalala sa account.'
      : 'In-app notifications for orders, payments, and account notices are always on.';
  String get smsForDeliveryUpdates =>
      _tl ? 'SMS para sa Delivery at Pickup Updates' : 'SMS for Delivery & Pickup Updates';
  String get textMessagesToPhoneOnAccount => _tl
      ? 'Text messages sa numero ng telepono sa iyong account.'
      : 'Text messages to the phone number on your account.';
  String get emailForDeliveryUpdates =>
      _tl ? 'Email para sa Delivery at Pickup Updates' : 'Email for Delivery & Pickup Updates';
  String get emailsToAddressOnAccount => _tl
      ? 'Mga email sa address na nasa iyong account.'
      : 'Emails to the address on your account.';
  String get turnOffBothQuestion => _tl ? 'I-off ang pareho?' : 'Turn off both?';
  String get willOnlySeeUpdatesInApp => _tl
      ? 'Makikita mo na lang ang mga delivery at pickup update sa app. Maaaring mawala sa iyo ang mga mahalagang update.'
      : 'You\'ll only see delivery and pickup updates in the app. You may miss time-sensitive updates.';
  String get turnOff => _tl ? 'I-off' : 'Turn Off';

  // ── Accessibility settings (lib/features/accessibility/presentation/accessibility_settings_screen.dart) ──
  String get accessibilityTitle => _tl ? 'Accessibility' : 'Accessibility';
  String get couldntSaveSettingStillAppliesLocally => _tl
      ? 'Hindi namin na-save ang setting na ito. Ipapatupad pa rin ito sa device na ito. Pakisubukan ulit.'
      : 'We couldn\'t save this setting. It will still apply on this device. Please try again.';
  String get previewTextAtThisSize => _tl
      ? 'Preview: Ganito ang text ng NagaGuno sa sukat na ito.'
      : 'Preview: NagaGuno text at this size.';
  String get textSize => _tl ? 'Sukat ng Text' : 'Text Size';
  // REAL GAP FOUND AND FIXED, by explicit request: the original 4
  // names (Standard/Large/Extra Large/Maximum) read as informal/odd --
  // renamed to the conventional 4-rung ladder every OS text-size
  // setting already uses (Small/Default/Large/Extra Large), mapped by
  // RANK onto the same 4 existing data values (standard/large/
  // extra_large/maximum, unchanged -- these are the stored enum
  // values, not display text, and still match what the backend's
  // CHECK constraint and every stored user preference already expect).
  // Getter names renamed to match what they now actually return, not
  // left pointing at a name that no longer describes the label.
  String get textSizeSmall => _tl ? 'Maliit' : 'Small';
  String get textSizeDefault => _tl ? 'Karaniwan' : 'Default';
  String get textSizeLarge => _tl ? 'Malaki' : 'Large';
  String get textSizeExtraLarge => _tl ? 'Mas Malaki' : 'Extra Large';
  String get highContrast => _tl ? 'Mataas na Contrast' : 'High Contrast';
  String get highContrastSubtitle => _tl
      ? 'Mas maitim na text, mas matingkad na border, at plain na background.'
      : 'Darker text, stronger borders, and plain backgrounds.';
  String get boldText => _tl ? 'Makapal na Text' : 'Bold Text';
  String get boldTextSubtitle => _tl
      ? 'Mas makapal na font sa buong app.'
      : 'A heavier font weight throughout.';
  String get reduceMotion => _tl ? 'Bawasan ang Galaw' : 'Reduce Motion';
  String get reduceMotionSubtitle => _tl
      ? 'Patayin ang mga animation at animated chart.'
      : 'Turn off animations and animated charts.';
  String get readAloud => _tl ? 'Basahin nang Malakas' : 'Read Aloud';
  String get readAloudSubtitle => _tl
      ? 'Nagpapakita ng speaker button sa tabi ng mga listing, notification, at order status text para basahin ito nang malakas.'
      : 'Shows a speaker button beside listings, notifications, and order status text to read them aloud.';
  String get easyMode => _tl ? 'Easy Mode' : 'Easy Mode';
  String get easyModeSubtitle => _tl
      ? 'Mas malaking navigation button at pinasimpleng Home screen na may pinaka-ginagamit mong mga aksyon. Walang matatanggal -- nasa ilalim ng More ang lahat ng iba pa.'
      : 'Larger navigation buttons and a simplified Home screen with your most-used actions. Nothing is removed -- everything else stays under More.';

  // ── Account & Security (lib/features/profile/presentation/account_security_screen.dart) ──
  String get accountAndSecurityTitle =>
      _tl ? 'Account at Seguridad' : 'Account & Security';
  String get currentPasswordLabel =>
      _tl ? 'Kasalukuyang Password' : 'Current Password';
  String get newPasswordLabel => _tl ? 'Bagong Password' : 'New Password';
  String get changePasswordButton =>
      _tl ? 'Palitan ang Password' : 'Change Password';
  String get passwordChangedMessage =>
      _tl ? 'Napalitan ang password.' : 'Password changed.';
  String get twoFactorAuthenticationTitle =>
      _tl ? 'Two-Factor Authentication' : 'Two-Factor Authentication';
  String get confirmYourPasswordTitle =>
      _tl ? 'Kumpirmahin ang iyong password' : 'Confirm your password';
  String get twoFactorOnSubtitle => _tl
      ? 'Ipinapadala ang code sa iyong telepono sa bawat paglog-in.'
      : 'A code is sent to your phone each time you log in.';
  String get twoFactorOffSubtitle => _tl
      ? 'Off -- ang pag-on nito ay magpapadala ng code sa nakarehistrong telepono para kumpirmahin na naaabot ito.'
      : 'Off -- turning this on sends a code to the phone on file to confirm it\'s reachable.';
  String get twoFactorEnabledMessage => _tl
      ? 'Naka-on na ang Two-Factor Authentication.'
      : 'Two-factor authentication is on.';
  String get twoFactorDisabledMessage => _tl
      ? 'Naka-off na ang Two-Factor Authentication.'
      : 'Two-factor authentication is off.';
  String get enterSixDigitCodeToConfirmPhone => _tl
      ? 'Ilagay ang 6-digit code na ipinadala sa iyong telepono para kumpirmahin na naaabot ito.'
      : 'Enter the 6-digit code sent to your phone to confirm it\'s reachable.';
  String get confirmationCodeLabel =>
      _tl ? 'Confirmation Code' : 'Confirmation Code';
  String get enterSixDigitCodeError =>
      _tl ? 'Ilagay ang 6-digit code.' : 'Enter the 6-digit code.';
  String get confirmLabel => _tl ? 'Kumpirmahin' : 'Confirm';
  String get loggedInDevicesTitle =>
      _tl ? 'Mga Naka-login na Device' : 'Logged-in Devices';
  String get justNowLabel => _tl ? 'Ngayon lang' : 'Just now';
  String get minutesAgo => _tl ? 'min ang nakalipas' : 'm ago';
  String get hoursAgo => _tl ? 'oras ang nakalipas' : 'h ago';
  String get unknownDevice => _tl ? 'Hindi kilalang device' : 'Unknown device';
  String get thisDeviceLabel => _tl ? 'Ang device na ito' : 'This device';
  String get lastActivePrefix =>
      _tl ? 'Huling aktibo noong ' : 'Last active ';
  String get logOutAllOtherDevices => _tl
      ? 'I-log Out ang Lahat ng Ibang Device'
      : 'Log Out All Other Devices';
  String get allOtherDevicesLoggedOut => _tl
      ? 'Na-log out na ang lahat ng ibang device.'
      : 'All other devices logged out.';
  String get couldntLoadDevices =>
      _tl ? 'Hindi na-load ang iyong mga device.' : 'Couldn\'t load your devices.';
  String get retry => _tl ? 'Subukan Ulit' : 'Retry';

  // ── Payment Methods (lib/features/payment_methods/presentation/payment_methods_screen.dart) ──
  String get paymentMethodsTitle =>
      _tl ? 'Mga Paraan ng Pagbabayad' : 'Payment Methods';
  String requiredForPaymentAction(String actionEn, String actionTl) => _tl
      ? 'Kailangan para $actionTl ang iyong mga detalye ng bayad.'
      : 'Required to $actionEn your payment details.';
  // REAL GAP FOUND AND FIXED: UW 21.3's remove-confirmation is two
  // sentences, not one -- "Remove this payment method? Buyers will no
  // longer see it at checkout." This previously dropped the second
  // sentence entirely.
  String get removePaymentMethodQuestion => _tl
      ? 'Alisin ang paraan ng pagbabayad na ito? Hindi na ito makikita ng mga buyer sa checkout.'
      : 'Remove this payment method? Buyers will no longer see it at checkout.';
  // UW 21.3: "If it was a Farmer's or Vendor's last method, the
  // confirmation adds: 'Manual Transfer will be unavailable on your
  // listings until you add another method. Gateway payments are not
  // affected.'" Previously missing entirely -- the dialog never checked
  // whether this was the seller's last remaining method.
  String get removeLastPaymentMethodWarning => _tl
      ? 'Hindi magagamit ang Manual Transfer sa iyong mga listing hangga\'t wala kang idinadagdag na ibang paraan. Hindi apektado ang mga Gateway payment.'
      : 'Manual Transfer will be unavailable on your listings until you add another method. Gateway payments are not affected.';
  String get removeLabel => _tl ? 'Alisin' : 'Remove';
  String get couldntLoadPaymentMethods => _tl
      ? 'Hindi na-load ang iyong mga paraan ng pagbabayad.'
      : 'Couldn\'t load your payment methods.';
  String get addLabel => _tl ? 'Idagdag' : 'Add';
  String get sellerPaymentExplanation => _tl
      ? 'Dito ipinapadala ng mga buyer ang bayad kapag pinili nila ang Manual Transfer sa iyong mga listing. Ipinapadala rin dito ang iyong parte sa Online Payment via GCash (Gateway) sales sa oras ng settlement. Ipinapadala rin dito ang anumang refund na utang sa iyo.'
      : 'Buyers pay into these when they choose Manual Transfer on your listings. Your share of Online Payment via GCash (Gateway) sales is also sent here during settlement. Any refund owed to you is sent here too.';
  String get buyerPaymentExplanation => _tl
      ? 'Dito ipinapadala ang anumang refund na utang sa iyo.'
      : 'Any refund owed to you is sent here.';
  String get gatewayNeedsNothingFromYou => _tl
      ? 'Walang kailangan sa iyo ang Online Payment via GCash (Gateway).'
      : 'Online Payment via GCash (Gateway) needs nothing from you.';
  String get makeSureAccountDetailsCorrect => _tl
      ? 'Tiyaking tama ang mga detalye ng iyong account. Anumang refund na utang sa iyo ay ipapadala rito.'
      : 'Make sure your account details are correct. Any refund owed to you will be sent here.';
  String get makeSureAccountDetailsCorrectTestMode => _tl
      ? 'Tiyaking tama ang mga detalye ng iyong account. Anumang refund na utang sa iyo ay ipapadala rito. Nasa test mode ang gateway. Walang tunay na pera ang sisingilin.'
      : 'Make sure your account details are correct. Any refund owed to you will be sent here. The gateway is in test mode. No real money is charged.';
  String get noPaymentMethodsAddedYet =>
      _tl ? 'Wala ka pang naidadagdag na paraan ng pagbabayad.' : 'No payment methods added yet.';
  String get bankTransferLabel => _tl ? 'Bank Transfer' : 'Bank Transfer';
  String get editTooltip => _tl ? 'I-edit' : 'Edit';
  String get addPaymentMethodTitle =>
      _tl ? 'Magdagdag ng Paraan ng Pagbabayad' : 'Add Payment Method';
  String get editPaymentMethodTitle =>
      _tl ? 'I-edit ang Paraan ng Pagbabayad' : 'Edit Payment Method';
  String get gcashNumberHint =>
      _tl ? 'GCash Number (hal. 09123456789)' : 'GCash Number (e.g. 09123456789)';
  String get addGcashQrOptional =>
      _tl ? 'Magdagdag ng GCash QR Code (opsyonal)' : 'Add GCash QR Code (optional)';
  String get qrCodeSelected => _tl ? 'Napili ang QR Code' : 'QR Code Selected';
  String get bankAccountLabel => _tl ? 'Bank Account' : 'Bank Account';
  String get bankNameLabel => _tl ? 'Pangalan ng Bangko' : 'Bank Name';
  String get accountNumberLabel => _tl ? 'Account Number' : 'Account Number';
  String get accountNameLabel => _tl ? 'Pangalan sa Account' : 'Account Name';
  String get saveLabel => _tl ? 'I-save' : 'Save';
  String get provideAtLeastOnePaymentDetail => _tl
      ? 'Maglagay ng kahit isa: GCash number, GCash QR code, o bank account.'
      : 'Provide at least a GCash number, a GCash QR code, or a bank account.';
  String get qrCodeOnFile => _tl ? 'May QR code na naka-file' : 'QR code on file';

  // ── Marketplace (lib/features/marketplace/presentation/marketplace_screen.dart) ──
  String get marketplaceTitle => _tl ? 'Marketplace' : 'Marketplace';
  String get searchTheMarketplaceHint =>
      _tl ? 'Maghanap sa marketplace' : 'Search the marketplace';
  String get cropListingsLabel => _tl ? 'Mga Pananim' : 'Crop Listings';
  String get productionPlansLabel =>
      _tl ? 'Mga Plano sa Produksyon' : 'Production Plans';
  String get flashSaleLabel => _tl ? 'Flash Sale' : 'Flash Sale';
  String get filtersLabel => _tl ? 'Mga Filter' : 'Filters';
  String get filtersActiveLabel => _tl ? 'Mga Filter •' : 'Filters •';
  String get sortLabel => _tl ? 'Ayusin' : 'Sort';
  String get sortNewest => _tl ? 'Pinakabago' : 'Newest';
  String get sortPriceAsc =>
      _tl ? 'Presyo: Mababa hanggang Mataas' : 'Price: Low to High';
  String get sortPriceDesc =>
      _tl ? 'Presyo: Mataas hanggang Mababa' : 'Price: High to Low';
  String get sortStock => _tl ? 'Pinakamaraming Stock' : 'Most in Stock';
  String get sortDiscount => _tl ? 'Pinakamalaking Diskwento' : 'Biggest Discount';
  String get minPriceLabel => _tl ? 'Pinakamababang Presyo (₱)' : 'Min Price (₱)';
  String get maxPriceLabel => _tl ? 'Pinakamataas na Presyo (₱)' : 'Max Price (₱)';
  String get barangayLabel => _tl ? 'Barangay' : 'Barangay';
  String get clearLabel => _tl ? 'I-clear' : 'Clear';
  String get applyLabel => _tl ? 'I-apply' : 'Apply';
  String get couldntLoadProductionPlans => _tl
      ? 'Hindi na-load ang mga plano sa produksyon. Suriin ang iyong koneksyon at subukan ulit.'
      : 'Couldn\'t load production plans. Check your connection and try again.';
  String get noProductionPlansOpenForRequests => _tl
      ? 'Walang bukas na plano sa produksyon para sa request sa ngayon.'
      : 'No production plans open for requests right now.';
  String get couldntLoadMarketplace => _tl
      ? 'Hindi na-load ang marketplace. Suriin ang iyong koneksyon at subukan ulit.'
      : 'Couldn\'t load the marketplace. Check your connection and try again.';
  String get noProductsFoundTryDifferent => _tl
      ? 'Walang nahanap na produkto. Subukan ang ibang paghahanap o kategorya.'
      : 'No products found. Try a different search or category.';

  // ── Orders (lib/features/orders/presentation/orders_screen.dart) ──
  String get ordersTitle => _tl ? 'Mga Order' : 'Orders';
  String get searchOrderHistoryHint =>
      _tl ? 'Maghanap sa order history' : 'Search order history';
  String get sellingLabel => _tl ? 'Nagbebenta' : 'Selling';
  String get salesLabel => _tl ? 'Benta' : 'Sales';
  String get buyingLabel => _tl ? 'Bumibili' : 'Buying';
  String get sourcingLabel => _tl ? 'Sourcing' : 'Sourcing';
  String get allLabel => _tl ? 'Lahat' : 'All';
  String get statusPending => _tl ? 'Pending' : 'Pending';
  String get statusConfirmed => _tl ? 'Nakumpirma' : 'Confirmed';
  String get statusPreparing => _tl ? 'Inihahanda' : 'Preparing';
  String get statusDispatched => _tl ? 'Nai-dispatch' : 'Dispatched';
  String get statusDelivered => _tl ? 'Naihatid' : 'Delivered';
  String get statusCancelled => _tl ? 'Kinansela' : 'Cancelled';
  String orderStatusLabel(String status) => switch (status) {
        'pending' => statusPending,
        'confirmed' => statusConfirmed,
        'preparing' => statusPreparing,
        'dispatched' => statusDispatched,
        'delivered' => statusDelivered,
        'cancelled' => statusCancelled,
        _ => status,
      };
  String get couldntLoadOrders =>
      _tl ? 'Hindi na-load ang iyong mga order.' : 'Couldn\'t load your orders.';
  String noOrdersMatchSearch(String query) => _tl
      ? 'Walang order na tumugma sa "$query".'
      : 'No orders match "$query".';
  String get noOrdersYetMessage => _tl
      ? 'Wala ka pang order. Lalabas dito ang mga order na inilagay o natanggap mo.'
      : 'No orders yet. Orders you place or receive will show up here.';
  String noOrdersWithStatus(String status) => _tl
      ? 'Walang order na $status.'
      : 'No $status orders.';

  // ── Smart Agreements (lib/features/agreements/presentation/agreements_screen.dart) ──
  String get smartAgreementsTitle =>
      _tl ? 'Mga Smart Agreement' : 'Smart Agreements';
  String get browseFarmers => _tl ? 'Mga Magsasaka' : 'Browse Farmers';
  String get browseVendors => _tl ? 'Mga Vendor' : 'Browse Vendors';
  String get newAgreementLabel =>
      _tl ? 'Bagong Agreement' : 'New Agreement';
  String get statusNegotiating => _tl ? 'Nagne-negotiate' : 'Negotiating';
  String get statusActive => _tl ? 'Aktibo' : 'Active';
  String get statusFulfilled => _tl ? 'Natupad' : 'Fulfilled';
  String get statusRejected => _tl ? 'Tinanggihan' : 'Rejected';
  String get statusExpired => _tl ? 'Nag-expire na' : 'Expired';
  String agreementStatusLabel(String status) => switch (status) {
        'pending' => statusPending,
        'negotiating' => statusNegotiating,
        'active' => statusActive,
        'fulfilled' => statusFulfilled,
        'rejected' => statusRejected,
        'expired' => statusExpired,
        'cancelled' => statusCancelled,
        _ => status,
      };
  String get couldntLoadAgreements => _tl
      ? 'Hindi na-load ang iyong mga agreement.'
      : 'Couldn\'t load your agreements.';
  String get noAgreementsYet => _tl ? 'Wala ka pang agreement.' : 'No agreements yet.';
  String noAgreementsWithStatus(String status) =>
      _tl ? 'Walang agreement na $status.' : 'No $status agreements.';
  String withCounterpartyName(String name) =>
      _tl ? 'kasama si $name' : 'with $name';
  String get awaitingYourResponse =>
      _tl ? 'Naghihintay ng iyong sagot' : 'Awaiting your response';

  // ── My Products (lib/features/products/presentation/my_products_screen.dart) ──
  String get myProductsTitle => _tl ? 'Mga Produkto Ko' : 'My Products';
  String get spoilageMonitoringTooltip =>
      _tl ? 'Pagsubaybay sa Pagkasira' : 'Spoilage Monitoring';
  String get addProductLabel => _tl ? 'Magdagdag ng Produkto' : 'Add Product';
  String get couldntLoadProducts =>
      _tl ? 'Hindi na-load ang iyong mga produkto.' : 'Couldn\'t load your products.';
  String get noProductsAddedYetTapAddProduct => _tl
      ? 'Wala ka pang naidadagdag na produkto. I-tap ang "Magdagdag ng Produkto" para ilista ang iyong unang item.'
      : 'You haven\'t added any products yet. Tap "Add Product" to list your first item.';
  String get totalLabel => _tl ? 'TOTAL' : 'TOTAL';
  String get liveLabel => _tl ? 'LIVE' : 'LIVE';
  String get hiddenLabel => _tl ? 'NAKATAGO' : 'HIDDEN';
  String noProductsWithFilter(String filterKey) {
    final name = filterKey == 'live' ? 'live' : (_tl ? 'nakatagong' : 'hidden');
    return _tl ? 'Walang $name produkto.' : 'No $name products.';
  }
  String get liveStatusLabel => _tl ? 'Live' : 'Live';
  String get hiddenStatusLabel => _tl ? 'Nakatago' : 'Hidden';
  String get addPaymentMethodBannerText => _tl
      ? 'Magdagdag ng paraan ng pagbabayad para makapagbayad ang mga buyer gamit ang Manual Transfer'
      : 'Add a payment method to let buyers pay by Manual Transfer';
  String get deleteThisListingQuestion =>
      _tl ? 'Burahin ang listing na ito?' : 'Delete this listing?';
  String productWillBeRemovedCantUndo(String name) => _tl
      ? '"$name" ay aalisin sa marketplace. Hindi na ito maibabalik.'
      : '"$name" will be removed from the marketplace. This can\'t be undone.';
  String get deleteLabel => _tl ? 'Burahin' : 'Delete';
  String get showLabel => _tl ? 'Ipakita' : 'Show';
  String get hideLabel => _tl ? 'Itago' : 'Hide';

  // ── My Production / Crop Plans (lib/features/crop_plans/presentation/crop_plans_screen.dart) ──
  String get myProductionTitle => _tl ? 'Produksyon Ko' : 'My Production';
  String get addCropLabel => _tl ? 'Magdagdag ng Pananim' : 'Add Crop';
  String get stagePlanted => _tl ? 'Nataniman' : 'Planted';
  String get stageGrowing => _tl ? 'Lumalaki' : 'Growing';
  String get stageHarvesting => _tl ? 'Inaani' : 'Harvesting';
  String get stageDone => _tl ? 'Tapos na' : 'Done';
  String cropStageLabel(String stage) => switch (stage) {
        'planted' => stagePlanted,
        'growing' => stageGrowing,
        'harvesting' => stageHarvesting,
        'done' => stageDone,
        _ => stage,
      };
  String get couldntLoadCropPlans => _tl
      ? 'Hindi na-load ang iyong mga plano sa pananim.'
      : 'Couldn\'t load your crop plans.';
  String get noCropPlansYetTapAddCrop => _tl
      ? 'Wala ka pang plano sa pananim. I-tap ang "Magdagdag ng Pananim" para subaybayan ang iyong unang tanim.'
      : 'No crop plans yet. Tap "Add Crop" to track your first planting.';
  String noCropPlansWithStage(String stageLabel) => _tl
      ? 'Walang plano sa pananim na $stageLabel.'
      : 'No $stageLabel crop plans.';
  String get dueLabel => _tl ? 'DUE NA' : 'DUE';
  String get daysLabel => _tl ? 'ARAW' : 'DAYS';
  String get editDetailsLabel => _tl ? 'I-edit ang Detalye' : 'Edit Details';
  String get createListingFromPlanLabel =>
      _tl ? 'Gumawa ng Listing mula sa Plano' : 'Create Listing from Plan';
  String markAsStage(String stageLabel) =>
      _tl ? 'Markahan bilang $stageLabel' : 'Mark as $stageLabel';
  String get deleteThisCropPlanQuestion =>
      _tl ? 'Burahin ang plano sa pananim na ito?' : 'Delete this crop plan?';
  String cropPlanWillBePermanentlyRemoved(String name) => _tl
      ? '"$name" ay permanenteng aalisin. Hindi na ito maibabalik.'
      : '"$name" will be permanently removed. This can\'t be undone.';
  String get couldntDeleteCropPlanTryAgain => _tl
      ? 'Hindi naburahan ang plano sa pananim na ito. Pakisubukan ulit.'
      : 'Couldn\'t delete this crop plan. Please try again.';
  String get couldntUpdateStageTryAgain => _tl
      ? 'Hindi na-update ang stage. Pakisubukan ulit.'
      : 'Couldn\'t update the stage. Please try again.';

  // ── Product Detail (lib/features/marketplace/presentation/product_detail_screen.dart) ──
  String get couldntLoadProduct =>
      _tl ? 'Hindi na-load ang produktong ito.' : 'Couldn\'t load this product.';
  String addedToCartMessage(String quantity, String unit, String name) => _tl
      ? 'Naidagdag ang $quantity $unit ng $name sa cart.'
      : 'Added $quantity $unit of $name to cart.';
  String stockAvailable(String qty, String unit) =>
      _tl ? 'May $qty $unit na available' : '$qty $unit available';
  String get quantityLabel => _tl ? 'Dami' : 'Quantity';
  String get totalPrefix => _tl ? 'Kabuuan: ' : 'Total: ';
  String get maximumAvailableQuantityReached => _tl
      ? 'Narating na ang pinakamataas na available na dami.'
      : 'Maximum available quantity reached.';
  String get soldOutLabel => _tl ? 'Ubos na' : 'Sold Out';
  String get reviewsLabel => _tl ? 'Mga Review' : 'Reviews';
  String get addToCartLabel => _tl ? 'Idagdag sa Cart' : 'Add to Cart';
  String get placeOrderLabel => _tl ? 'Mag-order' : 'Place Order';
  String get thisIsYourOwnListing => _tl
      ? 'Ito ang sarili mong listahan -- hindi ka maaaring mag-order dito.'
      : 'This is your own listing -- you cannot order from yourself.';

  // ── Checkout (lib/features/orders/presentation/checkout_screen.dart) ──
  String get checkoutTitle => _tl ? 'Checkout' : 'Checkout';
  String get confirmPaymentTitle => _tl ? 'Kumpirmahin ang Bayad' : 'Confirm Payment';
  String sellerLine(String name) => _tl ? 'Nagbebenta: $name' : 'Seller: $name';
  String amountLine(String amount) => _tl ? 'Halaga: $amount' : 'Amount: $amount';
  String get orderReferenceLabel => _tl ? 'Order Reference' : 'Order Reference';
  String get laterLabel => _tl ? 'Mamaya Na Lang' : 'Later';
  String get continueToPaymentLabel =>
      _tl ? 'Magpatuloy sa Pagbabayad' : 'Continue to Payment';
  String get selectPickupDateTimeError => _tl
      ? 'Pumili ng petsa at oras ng pickup.'
      : 'Select a pickup date and time slot.';
  String get enterCompleteDeliveryDetailsError => _tl
      ? 'Ilagay ang kumpletong delivery address, pangalan ng tatanggap, at contact number.'
      : 'Enter a complete delivery address, recipient name, and contact number.';
  String get orderPlacedCheckMyOrders => _tl
      ? 'Nailagay na ang order! Tingnan ang iyong order sa ilalim ng Mga Order Ko.'
      : 'Order placed! Check your order under My Orders.';
  String orderPlacedForSeller(String sellerName) => _tl
      ? 'Nailagay ang order sa $sellerName.'
      : 'Order placed with $sellerName.';
  String get totalWord => _tl ? 'Kabuuan' : 'Total';
  String get paymentMethodLabel => _tl ? 'Paraan ng Pagbabayad' : 'Payment Method';
  String get onlinePaymentLabel => _tl ? 'Online Payment' : 'Online Payment';
  String get cashOnDeliveryLabel =>
      _tl ? 'Cash on Delivery' : 'Cash on Delivery';
  String get payViaLabel => _tl ? 'Bayaran sa pamamagitan ng' : 'Pay via';
  String get gatewayGcashLabel => _tl ? 'GCash' : 'GCash';
  String get manualTransferLabel => _tl ? 'Manual Transfer' : 'Manual Transfer';
  String get manualTransferUnavailableForSeller => _tl
      ? 'Hindi available ang Manual Transfer para sa nagbebentang ito.'
      : 'Manual Transfer unavailable for this seller.';
  String get settlementMethodOptionalLabel => _tl
      ? 'Paraan ng bayad sa paghahatid (opsyonal)'
      : 'How will you pay on delivery? (optional)';
  String get cashLabel => _tl ? 'Cash' : 'Cash';
  String get fulfillmentMethodLabel =>
      _tl ? 'Paraan ng Pagkuha/Paghahatid' : 'Fulfillment Method';
  String get pickupLabel => _tl ? 'Pickup' : 'Pickup';
  String get onlyAvailableWithOnlinePayment => _tl
      ? 'Available lang sa Online Payment'
      : 'Only available with Online Payment';
  // Reverse direction of the note above -- shown on Cash on Delivery
  // itself when Pickup is already selected (see checkout_screen.dart's
  // own _onFulfillmentMethodChanged fix).
  String get notAvailableWithPickup => _tl
      ? 'Hindi available kapag Pickup ang napili'
      : 'Not available with Pickup selected';
  String get vendorDeliveryLabel =>
      _tl ? 'Delivery ng Vendor' : 'Vendor Delivery';
  String get thirdPartyDeliveryLabel =>
      _tl ? 'Third-Party Delivery' : 'Third-Party Delivery';
  // REAL GAP FOUND AND FIXED: all three fulfillment methods were just
  // bare radio labels, with nothing anywhere explaining what actually
  // happens for any of them -- confirmed by grepping the whole backend
  // for "third-party" and finding only the enum name itself, no
  // explanatory text. A buyer picking "Third-Party Delivery" had no
  // way to know it means THEY book and pay their own courier (Lalamove,
  // Grab Express, a personal rider), not the seller -- the opposite of
  // Vendor Delivery, where the seller/farmer personally delivers.
  String get pickupExplanation => _tl
      ? 'Kukunin mo mismo ang order sa seller.'
      : 'You collect the order in person from the seller.';
  String get vendorDeliveryExplanation => _tl
      ? 'Ang seller mismo ang maghahatid ng order sa iyo.'
      : 'The seller delivers the order to you themselves.';
  String get thirdPartyDeliveryExplanation => _tl
      ? 'Ikaw ang mag-aayos at magbabayad ng sarili mong courier (hal. Lalamove, Grab Express) para kunin ang order sa seller. Kausapin ang seller para sa oras ng pag-pickup.'
      : 'You arrange and pay for your own courier (e.g. Lalamove, Grab Express) to pick up the order from the seller. Coordinate pickup timing with the seller directly.';
  // Seller-side counterpart, shown on the order itself once a buyer
  // has chosen Third-Party Delivery, so the seller knows they aren't
  // the one responsible for getting it there.
  String get thirdPartyDeliverySellerNote => _tl
      ? 'Ang buyer ang mag-aayos ng sariling courier para kunin ang order. Ihanda lang ang order at ikoordinate ang oras ng pag-pickup.'
      : 'The buyer has arranged their own courier to collect this order. Just have it ready and coordinate pickup timing with them.';
  String get pickupDateLabel => _tl ? 'Petsa ng Pickup' : 'Pickup Date';
  String get selectDateLabel => _tl ? 'Pumili ng petsa' : 'Select date';
  String get pickupTimeSlotLabel => _tl ? 'Oras ng Pickup' : 'Pickup Time Slot';
  String get deliveryAddressLabel =>
      _tl ? 'Address para sa Delivery' : 'Delivery Address';
  String get recipientNameLabel =>
      _tl ? 'Pangalan ng Tatanggap' : 'Recipient Name';
  String get recipientContactNumberLabel =>
      _tl ? 'Contact Number ng Tatanggap' : 'Recipient Contact Number';
  String get deliveryNoteOptionalLabel =>
      _tl ? 'Tala sa Delivery (opsyonal)' : 'Delivery Note (optional)';
  String get orderNotesOptionalLabel =>
      _tl ? 'Mga Tala sa Order (opsyonal)' : 'Order Notes (optional)';

  // ── Cart (lib/features/cart/presentation/cart_screen.dart) ──
  String get cartTitle => _tl ? 'Cart' : 'Cart';
  String get yourCartIsEmpty =>
      _tl ? 'Walang laman ang iyong cart.' : 'Your cart is empty.';
  String subtotalLine(String amount) =>
      _tl ? 'Subtotal: $amount' : 'Subtotal: $amount';
  // Cart-wide checkout bar: lets the buyer pick exactly which items to
  // buy (even across different stores) in one pass, instead of one
  // all-or-nothing "Checkout" button per store.
  String itemsSelectedCount(int count) =>
      _tl ? '$count napiling item' : '$count item${count == 1 ? '' : 's'} selected';
  String get checkoutSelectedLabel =>
      _tl ? 'I-checkout' : 'Checkout';
  String get selectAtLeastOneItemError => _tl
      ? 'Pumili ng kahit isang item para mag-checkout.'
      : 'Select at least one item to checkout.';
  // Multi-store checkout queue (lib/features/cart/presentation/
  // multi_store_checkout_screen.dart): POST /orders is one seller per
  // call, so buying from several stores at once is this screen's own
  // same checkout form, run once per store in sequence.
  String storeProgressLabel(int current, int total) => _tl
      ? 'Tindahan $current sa $total'
      : 'Store $current of $total';
  String get allOrdersPlacedTitle =>
      _tl ? 'Nailagay ang lahat ng order!' : 'All orders placed!';
  String ordersPlacedCount(int count) => _tl
      ? 'Matagumpay na nailagay ang $count order.'
      : '$count order${count == 1 ? '' : 's'} placed successfully.';
  String get viewMyOrdersLabel =>
      _tl ? 'Tingnan ang Mga Order Ko' : 'View My Orders';

  // ── Farmers / Vendors directory (lib/features/farmers/presentation/*.dart) ──
  String get farmersTitle => _tl ? 'Mga Magsasaka' : 'Farmers';
  String get vendorsTitle => _tl ? 'Mga Vendor' : 'Vendors';
  String get couldntLoadFarmers =>
      _tl ? 'Hindi na-load ang mga magsasaka.' : 'Couldn\'t load farmers.';
  String get couldntLoadVendors =>
      _tl ? 'Hindi na-load ang mga vendor.' : 'Couldn\'t load vendors.';
  String get noFarmersFound => _tl ? 'Walang nahanap na magsasaka.' : 'No farmers found.';
  String get noVendorsFound => _tl ? 'Walang nahanap na vendor.' : 'No vendors found.';
  String productsCountSuffix(int count) =>
      _tl ? '$count produkto' : '$count products';
  String get couldntLoadSavedFarmers => _tl
      ? 'Hindi na-load ang iyong mga na-save na magsasaka.'
      : 'Couldn\'t load your saved farmers.';
  String get noSavedFarmersYetTapHeart => _tl
      ? 'Wala ka pang na-save na magsasaka. I-tap ang heart icon sa profile ng magsasaka para i-save sila dito.'
      : 'You haven\'t saved any farmers yet. Tap the heart icon on a farmer\'s profile to save them here.';

  // ── Order Detail (lib/features/orders/presentation/order_detail_screen.dart) ──
  String get orderDetailsTitle => _tl ? 'Mga Detalye ng Order' : 'Order Details';
  String get couldntLoadOrder =>
      _tl ? 'Hindi na-load ang order na ito.' : 'Couldn\'t load this order.';
  String get couldntOpenConversationTryAgain => _tl
      ? 'Hindi mabuksan ang usapan. Pakisubukan ulit.'
      : 'Couldn\'t open conversation. Please try again.';
  String get declineOrderTitle => _tl ? 'Tanggihan ang Order' : 'Decline Order';
  String get cancelOrderTitle => _tl ? 'Kanselahin ang Order' : 'Cancel Order';
  String get reasonForCancellingLabel =>
      _tl ? 'Dahilan ng pagkansela' : 'Reason for cancelling';
  String get reschedulePickupTitle =>
      _tl ? 'I-reschedule ang Pickup' : 'Reschedule Pickup';
  String get rescheduleDeliveryTitle =>
      _tl ? 'I-reschedule ang Delivery' : 'Reschedule Delivery';
  String get selectNewPickupDateLabel =>
      _tl ? 'Pumili ng bagong petsa ng pickup' : 'Select new pickup date';
  String get timeSlotLabel => _tl ? 'Time Slot' : 'Time Slot';
  String get selectNewDeliveryDateLabel =>
      _tl ? 'Pumili ng bagong petsa ng delivery' : 'Select new delivery date';
  String get pleaseSpecifyLabel =>
      _tl ? 'Pakisabi' : 'Please specify';
  String get rejectPaymentProofTitle =>
      _tl ? 'Tanggihan ang Patunay ng Bayad' : 'Reject Payment Proof';
  String get addNoteTitle => _tl ? 'Magdagdag ng Tala' : 'Add Note';
  String get editNoteTitle => _tl ? 'I-edit ang Tala' : 'Edit Note';
  String get addNoteButtonLabel => _tl ? 'Magdagdag ng tala' : 'Add note';
  String get editNoteButtonLabel => _tl ? 'I-edit ang tala' : 'Edit note';
  String get noteLabel => _tl ? 'Tala' : 'Note';
  String get notesSectionTitle => _tl ? 'Mga Tala' : 'Notes';
  String get backLabel => _tl ? 'Bumalik' : 'Back';
  String get otherReasonLabel => _tl ? 'Iba pa' : 'Other';
  String codDeclineReasonLabel(String key) => switch (key) {
        'insufficient_quantity' => _tl
            ? 'Hindi kayang tustusan ang hiniling na dami'
            : 'Unable to fulfill the requested quantity',
        'settlement_method_unavailable' => _tl
            ? 'Hindi matanggap ang inilahad na paraan ng settlement ng buyer'
            : 'Cannot accommodate the buyer\'s declared settlement method',
        'outside_service_area' => _tl
            ? 'Ang delivery address ay nasa labas ng service area'
            : 'Delivery address outside service area',
        _ => otherReasonLabel,
      };
  String paidDeclineReasonLabel(String key) => switch (key) {
        'insufficient_quantity' => _tl
            ? 'Hindi kayang tustusan ang hiniling na dami'
            : 'Unable to fulfill the requested quantity',
        'product_no_longer_available' =>
          _tl ? 'Hindi na available ang produkto' : 'Product no longer available',
        'outside_service_area' => _tl
            ? 'Ang delivery address ay nasa labas ng service area'
            : 'Delivery address outside service area',
        _ => otherReasonLabel,
      };
  String fulfillmentReasonLabel(String key) => switch (key) {
        'no_cash_on_hand' => _tl ? 'Walang available na cash' : 'No cash on hand',
        'not_available' => _tl
            ? 'Hindi available sa naka-iskedyul na oras'
            : 'Not available at the scheduled time',
        'address_needs_correction' => _tl
            ? 'Kailangan ng pagwawasto ang delivery address'
            : 'Delivery address needs correction',
        _ => otherReasonLabel,
      };
  String proofRejectReasonLabel(String key) => switch (key) {
        'unreadable_or_incomplete' => _tl
            ? 'Hindi mabasa o hindi kumpleto ang larawan ng patunay'
            : 'Proof image unreadable or incomplete',
        'amount_mismatch' => _tl
            ? 'Hindi tugma ang halaga sa napagkasunduang presyo'
            : 'Amount does not match the agreed price',
        'altered_or_inconsistent' => _tl
            ? 'Mukhang binago o hindi magkatugma ang patunay'
            : 'Proof appears altered or inconsistent',
        'payment_not_received' => _tl
            ? 'Hindi natanggap o hindi nakumpirma ang bayad'
            : 'Payment not received or not confirmed',
        _ => otherReasonLabel,
      };
  String orderStatusSpokenText(String label) =>
      _tl ? 'Katayuan ng order: $label.' : 'Order status: $label.';
  String get reviewThisProductTooltip =>
      _tl ? 'I-review ang produktong ito' : 'Review this product';
  String get paymentLabel => _tl ? 'Bayad' : 'Payment';
  String get settlementNoteLabel => _tl ? 'Tala sa Settlement' : 'Settlement Note';
  String get pickupTimeLabel => _tl ? 'Oras ng Pickup' : 'Pickup Time';
  String get recipientLabel => _tl ? 'Tatanggap' : 'Recipient';
  String get contactLabel => _tl ? 'Contact' : 'Contact';
  String get estimatedDeliveryLabel =>
      _tl ? 'Tinatayang Paghahatid' : 'Estimated Delivery';
  String get onlineGatewayLabel =>
      _tl ? 'Online — GCash' : 'Online — GCash';
  String get onlineManualTransferLabel =>
      _tl ? 'Online — Manual Transfer' : 'Online — Manual Transfer';
  String get paymentProofSectionTitle =>
      _tl ? 'Patunay ng Bayad' : 'Payment Proof';
  String get sendPaymentToLabel =>
      _tl ? 'Ipadala ang bayad sa:' : 'Send payment to:';
  String get paymentReminderBeforeSending => _tl
      ? 'Tiyaking tama ang mga detalye ng bayad bago magpadala ng pera. Hindi mananagot ang NagaGuno sa anumang pagkalugi dahil sa bayad na ipinadala sa maling detalye.'
      : 'Double-check these payment details before sending money. NagaGuno is not responsible for any loss resulting from payment sent to incorrect details.';
  String get paymentReminderBeforeAccepting => _tl
      ? 'Suriin muna ang iyong sariling account (bangko o GCash) para makumpirma na natanggap mo talaga ang bayad, bago suriin ang patunay na ito. Hindi mananagot ang NagaGuno sa anumang pagkalugi dahil sa pagtanggap ng patunay na lumabas na mali o peke.'
      : 'Check your own account (bank or GCash) first to confirm you actually received the payment, before reviewing this proof. NagaGuno is not responsible for any loss resulting from accepting proof that turns out to be incorrect or fraudulent.';
  String get uploadPaymentProofLabel =>
      _tl ? 'Mag-upload ng Patunay ng Bayad' : 'Upload Payment Proof';
  String get rejectLabel => _tl ? 'Tanggihan' : 'Reject';
  String get verifyLabel => _tl ? 'I-verify' : 'Verify';
  String get retryPaymentLabel => _tl ? 'Subukan Ulit ang Bayad' : 'Retry Payment';
  String get confirmOrderLabel => _tl ? 'Kumpirmahin ang Order' : 'Confirm Order';
  String get markAsPreparingLabel =>
      _tl ? 'Markahan bilang Inihahanda' : 'Mark as Preparing';
  String get markAsDispatchedLabel =>
      _tl ? 'Markahan bilang Nai-dispatch' : 'Mark as Dispatched';
  String get notifyReadyForPickupLabel =>
      _tl ? 'Ipaalam na Handa na para sa Pickup' : 'Notify Ready for Pickup';
  String get markAsPickedUpLabel =>
      _tl ? 'Markahan bilang Nakuha Na' : 'Mark as Picked Up';
  String get declineOrderRefundBuyerLabel => _tl
      ? 'Tanggihan ang Order (I-refund ang Buyer)'
      : 'Decline Order (Refund Buyer)';
  String get markAsReceivedLabel =>
      _tl ? 'Markahan bilang Natanggap' : 'Mark as Received';
  String get leaveAReviewLabel => _tl ? 'Mag-iwan ng Review' : 'Leave a Review';
  String get reportOrderNotArrivedLabel => _tl
      ? 'I-report: Hindi Dumating ang Order'
      : 'Report: Order Not Arrived';
  String get proofNoneLabel => _tl
      ? 'Wala pang na-upload na patunay ng bayad.'
      : 'No payment proof uploaded yet.';
  String get proofPendingLabel =>
      _tl ? 'Hinihintay ang review ng nagbebenta.' : 'Awaiting seller review.';
  String get proofVerifiedLabel =>
      _tl ? 'Na-verify na ang bayad.' : 'Payment verified.';
  String get proofRejectedLabel => _tl
      ? 'Tinanggihan ang patunay ng bayad. Pakiupload ng bago.'
      : 'Payment proof was rejected. Please upload a new one.';
  String get orderCancelledLabel =>
      _tl ? 'Kinansela ang Order' : 'Order Cancelled';
  String get pickedUpLabel => _tl ? 'Nakuha Na' : 'Picked Up';

  // ── Farmer / Vendor Profile (lib/features/farmers/presentation/farmer_detail_screen.dart, vendor_detail_screen.dart) ──
  String get farmerProfileTitle => _tl ? 'Profile ng Magsasaka' : 'Farmer Profile';
  String get vendorProfileTitle => _tl ? 'Profile ng Vendor' : 'Vendor Profile';
  String get couldntLoadFarmer =>
      _tl ? 'Hindi na-load ang magsasakang ito.' : 'Couldn\'t load this farmer.';
  String get couldntLoadVendor =>
      _tl ? 'Hindi na-load ang vendor na ito.' : 'Couldn\'t load this vendor.';
  String get messageLabel => _tl ? 'Mensahe' : 'Message';
  String get aboutLabel => _tl ? 'Tungkol' : 'About';
  String get ratingsAndReviewsLabel =>
      _tl ? 'Mga Rating at Review' : 'Ratings & Reviews';
  String get productsLabel => _tl ? 'Mga Produkto' : 'Products';
  String get openForAgreementRequestsLabel =>
      _tl ? 'Bukas para sa Agreement Request' : 'Open for Agreement Requests';
  String estHarvestLabel(String date) =>
      _tl ? 'Tinatayang ani: $date' : 'Est. harvest: $date';
  String get requestLabel => _tl ? 'Mag-request' : 'Request';
  String get noOpenProductionPlansRightNow => _tl
      ? 'Walang bukas na plano sa produksyon sa ngayon.'
      : 'No open production plans right now.';
  String joinedYear(String year) => _tl ? 'Sumali noong $year' : 'Joined $year';

  // ── Notifications (lib/features/notifications/presentation/notifications_screen.dart) ──
  String get notificationsTitle => _tl ? 'Mga Notification' : 'Notifications';
  String get markAllReadLabel =>
      _tl ? 'Markahan Lahat na Nabasa' : 'Mark all read';
  String get couldntMarkAllAsReadTryAgain => _tl
      ? 'Hindi namarkahan lahat bilang nabasa. Pakisubukan ulit.'
      : 'Couldn\'t mark all as read. Please try again.';
  String get couldntLoadNotifications =>
      _tl ? 'Hindi na-load ang mga notification.' : 'Couldn\'t load notifications.';
  String get noNotificationsYet =>
      _tl ? 'Wala pang notification.' : 'No notifications yet.';

  // ── KYC (lib/features/kyc/presentation/kyc_screen.dart) ──
  String get verificationTitle => _tl ? 'Pagpapatunay' : 'Verification';
  String get couldntLoadVerificationStatus => _tl
      ? 'Hindi na-load ang status ng iyong pagpapatunay.'
      : 'Couldn\'t load your verification status.';
  String get checkAgainLabel => _tl ? 'Suriin Ulit' : 'Check Again';

  // ── KYC Submission (lib/features/kyc/presentation/kyc_submission_screen.dart) ──
  String get verifyYourAccountTitle =>
      _tl ? 'Patunayan ang Iyong Account' : 'Verify Your Account';
  String get resubmissionRequiredLabel =>
      _tl ? 'Kailangan ng resubmission' : 'Resubmission required';
  String get previousSubmissionNotApproved => _tl
      ? 'Hindi na-approve ang iyong nakaraang submission'
      : 'Your previous submission was not approved';
  String pleaseUpdateFieldsLabel(String fields) =>
      _tl ? 'Pakiupdate ang: $fields.' : 'Please update: $fields.';
  String resubmissionFieldLabel(String key) => switch (key) {
        'id_front' => _tl ? 'ang unahan ng iyong ID' : 'the front of your ID',
        'id_back' => _tl ? 'ang likod ng iyong ID' : 'the back of your ID',
        'supporting_doc' =>
          _tl ? 'ang iyong supporting document' : 'your supporting document',
        'liveness' => _tl
            ? 'ang iyong liveness/selfie check'
            : 'your liveness/selfie check',
        'id_type' => _tl ? 'ang iyong napiling ID type' : 'your selected ID type',
        'account_details' => _tl
            ? 'ang iyong buong pangalan o petsa ng kapanganakan'
            : 'your full name or date of birth',
        _ => key,
      };
  // Age is calculated from date of birth, never typed in -- same UW 1
  // rule registration already follows (see kyc_submission_screen.dart's
  // own header note on the Age field this replaced).
  String ageFromDateOfBirth(int age) =>
      _tl ? 'Edad: $age' : 'Age: $age';
  String get pleaseSelectBarangayError =>
      _tl ? 'Mangyaring pumili ng barangay.' : 'Please select a barangay.';
  String get addressDetailLabel => _tl
      ? 'Numero ng Bahay/Lote, Kalye, Zone'
      : 'House/Lot No., Street, Zone';
  String get addressDetailHint =>
      _tl ? 'hal. 12 Rizal St., Zone 3' : 'e.g. 12 Rizal St., Zone 3';
  String get addressRequiredError =>
      _tl ? 'Kailangan ang address.' : 'Address is required.';
  String get contactNumberLabel => _tl ? 'Contact Number' : 'Contact Number';
  String get contactNumberHint =>
      _tl ? '09123456789 o +639123456789' : '09123456789 or +639123456789';
  String get contactNumberRequiredError =>
      _tl ? 'Kailangan ang contact number.' : 'Contact number is required.';
  String get enterValidPhMobileNumberError => _tl
      ? 'Maglagay ng wastong PH mobile number.'
      : 'Enter a valid PH mobile number.';
  String get idTypeLabel => _tl ? 'ID Type' : 'ID Type';
  String get idFrontPhotoLabel => _tl ? 'Larawan ng Unahan ng ID' : 'ID Front Photo';
  String get idBackPhotoLabel => _tl ? 'Larawan ng Likod ng ID' : 'ID Back Photo';
  String get livenessCheckLabel => _tl ? 'Liveness Check' : 'Liveness Check';
  String get livenessCheckSkippedLabel =>
      _tl ? 'Liveness Check — Nilaktawan' : 'Liveness Check — Skipped';
  String get idTypeVerifiedAutomaticallyNote => _tl
      ? 'Awtomatikong na-verify ang ID type na ito. Pagkatapos mong magsubmit, dadalhin ka sa isang secure page para kumpletuhin ang iyong ID scan at mabilisang selfie check.'
      : 'This ID type is verified automatically. After you submit, you\'ll be taken to a secure page to complete your ID scan and a quick selfie check.';
  String get supportingDocumentOptionalLabel =>
      _tl ? 'Supporting Document (opsyonal)' : 'Supporting Document (optional)';
  String addedSuffixLabel(String label) =>
      _tl ? '$label — Naidagdag' : '$label — Added';
  String get submitForVerificationLabel =>
      _tl ? 'Isumite para sa Pagpapatunay' : 'Submit for Verification';
  String get pleaseSelectDateOfBirthError => _tl
      ? 'Mangyaring pumili ng petsa ng kapanganakan.'
      : 'Please select your date of birth.';
  String get pleaseUploadIdFrontError => _tl
      ? 'Mangyaring i-upload ang unahan ng iyong ID.'
      : 'Please upload the front of your ID.';
  String get idTypeRequiresBackUploadError => _tl
      ? 'Ang ID type na ito ay nangangailangan ng back-image upload.'
      : 'This ID type requires a back-image upload.';
  String get pleaseCompleteLivenessCheckError => _tl
      ? 'Mangyaring kumpletuhin ang liveness check.'
      : 'Please complete the liveness check.';
  String get couldntOpenVerificationLinkError => _tl
      ? 'Hindi mabuksan ang verification page. Suriin ang iyong koneksyon at subukan muli.'
      : "Couldn't open the verification page. Check your connection and try again.";

  // ── Walkthrough (lib/features/walkthrough/presentation/walkthrough_screen.dart) ──
  String get skipLabel => _tl ? 'Laktawan' : 'Skip';
  String get nextLabel => _tl ? 'Susunod' : 'Next';
  String get isTheTextEasyToRead =>
      _tl ? 'Madali bang basahin ang text?' : 'Is the text easy to read?';
  String get pickComfortableSizeNote => _tl
      ? 'Pumili ng komportableng sukat ngayon. Maaari mo itong baguhin anumang oras sa Settings.'
      : 'Pick a comfortable size now. You can change this anytime in Settings.';

  // ── Conversations / Messages (lib/features/conversations/presentation/*.dart) ──
  String get messagesTitle => _tl ? 'Mga Mensahe' : 'Messages';
  String get couldntLoadConversations => _tl
      ? 'Hindi na-load ang iyong mga conversation.'
      : 'Couldn\'t load your conversations.';
  String get noConversationsYet =>
      _tl ? 'Wala ka pang conversation.' : 'No conversations yet.';
  String get noMessagesYet => _tl ? 'Wala pang mensahe.' : 'No messages yet.';
  String get couldntLoadMessages =>
      _tl ? 'Hindi na-load ang mga mensahe.' : 'Couldn\'t load messages.';
  String get failedTapToRetry =>
      _tl ? 'Nabigo. I-tap para subukan ulit.' : 'Failed. Tap to retry.';
  String get imageAttachedLabel =>
      _tl ? 'May nakalakip na larawan' : 'Image attached';
  String get typeAMessageHint =>
      _tl ? 'Mag-type ng mensahe...' : 'Type a message...';

  // ── Reports / Blocking (lib/features/reports/presentation/*.dart) ──
  String get reportTooltip => _tl ? 'I-report' : 'Report';
  String reportUserLabel(String name) =>
      _tl ? 'I-report si $name' : 'Report $name';
  String get reportProfilePictureLabel =>
      _tl ? 'I-report ang profile picture' : 'Report profile picture';
  String get myReportsTitle => _tl ? 'Mga Report Ko' : 'My Reports';
  String get couldntLoadReports =>
      _tl ? 'Hindi na-load ang iyong mga report.' : 'Couldn\'t load your reports.';
  String get havenFiledAnyReportsYet =>
      _tl ? 'Wala ka pang isinampang report.' : 'You haven\'t filed any reports.';
  String get reportStatusUnderReview => _tl ? 'Sinusuri' : 'Under Review';
  String get reportStatusVerified => _tl ? 'Na-verify' : 'Verified';
  String get reportStatusDismissed => _tl ? 'Idinismiss' : 'Dismissed';
  String get reportStatusMoreInfoNeeded =>
      _tl ? 'Kailangan ng Karagdagang Impormasyon' : 'More Info Needed';
  String reportStatusLabel(String status) => switch (status) {
        'pending' => reportStatusUnderReview,
        'verified' => reportStatusVerified,
        'dismissed' => reportStatusDismissed,
        'more_info_requested' => reportStatusMoreInfoNeeded,
        _ => status,
      };

  // ── Report User (lib/features/reports/presentation/report_user_screen.dart) ──
  // Violation group/type labels themselves (violationTypes, defined in
  // domain/report_models.dart) are left in English for now, same
  // "representative, not exhaustive" scope as other large domain
  // content catalogs this pass -- only the screen's own chrome below
  // is translated here.
  String get selectWhatHappenedError =>
      _tl ? 'Pumili kung ano ang nangyari.' : 'Select what happened.';
  String get pleaseDescribeWhatHappenedError => _tl
      ? 'Mangyaring ilarawan kung ano ang nangyari.'
      : 'Please describe what happened.';
  String get reportSubmittedAdminWillReview => _tl
      ? 'Naisumite ang report. Susuriin ito ng admin.'
      : 'Report submitted. An admin will review it.';
  String get whatKindOfIssueIsThisLabel =>
      _tl ? 'Anong klaseng isyu ito?' : 'What kind of issue is this?';
  String get transactionIssueLabel =>
      _tl ? 'Isyu sa Transaksyon' : 'Transaction Issue';
  String get orderNotArrivedLabel =>
      _tl ? 'Hindi Dumating ang Order' : 'Order Not Arrived';
  String get buyerConductLabel => _tl ? 'Ugali ng Buyer' : 'Buyer Conduct';
  String get sellerConductLabel => _tl ? 'Ugali ng Seller' : 'Seller Conduct';
  String violationGroupLabel(String group) => switch (group) {
        'transaction' => transactionIssueLabel,
        'non_arrival' => orderNotArrivedLabel,
        'buyer_conduct' => buyerConductLabel,
        'seller_conduct' => sellerConductLabel,
        _ => group,
      };
  String get whatHappenedLabel => _tl ? 'Ano ang nangyari?' : 'What happened?';
  String get pleaseDescribeWhatHappenedLabel =>
      _tl ? 'Ilarawan kung ano ang nangyari' : 'Please describe what happened';
  String get additionalDetailsOptionalLabel =>
      _tl ? 'Karagdagang detalye (opsyonal)' : 'Additional details (optional)';
  String photosEvidenceCount(int count) =>
      _tl ? '$count/5 larawan (ebidensya)' : '$count/5 photos (evidence)';
  String get submitReportLabel => _tl ? 'Isumite ang Report' : 'Submit Report';

  // ── Block User (lib/features/blocks/presentation/*.dart) ──
  String unblockUserQuestion(String name) =>
      _tl ? 'I-unblock si $name?' : 'Unblock $name?';
  String blockUserQuestion(String name) =>
      _tl ? 'I-block si $name?' : 'Block $name?';
  String get unblockExplanation => _tl
      ? 'Makikita mo ulit ang kanilang mga listing at profile, at makakapagmensahe na sila sa iyo.'
      : 'You\'ll see their listings and profile again, and they\'ll be able to message you.';
  String get blockExplanation => _tl
      ? 'Itatago sa iyo ang kanilang mga listing at profile, at hindi na sila makakapagmensahe sa iyo. Hindi sila mapapaalaman nito, at maaari mo itong bawiin anumang oras.'
      : 'Their listings and profile will be hidden from you, and they won\'t be able to message you. This won\'t notify them, and you can undo it anytime.';
  String get unblockLabel => _tl ? 'I-unblock' : 'Unblock';
  String get blockLabel => _tl ? 'I-block' : 'Block';
  String get blockedUsersTitle => _tl ? 'Mga Naka-block na User' : 'Blocked Users';
  String get couldntLoadBlockedUsers => _tl
      ? 'Hindi na-load ang iyong mga naka-block na user.'
      : 'Couldn\'t load your blocked users.';
  String get noBlockedUsersYet =>
      _tl ? 'Wala kang naka-block na user.' : 'You haven\'t blocked anyone.';
  String roleLabel(String role) => switch (role) {
        'buyer' => buyer,
        'farmer' => farmer,
        'vendor' => vendor,
        _ => role.isEmpty ? role : role[0].toUpperCase() + role.substring(1),
      };
}
