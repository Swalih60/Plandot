import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../services/pro_service.dart';
import 'theme.dart';

/// Opens the paywall. Resolves to true if the user is Pro afterwards.
Future<bool> showPaywall(BuildContext context, {String? reason}) async {
  final pro = context.read<ProService>();
  if (pro.isPro) return true;
  await Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PaywallScreen(reason: reason),
    ),
  );
  return pro.isPro;
}

Future<void> openUrl(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, this.reason});
  final String? reason;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Package? _selected;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final pro = context.read<ProService>();
    if (pro.offering == null) pro.loadOfferings();
  }

  List<Package> _packages(Offering? o) {
    if (o == null) return const [];
    return [
      o.annual,
      o.monthly,
      o.lifetime,
      o.weekly,
    ].whereType<Package>().toList();
  }

  static String? trialText(Package p) {
    final sp = p.storeProduct;
    final intro = sp.introductoryPrice;
    if (intro != null && intro.price == 0) {
      return _period(intro.periodNumberOfUnits, intro.periodUnit);
    }
    final free = sp.defaultOption?.freePhase?.billingPeriod;
    if (free != null) return _period(free.value, free.unit);
    return null;
  }

  static String _period(int n, PeriodUnit u) {
    final days = switch (u) {
      PeriodUnit.day => n,
      PeriodUnit.week => n * 7,
      PeriodUnit.month => n * 30,
      PeriodUnit.year => n * 365,
      PeriodUnit.unknown => n,
    };
    return '$days-day';
  }

  static String _title(Package p) => switch (p.packageType) {
    PackageType.annual => 'Yearly',
    PackageType.monthly => 'Monthly',
    PackageType.weekly => 'Weekly',
    PackageType.lifetime => 'Lifetime',
    _ => p.storeProduct.title,
  };

  static String _per(Package p) => switch (p.packageType) {
    PackageType.annual => '/year',
    PackageType.monthly => '/month',
    PackageType.weekly => '/week',
    PackageType.lifetime => ' once',
    _ => '',
  };

  Future<void> _buy() async {
    final p = _selected;
    if (p == null) return;
    setState(() => _busy = true);
    try {
      final ok = await context.read<ProService>().buy(p);
      if (ok && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Welcome to Pro! 🎉')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    try {
      final ok = await context.read<ProService>().restore();
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchases restored. You\'re Pro!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active Pro purchase found for this account.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pro = context.watch<ProService>();
    final packages = _packages(pro.offering);
    _selected ??= packages.isEmpty ? null : packages.first;
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    final sel = _selected;
    final trial = sel == null ? null : trialText(sel);
    final isSub = sel != null && sel.packageType != PackageType.lifetime;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : _restore,
            child: const Text('Restore'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            const _MiniGrid(),
            const SizedBox(height: 20),
            const Text(
              'Plandot Pro',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.reason ?? 'Plan smarter, every single day. No ads, ever.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 15),
            ),
            const SizedBox(height: 22),
            for (final f in const [
              ('🔁', 'Repeating tasks', 'Daily, weekdays or weekly routines'),
              ('📊', 'Insights', 'Trends, best days, priority breakdown'),
              ('🎨', '7 premium themes', 'Make Plandot feel like yours'),
              ('⚡', 'Everything future', 'New Pro features as they ship'),
              (
                '🔒',
                'Private forever',
                'No account, no ads, data stays on device',
              ),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Text(f.$1, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.$2,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            f.$3,
                            style: TextStyle(color: muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            if (!AppConfig.storeConfigured ||
                (pro.configured && packages.isEmpty))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        AppConfig.storeConfigured
                            ? 'Plans are loading. Check your connection and try again.'
                            : 'The store isn\'t set up yet in this build.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted),
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            pro.toggleDebugPro();
                            Navigator.of(context).pop();
                          },
                          child: const Text('Debug: unlock Pro'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              for (final p in packages)
                _PlanTile(
                  title: _title(p),
                  price: '${p.storeProduct.priceString}${_per(p)}',
                  badge: p.packageType == PackageType.annual
                      ? (trialText(p) != null
                            ? '${trialText(p)} free trial'
                            : 'Best value')
                      : p.packageType == PackageType.lifetime
                      ? 'Pay once'
                      : null,
                  sub:
                      p.packageType == PackageType.annual &&
                          p.storeProduct.pricePerMonth != null
                      ? 'Just ${_money(p.storeProduct.pricePerMonth!, p.storeProduct.currencyCode)}/month'
                      : null,
                  selected: identical(p, _selected),
                  onTap: () => setState(() => _selected = p),
                ),
            const SizedBox(height: 16),
            if (packages.isNotEmpty)
              FilledButton(
                onPressed: _busy ? null : _buy,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(
                        trial != null
                            ? 'Start $trial free trial'
                            : sel?.packageType == PackageType.lifetime
                            ? 'Unlock forever'
                            : 'Continue',
                      ),
              ),
            const SizedBox(height: 12),
            if (sel != null)
              Text(
                isSub
                    ? '${trial != null ? 'Free for $trial trial, then ' : ''}'
                          '${sel.storeProduct.priceString}${_per(sel)}. '
                          'Subscription renews automatically until cancelled. '
                          'Cancel anytime in your ${Theme.of(context).platform == TargetPlatform.iOS ? 'App Store' : 'Google Play'} '
                          'settings at least 24 hours before the period ends.'
                    : 'One-time purchase. No subscription.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 11.5),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => openUrl(
                    Theme.of(context).platform == TargetPlatform.iOS
                        ? AppConfig.appleEulaUrl
                        : AppConfig.termsUrl,
                  ),
                  child: const Text(
                    'Terms of Use',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                Text('·', style: TextStyle(color: muted)),
                TextButton(
                  onPressed: () => openUrl(AppConfig.privacyUrl),
                  child: const Text(
                    'Privacy Policy',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _money(double v, String currency) {
    final symbol = switch (currency) {
      'USD' => '\$',
      'INR' => '₹',
      'EUR' => '€',
      'GBP' => '£',
      _ => '$currency ',
    };
    return '$symbol${v.toStringAsFixed(v >= 100 ? 0 : 2)}';
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.title,
    required this.price,
    required this.selected,
    required this.onTap,
    this.badge,
    this.sub,
  });

  final String title;
  final String price;
  final String? badge;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : context.pal.line,
              width: selected ? 2.5 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? scheme.primary : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badge!,
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (sub != null)
                      Text(
                        sub!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              ),
              Text(price, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decorative stack of checked tasks shown at the top of the paywall.
class _MiniGrid extends StatelessWidget {
  const _MiniGrid();

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    const rows = [
      ('Ship the proposal', Color(0xFFFF4D57)),
      ('Morning workout', Color(0xFFFFA41B)),
      ('Call mom', Color(0xFF3B9CFF)),
    ];
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Container(
                margin: EdgeInsets.only(
                  bottom: 8,
                  left: i * 14.0,
                  right: (2 - i) * 14.0,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: pal.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: pal.line),
                  boxShadow: softShadow(context),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: rows[i].$2,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      rows[i].$1,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: pal.muted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(delay: (120 * i).ms, duration: 350.ms)
              .slideY(
                begin: 0.4,
                curve: Curves.easeOutBack,
                delay: (120 * i).ms,
              ),
      ],
    );
  }
}
