/// App-wide configuration. Fill in the RevenueCat public SDK keys before
/// release (RevenueCat dashboard → Project → API keys).
class AppConfig {
  static const appName = 'Plandot';

  static const revenueCatAppleKey = 'REPLACE_WITH_appl_KEY';
  static const revenueCatGoogleKey = 'REPLACE_WITH_goog_KEY';
  static const entitlementId = 'pro';

  static const privacyUrl = 'https://swalih60.github.io/Ticklist/privacy.html';
  static const termsUrl = 'https://swalih60.github.io/Ticklist/terms.html';
  static const appleEulaUrl =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  static const supportEmail = 'support@EXAMPLE.com';

  static bool get storeConfigured =>
      !revenueCatAppleKey.startsWith('REPLACE') ||
      !revenueCatGoogleKey.startsWith('REPLACE');
}
