import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config.dart';

/// Wraps RevenueCat. RevenueCat validates receipts on its own servers, so the
/// app needs no backend of its own.
class ProService extends ChangeNotifier {
  bool _isPro = false;
  bool _debugPro = false;
  bool configured = false;
  Offering? offering;
  String? lastError;

  /// Owner build: `--dart-define=OWNER_BUILD=true` unlocks Pro for the
  /// developer's own copy. Store builds never set this flag.
  static const ownerBuild = bool.fromEnvironment('OWNER_BUILD');

  bool get isPro => ownerBuild || _isPro || _debugPro;

  Future<void> init() async {
    if (!(Platform.isIOS || Platform.isAndroid)) return;
    final key = Platform.isIOS
        ? AppConfig.revenueCatAppleKey
        : AppConfig.revenueCatGoogleKey;
    if (key.startsWith('REPLACE')) return;
    try {
      if (kDebugMode) await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(key));
      configured = true;
      Purchases.addCustomerInfoUpdateListener(_apply);
      _apply(await Purchases.getCustomerInfo());
      await loadOfferings();
    } catch (e) {
      lastError = '$e';
      debugPrint('RevenueCat init failed: $e');
    }
  }

  void _apply(CustomerInfo info) {
    final active = info.entitlements.active.containsKey(AppConfig.entitlementId);
    if (active != _isPro) {
      _isPro = active;
      notifyListeners();
    }
  }

  Future<void> loadOfferings() async {
    if (!configured) return;
    try {
      final o = await Purchases.getOfferings();
      offering = o.current;
      notifyListeners();
    } catch (e) {
      lastError = '$e';
    }
  }

  /// Returns true when the purchase unlocked Pro. Returns false if the user
  /// cancelled. Throws a readable message on other failures.
  Future<bool> buy(Package p) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(p));
      _apply(result.customerInfo);
      return isPro;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) return false;
      throw e.message ?? 'Purchase failed. Please try again.';
    }
  }

  /// Returns true if an active Pro purchase was found.
  Future<bool> restore() async {
    if (!configured) return false;
    try {
      _apply(await Purchases.restorePurchases());
      return isPro;
    } on PlatformException catch (e) {
      throw e.message ?? 'Restore failed. Please try again.';
    }
  }

  /// Debug builds only: lets you test Pro features before the store is set up.
  void toggleDebugPro() {
    if (!kDebugMode) return;
    _debugPro = !_debugPro;
    notifyListeners();
  }
}
