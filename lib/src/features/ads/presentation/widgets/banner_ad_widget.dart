import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/config/admob_config.dart';
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

  static final AdRequest _request = AdRequest(
    keywords: const ['travel', 'trips', 'vacation', 'flights', 'hotels'],
  );

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  Future<void> _load(double width, Orientation orientation) async {
    if (_loading || _loaded || !AdMobConfig.isSupportedPlatform) return;
    _loading = true;

    final size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
      orientation,
      width.truncate(),
    );
    if (size == null || !mounted) {
      _loading = false;
      return;
    }

    final banner = BannerAd(
      adUnitId: AdMobConfig.bannerAdUnitId,
      size: size,
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
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _loading = false;
          AppLogger.debug('Banner failed to load: ${error.message}');
        },
      ),
    );
    await banner.load();
  }

  void _teardown() {
    _banner?.dispose();
    _banner = null;
    _loaded = false;
    _loading = false;
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

    if (!_loaded && !_loading) {
      final mq = MediaQuery.of(context);
      final width = mq.size.width;
      final orientation = mq.orientation;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(width, orientation);
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
