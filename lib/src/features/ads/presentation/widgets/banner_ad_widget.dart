import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/config/admob_config.dart';
import '../../../../core/providers/analytics_provider.dart';
import '../../../../core/services/logger_service.dart';
import '../providers/ads_providers.dart';

/// An anchored, orientation-aware **adaptive** banner ad.
///
/// Renders nothing (`SizedBox.shrink`) for premium users, on unsupported
/// platforms, or until an ad has loaded — so it's always safe to drop into any
/// layout (typically the bottom of a screen). Reacts to premium upgrades: if
/// ads become disabled while mounted, the banner is torn down automatically.
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

  static final AdRequest _request = AdRequest(
    keywords: const ['travel', 'trips', 'vacation', 'flights', 'hotels'],
  );

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
    final enabled = ref.watch(adsEnabledProvider);

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

    final banner = _banner;
    if (banner == null || !_loaded) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        width: double.infinity,
        height: banner.size.height.toDouble(),
        alignment: Alignment.center,
        child: AdWidget(ad: banner),
      ),
    );
  }
}
