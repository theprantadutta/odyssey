import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/config/admob_config.dart';
import '../../../../core/providers/analytics_provider.dart';
import '../../../../core/services/logger_service.dart';
import '../providers/ads_providers.dart';

/// An inline **native** ad styled to sit inside a scrolling list (e.g. between
/// trip cards). Uses Google's "small" native template, themed to the app's
/// surface colour so it blends with surrounding cards.
///
/// Renders nothing for premium users / unsupported platforms / before load, so
/// it can be returned directly from a list builder without reserving space.
///
/// The state is kept alive while the list is scrolled: without that, scrolling
/// an ad tile past the viewport's cache extent disposes its [State], and
/// scrolling back fires a brand new [NativeAd] load. On a list a user scrolls up
/// and down a few times that turns into a stream of ad requests for a handful of
/// actual impressions — wasteful, bad for fill rate, and the kind of request
/// pattern that draws invalid-traffic scrutiny.
class NativeAdListTile extends ConsumerStatefulWidget {
  const NativeAdListTile({super.key, this.margin});

  /// Outer margin, so callers can match the surrounding list item spacing.
  final EdgeInsetsGeometry? margin;

  @override
  ConsumerState<NativeAdListTile> createState() => _NativeAdListTileState();
}

class _NativeAdListTileState extends ConsumerState<NativeAdListTile>
    with AutomaticKeepAliveClientMixin {
  NativeAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  /// Height for the small template. Google's guidance is a minimum of 90 logical
  /// px; the extra headroom keeps the template from clipping at large text
  /// scales. Roughly a third of the "medium" template this replaced, which at
  /// 320px took over half a phone viewport.
  static const double _smallTemplateHeight = 120;

  static final AdRequest _request = AdRequest(
    keywords: const ['travel', 'trips', 'vacation', 'flights', 'hotels'],
  );

  /// Keep the loaded ad alive across scrolls, but only once there's something
  /// worth keeping — an unloaded tile has no state worth the retention.
  @override
  bool get wantKeepAlive => _loaded;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Loading lives here rather than in build(): starting a network request from
    // build() is a side effect in a method that may run many times per frame.
    if (!ref.read(nativeAdsEnabledProvider)) return;
    final scheme = Theme.of(context).colorScheme;
    _load(scheme.surface, scheme.onSurface);
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  void _load(Color background, Color onSurface) {
    // One attempt per tile, ever. A failed load is not retried: the tile simply
    // stays collapsed, which is invisible to the user and costs one request
    // instead of an unbounded stream of them.
    if (_requested || !AdMobConfig.isSupportedPlatform) return;
    _requested = true;

    final ad = NativeAd(
      adUnitId: AdMobConfig.nativeAdUnitId,
      request: _request,
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
        mainBackgroundColor: background,
        cornerRadius: 16,
        primaryTextStyle: NativeTemplateTextStyle(textColor: onSurface),
        secondaryTextStyle: NativeTemplateTextStyle(textColor: onSurface),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _ad = ad as NativeAd;
            _loaded = true;
          });
          // wantKeepAlive just flipped to true; tell the framework.
          updateKeepAlive();
        },
        onPaidEvent: (ad, valueMicros, precision, currencyCode) {
          ref.read(analyticsServiceProvider).trackAdRevenue(
                format: 'native',
                valueMicros: valueMicros,
                currency: currencyCode,
                precision: precision.index,
              );
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          AppLogger.debug('Native ad failed to load: ${error.message}');
        },
      ),
    );
    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    final enabled = ref.watch(nativeAdsEnabledProvider);
    if (!enabled) return const SizedBox.shrink();

    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();

    return Padding(
      padding: widget.margin ?? const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: _smallTemplateHeight,
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
