import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/config/admob_config.dart';
import '../../../../core/providers/analytics_provider.dart';
import '../../../../core/services/logger_service.dart';
import '../providers/ads_providers.dart';

/// An anchored bottom banner ad.
///
/// Renders nothing (`SizedBox.shrink`) for premium users, on unsupported
/// platforms, during the new-user grace period, or until an ad has loaded — so
/// it's always safe to drop into any layout as a `bottomNavigationBar`. Reacts
/// to premium upgrades: if ads become disabled while mounted, the banner is torn
/// down automatically.
///
/// Two layout details matter as much as the gating:
///
///  * The reveal is **animated**. Collapsing to zero height and then snapping to
///    50px the instant an ad arrives shifts the whole screen under the user's
///    thumb, which is a large part of what makes banners feel cheap.
///  * There's a **separator and a gutter** above the ad. It marks the banner as
///    a distinct zone rather than part of the app, and it keeps a floating
///    action button from sitting flush against a tappable ad.
class BannerAdWidget extends ConsumerStatefulWidget {
  const BannerAdWidget({super.key});

  @override
  ConsumerState<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends ConsumerState<BannerAdWidget> {
  BannerAd? _banner;
  bool _loaded = false;
  bool _loading = false;

  /// Failed loads must NOT retry on every rebuild — that would fire an unbounded
  /// stream of ad requests (wasted requests + AdMob "invalid traffic" risk). Cap
  /// the attempts and then give up for this widget's lifetime.
  int _attempts = 0;
  bool _failed = false;
  static const int _maxAttempts = 2;

  /// Gutter between app content (or a FAB) and the ad itself.
  static const double _gutter = 8;
  static const Duration _revealDuration = Duration(milliseconds: 220);

  static final AdRequest _request = AdRequest(
    keywords: const ['travel', 'trips', 'vacation', 'flights', 'hotels'],
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kick the load off here rather than from build(): starting a network
    // request from build() is a side effect in a method that can run repeatedly.
    if (ref.read(bannerAdsEnabledProvider)) _load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  void _load() {
    if (_loading || _loaded || _failed || !AdMobConfig.isSupportedPlatform) {
      return;
    }
    _loading = true;
    _attempts++;

    // Standard 320x50 banner — compact and predictable. (The adaptive sizes in
    // google_mobile_ads 9.x are the tall "Large" anchored format, which eats too
    // much vertical space at the bottom of a screen.)
    final banner = BannerAd(
      adUnitId: AdMobConfig.bannerAdUnitId,
      size: AdSize.banner,
      request: _request,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _banner = ad as BannerAd;
            _loaded = true;
            _loading = false;
          });
        },
        onPaidEvent: (ad, valueMicros, precision, currencyCode) {
          ref.read(analyticsServiceProvider).trackAdRevenue(
                format: 'banner',
                valueMicros: valueMicros,
                currency: currencyCode,
                precision: precision.index,
              );
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _loading = false;
          if (_attempts >= _maxAttempts) _failed = true;
          AppLogger.debug('Banner failed to load: ${error.message}');
        },
      ),
    );
    banner.load();
  }

  void _teardown() {
    _banner?.dispose();
    _banner = null;
    _loaded = false;
    _loading = false;
    _failed = false;
    _attempts = 0;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(bannerAdsEnabledProvider);

    if (!enabled) {
      if (_banner != null || _loaded) {
        // Premium upgrade (or consent revoked) mid-session: tear down.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(_teardown);
        });
      }
      return const SizedBox.shrink();
    }

    if (!_loaded && !_loading && !_failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }

    final theme = Theme.of(context);
    final banner = _banner;

    // Always return the AnimatedSize so the reveal is a growth rather than a
    // snap; the child is what changes height, from nothing to the loaded ad.
    return SafeArea(
      top: false,
      child: AnimatedSize(
        duration: _revealDuration,
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: banner == null || !_loaded
            ? const SizedBox(width: double.infinity)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: _gutter),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                  Container(
                    color: theme.colorScheme.surface,
                    width: double.infinity,
                    height: banner.size.height.toDouble(),
                    alignment: Alignment.center,
                    child: AdWidget(ad: banner),
                  ),
                ],
              ),
      ),
    );
  }
}
